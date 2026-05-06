import os
import requests
import re
import unicodedata
import time
from pathlib import Path

# Configuración
OUTPUT_DIR = Path('/root/apps/prosodia/assets/reading_covers')
WIDTH = 960
HEIGHT = 540
STYLE = "Digital children's book illustration, vibrant colors, soft lighting, clean lines, friendly characters, minimalist but detailed background, 2D art"

STORIES = [
    ('1', 'El perro y la pelota', "A small happy brown dog with long ears jumping with a red ball in its mouth by a sparkling river"),
    ('1', 'La mochila azul', "A little girl named Martina with a bright blue backpack in a sunny school patio, a pencil on the ground"),
    ('1', 'Las nubes de algodón', "A girl and her brother looking through a window at white fluffy clouds shaped like a rabbit and a fish in a blue sky"),
    ('2', 'La semilla mágica', "A girl named Ana planting a sunflower seed in a pot on a kitchen table with her grandmother, warm sunlight"),
    ('2', 'El cuaderno viajero', "A boy named Benjamin writing in a special notebook about cooking with his grandfather, cozy home interior"),
    ('2', 'La feria del barrio', "A colorful neighborhood street market with stalls of fresh fruits and vegetables, a girl smelling a branch of basil"),
    ('3', 'El faro del cabo', "An old lighthouse on a cliff during a stormy night, a bright beam of light cutting through the rain"),
    ('3', 'La carta para el abuelo', "A girl putting a yellow envelope into a red mailbox, sunny day, clear handwriting on the letter"),
    ('3', 'El puente de madera', "A small wooden bridge over a narrow stream, a young boy pointing at a loose plank, school path"),
    ('4', 'El mercado de los sabores', "A bustling market stall with colorful jars of exotic jams like pumpkin and raspberry, a curious girl tasting one"),
    ('4', 'El taller de volantines', "A library workshop where children and grandparents are building colorful kites (volantines) with paper and sticks"),
    ('4', 'La isla de los pingüinos', "A group of penguins on a rocky beach of a small island, distant humans watching from a path"),
    ('5', 'El río que olvidó su camino', "A young girl and neighbors digging a small canal in a dry valley to bring water back to the fields"),
    ('5', 'La fotógrafa del humedal', "A girl with a vintage camera waiting patiently among tall reeds in a wetland to photograph a small heron"),
    ('5', 'La ruta del agua', "Water traveling from a reservoir through a treatment plant to a house, educational and friendly"),
    ('6', 'La biblioteca de las estrellas', "An astronomer woman looking through a large telescope in an observatory in the Atacama desert under a starry sky"),
    ('6', 'La brigada del cerro', "A group of students with gloves and bags cleaning up a green hill, placing trash in containers"),
    ('6', 'El viaje de la quínoa', "Quinoa plants growing in the high Andes mountains under a bright sun, traditional clay pots with seeds"),
    ('7', 'Cuando la ciudad escucha', "Students with microphones and notebooks recording sounds in a busy city street with buses and a market"),
    ('7', 'La bitácora del canal', "An old handwritten diary with sketches of a canal construction, engineers and workers in the background"),
    ('7', 'La discusión del huerto', "Children in a school garden discussing whether to plant lettuce or flowers, a teacher listening"),
    ('8', 'El archivo bajo la lluvia', "A girl interviewing an archivist in a room filled with old maps and boxes of documents, rainy window"),
    ('8', 'Energía para el invierno', "A cozy house in southern Chile with insulated windows and curtains, a fireplace, snow outside"),
    ('8', 'La última entrevista', "An old inventor in his workshop filled with opened radios and clocks, talking to a young student journalist"),
]

def slugify(text: str) -> str:
    normalized = unicodedata.normalize('NFKD', text)
    ascii_text = ''.join(ch for ch in normalized if not unicodedata.combining(ch))
    clean = re.sub(r'[^a-zA-Z0-9]+', '_', ascii_text.lower()).strip('_')
    return re.sub(r'_+', '_', clean)

def download_image(level, title, prompt):
    filename = f"{level}_{slugify(title)}.png"
    filepath = OUTPUT_DIR / filename
    
    if filepath.exists() and filepath.stat().st_size > 10000:
        print(f"Skipping {filename}, already exists and looks valid.")
        return True

    full_prompt = f"{prompt}, {STYLE}"
    encoded_prompt = requests.utils.quote(full_prompt)
    url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width={WIDTH}&height={HEIGHT}&seed={hash(title) % 1000}&nologo=true&enhance=true"
    
    retries = 3
    for attempt in range(retries):
        print(f"Downloading {filename} (Attempt {attempt+1})...")
        try:
            response = requests.get(url, timeout=60)
            if response.status_code == 200:
                with open(filepath, 'wb') as f:
                    f.write(response.content)
                print(f"Successfully saved to {filepath}")
                return True
            elif response.status_code == 429:
                print(f"Rate limited (429). Waiting longer...")
                time.sleep(20)
            else:
                print(f"Failed with status {response.status_code}")
        except Exception as e:
            print(f"Error: {e}")
        
        time.sleep(5 * (attempt + 1))
    
    return False

def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    # Remove the invalid HTML files first to be safe
    for f in OUTPUT_DIR.glob("*.png"):
        if f.stat().st_size < 10000:
            f.unlink()
            
    for level, title, prompt in STORIES:
        success = download_image(level, title, prompt)
        if success:
            time.sleep(5) # Delay to be nice to the API

if __name__ == "__main__":
    main()
