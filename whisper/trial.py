"""Colegios de prueba: entrar con correo + PIN, recibir el listado de alumnos y
respaldar cada resultado en el JSON del colegio.

Va aparte de Anahuac a propósito: son alumnos de otro colegio y no tienen por
qué quedar en esa base. Ver wiki/projects/prosodia/decisions/modo-prueba.md.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time
from datetime import datetime, timezone

from fastapi import APIRouter, Header, HTTPException, Request
from pydantic import BaseModel, Field

import trial_store as store

API_KEY = os.environ.get("WHISPER_API_KEY", "")

# Una jornada de prueba. Lo que no alcance a enviarse queda en la tablet y sale
# la próxima vez que se entre con el PIN.
TOKEN_TTL = 12 * 3600

# El PIN es de 6 dígitos: sin tope de intentos se adivina por fuerza bruta.
MAX_FAILS_PER_CORREO = 5
MAX_FAILS_PER_IP = 20
LOCK_SECONDS = 15 * 60

router = APIRouter(prefix="/trial")

_fails: dict[str, list[float]] = {}


def _recent_fails(key: str, now: float) -> list[float]:
    recent = [t for t in _fails.get(key, []) if now - t < LOCK_SECONDS]
    _fails[key] = recent
    return recent


def _client_ip(request: Request) -> str:
    # Cloudflare → NPM → contenedor: la IP real viene en cabecera.
    return (
        request.headers.get("cf-connecting-ip")
        or request.headers.get("x-real-ip")
        or (request.client.host if request.client else "?")
    )


def _check_api_key(x_api_key: str) -> None:
    if not API_KEY or not hmac.compare_digest(x_api_key, API_KEY):
        raise HTTPException(status_code=401, detail="Unauthorized")


def _b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _unb64(text: str) -> bytes:
    return base64.urlsafe_b64decode(text + "=" * (-len(text) % 4))


def make_token(colegio_id: str, correo: str, now: float | None = None) -> str:
    payload = _b64(json.dumps({
        "c": colegio_id,
        "u": correo,
        "exp": int((now or time.time()) + TOKEN_TTL),
    }).encode())
    firma = _b64(hmac.new(store.secret(), payload.encode(), hashlib.sha256).digest())
    return f"{payload}.{firma}"


def read_token(authorization: str) -> dict:
    """Payload del token, o 401. Revalida que el usuario siga existiendo: quitar
    a alguien del JSON le corta el acceso sin esperar a que venza."""
    try:
        scheme, token = authorization.split(" ", 1)
        payload, firma = token.split(".", 1)
        expected = _b64(hmac.new(store.secret(), payload.encode(), hashlib.sha256).digest())
        if scheme.lower() != "bearer" or not hmac.compare_digest(firma, expected):
            raise ValueError
        data = json.loads(_unb64(payload))
    except Exception:
        raise HTTPException(status_code=401, detail="Sesión de prueba inválida")
    if data["exp"] < time.time():
        raise HTTPException(status_code=401, detail="La sesión de prueba venció")
    found = store.find_user(data["u"])
    if found is None or found[0]["id"] != data["c"]:
        raise HTTPException(status_code=401, detail="Usuario de prueba no encontrado")
    return data


class LoginBody(BaseModel):
    correo: str = Field(max_length=200)
    pin: str = Field(max_length=20)


@router.post("/login")
def login(body: LoginBody, request: Request, x_api_key: str = Header("")):
    _check_api_key(x_api_key)
    correo = store.normalize_correo(body.correo)
    ip = _client_ip(request)
    now = time.time()

    if (
        len(_recent_fails(f"c:{correo}", now)) >= MAX_FAILS_PER_CORREO
        or len(_recent_fails(f"ip:{ip}", now)) >= MAX_FAILS_PER_IP
    ):
        raise HTTPException(
            status_code=429,
            detail="Demasiados intentos. Espera 15 minutos e intenta de nuevo.",
        )

    found = store.find_user(correo)
    if found is None or not store.check_pin(found[1], body.pin.strip()):
        _fails.setdefault(f"c:{correo}", []).append(now)
        _fails.setdefault(f"ip:{ip}", []).append(now)
        raise HTTPException(status_code=401, detail="Correo o PIN incorrectos.")

    _fails.pop(f"c:{correo}", None)
    colegio, usuario = found
    return {
        "token": make_token(colegio["id"], correo, now),
        "colegio": {"id": colegio["id"], "nombre": colegio["nombre"]},
        "usuario": {"correo": correo, "nombre": usuario.get("nombre")},
        "alumnos": colegio.get("alumnos", []),
    }


class ResultBody(BaseModel):
    # Lo genera la tablet: si la respuesta se pierde y reintenta, no se duplica.
    id: str = Field(min_length=1, max_length=64)
    alumno_id: int | None = None
    alumno: str | None = Field(None, max_length=200)
    curso: str = Field(max_length=40)
    fecha: str = Field(max_length=40)
    lectura_id: int | None = None
    lectura: str | None = Field(None, max_length=200)
    palabras_leidas: int
    errores: int
    segundos: float
    pcpm: float
    velocidad: str = Field(max_length=60)
    nivel_logro: str = Field(max_length=60)
    calidad: str = Field(max_length=60)
    prosodia: str = Field(max_length=60)
    transcripcion: str | None = Field(None, max_length=8000)
    whisper_analizado: bool = False
    app_build: int | None = None


@router.post("/results")
def save_result(
    body: ResultBody,
    authorization: str = Header(""),
    x_api_key: str = Header(""),
):
    _check_api_key(x_api_key)
    token = read_token(authorization)

    with store.write_lock():
        colegio = store.load(token["c"])
        resultados = colegio.setdefault("resultados", [])
        if any(r["id"] == body.id for r in resultados):
            return {"ok": True, "duplicado": True}
        if body.alumno_id is not None and not any(
            a["id"] == body.alumno_id for a in colegio.get("alumnos", [])
        ):
            raise HTTPException(status_code=400, detail="El alumno ya no está en el listado")
        resultados.append({
            **body.model_dump(),
            "evaluador": token["u"],
            "recibido": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        })
        store.save(colegio)
    return {"ok": True, "duplicado": False}
