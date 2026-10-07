"""Almacenamiento de los colegios de prueba: un JSON por colegio.

Lo usan dos procesos distintos —el servicio (`trial.py`, dentro del contenedor)
y el script de carga (`trial_admin.py`, en el host)— sobre el mismo directorio
montado. Por eso toda escritura toma un `flock` sobre `DATA_DIR/.lock` y no un
lock de Python: el del servicio no ve al script ni viceversa.

Solo depende de la biblioteca estándar para que el script corra en el host sin
instalar nada.
"""

from __future__ import annotations

import fcntl
import hashlib
import hmac
import json
import os
import re
import secrets
import unicodedata
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

DATA_DIR = Path(os.environ.get("TRIAL_DATA_DIR", "/data/trial"))

PIN_LENGTH = 6
_PBKDF2_ITERATIONS = 120_000


def colegios_dir() -> Path:
    return DATA_DIR / "colegios"


def colegio_path(colegio_id: str) -> Path:
    if not re.fullmatch(r"[a-z0-9-]{1,64}", colegio_id):
        raise ValueError(f"id de colegio inválido: {colegio_id!r}")
    return colegios_dir() / f"{colegio_id}.json"


@contextmanager
def write_lock() -> Iterator[None]:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    with open(DATA_DIR / ".lock", "a") as fh:
        fcntl.flock(fh, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(fh, fcntl.LOCK_UN)


def load(colegio_id: str) -> dict:
    with open(colegio_path(colegio_id), encoding="utf-8") as fh:
        return json.load(fh)


def save(colegio: dict) -> None:
    """Escribe a un temporal y renombra: quien lea nunca ve un JSON a medias."""
    path = colegio_path(colegio["id"])
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".json.tmp")
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(colegio, fh, ensure_ascii=False, indent=2)
        fh.flush()
        os.fsync(fh.fileno())
    os.chmod(tmp, 0o600)
    os.replace(tmp, path)


def all_ids() -> list[str]:
    if not colegios_dir().exists():
        return []
    return sorted(p.stem for p in colegios_dir().glob("*.json"))


def normalize_correo(correo: str) -> str:
    return correo.strip().lower()


def find_user(correo: str) -> tuple[dict, dict] | None:
    """(colegio, usuario) dueño de ese correo, o None."""
    correo = normalize_correo(correo)
    for colegio_id in all_ids():
        colegio = load(colegio_id)
        for usuario in colegio.get("usuarios", []):
            if usuario["correo"] == correo:
                return colegio, usuario
    return None


def new_pin() -> str:
    return "".join(secrets.choice("0123456789") for _ in range(PIN_LENGTH))


def hash_pin(pin: str, salt: str | None = None) -> dict:
    salt = salt or secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256", pin.encode(), bytes.fromhex(salt), _PBKDF2_ITERATIONS
    )
    return {"pin_salt": salt, "pin_hash": digest.hex()}


def check_pin(usuario: dict, pin: str) -> bool:
    expected = hash_pin(pin, usuario["pin_salt"])["pin_hash"]
    return hmac.compare_digest(expected, usuario["pin_hash"])


def secret() -> bytes:
    """Clave de firma de los tokens. Se crea sola la primera vez.

    Vive junto a los datos y no en `.env` para que no haya que tocar la
    configuración del contenedor: si se borra, los tokens vigentes dejan de
    servir y basta con volver a entrar con el PIN.
    """
    path = DATA_DIR / ".secret"
    try:
        return bytes.fromhex(path.read_text().strip())
    except FileNotFoundError:
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        value = secrets.token_hex(32)
        try:
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        except FileExistsError:
            return bytes.fromhex(path.read_text().strip())
        with os.fdopen(fd, "w") as fh:
            fh.write(value)
        return bytes.fromhex(value)


def slugify(nombre: str) -> str:
    plain = unicodedata.normalize("NFKD", nombre).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z0-9]+", "-", plain.lower()).strip("-")[:64]


_ORDINALES = {
    "primero": 1, "segundo": 2, "tercero": 3, "cuarto": 4,
    "quinto": 5, "sexto": 6, "septimo": 7, "octavo": 8,
}


def normalize_curso(raw: str) -> str | None:
    """Lleva el curso a la forma de Anahuac (`2°A`), o None si no se reconoce.

    La app saca el nivel del curso con `\\d+` para elegir las lecturas, así que
    lo único imprescindible es que el número quede primero. «2° Básico A»,
    «2B», «2 básico b» y «Segundo A» terminan todos en `2°A`/`2°B`.
    """
    # NFKD convierte el ordinal «º» en una «o», que después se leía como la
    # letra del curso: «1º Básico A» quedaba en `1°O`.
    raw = re.sub(r"[º°ª]", " ", str(raw))
    plain = unicodedata.normalize("NFKD", raw).encode("ascii", "ignore").decode()
    plain = re.sub(r"\b(basico|ano)\b", " ", plain.lower())
    # Las lecturas son de básica: un «1° medio» no puede caer en 1° básico.
    if "medio" in plain:
        return None
    nivel = None
    match = re.search(r"\d+", plain)
    if match:
        nivel = int(match.group())
        rest = plain[match.end():]
    else:
        for palabra, n in _ORDINALES.items():
            if palabra in plain:
                nivel = n
                rest = plain.split(palabra, 1)[1]
                break
    if nivel is None or not 1 <= nivel <= 8:
        return None
    letra = re.search(r"\b([a-z])\b", rest)
    return f"{nivel}°{letra.group(1).upper()}" if letra else f"{nivel}°"
