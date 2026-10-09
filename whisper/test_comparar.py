"""Pruebas de la comparación texto esperado ↔ transcripción.

Corren dentro de la imagen del servicio, sin cargar el modelo Whisper:

    docker run --rm -v "$PWD":/app -w /app whisper-whisper python test_comparar.py
"""

import unittest

from main import _comparar

TEXTO = "La paloma come una pera en el sofá de la casa"


class CompararTest(unittest.TestCase):
    def test_lectura_completa_sin_errores(self):
        r = _comparar(TEXTO, TEXTO)
        self.assertEqual(r["palabras_texto"], 11)
        self.assertEqual(r["palabras_leidas"], 11)
        self.assertEqual(r["errores"], 0)
        self.assertEqual(r["palabras_correctas"], 11)

    def test_lectura_cortada_no_cuenta_lo_que_falto(self):
        r = _comparar(TEXTO, "la paloma come una")
        self.assertEqual(r["palabras_texto"], 11)
        self.assertEqual(r["palabras_leidas"], 4)
        self.assertEqual(r["errores"], 0)
        self.assertEqual(r["errores_detalle"], [])

    def test_omision_en_medio_si_es_error(self):
        r = _comparar(TEXTO, "la paloma come pera en el sofá de la casa")
        self.assertEqual(r["palabras_leidas"], 11)
        self.assertEqual(r["errores"], 1)
        self.assertEqual(r["errores_detalle"][0]["tipo"], "omisión")
        self.assertEqual(r["errores_detalle"][0]["indice"], 3)

    def test_sustitucion_al_cortar_cuenta_hasta_ahi(self):
        r = _comparar(TEXTO, "la paloma toma")
        self.assertEqual(r["palabras_leidas"], 3)
        self.assertEqual(r["errores"], 1)
        self.assertEqual(r["palabras_correctas"], 2)

    def test_adiciones_no_son_error(self):
        r = _comparar(TEXTO, "la paloma eh come una pera")
        self.assertEqual(r["palabras_leidas"], 5)
        self.assertEqual(r["errores"], 0)

    def test_transcripcion_vacia(self):
        r = _comparar(TEXTO, "")
        self.assertEqual(r["palabras_leidas"], 0)
        self.assertEqual(r["errores"], 0)
        self.assertEqual(r["palabras_correctas"], 0)

    def test_correctas_igual_que_antes(self):
        # Antes: leídas = total del texto y lo no leído contaba como omisión.
        # Las correctas —y por tanto el PCPM— no pueden cambiar.
        casos = [
            "la paloma come una",
            "la paloma toma una pera en el sillón",
            "la come una pera el sofá casa",
            "la paloma toma",
            "subtítulos realizados por la comunidad de amara org",
            "",
            TEXTO,
        ]
        for transcrito in casos:
            r = _comparar(TEXTO, transcrito)
            self.assertEqual(r["palabras_correctas"], _correctas_antes(TEXTO, transcrito), transcrito)


def _correctas_antes(esperado: str, transcrito: str) -> int:
    """La cuenta anterior a 2026-10-09, para comparar."""
    import difflib
    import re

    esp = re.findall(r"\b\w+\b", esperado.lower())
    got = re.findall(r"\b\w+\b", transcrito.lower())
    errores = 0
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, esp, got).get_opcodes():
        if tag == "replace":
            errores += i2 - i1
        elif tag == "delete":
            errores += i2 - i1
    return max(0, len(esp) - errores)


if __name__ == "__main__":
    unittest.main()
