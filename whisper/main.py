import os
import re
import tempfile
import difflib
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from faster_whisper import WhisperModel

from trial import router as trial_router

API_KEY = os.environ.get("WHISPER_API_KEY", "")
MODEL_SIZE = os.environ.get("WHISPER_MODEL", "small")

model: WhisperModel | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global model
    print(f"Cargando modelo Whisper '{MODEL_SIZE}'...")
    model = WhisperModel(MODEL_SIZE, device="cpu", compute_type="int8")
    print("Modelo listo.")
    yield


app = FastAPI(title="ProsodIA Whisper Service", lifespan=lifespan)

app.include_router(trial_router)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)


def _tokenizar(texto: str) -> list[str]:
    return re.findall(r"\b\w+\b", texto.lower())


# Una palabra de los textos de básica leída por sílabas no pasa de ~6 trozos.
_MAX_SILABAS = 6


def _unir_silabas(palabras_esperadas: list[str], palabras_transcritas: list[str]) -> tuple[list[str], int]:
    """Junta los trozos consecutivos que forman una palabra del texto.

    Un niño que lee "pa-lo-ma" leyó bien "paloma", pero Whisper lo transcribe en
    trozos y cada uno contaba como error: el PCPM de los lectores silábicos de
    1°-2° caía a menos de la mitad. Solo se une si el resultado es una palabra
    que está en el texto; la más larga gana.
    """
    vocabulario = set(palabras_esperadas)
    unidas = []
    n_unidas = 0
    j = 0
    while j < len(palabras_transcritas):
        for k in range(min(_MAX_SILABAS, len(palabras_transcritas) - j), 1, -1):
            candidata = "".join(palabras_transcritas[j:j + k])
            if candidata in vocabulario:
                unidas.append(candidata)
                n_unidas += 1
                j += k
                break
        else:
            unidas.append(palabras_transcritas[j])
            j += 1
    return unidas, n_unidas


def _comparar(esperado: str, transcrito: str) -> dict:
    palabras_esperadas = _tokenizar(esperado)
    palabras_transcritas = _tokenizar(transcrito)
    unidas, n_unidas = _unir_silabas(palabras_esperadas, palabras_transcritas)

    resultado = _alinear(palabras_esperadas, palabras_transcritas)
    if n_unidas:
        # Unir trozos nunca debe empeorar la lectura: si por azar junta dos
        # palabras que el niño sí leyó separadas, se queda la cuenta original.
        con_silabas = _alinear(palabras_esperadas, unidas)
        if con_silabas["palabras_correctas"] > resultado["palabras_correctas"]:
            resultado = con_silabas
        else:
            n_unidas = 0
    resultado["palabras_por_silabas"] = n_unidas
    return resultado


def _alinear(palabras_esperadas: list[str], palabras_transcritas: list[str]) -> dict:
    matcher = difflib.SequenceMatcher(None, palabras_esperadas, palabras_transcritas)
    errores = []
    # Última palabra del texto que el alumno alcanzó a decir, bien o mal.
    ultima_leida = -1

    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "equal":
            ultima_leida = i2 - 1
        elif tag == "replace":
            esp = palabras_esperadas[i1:i2]
            got = palabras_transcritas[j1:j2]
            for k in range(max(len(esp), len(got))):
                e = esp[k] if k < len(esp) else None
                g = got[k] if k < len(got) else None
                idx = (i1 + k) if k < len(esp) else None
                if e and g:
                    errores.append({"tipo": "sustitución", "esperado": e, "leído": g, "indice": idx})
                    ultima_leida = idx
                elif e:
                    errores.append({"tipo": "omisión", "esperado": e, "leído": None, "indice": idx})
                else:
                    errores.append({"tipo": "adición", "esperado": None, "leído": g, "indice": None})
        elif tag == "delete":
            for offset, w in enumerate(palabras_esperadas[i1:i2]):
                errores.append({"tipo": "omisión", "esperado": w, "leído": None, "indice": i1 + offset})
        elif tag == "insert":
            for w in palabras_transcritas[j1:j2]:
                errores.append({"tipo": "adición", "esperado": None, "leído": w, "indice": None})

    # Lo que queda después de la última palabra dicha no se leyó: la lectura se
    # cortó ahí (el docente detuvo el cronómetro). Contarlo como omisión no
    # cambia el PCPM, pero inflaba "palabras leídas" al total del texto y con
    # eso el PPM salía como si el alumno hubiera terminado.
    errores = [
        e for e in errores
        if e["tipo"] == "adición" or e["indice"] <= ultima_leida
    ]

    # Solo sustituciones y omisiones cuentan como error en fluidez lectora
    n_errores = sum(1 for e in errores if e["tipo"] in ("sustitución", "omisión"))
    palabras_leidas = ultima_leida + 1

    return {
        "palabras_leidas": palabras_leidas,
        "palabras_texto": len(palabras_esperadas),
        "errores": n_errores,
        "palabras_correctas": max(0, palabras_leidas - n_errores),
        "errores_detalle": errores[:60],
    }


@app.get("/health")
def health():
    return {"status": "ok", "model": MODEL_SIZE, "ready": model is not None}


@app.post("/transcribe")
async def transcribe(
    audio: UploadFile = File(...),
    texto_esperado: str = Form(...),
    x_api_key: str = Header(...),
):
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Unauthorized")

    if model is None:
        raise HTTPException(status_code=503, detail="Modelo aún no listo")

    audio_bytes = await audio.read()

    with tempfile.NamedTemporaryFile(suffix=".m4a", delete=False) as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name

    try:
        segments, info = model.transcribe(
            tmp_path,
            language="es",
            beam_size=5,
            vad_filter=True,
        )
        transcript = " ".join(seg.text.strip() for seg in segments).strip()
        comparacion = _comparar(texto_esperado, transcript)

        return {
            "transcript": transcript,
            "language": info.language,
            "language_probability": round(info.language_probability, 3),
            **comparacion,
        }
    finally:
        Path(tmp_path).unlink(missing_ok=True)
