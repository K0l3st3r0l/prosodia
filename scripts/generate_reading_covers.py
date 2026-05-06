from __future__ import annotations

import math
import re
import unicodedata
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / 'assets' / 'reading_covers'
SIZE = (960, 540)


READINGS = [
    ('1', 'El perro y la pelota', 'playground'),
    ('1', 'La mochila azul', 'school'),
    ('1', 'Las nubes de algodón', 'sky'),
    ('2', 'La semilla mágica', 'garden'),
    ('2', 'El cuaderno viajero', 'school'),
    ('2', 'La feria del barrio', 'market'),
    ('3', 'El faro del cabo', 'sea'),
    ('3', 'La carta para el abuelo', 'school'),
    ('3', 'El puente de madera', 'mountains'),
    ('4', 'El mercado de los sabores', 'market'),
    ('4', 'El taller de volantines', 'night'),
    ('4', 'La isla de los pingüinos', 'sea'),
    ('5', 'El río que olvidó su camino', 'sea'),
    ('5', 'La fotógrafa del humedal', 'studio'),
    ('5', 'La ruta del agua', 'sea'),
    ('6', 'La biblioteca de las estrellas', 'night'),
    ('6', 'La brigada del cerro', 'mountains'),
    ('6', 'El viaje de la quínoa', 'garden'),
    ('7', 'Cuando la ciudad escucha', 'city'),
    ('7', 'La bitácora del canal', 'sea'),
    ('7', 'La discusión del huerto', 'garden'),
    ('8', 'El archivo bajo la lluvia', 'city'),
    ('8', 'Energía para el invierno', 'city'),
    ('8', 'La última entrevista', 'studio'),
]


SCENES = {
    'playground': {
        'colors': ('#FF9A62', '#F06A3D'),
        'accent': '#FFF3E7',
        'label': 'Aventura',
    },
    'school': {
        'colors': ('#76B2FF', '#2F6FE4'),
        'accent': '#EFF6FF',
        'label': 'Escuela',
    },
    'sky': {
        'colors': ('#B8E3FF', '#61B8FF'),
        'accent': '#F5FBFF',
        'label': 'Imaginación',
    },
    'garden': {
        'colors': ('#98E79C', '#2E9D52'),
        'accent': '#F0FFF0',
        'label': 'Naturaleza',
    },
    'market': {
        'colors': ('#FFD274', '#F29E2E'),
        'accent': '#FFF8EA',
        'label': 'Vida cotidiana',
    },
    'sea': {
        'colors': ('#84ECFF', '#1996E4'),
        'accent': '#E9FBFF',
        'label': 'Entorno',
    },
    'mountains': {
        'colors': ('#98F0D5', '#21936E'),
        'accent': '#F0FFFB',
        'label': 'Territorio',
    },
    'night': {
        'colors': ('#BFA4FF', '#6F49E5'),
        'accent': '#F5F0FF',
        'label': 'Exploración',
    },
    'studio': {
        'colors': ('#FFA7D1', '#CF347D'),
        'accent': '#FFF0F7',
        'label': 'Observación',
    },
    'city': {
        'colors': ('#DDB8FF', '#8860E8'),
        'accent': '#F7F0FF',
        'label': 'Sociedad',
    },
}


def slugify(text: str) -> str:
    normalized = unicodedata.normalize('NFKD', text)
    ascii_text = ''.join(ch for ch in normalized if not unicodedata.combining(ch))
    clean = re.sub(r'[^a-zA-Z0-9]+', '_', ascii_text.lower()).strip('_')
    return re.sub(r'_+', '_', clean)


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip('#')
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
        '/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf' if bold else '/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf',
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


TITLE_FONT = load_font(56, bold=True)
META_FONT = load_font(24, bold=False)
BADGE_FONT = load_font(22, bold=True)


def draw_gradient(base: Image.Image, top_color: str, bottom_color: str) -> None:
    top = hex_rgb(top_color)
    bottom = hex_rgb(bottom_color)
    draw = ImageDraw.Draw(base)
    for y in range(base.height):
        t = y / max(base.height - 1, 1)
        color = mix(top, bottom, t)
        draw.line((0, y, base.width, y), fill=color)


def add_glow(draw: ImageDraw.ImageDraw, center: tuple[int, int], radius: int, color: tuple[int, int, int, int]) -> None:
    x, y = center
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color)


def scene_playground(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    draw.ellipse((930, 74, 1020, 164), fill=(255, 242, 190, 230))
    draw.rounded_rectangle((0, 520, 1280, 760), radius=80, fill=(255, 255, 255, 55))
    draw.ellipse((190, 420, 320, 550), fill=(*accent, 180))
    draw.ellipse((265, 468, 370, 574), fill=(255, 255, 255, 220))
    draw.rounded_rectangle((420, 458, 520, 516), radius=28, fill=(255, 255, 255, 195))
    draw.ellipse((488, 438, 548, 498), fill=(255, 255, 255, 195))
    draw.polygon([(520, 470), (558, 446), (542, 490)], fill=(255, 255, 255, 195))


def scene_school(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    draw.ellipse((980, 72, 1052, 144), fill=(255, 244, 190, 235))
    draw.rounded_rectangle((208, 230, 480, 470), radius=24, fill=(255, 255, 255, 78))
    draw.polygon([(188, 240), (344, 130), (500, 240)], fill=(255, 255, 255, 118))
    for row in range(2):
        for col in range(4):
            x = 238 + col * 54
            y = 270 + row * 72
            draw.rounded_rectangle((x, y, x + 28, y + 36), radius=6, fill=(255, 255, 255, 172))
    draw.rounded_rectangle((780, 302, 944, 504), radius=28, fill=(*accent, 220), outline=(255, 255, 255, 180), width=4)
    draw.rounded_rectangle((826, 256, 898, 322), radius=18, fill=(*accent, 200), outline=(255, 255, 255, 180), width=4)


def scene_sky(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    draw.ellipse((930, 78, 1010, 158), fill=(255, 247, 205, 230))
    for x, y, w, h in [(174, 160, 236, 92), (510, 110, 200, 82), (780, 188, 218, 88)]:
        draw.rounded_rectangle((x, y, x + w, y + h), radius=80, fill=(255, 255, 255, 150))
    draw.arc((280, 248, 536, 452), start=200, end=340, fill=(255, 255, 255, 170), width=14)


def scene_garden(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    draw.ellipse((954, 84, 1024, 154), fill=(255, 242, 184, 234))
    draw.rounded_rectangle((0, 520, 1280, 760), radius=84, fill=(255, 255, 255, 48))
    stems = [250, 410, 570, 730, 890]
    for x in stems:
        draw.rectangle((x, 398, x + 8, 544), fill=(255, 255, 255, 178))
        draw.ellipse((x - 24, 422, x + 18, 460), fill=(255, 255, 255, 115))
        draw.ellipse((x - 10, 374, x + 38, 420), fill=(*accent, 220))


def scene_market(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    draw.rounded_rectangle((152, 182, 1112, 256), radius=24, fill=(255, 255, 255, 138))
    stripe_w = 120
    x = 152
    toggle = True
    while x < 1112:
        if toggle:
            draw.rectangle((x, 182, min(x + stripe_w, 1112), 256), fill=(*accent, 230))
        toggle = not toggle
        x += stripe_w
    draw.rounded_rectangle((214, 264, 1046, 438), radius=28, fill=(255, 255, 255, 70))
    for idx, cx in enumerate([300, 410, 520, 630, 740, 850]):
        draw.ellipse((cx, 338, cx + 68, 406), fill=((255, 255, 255, 210) if idx % 2 == 0 else (*accent, 210)))


def scene_sea(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    draw.ellipse((980, 84, 1046, 150), fill=(255, 248, 205, 232))
    draw.rounded_rectangle((0, 484, 1280, 580), radius=60, fill=(255, 255, 255, 62))
    draw.rounded_rectangle((0, 552, 1280, 720), radius=60, fill=(255, 255, 255, 88))
    draw.polygon([(454, 430), (564, 354), (676, 430)], fill=(255, 255, 255, 188))
    draw.rounded_rectangle((520, 430, 608, 456), radius=10, fill=(255, 255, 255, 195))
    draw.rectangle((930, 264, 952, 504), fill=(255, 255, 255, 175))
    draw.rounded_rectangle((902, 220, 980, 286), radius=14, fill=(*accent, 215), outline=(255, 255, 255, 150), width=4)


def scene_mountains(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    draw.polygon([(60, 472), (292, 202), (520, 472)], fill=(255, 255, 255, 84))
    draw.polygon([(350, 520), (652, 144), (938, 520)], fill=(255, 255, 255, 112))
    draw.polygon([(812, 500), (1044, 230), (1264, 500)], fill=(255, 255, 255, 74))
    draw.rounded_rectangle((0, 560, 1280, 760), radius=80, fill=(255, 255, 255, 52))
    draw.line((166, 506, 938, 506), fill=(255, 255, 255, 180), width=12)


def scene_night(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    draw.ellipse((978, 84, 1046, 152), fill=(255, 255, 255, 155))
    for cx, cy, size in [(204, 154, 16), (322, 112, 12), (438, 178, 14), (842, 144, 12), (916, 202, 18)]:
        draw.regular_polygon((cx, cy, size), n_sides=5, rotation=0, fill=(255, 255, 255, 205))
    draw.line((260, 560, 548, 302), fill=(255, 255, 255, 155), width=6)
    draw.polygon([(548, 302), (672, 342), (602, 452)], fill=(*accent, 225), outline=(255, 255, 255, 150))
    draw.line((672, 342, 736, 378), fill=(255, 255, 255, 190), width=5)


def scene_studio(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    draw.ellipse((212, 130, 434, 352), fill=(255, 255, 255, 66))
    draw.ellipse((258, 176, 388, 306), outline=(255, 255, 255, 220), width=18)
    draw.ellipse((300, 218, 346, 264), fill=(*accent, 235))
    draw.rounded_rectangle((780, 222, 856, 410), radius=36, fill=(255, 255, 255, 205))
    draw.rectangle((814, 410, 822, 494), fill=(255, 255, 255, 205))
    draw.rounded_rectangle((770, 494, 866, 512), radius=8, fill=(255, 255, 255, 175))


def scene_city(draw: ImageDraw.ImageDraw, accent: tuple[int, int, int]) -> None:
    draw.rounded_rectangle((0, 560, 1280, 760), radius=80, fill=(255, 255, 255, 48))
    heights = [168, 242, 196, 284, 212, 170, 236]
    x = 138
    for idx, height in enumerate(heights):
        width = 98 if idx % 2 == 0 else 82
        draw.rounded_rectangle((x, 560 - height, x + width, 560), radius=12, fill=(255, 255, 255, 98))
        for wy in range(560 - height + 22, 540, 32):
            for wx in range(x + 16, x + width - 18, 24):
                draw.rounded_rectangle((wx, wy, wx + 10, wy + 14), radius=3, fill=(*accent, 195))
        x += width + 26
    draw.polygon([(978, 184), (1042, 184), (1000, 290), (1060, 290), (946, 450), (978, 324), (922, 324)], fill=(255, 255, 255, 210))


DRAW_SCENE = {
    'playground': scene_playground,
    'school': scene_school,
    'sky': scene_sky,
    'garden': scene_garden,
    'market': scene_market,
    'sea': scene_sea,
    'mountains': scene_mountains,
    'night': scene_night,
    'studio': scene_studio,
    'city': scene_city,
}


def build_cover(level: str, title: str, scene: str) -> Image.Image:
    scene_spec = SCENES[scene]
    image = Image.new('RGBA', SIZE)
    draw_gradient(image, scene_spec['colors'][0], scene_spec['colors'][1])

    overlay = Image.new('RGBA', SIZE, (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    add_glow(overlay_draw, (1060, 126), 120, (255, 255, 255, 28))
    add_glow(overlay_draw, (176, 594), 110, (255, 255, 255, 20))

    accent = hex_rgb(scene_spec['accent'])
    DRAW_SCENE[scene](overlay_draw, accent)

    text_plate_top = 486
    overlay_draw.rounded_rectangle(
        (62, text_plate_top, 1218, 658),
        radius=34,
        fill=(14, 16, 28, 108),
        outline=(255, 255, 255, 48),
        width=2,
    )
    overlay_draw.rounded_rectangle(
        (62, 52, 240, 106),
        radius=999,
        fill=(255, 255, 255, 42),
    )
    overlay_draw.rounded_rectangle(
        (1116, 54, 1208, 106),
        radius=999,
        fill=(255, 255, 255, 34),
    )

    image = Image.alpha_composite(image, overlay)
    image = image.filter(ImageFilter.GaussianBlur(radius=0.2))
    draw = ImageDraw.Draw(image)

    draw.text((94, 66), scene_spec['label'], font=BADGE_FONT, fill=(255, 255, 255, 240))
    draw.text((1148, 69), f'{level}°', font=BADGE_FONT, fill=(255, 255, 255, 230), anchor='mm')
    draw.text((94, 524), title, font=TITLE_FONT, fill=(255, 255, 255, 248))
    draw.text((94, 594), 'ProsodIA  •  Fluidez lectora', font=META_FONT, fill=(240, 244, 255, 214))

    return image.convert('RGB')


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for level, title, scene in READINGS:
      filename = f'{level}_{slugify(title)}.jpg'
      cover = build_cover(level, title, scene)
      cover.save(
          OUTPUT_DIR / filename,
          format='JPEG',
          quality=92,
          optimize=True,
          progressive=False,
          subsampling=0,
      )
      print(f'generated {filename}')


if __name__ == '__main__':
    main()