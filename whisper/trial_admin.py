#!/usr/bin/env python3
"""Administra los colegios de prueba de ProsodIA desde el host.

    python3 whisper/trial_admin.py colegio "Colegio San José"
    python3 whisper/trial_admin.py alumnos colegio-san-jose listado.xlsx
    python3 whisper/trial_admin.py usuario colegio-san-jose profe@colegio.cl --nombre "Ana Pérez"
    python3 whisper/trial_admin.py quitar-usuario colegio-san-jose profe@colegio.cl
    python3 whisper/trial_admin.py ver [colegio-san-jose]

El Excel/CSV necesita el nombre, ya sea en una columna «nombre» o repartido en
«nombres» + «apellidos» (o paterno/materno), y el curso: como columna, en una
celda «Curso:» sobre los encabezados o como nombre de la hoja. Se leen todas
las hojas salvo que se indique `--hoja`.
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

os.environ.setdefault("TRIAL_DATA_DIR", "/root/apps/prosodia-data/trial")

import trial_store as store  # noqa: E402


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _key(text: str) -> str:
    plain = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return " ".join(plain.lower().split())


def _read_sheets(path: Path, hoja: str | None) -> list[tuple[str, list[list[str]]]]:
    """(título, filas) de cada hoja. Sin `--hoja` se leen todas: los colegios
    suelen mandar un curso por hoja."""
    if path.suffix.lower() in (".xlsx", ".xlsm"):
        import openpyxl

        wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
        sheets = [wb[hoja]] if hoja else wb.worksheets
        return [
            (ws.title, [
                ["" if c is None else str(c).strip() for c in row]
                for row in ws.iter_rows(values_only=True)
            ])
            for ws in sheets
        ]
    with open(path, encoding="utf-8-sig", newline="") as fh:
        sample = fh.read(4096)
        fh.seek(0)
        # `csv.Sniffer` se rinde con la fila de título que traen los listados
        # exportados; contar separadores basta.
        delimiter = max(";,\t", key=sample.count)
        return [(path.stem, [[c.strip() for c in row] for row in csv.reader(fh, delimiter=delimiter)])]


def _sheet_curso(title: str, above: list[list[str]]) -> str | None:
    """Curso de toda la hoja, cuando no viene por fila: una celda «Curso:» con
    el valor al lado, sobre los encabezados, o si no el nombre de la hoja."""
    for row in above:
        for j, cell in enumerate(row):
            if _key(cell).startswith("curso"):
                valor = next((c for c in row[j + 1:] if c), "")
                if store.normalize_curso(valor):
                    return valor
    return title if store.normalize_curso(title) else None


def _find_header(rows: list[list[str]]) -> tuple[int, dict[str, int]] | None:
    """Primera fila con algo de nombre; el Excel suele traer títulos o filas
    vacías antes de los encabezados. El curso puede venir como columna o
    para toda la hoja (ver `_sheet_curso`)."""
    for i, row in enumerate(rows[:20]):
        cols = {_key(c): j for j, c in enumerate(row) if c}
        found: dict[str, int] = {}
        for name, j in cols.items():
            if "curso" in name:
                found.setdefault("curso", j)
            elif "paterno" in name:
                found.setdefault("paterno", j)
            elif "materno" in name:
                found.setdefault("materno", j)
            elif name.startswith("apellido"):
                found.setdefault("apellidos", j)
            elif name.startswith("nombres") or name == "nombre social":
                found.setdefault("nombres", j)
            elif name.startswith("nombre"):
                found.setdefault("nombre", j)
        if "nombre" in found or "nombres" in found:
            return i, found
    return None


def _nombre(row: list[str], cols: dict[str, int]) -> str:
    def get(k: str) -> str:
        j = cols.get(k)
        return row[j].strip() if j is not None and j < len(row) else ""

    apellidos = get("apellidos") or " ".join(p for p in (get("paterno"), get("materno")) if p)
    # Mismo orden que la app con los alumnos de Anahuac: apellido primero. Con
    # una sola columna «nombre» se asume que ya trae el nombre completo.
    partes = f"{apellidos} {get('nombres') or get('nombre')}".split()
    # Algunos listados mezclan filas en mayúsculas; en la app se ven gritadas.
    return " ".join(p.title() if p.isupper() else p for p in partes)


def cmd_colegio(args) -> None:
    colegio_id = store.slugify(args.nombre)
    with store.write_lock():
        if store.colegio_path(colegio_id).exists():
            sys.exit(f"Ya existe: {colegio_id}")
        store.save({
            "id": colegio_id,
            "nombre": args.nombre.strip(),
            "creado": _now(),
            "usuarios": [],
            "alumnos": [],
            "resultados": [],
        })
    print(f"Colegio creado: {colegio_id}")


def cmd_alumnos(args) -> None:
    nuevos: list[tuple[str, str]] = []
    rechazados: list[str] = []
    for title, rows in _read_sheets(Path(args.archivo), args.hoja):
        found = _find_header(rows)
        if found is None:
            rechazados.append(f"hoja {title!r}: sin encabezado de nombre")
            continue
        header, cols = found
        curso_hoja = None if "curso" in cols else _sheet_curso(title, rows[:header])
        if "curso" not in cols and curso_hoja is None:
            rechazados.append(f"hoja {title!r}: no encontré el curso")
            continue
        for n, row in enumerate(rows[header + 1:], start=header + 2):
            if not any(row):
                continue
            nombre = _nombre(row, cols)
            if curso_hoja is not None:
                raw_curso = curso_hoja
            else:
                raw_curso = row[cols["curso"]] if cols["curso"] < len(row) else ""
            curso = store.normalize_curso(raw_curso)
            if not nombre or curso is None:
                rechazados.append(f"hoja {title!r} fila {n}: nombre={nombre!r} curso={raw_curso!r}")
                continue
            nuevos.append((nombre, curso))

    # Un archivo que no se pudo leer no puede vaciar el listado que ya estaba.
    if not nuevos:
        sys.exit("No salió ningún alumno; el listado anterior queda igual.\n" + "\n".join(rechazados))

    with store.write_lock():
        colegio = store.load(args.colegio)
        # Se conserva el id de quien ya estaba: los resultados guardados lo
        # referencian, y volver a cargar el Excel no debería desconectarlos.
        previos = {(_key(a["nombre"]), a["curso"]): a["id"] for a in colegio["alumnos"]}
        next_id = max(previos.values(), default=0) + 1
        alumnos = []
        vistos = set()
        for nombre, curso in nuevos:
            k = (_key(nombre), curso)
            if k in vistos:
                continue
            vistos.add(k)
            if k in previos:
                alumno_id = previos[k]
            else:
                alumno_id = next_id
                next_id += 1
            alumnos.append({"id": alumno_id, "nombre": nombre, "curso": curso})
        alumnos.sort(key=lambda a: (a["curso"], _key(a["nombre"])))
        colegio["alumnos"] = alumnos
        colegio["alumnos_actualizado"] = _now()
        store.save(colegio)

    cursos: dict[str, int] = {}
    for a in alumnos:
        cursos[a["curso"]] = cursos.get(a["curso"], 0) + 1
    print(f"{len(alumnos)} alumnos en {args.colegio}:")
    for curso, n in sorted(cursos.items()):
        print(f"  {curso}: {n}")
    if rechazados:
        print(f"{len(rechazados)} filas sin nombre o con curso no reconocido:")
        for r in rechazados:
            print(f"  {r}")


def cmd_usuario(args) -> None:
    correo = store.normalize_correo(args.correo)
    if "@" not in correo:
        sys.exit("El correo no parece válido.")
    pin = store.new_pin()
    with store.write_lock():
        owner = store.find_user(correo)
        if owner and owner[0]["id"] != args.colegio:
            sys.exit(f"Ese correo ya está en otro colegio: {owner[0]['id']}")
        colegio = store.load(args.colegio)
        usuarios = [u for u in colegio["usuarios"] if u["correo"] != correo]
        previo = next((u for u in colegio["usuarios"] if u["correo"] == correo), None)
        usuarios.append({
            "correo": correo,
            "nombre": args.nombre or (previo or {}).get("nombre"),
            **store.hash_pin(pin),
            "pin_creado": _now(),
        })
        colegio["usuarios"] = usuarios
        store.save(colegio)
    accion = "PIN nuevo para" if previo else "Usuario creado:"
    print(f"{accion} {correo} ({args.colegio})")
    print(f"PIN: {pin}")
    print("Este PIN no se puede volver a ver: anótalo ahora.")


def cmd_quitar_usuario(args) -> None:
    correo = store.normalize_correo(args.correo)
    with store.write_lock():
        colegio = store.load(args.colegio)
        antes = len(colegio["usuarios"])
        colegio["usuarios"] = [u for u in colegio["usuarios"] if u["correo"] != correo]
        if len(colegio["usuarios"]) == antes:
            sys.exit("Ese correo no está en el colegio.")
        store.save(colegio)
    print(f"Quitado {correo}. Su sesión abierta deja de servir de inmediato.")


def cmd_ver(args) -> None:
    ids = [args.colegio] if args.colegio else store.all_ids()
    if not ids:
        print(f"Sin colegios en {store.DATA_DIR}")
    for colegio_id in ids:
        c = store.load(colegio_id)
        print(f"{c['id']} — {c['nombre']}")
        print(f"  alumnos: {len(c['alumnos'])}  resultados: {len(c.get('resultados', []))}")
        for u in c["usuarios"]:
            print(f"  usuario: {u['correo']}  {u.get('nombre') or ''}")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("colegio", help="crear un colegio")
    s.add_argument("nombre")
    s.set_defaults(fn=cmd_colegio)

    s = sub.add_parser("alumnos", help="cargar (reemplazar) el listado desde Excel o CSV")
    s.add_argument("colegio")
    s.add_argument("archivo")
    s.add_argument("--hoja")
    s.set_defaults(fn=cmd_alumnos)

    s = sub.add_parser("usuario", help="crear usuario o generarle un PIN nuevo")
    s.add_argument("colegio")
    s.add_argument("correo")
    s.add_argument("--nombre")
    s.set_defaults(fn=cmd_usuario)

    s = sub.add_parser("quitar-usuario", help="quitar acceso a un usuario")
    s.add_argument("colegio")
    s.add_argument("correo")
    s.set_defaults(fn=cmd_quitar_usuario)

    s = sub.add_parser("ver", help="resumen de colegios")
    s.add_argument("colegio", nargs="?")
    s.set_defaults(fn=cmd_ver)

    args = p.parse_args()
    args.fn(args)


if __name__ == "__main__":
    main()
