"""Reading covers generated with Codex's built-in `image_gen` tool.

Runs against the ChatGPT subscription (no OPENAI_API_KEY), ~40 s per image.
Replaces the Pollinations/"sana" covers of `generate_ai_covers.py`: those had
mixed styles and often missed the story (the dog without the ball, quinoa in
flower pots).

Usage:
    python3 scripts/generate_codex_covers.py              # missing covers only
    python3 scripts/generate_codex_covers.py --force      # regenerate all
    python3 scripts/generate_codex_covers.py el_zapatero  # filter by slug
    python3 scripts/generate_codex_covers.py --recrop     # re-crop saved raws

Raw PNGs are kept in build/cover_raw/ so the crop can be adjusted without
spending another generation.
"""

import argparse
import glob
import os
import re
import subprocess
import sys
import time
import unicodedata
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / 'assets' / 'reading_covers'
RAW_DIR = ROOT / 'build' / 'cover_raw'
CODEX_BIN = os.getenv('CODEX_BIN', '/root/.local/bin/codex')
CODEX_HOME = Path(os.getenv('CODEX_HOME', os.path.expanduser('~/.codex')))
# The configured default (gpt-6-sol) is rejected with a ChatGPT account; the
# text model only drives the tool call, so the cheapest one is enough.
CODEX_MODEL = os.getenv('CODEX_MODEL', 'gpt-5.6-luna')
TIMEOUT_S = 300

WIDTH, HEIGHT = 960, 540
JPEG_QUALITY = 86

# One art direction for the whole library so the gallery reads as a series.
# The gallery crops each cover to cards between 1.6:1 and 2.3:1, hence the
# instruction to keep the subject in the central band.
STYLE = (
    "Children's picture-book illustration in gouache and colored pencil, "
    'with a subtle paper texture. Warm, luminous and harmonious palette, soft '
    'natural light, gentle rounded shapes, friendly characters with simple '
    'expressive faces. Chilean setting and everyday details. '
    'Wide landscape format (3:2). Keep the main subject and every character '
    "fully inside the central horizontal band of the image, leaving calm sky, "
    'wall or ground above and below, because the image will be cropped into a '
    'wide banner. Clear focal point, readable at small size. '
    'Absolutely no text, letters, numbers, writing, logos, signatures, frames '
    'or watermarks anywhere in the image.'
)

AUDIENCE = {
    '1': 'Audience: 6-7 year olds. Big simple shapes, few elements.',
    '2': 'Audience: 7-8 year olds. Big simple shapes, few elements.',
    '3': 'Audience: 8-9 year olds.',
    '4': 'Audience: 9-10 year olds.',
    '5': 'Audience: 10-11 year olds. Slightly more detailed.',
    '6': 'Audience: 11-12 year olds. Slightly more detailed.',
    '7': 'Audience: 12-13 year olds. More mature and less cartoonish, still illustrated.',
    '8': 'Audience: 13-14 year olds. More mature and less cartoonish, still illustrated.',
}

# (nivel, titulo, scene, vertical_focus) — vertical_focus is the crop center
# as a fraction of the height (0.5 = middle).
COVERS = [
    ('1', 'El perro y la pelota',
     'Tito, a small cheerful brown dog with long floppy ears and wet fur, '
     'stepping out of a clear shallow river onto the grassy bank with a red '
     'ball held in his mouth, wagging his tail. His young owner kneels on the '
     'bank with open arms, ready to hug him. Sunny afternoon.', 0.5),
    ('1', 'La mochila azul',
     'A sunny Chilean school patio. A boy (Diego) runs toward a smiling girl '
     '(Martina) to hand her back a yellow pencil. Martina wears a bright blue '
     'backpack that is slightly open.', 0.5),
    ('1', 'Las nubes de algodón',
     'A girl (Sofía) and her little brother (Tomás) leaning out of an open '
     'window, laughing and pointing at big fluffy white clouds in a blue sky: '
     'one cloud shaped like a rabbit, one like a slow boat and one like a fish.',
     0.5),
    ('1', 'La paloma y la pera',
     'A gray dove perched on a pine branch beside its round twig nest. Below '
     'the pine, in a small home garden, a mother and a father drink juice from '
     'glasses at a little table while their child happily holds a big green '
     'pear. Early evening, a pale full moon rising in a soft sky.', 0.0),
    ('1', 'Un día en casa',
     'Dusk in the back patio of a cozy Chilean home. A mother, a father and '
     'their child stand together looking up at a big full moon. Through the '
     'lit window behind them you see a comfy sofa with a ball of wool and a '
     'warm wood stove. A dove returns to its nest in a pine tree and two green '
     'parrots rest on a yellow-blossomed aromo (acacia) tree.', 0.0),
    ('1', 'El zapatero',
     'A kind old shoemaker in his small cozy workshop repairing a man\'s '
     'leather shoe at his workbench. On the table: a porcelain teacup, a sugar '
     'bowl and a bread roll. A goldfish swims in a bowl on the sunny '
     'windowsill. On the wall, a chalkboard with a chalk drawing of a flower '
     'bouquet tied with a light-blue ribbon. Through the window, a garden '
     'where a thrush eats a worm and a hedgehog walks slowly.', 0.0),
    ('2', 'La semilla mágica',
     'A girl (Ana) watering a tall bright yellow sunflower growing in a clay '
     'pot on a sunny kitchen windowsill, her smiling grandmother beside her. '
     'The sunflower faces the sun through the window.', 0.5),
    ('2', 'El cuaderno viajero',
     'A boy (Benjamín) standing at the front of his classroom reading aloud '
     'from a special decorated notebook with a colorful cover; the open page '
     'shows only a small doodle of sopaipillas and a town square. His '
     'classmates listen attentively at their desks, some raising their hands.',
     0.5),
    ('2', 'La feria del barrio',
     'A lively Saturday street market (feria libre) in a Chilean neighborhood: '
     'wooden stalls under striped awnings with crates of apples, tomatoes, '
     'lemons, bread and flowers. A girl (Camila) holding her father\'s hand '
     'smells a sprig of fresh basil that a friendly vendor just gave her.', 0.3),
    ('3', 'El faro del cabo',
     'A stormy night on a rocky cliff by the sea. An old lighthouse whose '
     'bright beam sweeps across the rain over the rough dark waves; in the '
     'lit lantern room the old keeper (don Héctor) holds a flashlight. Far '
     'away, a small fishing boat turns away from the rocks.', 0.0),
    ('3', 'La carta para el abuelo',
     'A girl (Amparo) and her mother on a sunny neighborhood sidewalk; the girl '
     'drops a yellow envelope into a street mailbox. Behind a garden wall, a '
     'lemon tree in bloom. She also holds a child\'s drawing of a house with '
     'smoke coming out of the chimney.', 0.0),
    ('3', 'El puente de madera',
     'A rural path to school after days of rain: a small wooden footbridge '
     'over a narrow stream. A boy (Matías) kneels and points at one loose '
     'plank while the school principal and a maintenance worker with a '
     'toolbox listen to him. Puddles, wet grass, clearing sky.', 0.1),
    ('4', 'El mercado de los sabores',
     'Inside a bustling covered market full of spices, a girl (Valentina) '
     'tastes a spoonful of jam with wide surprised eyes at the stall of a '
     'kind elderly woman who sells homemade jams in glass jars (pumpkin '
     'orange, tomato red, raspberry pink). The girl\'s mother stands beside '
     'her.', 0.5),
    ('4', 'El taller de volantines',
     'A September Sunday on an open grass field in Chile: a girl (Elisa) flies '
     'her handmade diamond-shaped paper kite (volantín) high in a blue sky, an '
     'elderly man beside her smiling proudly. Other children and grandparents '
     'fly colorful kites in the background.', 0.0),
    ('4', 'La isla de los pingüinos',
     'A small rocky island off the Chilean coast: Humboldt penguins nesting '
     'among rocks and burrows, sea lions resting on the shore, seabirds above. '
     'In the distance a park ranger guides a small group of respectful '
     'visitors along a path marked with a low rope fence. Blue Pacific ocean.',
     0.5),
    ('5', 'El río que olvidó su camino',
     'A dry Chilean valley under a hot sun, mountains behind. A 12-year-old '
     'girl (Isidora) and her neighbors dig a small canal with shovels and '
     'picks; the river water starts flowing through it back toward cracked '
     'fields that are turning green again.', 0.5),
    ('5', 'La fotógrafa del humedal',
     'A winter morning in a wetland. A young woman (Amanda) crouches silently '
     'among tall reeds with an old film camera and a small notebook, '
     'photographing a small white heron that spreads its wings. Golden '
     'reflections on the water and tiny droplets suspended in the air.', 0.5),
    ('5', 'La ruta del agua',
     'An educational panoramic landscape showing the journey of water: a '
     'mountain reservoir, a water treatment plant with round clean tanks, '
     'pipes running under the ground to a small town, and a house where a '
     'child fills a glass at the kitchen tap. The water path is clear and '
     'easy to follow from left to right.', 0.5),
    ('6', 'La biblioteca de las estrellas',
     'Night in the Atacama desert: a large observatory with an open dome and '
     'a big telescope under a crystal-clear sky full of stars and the Milky '
     'Way. A woman astronomer (Dr. Renata Fuentes) sits at a desk beside the '
     'telescope looking at a glowing screen with an abstract wave graph.',
     0.5),
    ('6', 'La brigada del cerro',
     'A green hill near a school after the winter rains, dotted with small '
     'wildflowers, insects and birds. A group of students wearing gloves '
     'collects bottles, cans and plastic bags into bags and bins; one student '
     'takes notes on a clipboard. At the foot of the hill, a bus stop with a '
     'new trash bin.', 0.5),
    ('6', 'El viaje de la quínoa',
     'Quinoa fields on the Andean altiplano with red, orange and yellow '
     'seed heads, snow-capped mountains and a deep blue sky. An Andean farmer '
     'harvests the plants; in the foreground a wooden bowl full of quinoa '
     'seeds.', 0.2),
    ('7', 'Cuando la ciudad escucha',
     'Teenage students investigating sound in a Chilean city: one holds a '
     'handheld sound level meter, another wears headphones with a recorder, '
     'another takes notes. On one side a lively street market, on the other a '
     'busy avenue with buses. Subtle sound waves drawn in the air.', 0.5),
    ('7', 'La bitácora del canal',
     'Late 19th century, the desert of northern Chile: workers with picks and '
     'shovels build a stone irrigation canal along a hillside, moving big '
     'rocks. In the foreground, a foreman writes in a worn leather-bound '
     'logbook. Historic feel with warm earthy tones.', 0.2),
    ('7', 'La discusión del huerto',
     'A school vegetable garden in winter. A group of teenage students debate '
     'around raised garden beds: one bed with lettuces and radishes, another '
     'with native flowers and herbs visited by bees. Their teacher listens; '
     'some students hold notebooks.', 0.5),
    ('8', 'El archivo bajo la lluvia',
     'An old municipal archive room on a rainy day, rain streaming down tall '
     'windows. A teenage girl (Emilia) interviews a woman archivist at a large '
     'table covered with old street maps and documents; archival boxes on '
     'shelves, warm lamp light.', 0.5),
    ('8', 'Energía para el invierno',
     'A small town in southern Chile in winter with wooden houses, chimneys '
     'and forested hills under light rain. Workers install insulation on a '
     'roof and fit a new double-glazed window on a house whose windows glow '
     'with warm light; thick curtains visible inside.', 0.0),
    ('8', 'La última entrevista',
     'An old inventor (don Esteban) in his workshop full of opened radios, '
     'antique clocks and neatly arranged metal parts, talking to a teenage '
     'student journalist who takes notes in a notebook. He looks at a '
     'half-assembled radio. Warm afternoon light.', 0.5),
]


def slugify(text: str) -> str:
    normalized = unicodedata.normalize('NFKD', text)
    ascii_text = ''.join(ch for ch in normalized if not unicodedata.combining(ch))
    clean = re.sub(r'[^a-z0-9]+', '_', ascii_text.lower()).strip('_')
    return re.sub(r'_+', '_', clean)


def build_prompt(nivel: str, scene: str) -> str:
    return (
        'Use your image generation tool to create exactly one image, '
        'in landscape size 1536x1024. '
        f'Scene: {scene} {AUDIENCE[nivel]} Style: {STYLE} '
        'Only generate the image, do not explain anything.'
    )


def known_pngs() -> set[str]:
    return set(glob.glob(str(CODEX_HOME / 'generated_images' / '*' / '*.png')))


def generate_raw(prompt: str) -> Path | None:
    before = known_pngs()
    subprocess.run(
        [CODEX_BIN, 'exec', '--skip-git-repo-check', '--sandbox', 'read-only',
         '-m', CODEX_MODEL, '-c', 'model_reasoning_effort="low"', prompt],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        timeout=TIMEOUT_S,
        cwd='/tmp',
    )
    new = [p for p in known_pngs() - before]
    if not new:
        return None
    return Path(max(new, key=os.path.getmtime))


def crop_to_cover(raw: Path, dest: Path, focus: float) -> None:
    im = Image.open(raw).convert('RGB')
    w, h = im.size
    target = WIDTH / HEIGHT
    if w / h > target:
        cw, ch = round(h * target), h
    else:
        cw, ch = w, round(w / target)
    left = (w - cw) // 2
    top = round((h - ch) * focus)
    top = max(0, min(h - ch, top))
    im = im.crop((left, top, left + cw, top + ch))
    im = im.resize((WIDTH, HEIGHT), Image.LANCZOS)
    im.save(dest, 'JPEG', quality=JPEG_QUALITY, optimize=True, progressive=False)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('slugs', nargs='*', help='only covers whose slug contains any of these')
    parser.add_argument('--force', action='store_true', help='regenerate existing covers')
    parser.add_argument('--recrop', action='store_true', help='only re-crop saved raws')
    args = parser.parse_args()

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    failures = []

    for nivel, titulo, scene, focus in COVERS:
        name = f'{nivel}_{slugify(titulo)}'
        if args.slugs and not any(s in name for s in args.slugs):
            continue
        dest = OUTPUT_DIR / f'{name}.jpg'
        raw = RAW_DIR / f'{name}.png'

        if args.recrop:
            if raw.exists():
                crop_to_cover(raw, dest, focus)
                print(f'recropped {name}')
            continue
        if dest.exists() and not args.force:
            print(f'skip {name}')
            continue

        start = time.time()
        generated = None
        for attempt in range(2):
            try:
                generated = generate_raw(build_prompt(nivel, scene))
            except subprocess.TimeoutExpired:
                generated = None
            if generated:
                break
            print(f'  retry {name} ({attempt + 1})')
        if not generated:
            print(f'FAIL {name}')
            failures.append(name)
            continue

        raw.write_bytes(generated.read_bytes())
        crop_to_cover(raw, dest, focus)
        print(f'ok {name} {Image.open(raw).size} {time.time() - start:.0f}s', flush=True)

    if failures:
        print('failed:', ', '.join(failures))
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
