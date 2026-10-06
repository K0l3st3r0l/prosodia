"""Pruebas de los endpoints de colegios de prueba.

Corren dentro de la imagen del servicio (tiene fastapi y httpx), sin cargar el
modelo Whisper:

    docker run --rm -v "$PWD":/app -w /app whisper-whisper python test_trial.py
"""

import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

os.environ["TRIAL_DATA_DIR"] = tempfile.mkdtemp()
os.environ["WHISPER_API_KEY"] = "test-key"

from fastapi import FastAPI  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

import trial  # noqa: E402
import trial_store as store  # noqa: E402

KEY = {"X-API-Key": "test-key"}

app = FastAPI()
app.include_router(trial.router)
client = TestClient(app)


def admin(*args: str) -> str:
    return subprocess.run(
        [sys.executable, "trial_admin.py", *args],
        check=True, capture_output=True, text=True,
    ).stdout


def result(**overrides) -> dict:
    base = {
        "id": f"r-{time.time_ns()}",
        "alumno_id": 1,
        "alumno": "PÉREZ SOTO Ana",
        "curso": "2°A",
        "fecha": "2026-10-06T10:00:00",
        "lectura_id": 3,
        "lectura": "Tito",
        "palabras_leidas": 80,
        "errores": 2,
        "segundos": 60,
        "pcpm": 78,
        "velocidad": "Rápida",
        "nivel_logro": "Logrado",
        "calidad": "fluida",
        "prosodia": "adecuada",
        "whisper_analizado": True,
    }
    return {**base, **overrides}


class TrialTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        admin("colegio", "Colegio San José")
        csv = Path(os.environ["TRIAL_DATA_DIR"]) / "lista.csv"
        csv.write_text(
            "Listado 2026\n"
            "Curso;Apellido Paterno;Apellido Materno;Nombres\n"
            "2° Básico A;Pérez;Soto;Ana\n"
            "2B;Rojas;;Luis\n"
            "Segundo A;Díaz;Mora;Eva\n"
            "1° Medio A;Lagos;;Iván\n",
            encoding="utf-8",
        )
        cls.alumnos_out = admin("alumnos", "colegio-san-jose", str(csv))
        out = admin("usuario", "colegio-san-jose", "Profe@Colegio.cl", "--nombre", "Ana")
        cls.pin = out.split("PIN: ")[1].split()[0]

    def setUp(self):
        trial._fails.clear()

    def login(self, correo="profe@colegio.cl", pin=None, **headers):
        return client.post(
            "/trial/login",
            json={"correo": correo, "pin": pin or self.pin},
            headers={**KEY, **headers},
        )

    def test_carga_normaliza_cursos_y_rechaza_media(self):
        alumnos = store.load("colegio-san-jose")["alumnos"]
        self.assertEqual(
            [(a["nombre"], a["curso"]) for a in alumnos],
            [("Díaz Mora Eva", "2°A"), ("Pérez Soto Ana", "2°A"), ("Rojas Luis", "2°B")],
        )
        self.assertIn("1 filas sin nombre", self.alumnos_out)

    def test_recarga_conserva_ids(self):
        before = {a["nombre"]: a["id"] for a in store.load("colegio-san-jose")["alumnos"]}
        csv = Path(os.environ["TRIAL_DATA_DIR"]) / "lista2.csv"
        csv.write_text("Curso,Nombre\n2°A,Pérez Soto Ana\n3°C,Nuevo Alumno\n", encoding="utf-8")
        admin("alumnos", "colegio-san-jose", str(csv))
        after = {a["nombre"]: a["id"] for a in store.load("colegio-san-jose")["alumnos"]}
        self.assertEqual(after["Pérez Soto Ana"], before["Pérez Soto Ana"])
        self.assertNotIn(after["Nuevo Alumno"], before.values())
        # Restituye el listado original para el resto de las pruebas.
        admin("alumnos", "colegio-san-jose", str(Path(os.environ["TRIAL_DATA_DIR"]) / "lista.csv"))

    def test_login_ok_devuelve_alumnos_y_correo_sin_mayusculas(self):
        r = self.login(correo="  PROFE@colegio.cl ")
        self.assertEqual(r.status_code, 200, r.text)
        data = r.json()
        self.assertEqual(data["colegio"]["nombre"], "Colegio San José")
        self.assertEqual(len(data["alumnos"]), 3)
        self.assertNotIn("pin_hash", r.text)

    def test_login_sin_api_key(self):
        r = client.post("/trial/login", json={"correo": "profe@colegio.cl", "pin": self.pin})
        self.assertEqual(r.status_code, 401)

    def test_pin_malo_y_bloqueo(self):
        for _ in range(trial.MAX_FAILS_PER_CORREO):
            self.assertEqual(self.login(pin="000000").status_code, 401)
        # Bloqueado incluso con el PIN correcto.
        self.assertEqual(self.login().status_code, 429)

    def test_bloqueo_por_ip_cubre_muchos_correos(self):
        ip = {"cf-connecting-ip": "203.0.113.9"}
        for i in range(trial.MAX_FAILS_PER_IP):
            self.login(correo=f"x{i}@a.cl", pin="000000", **ip)
        self.assertEqual(self.login(**ip).status_code, 429)
        self.assertEqual(self.login().status_code, 200)

    def test_resultado_se_guarda_una_vez(self):
        token = self.login().json()["token"]
        auth = {**KEY, "Authorization": f"Bearer {token}"}
        body = result()
        r1 = client.post("/trial/results", json=body, headers=auth)
        r2 = client.post("/trial/results", json=body, headers=auth)
        self.assertEqual(r1.json(), {"ok": True, "duplicado": False})
        self.assertEqual(r2.json(), {"ok": True, "duplicado": True})
        guardados = [r for r in store.load("colegio-san-jose")["resultados"] if r["id"] == body["id"]]
        self.assertEqual(len(guardados), 1)
        self.assertEqual(guardados[0]["evaluador"], "profe@colegio.cl")

    def test_resultado_sin_alumno_se_acepta(self):
        token = self.login().json()["token"]
        r = client.post(
            "/trial/results",
            json=result(alumno_id=None, alumno=None),
            headers={**KEY, "Authorization": f"Bearer {token}"},
        )
        self.assertEqual(r.status_code, 200, r.text)

    def test_resultado_alumno_ajeno(self):
        token = self.login().json()["token"]
        r = client.post(
            "/trial/results",
            json=result(alumno_id=999),
            headers={**KEY, "Authorization": f"Bearer {token}"},
        )
        self.assertEqual(r.status_code, 400)

    def test_token_falso_o_vencido(self):
        token = self.login().json()["token"]
        bad = token[:-2] + ("AA" if not token.endswith("AA") else "BB")
        r = client.post("/trial/results", json=result(), headers={**KEY, "Authorization": f"Bearer {bad}"})
        self.assertEqual(r.status_code, 401)
        old = trial.make_token("colegio-san-jose", "profe@colegio.cl", now=time.time() - trial.TOKEN_TTL - 1)
        r = client.post("/trial/results", json=result(), headers={**KEY, "Authorization": f"Bearer {old}"})
        self.assertEqual(r.status_code, 401)

    def test_quitar_usuario_corta_la_sesion(self):
        out = admin("usuario", "colegio-san-jose", "temporal@colegio.cl")
        pin = out.split("PIN: ")[1].split()[0]
        token = self.login(correo="temporal@colegio.cl", pin=pin).json()["token"]
        admin("quitar-usuario", "colegio-san-jose", "temporal@colegio.cl")
        r = client.post("/trial/results", json=result(), headers={**KEY, "Authorization": f"Bearer {token}"})
        self.assertEqual(r.status_code, 401)

    def test_correo_no_se_repite_entre_colegios(self):
        admin("colegio", "Otro Colegio")
        r = subprocess.run(
            [sys.executable, "trial_admin.py", "usuario", "otro-colegio", "profe@colegio.cl"],
            capture_output=True, text=True,
        )
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("otro colegio", r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
