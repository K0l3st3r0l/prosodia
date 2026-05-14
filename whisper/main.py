import os
import re
import tempfile
import difflib
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, File, Form, Header, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from faster_whisper import WhisperModel

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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)


def _tokenizar(texto: str) -> list[str]:
    return re.findall(r"\b\w+\b", texto.lower())


def _comparar(esperado: str, transcrito: str) -> dict:
    palabras_esperadas = _tokenizar(esperado)
    palabras_transcritas = _tokenizar(transcrito)

    matcher = difflib.SequenceMatcher(None, palabras_esperadas, palabras_transcritas)
    errores = []

    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == "replace":
            esp = palabras_esperadas[i1:i2]
            got = palabras_transcritas[j1:j2]
            for k in range(max(len(esp), len(got))):
                e = esp[k] if k < len(esp) else None
                g = got[k] if k < len(got) else None
                idx = (i1 + k) if k < len(esp) else None
                if e and g:
                    errores.append({"tipo": "sustitución", "esperado": e, "leído": g, "indice": idx})
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

    # Solo sustituciones y omisiones cuentan como error en fluidez lectora
    n_errores = sum(1 for e in errores if e["tipo"] in ("sustitución", "omisión"))
    palabras_leidas = len(palabras_esperadas)

    return {
        "palabras_leidas": palabras_leidas,
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
