#!/usr/bin/env python3
"""
Portadas juveniles/infantiles para ProsodIA.
Diseño divertido: ilustración central temática + panel de ola + confetti.
Canvas: 800×400 (ratio 2:1 coincide con las tarjetas de la app).
"""

import re
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

COVERS_DIR = Path(__file__).parent.parent / "assets" / "reading_covers"
COVERS_DIR.mkdir(parents=True, exist_ok=True)

W, H = 800, 400
WAVE_Y = 258        # donde empieza el panel inferior
WAVE_AMP = 18       # amplitud de la ola

THEMES = {
    'adventure': {
        'bg1': (255, 138, 0),   'bg2': (255, 80, 30),
        'accent': (255, 230, 50), 'dark': (160, 45, 0),
        'panel': (255, 250, 235),
    },
    'school': {
        'bg1': (41, 182, 246),  'bg2': (25, 118, 210),
        'accent': (179, 229, 252), 'dark': (13, 71, 161),
        'panel': (240, 249, 255),
    },
    'sky': {
        'bg1': (79, 195, 247),  'bg2': (3, 155, 229),
        'accent': (255, 245, 157), 'dark': (1, 87, 155),
        'panel': (240, 252, 255),
    },
    'nature': {
        'bg1': (102, 217, 108), 'bg2': (27, 158, 62),
        'accent': (255, 241, 118), 'dark': (15, 100, 40),
        'panel': (240, 255, 244),
    },
    'market': {
        'bg1': (255, 202, 40),  'bg2': (245, 124, 0),
        'accent': (255, 138, 101), 'dark': (130, 60, 0),
        'panel': (255, 252, 235),
    },
    'water': {
        'bg1': (38, 198, 218),  'bg2': (0, 151, 167),
        'accent': (178, 235, 242), 'dark': (0, 77, 100),
        'panel': (240, 254, 255),
    },
    'mountain': {
        'bg1': (77, 208, 137),  'bg2': (0, 137, 123),
        'accent': (200, 230, 201), 'dark': (0, 77, 70),
        'panel': (240, 255, 250),
    },
    'kite': {
        'bg1': (186, 104, 200), 'bg2': (106, 27, 154),
        'accent': (255, 241, 118), 'dark': (74, 0, 130),
        'panel': (252, 240, 255),
    },
    'photo': {
        'bg1': (240, 98, 146),  'bg2': (194, 24, 91),
        'accent': (255, 205, 210), 'dark': (136, 14, 79),
        'panel': (255, 242, 247),
    },
    'city': {
        'bg1': (149, 117, 205), 'bg2': (81, 45, 168),
        'accent': (179, 157, 219), 'dark': (49, 27, 146),
        'panel': (248, 245, 255),
    },
    'stars': {
        'bg1': (92, 107, 192),  'bg2': (26, 35, 126),
        'accent': (255, 241, 118), 'dark': (13, 27, 100),
        'panel': (240, 241, 255),
    },
    'energy': {
        'bg1': (255, 167, 38),  'bg2': (230, 81, 0),
        'accent': (255, 238, 88), 'dark': (130, 40, 0),
        'panel': (255, 252, 235),
    },
    'rain': {
        'bg1': (120, 144, 156), 'bg2': (55, 71, 79),
        'accent': (178, 235, 242), 'dark': (38, 50, 56),
        'panel': (245, 250, 252),
    },
    'interview': {
        'bg1': (240, 98, 146),  'bg2': (136, 14, 79),
        'accent': (255, 205, 210), 'dark': (80, 0, 50),
        'panel': (255, 242, 247),
    },
}

READING_THEMES = {
    'El perro y la pelota':           'adventure',
    'La mochila azul':                'school',
    'Las nubes de algodón':           'sky',
    'La semilla mágica':              'nature',
    'El cuaderno viajero':            'school',
    'La feria del barrio':            'market',
    'El faro del cabo':               'water',
    'La carta para el abuelo':        'school',
    'El puente de madera':            'mountain',
    'El mercado de los sabores':      'market',
    'El taller de volantines':        'kite',
    'La isla de los pingüinos':       'water',
    'El río que olvidó su camino':    'water',
    'La fotógrafa del humedal':       'photo',
    'La ruta del agua':               'water',
    'La biblioteca de las estrellas': 'stars',
    'La brigada del cerro':           'mountain',
    'El viaje de la quínoa':          'nature',
    'Cuando la ciudad escucha':       'city',
    'La bitácora del canal':          'water',
    'La discusión del huerto':        'nature',
    'El archivo bajo la lluvia':      'rain',
    'Energía para el invierno':       'energy',
    'La última entrevista':           'interview',
}

BADGES = {
    '1': 'Cuento', '2': 'Cuento',
    '3': 'Lectura guiada', '4': 'Lectura guiada',
    '5': 'Informativo', '6': 'Informativo',
    '7': 'Análisis', '8': 'Análisis',
}

READINGS = [
    ('1', 'El perro y la pelota'),
    ('1', 'La mochila azul'),
    ('1', 'Las nubes de algodón'),
    ('2', 'La semilla mágica'),
    ('2', 'El cuaderno viajero'),
    ('2', 'La feria del barrio'),
    ('3', 'El faro del cabo'),
    ('3', 'La carta para el abuelo'),
    ('3', 'El puente de madera'),
    ('4', 'El mercado de los sabores'),
    ('4', 'El taller de volantines'),
    ('4', 'La isla de los pingüinos'),
    ('5', 'El río que olvidó su camino'),
    ('5', 'La fotógrafa del humedal'),
    ('5', 'La ruta del agua'),
    ('6', 'La biblioteca de las estrellas'),
    ('6', 'La brigada del cerro'),
    ('6', 'El viaje de la quínoa'),
    ('7', 'Cuando la ciudad escucha'),
    ('7', 'La bitácora del canal'),
    ('7', 'La discusión del huerto'),
    ('8', 'El archivo bajo la lluvia'),
    ('8', 'Energía para el invierno'),
    ('8', 'La última entrevista'),
]


def slugify(t):
    s = t.lower()
    for src, dst in [('á','a'),('é','e'),('í','i'),('ó','o'),('ú','u'),('ü','u'),('ñ','n')]:
        s = s.replace(src, dst)
    return re.sub(r'[^a-z0-9]+', '_', s).strip('_')


def load_font(size, bold=False):
    paths = [
        f"/usr/share/fonts/truetype/dejavu/DejaVuSans-{'Bold' if bold else ''}.ttf",
        f"/usr/share/fonts/truetype/liberation/LiberationSans-{'Bold' if bold else 'Regular'}.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
    ]
    for p in paths:
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    return ImageFont.load_default()


def circle(draw, cx, cy, r, fill=None, outline=None, width=1):
    draw.ellipse([(cx-r, cy-r), (cx+r, cy+r)], fill=fill, outline=outline, width=width)


def sticker(draw, cx, cy, r, fill, outline=(255,255,255), width=6):
    """Círculo con borde blanco tipo sticker."""
    circle(draw, cx, cy, r+width//2, fill=outline)
    circle(draw, cx, cy, r, fill=fill)


# ─── Ilustraciones por tema ────────────────────────────────────────────────────

def illus_adventure(draw, t):
    """Perro persiguiendo una pelota."""
    acc, dk = t['accent'], t['dark']
    W_out = (255, 255, 255)
    # Pelota
    sticker(draw, 560, 115, 55, fill=acc, width=7)
    # Tiras de la pelota
    draw.arc([(512, 70), (608, 165)], -30, 150, fill=dk, width=5)
    draw.arc([(512, 70), (608, 165)], 150, 330, fill=dk, width=5)
    # Cuerpo del perro (elipse)
    draw.ellipse([(200, 130), (400, 210)], fill=W_out, outline=dk, width=5)
    # Cabeza
    draw.ellipse([(360, 85), (460, 175)], fill=W_out, outline=dk, width=5)
    # Oreja caída
    draw.ellipse([(350, 75), (400, 140)], fill=acc, outline=dk, width=4)
    # Ojo
    circle(draw, 420, 118, 10, fill=dk)
    circle(draw, 423, 115, 3, fill=(255,255,255))
    # Nariz
    circle(draw, 452, 142, 8, fill=dk)
    # Cola (arco)
    draw.arc([(140, 90), (230, 180)], 230, 350, fill=dk, width=6)
    # Patas delanteras
    draw.ellipse([(340, 200), (380, 245)], fill=W_out, outline=dk, width=4)
    draw.ellipse([(290, 200), (330, 245)], fill=W_out, outline=dk, width=4)
    # Patas traseras
    draw.ellipse([(210, 200), (250, 245)], fill=W_out, outline=dk, width=4)
    draw.ellipse([(160, 200), (200, 245)], fill=W_out, outline=dk, width=4)


def illus_school(draw, t):
    """Mochila y lápiz de colores."""
    acc, dk = t['accent'], t['dark']
    # Mochila
    draw.rounded_rectangle([(260, 60), (530, 230)], radius=30,
                            fill=(255,255,255), outline=dk, width=6)
    # Bolsillo frontal
    draw.rounded_rectangle([(295, 150), (495, 225)], radius=20,
                            fill=acc, outline=dk, width=4)
    # Cierre del bolsillo
    circle(draw, 395, 190, 10, fill=dk)
    # Asa superior
    draw.arc([(330, 30), (460, 100)], 180, 0, fill=dk, width=8)
    # Tirantes
    draw.rounded_rectangle([(280, 210), (310, 248)], radius=8, fill=dk)
    draw.rounded_rectangle([(480, 210), (510, 248)], radius=8, fill=dk)
    # Decoración: estrella en la mochila
    star_pts = []
    for i in range(10):
        angle = math.radians(i * 36 - 90)
        r = 28 if i % 2 == 0 else 14
        star_pts.append((395 + r*math.cos(angle), 100 + r*math.sin(angle)))
    draw.polygon(star_pts, fill=acc, outline=dk, width=3)
    # Lápiz
    draw.polygon([(580, 50), (610, 50), (620, 240), (570, 240)], fill=(255,220,80), outline=dk, width=4)
    draw.polygon([(580, 50), (595, 20), (610, 50)], fill=dk)
    draw.rectangle([(572, 220), (628, 245)], fill=(255,200,180), outline=dk, width=3)


def illus_sky(draw, t):
    """Nubes esponjosas y sol."""
    acc, dk = t['accent'], t['dark']
    # Sol
    sticker(draw, 650, 80, 55, fill=acc, width=8)
    # Rayos del sol (líneas)
    for angle in range(0, 360, 40):
        r = math.radians(angle)
        x1 = 650 + 62 * math.cos(r)
        y1 = 80 + 62 * math.sin(r)
        x2 = 650 + 82 * math.cos(r)
        y2 = 80 + 82 * math.sin(r)
        draw.line([(x1,y1),(x2,y2)], fill=acc, width=5)
    # Cara del sol
    circle(draw, 635, 72, 6, fill=dk)
    circle(draw, 665, 72, 6, fill=dk)
    draw.arc([(626, 80), (674, 105)], 10, 170, fill=dk, width=4)
    # Nube grande
    for cx2, cy2, r in [(300,150,65),(370,125,75),(445,145,65),(520,150,58),(240,160,50)]:
        circle(draw, cx2, cy2, r, fill=(255,255,255))
    draw.ellipse([(235, 155), (530, 225)], fill=(255,255,255))
    for cx2, cy2, r in [(300,150,60),(370,125,70),(445,145,60),(520,150,53),(240,160,45)]:
        circle(draw, cx2, cy2, r, fill=(255,255,255))
    # Contorno nube
    draw.arc([(235, 125), (535, 225)], 180, 360, fill=(220,235,255), width=4)
    # Nube pequeña
    for cx2, cy2, r in [(580, 165, 35), (630, 150, 42), (680, 163, 35)]:
        circle(draw, cx2, cy2, r, fill=(255,255,255))
    draw.ellipse([(578, 162), (720, 205)], fill=(255,255,255))


def illus_nature(draw, t):
    """Planta floreciendo."""
    acc, dk = t['accent'], t['dark']
    bg2 = t['bg2']
    # Tierra
    draw.ellipse([(280, 215), (520, 255)], fill=bg2, outline=dk, width=4)
    # Tallo
    draw.line([(400, 215), (400, 95)], fill=bg2, width=8)
    # Curva tallo
    draw.line([(400, 150), (350, 110)], fill=bg2, width=6)
    # Hoja izquierda
    pts_l = [(350,130),(300,100),(320,160),(370,165)]
    draw.polygon(pts_l, fill=(255,255,255), outline=dk, width=4)
    # Hoja derecha
    pts_r = [(400,160),(460,120),(450,175),(395,185)]
    draw.polygon(pts_r, fill=(255,255,255), outline=dk, width=4)
    # Flor centro
    sticker(draw, 400, 80, 35, fill=acc, width=7)
    # Pétalos
    for angle in range(0, 360, 60):
        r = math.radians(angle)
        px = 400 + 55 * math.cos(r)
        py = 80 + 55 * math.sin(r)
        circle(draw, int(px), int(py), 22, fill=(255,255,255), outline=dk, width=4)
    sticker(draw, 400, 80, 30, fill=acc, width=4)
    circle(draw, 400, 80, 14, fill=dk)
    # Semillas / puntos decorativos
    for px2, py2 in [(330,200),(420,205),(360,195),(460,200)]:
        circle(draw, px2, py2, 5, fill=(255,255,255))


def illus_market(draw, t):
    """Toldo de feria con frutas y colores."""
    acc, dk = t['accent'], t['dark']
    bg1 = t['bg1']
    # Toldo franjas
    stripe_colors = [(255,255,255), bg1]
    for i in range(12):
        x0 = 180 + i * 35
        color = stripe_colors[i % 2]
        draw.polygon([(x0,40),(x0+35,40),(x0+45,120),(x0-10,120)], fill=color)
    # Borde toldo
    draw.rectangle([(175,40),(600,60)], fill=dk)
    # Bordes triangulares del toldo
    for i in range(10):
        x0 = 175 + i * 43
        draw.polygon([(x0,120),(x0+43,120),(x0+22,145)], fill=acc)
    # Frutas / productos
    fruits = [
        (250, 185, 35, (255, 80, 80)),   # manzana
        (330, 180, 30, (255, 165, 0)),   # naranja
        (400, 188, 32, (255, 230, 50)),  # limón
        (475, 183, 36, (150, 80, 200)),  # uva
        (545, 186, 33, (255, 100, 120)), # sandía
    ]
    for fx, fy, fr, fc in fruits:
        sticker(draw, fx, fy, fr, fill=fc, width=5)
    # Palos del toldo
    draw.line([(190, 40), (190, 240)], fill=dk, width=6)
    draw.line([(590, 40), (590, 240)], fill=dk, width=6)


def illus_water(draw, t):
    """Faro con olas."""
    acc, dk = t['accent'], t['dark']
    # Olas (base)
    for i, (y0, amp) in enumerate([(210,25),(230,20),(215,30)]):
        pts_wave = [(0, H)]
        for x in range(801):
            yw = y0 + amp * math.sin((x + i*80) / 80 * math.pi)
            pts_wave.append((x, int(yw)))
        pts_wave.append((W, H))
        alpha = 200 - i*40
        wave_img = Image.new('RGBA', (W, H), (0,0,0,0))
        wave_draw = ImageDraw.Draw(wave_img)
        wave_draw.polygon(pts_wave, fill=(*t['bg2'], alpha))
    # Faro
    lx = 390
    draw.polygon([(lx-28,230),(lx+28,230),(lx+20,100),(lx-20,100)],
                 fill=(255,255,255), outline=dk, width=5)
    # Franjas del faro
    for i, y in enumerate([130,160,190]):
        draw.rectangle([(lx-26,y),(lx+26,y+14)],
                       fill=acc if i%2==0 else dk)
    # Cúpula
    draw.ellipse([(lx-28,88),(lx+28,112)], fill=acc, outline=dk, width=4)
    draw.polygon([(lx-20,88),(lx+20,88),(lx,65)], fill=dk)
    # Luz del faro
    for angle, alpha2 in [(-30,40),(-15,65),(0,90),(15,65),(30,40)]:
        r = math.radians(angle - 90)
        end_x = lx + 200 * math.cos(r)
        end_y = 100 + 200 * math.sin(r)
        ray = Image.new('RGBA', (W, H), (0,0,0,0))
        ray_d = ImageDraw.Draw(ray)
        ray_d.line([(lx,100),(int(end_x),int(end_y))], fill=(*acc,alpha2), width=4)
    # Olas simples
    for y2, amp2 in [(210,15),(225,12)]:
        draw.arc([(50,y2-amp2),(750,y2+amp2)], 0, 180, fill=(255,255,255,180), width=4)


def illus_mountain(draw, t):
    """Cerros con nieve y camino."""
    acc, dk = t['accent'], t['dark']
    # Cerro trasero (grande)
    draw.polygon([(160,240),(500,60),(760,240)], fill=t['bg2'], outline=dk, width=5)
    # Nieve
    draw.polygon([(430,95),(500,60),(570,95),(540,120),(460,120)],
                 fill=(255,255,255), outline=dk, width=3)
    # Cerro delantero izquierdo
    draw.polygon([(80,245),(300,110),(480,245)], fill=(255,255,255), outline=dk, width=5)
    # Nieve cerro chico
    draw.polygon([(265,128),(300,110),(335,128),(318,145),(282,145)],
                 fill=acc, outline=dk, width=3)
    # Árbolitos
    for tx in [170, 220, 420, 460]:
        draw.polygon([(tx,230),(tx+20,190),(tx+40,230)], fill=t['bg2'], outline=dk, width=3)
        draw.rectangle([(tx+17,228),(tx+23,242)], fill=dk)
    # Camino
    draw.polygon([(350,245),(450,245),(410,150),(390,150)], fill=acc, outline=dk, width=3)
    # Sol
    sticker(draw, 640, 85, 40, fill=acc, width=7)


def illus_kite(draw, t):
    """Volantín colorido en el cielo."""
    acc, dk = t['accent'], t['dark']
    bg1 = t['bg1']
    # Hilo del volantín
    pts_string = []
    for i in range(30):
        xi = 250 + i * 12
        yi = 230 + 10 * math.sin(i * 0.5) + i * 2
        pts_string.append((xi, yi))
    draw.line(pts_string, fill=dk, width=3)
    # Moñitos en el hilo
    for i in range(3, 30, 6):
        bx, by = pts_string[i]
        draw.ellipse([(bx-8,by-5),(bx+8,by+5)], fill=acc, outline=dk, width=2)
    # Volantín principal
    kx, ky = 400, 120
    diamond = [(kx,ky-90),(kx+70,ky),(kx,ky+90),(kx-70,ky)]
    draw.polygon(diamond, fill=(255,255,255), outline=dk, width=6)
    # Cuadrantes del volantín
    draw.polygon([(kx,ky-90),(kx+70,ky),(kx,ky)], fill=acc)
    draw.polygon([(kx,ky+90),(kx-70,ky),(kx,ky)], fill=acc)
    draw.polygon(diamond, outline=dk, width=6)
    # Cruz central
    draw.line([(kx,ky-90),(kx,ky+90)], fill=dk, width=4)
    draw.line([(kx-70,ky),(kx+70,ky)], fill=dk, width=4)
    # Volantín pequeño decorativo
    kx2, ky2 = 620, 80
    dm2 = [(kx2,ky2-50),(kx2+40,ky2),(kx2,ky2+50),(kx2-40,ky2)]
    draw.polygon(dm2, fill=bg1, outline=dk, width=4)
    draw.polygon([(kx2,ky2-50),(kx2+40,ky2),(kx2,ky2)], fill=acc)
    draw.polygon(dm2, outline=dk, width=4)
    # Nubes pequeñas
    for cx2, cy2, r in [(170,75,25),(210,62,30),(250,73,25)]:
        circle(draw, cx2, cy2, r, fill=(255,255,255,180))
    draw.ellipse([(165,72),(260,105)], fill=(255,255,255))


def illus_photo(draw, t):
    """Cámara fotográfica con corazón."""
    acc, dk = t['accent'], t['dark']
    bg1 = t['bg1']
    # Cuerpo cámara
    draw.rounded_rectangle([(230,80),(570,220)], radius=25,
                            fill=(255,255,255), outline=dk, width=6)
    # Flash
    draw.rounded_rectangle([(240,55),(320,88)], radius=10,
                            fill=acc, outline=dk, width=4)
    # Lente (círculos concéntricos)
    lx, ly = 390, 152
    circle(draw, lx, ly, 62, fill=bg1, outline=dk, width=5)
    circle(draw, lx, ly, 48, fill=(255,255,255), outline=dk, width=3)
    circle(draw, lx, ly, 30, fill=bg1, outline=dk, width=3)
    circle(draw, lx, ly, 14, fill=dk)
    circle(draw, lx+8, ly-8, 4, fill=(255,255,255))
    # Disparador
    draw.rounded_rectangle([(490,68),(550,88)], radius=10, fill=acc, outline=dk, width=3)
    # Correa
    draw.arc([(550,80),(640,180)], 270, 90, fill=dk, width=6)
    # Corazón decorativo
    hx, hy = 530, 165
    draw.polygon([(hx,hy+25),(hx-25,hy),(hx,hy-15),(hx+25,hy)], fill=acc)
    draw.ellipse([(hx-28,hy-20),(hx+2,hy+10)], fill=acc)
    draw.ellipse([(hx-2,hy-20),(hx+28,hy+10)], fill=acc)
    # Plantas del humedal
    for px2, py2 in [(200,180),(220,165),(180,175),(240,185)]:
        draw.line([(px2,240),(px2,py2)], fill=t['bg2'], width=5)
        draw.ellipse([(px2-12,py2-20),(px2+12,py2+6)], fill=t['bg2'])


def illus_city(draw, t):
    """Silueta de ciudad con ventanas iluminadas."""
    acc, dk = t['accent'], t['dark']
    bg1 = t['bg1']
    # Edificios (siluetas)
    buildings = [
        (150,170,240,245,32),
        (240,130,330,245,40),
        (320,150,400,245,36),
        (390,100,490,245,44),
        (475,140,560,245,38),
        (540,160,620,245,34),
    ]
    for x0,y0,x1,y1,ww in buildings:
        draw.rectangle([(x0,y0),(x1,y1)], fill=(255,255,255), outline=dk, width=4)
        # Ventanas
        for wy in range(y0+12, y1-10, 22):
            for wx in range(x0+8, x1-8, 18):
                col = acc if random.Random(wx+wy).random() > 0.35 else (200,220,240)
                draw.rectangle([(wx,wy),(wx+10,wy+14)], fill=col)
    # Luna
    sticker(draw, 680, 80, 38, fill=acc, width=6)
    circle(draw, 695, 68, 30, fill=bg1)
    # Estrellas
    for sx, sy in [(180,60),(300,40),(450,55),(580,45),(720,140)]:
        star_pts = []
        for i in range(10):
            angle = math.radians(i*36-90)
            r = 10 if i%2==0 else 5
            star_pts.append((sx+r*math.cos(angle), sy+r*math.sin(angle)))
        draw.polygon(star_pts, fill=acc)


def illus_stars(draw, t):
    """Libro abierto con estrellas."""
    acc, dk = t['accent'], t['dark']
    rng = random.Random(7)
    # Estrellas de fondo
    for _ in range(22):
        sx = rng.randint(100, 700)
        sy = rng.randint(20, 200)
        r = rng.randint(4, 11)
        star_pts = []
        for i in range(10):
            angle = math.radians(i*36-90)
            rad = r if i%2==0 else r//2
            star_pts.append((sx+rad*math.cos(angle), sy+rad*math.sin(angle)))
        draw.polygon(star_pts, fill=acc)
    # Libro abierto
    bx, by = 380, 160
    # Página izquierda
    draw.polygon([(bx-160,by-80),(bx,by-60),(bx,by+80),(bx-160,by+80)],
                 fill=(255,255,255), outline=dk, width=5)
    # Página derecha
    draw.polygon([(bx,by-60),(bx+160,by-80),(bx+160,by+80),(bx,by+80)],
                 fill=(255,255,255), outline=dk, width=5)
    # Lomo
    draw.polygon([(bx-8,by-62),(bx+8,by-62),(bx+8,by+82),(bx-8,by+82)], fill=acc)
    # Líneas de texto
    for i, lx2 in [(0,-140),(1,-100),(2,-60),(3,-30)]:
        draw.line([(bx+lx2, by-30+i*20), (bx-20, by-30+i*20)], fill=(200,210,230), width=3)
    for i, lx2 in [(0,30),(1,60),(2,100),(3,140)]:
        draw.line([(bx+20, by-30+i*20), (bx+lx2, by-30+i*20)], fill=(200,210,230), width=3)
    # Estrella grande sobre el libro
    sticker(draw, bx, by-80, 32, fill=acc, width=6)
    star_pts = []
    for i in range(10):
        angle = math.radians(i*36-90)
        r = 28 if i%2==0 else 14
        star_pts.append((bx+r*math.cos(angle), (by-80)+r*math.sin(angle)))
    draw.polygon(star_pts, fill=dk)


def illus_energy(draw, t):
    """Fogata con rayos de calor."""
    acc, dk = t['accent'], t['dark']
    bg2 = t['bg2']
    # Nieve de fondo (puntos blancos)
    rng = random.Random(3)
    for _ in range(20):
        sx = rng.randint(130, 670)
        sy = rng.randint(50, 200)
        r = rng.randint(3, 8)
        circle(draw, sx, sy, r, fill=(255,255,255,180))
    # Troncos
    draw.polygon([(310,235),(370,235),(350,195),(290,200)], fill=(120,70,30), outline=dk, width=3)
    draw.polygon([(430,235),(490,235),(500,195),(445,195)], fill=(100,60,25), outline=dk, width=3)
    # Llamas exteriores
    flame_pts = [(310,235),(380,120),(400,160),(420,100),(440,155),(470,115),(490,235)]
    draw.polygon(flame_pts, fill=bg2, outline=dk, width=4)
    # Llamas medias
    flame2 = [(330,235),(385,140),(400,170),(415,130),(450,155),(460,235)]
    draw.polygon(flame2, fill=t['bg1'])
    # Llamas centrales
    flame3 = [(350,235),(395,155),(400,175),(405,148),(445,235)]
    draw.polygon(flame3, fill=acc)
    # Brasas
    for bx2, by2, br in [(340,232,8),(380,230,6),(400,228,7),(425,231,6),(455,233,8)]:
        circle(draw, bx2, by2, br, fill=(255,120,0))
    # Rayos de calor
    for i, angle in enumerate([-50,-25,0,25,50]):
        r = math.radians(angle - 90)
        ex = 400 + 140*math.cos(r)
        ey = 130 + 140*math.sin(r)
        alpha = 80 - i*5
        draw.line([(400,130),(int(ex),int(ey))], fill=(*acc,alpha), width=3)
    # Copo de nieve
    for angle2 in [0,60,120]:
        r2 = math.radians(angle2)
        draw.line([(650-50*math.cos(r2), 100-50*math.sin(r2)),
                   (650+50*math.cos(r2), 100+50*math.sin(r2))], fill=(255,255,255), width=5)
    circle(draw, 650, 100, 10, fill=(255,255,255))


def illus_rain(draw, t):
    """Carpeta/archivos bajo la lluvia."""
    acc, dk = t['accent'], t['dark']
    # Nube
    for cx2, cy2, r in [(310,90,55),(380,68,65),(455,85,58),(520,92,50),(255,98,42)]:
        circle(draw, cx2, cy2, r, fill=(255,255,255))
    draw.ellipse([(248,90),(530,165)], fill=(255,255,255))
    draw.arc([(248,68),(530,165)], 180, 360, fill=(220,230,240), width=4)
    # Lluvia
    rng = random.Random(5)
    for _ in range(28):
        rx = rng.randint(180, 630)
        ry = rng.randint(155, 240)
        draw.line([(rx,ry),(rx-6,ry+20)], fill=acc, width=3)
    # Carpetas apiladas
    for i, fc in enumerate([(255,255,255),(230,240,255),(210,225,250)]):
        off = i * 10
        draw.rounded_rectangle([(280+off,175+off),(540+off,250)], radius=8,
                                fill=fc, outline=dk, width=4)
        # Pestaña
        draw.rounded_rectangle([(290+off,168+off),(360+off,182+off)], radius=6, fill=fc, outline=dk, width=3)
    # Líneas de texto en la carpeta de arriba
    for lly in [195,210,225]:
        draw.line([(305,lly),(510,lly)], fill=(180,200,220), width=3)
    # Paraguas
    ux, uy = 580, 180
    draw.arc([(ux-55,uy-50),(ux+55,uy)], 180, 0, fill=(255,255,255), width=6)
    draw.arc([(ux-55,uy-50),(ux+55,uy)], 180, 0, fill=dk, width=3)
    draw.line([(ux,uy),(ux,uy+60)], fill=dk, width=5)
    draw.arc([(ux-10,uy+45),(ux+14,uy+65)], 0, 180, fill=dk, width=5)


def illus_interview(draw, t):
    """Micrófono con ondas de sonido."""
    acc, dk = t['accent'], t['dark']
    bg1 = t['bg1']
    mx, my = 390, 145
    # Ondas de sonido (izquierda)
    for r, alpha2 in [(60,40),(90,30),(120,20)]:
        draw.arc([(mx-r-65, my-r), (mx-65, my+r)], 135, 225, fill=(*acc,alpha2), width=6)
    # Ondas de sonido (derecha)
    for r, alpha2 in [(60,40),(90,30),(120,20)]:
        draw.arc([(mx+65, my-r), (mx+r+65, my+r)], 315, 45, fill=(*acc,alpha2), width=6)
    # Cuerpo micrófono
    draw.rounded_rectangle([(mx-40,my-90),(mx+40,my+55)], radius=38,
                            fill=(255,255,255), outline=dk, width=6)
    # Franjas decorativas
    for lmy in [my-55, my-30, my-5, my+20]:
        draw.line([(mx-35, lmy),(mx+35, lmy)], fill=acc, width=5)
    # Base
    draw.arc([(mx-55,my+30),(mx+55,my+110)], 0, 180, fill=dk, width=7)
    draw.line([(mx,my+110),(mx,my+155)], fill=dk, width=7)
    draw.rounded_rectangle([(mx-40,my+153),(mx+40,my+170)], radius=10, fill=dk)
    # Botón de grabación
    sticker(draw, mx+95, my-70, 22, fill=acc, width=5)
    circle(draw, mx+95, my-70, 10, fill=(220,30,30))
    # Notas musicales decorativas
    for nx2, ny2 in [(220,70),(560,80)]:
        draw.ellipse([(nx2-12,ny2-8),(nx2+12,ny2+8)], fill=acc, outline=dk, width=3)
        draw.line([(nx2+12,ny2),(nx2+12,ny2-35)], fill=dk, width=4)
        draw.line([(nx2+12,ny2-35),(nx2+26,ny2-28)], fill=dk, width=4)


ILLUSTRATORS = {
    'adventure': illus_adventure,
    'school':    illus_school,
    'sky':       illus_sky,
    'nature':    illus_nature,
    'market':    illus_market,
    'water':     illus_water,
    'mountain':  illus_mountain,
    'kite':      illus_kite,
    'photo':     illus_photo,
    'city':      illus_city,
    'stars':     illus_stars,
    'energy':    illus_energy,
    'rain':      illus_rain,
    'interview': illus_interview,
}


def draw_confetti(draw, accent, bg2, seed=0):
    """Puntos de confeti dispersos en el fondo."""
    rng = random.Random(seed)
    for _ in range(18):
        cx2 = rng.randint(50, 750)
        cy2 = rng.randint(20, WAVE_Y - 20)
        r = rng.randint(5, 16)
        color = accent if rng.random() > 0.5 else (255, 255, 255)
        alpha = rng.randint(35, 80)
        circle(draw, cx2, cy2, r, fill=(*color, alpha))


def draw_wave_panel(img, panel_color, bg2):
    """Panel inferior con borde de ola."""
    overlay = Image.new('RGBA', (W, H), (0,0,0,0))
    d = ImageDraw.Draw(overlay)
    pts = [(0, H)]
    for x in range(W + 1):
        y = WAVE_Y + WAVE_AMP * math.sin(x / W * 2.8 * math.pi)
        pts.append((x, int(y)))
    pts.append((W, H))
    d.polygon(pts, fill=(*panel_color, 245))
    # Sombra suave encima de la ola
    for dy2 in range(1, 8):
        alpha2 = int(30 * (1 - dy2/8))
        shadow_pts = [(0, H)]
        for x in range(W + 1):
            y = WAVE_Y + WAVE_AMP * math.sin(x / W * 2.8 * math.pi) + dy2
            shadow_pts.append((x, int(y)))
        shadow_pts.append((W, H))
        d.polygon(shadow_pts, fill=(*bg2, alpha2))
    return Image.alpha_composite(img, overlay)


def wrap_text(draw, text, font, max_width):
    words = text.split()
    lines, current = [], ''
    for word in words:
        test = (current + ' ' + word).strip()
        bbox = draw.textbbox((0, 0), test, font=font)
        if bbox[2] - bbox[0] <= max_width:
            current = test
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def generate_cover(nivel: str, titulo: str):
    theme_name = READING_THEMES.get(titulo, 'market')
    t = THEMES[theme_name]
    bg1, bg2 = t['bg1'], t['bg2']
    accent, dark, panel = t['accent'], t['dark'], t['panel']

    # 1. Fondo: gradiente vertical
    img = Image.new('RGBA', (W, H))
    pixels = img.load()
    for y in range(H):
        fac = y / (WAVE_Y * 1.1)
        fac = min(fac, 1.0)
        r = int(bg1[0] + (bg2[0]-bg1[0]) * fac)
        g = int(bg1[1] + (bg2[1]-bg1[1]) * fac)
        b = int(bg1[2] + (bg2[2]-bg1[2]) * fac)
        for x in range(W):
            pixels[x, y] = (r, g, b, 255)

    # 2. Confeti en el fondo
    confetti_layer = Image.new('RGBA', (W, H), (0,0,0,0))
    draw_confetti(ImageDraw.Draw(confetti_layer), accent, bg2, seed=hash(titulo)%100)
    img = Image.alpha_composite(img, confetti_layer)

    # 3. Ilustración temática
    illus_layer = Image.new('RGBA', (W, H), (0,0,0,0))
    illus_fn = ILLUSTRATORS.get(theme_name)
    if illus_fn:
        illus_fn(ImageDraw.Draw(illus_layer), t)
    img = Image.alpha_composite(img, illus_layer)

    # 4. Panel inferior con ola
    img = draw_wave_panel(img, panel, bg2)

    draw = ImageDraw.Draw(img)

    # 5. Título en el panel inferior
    font_title = load_font(54, bold=True)
    margin = 36
    lines = wrap_text(draw, titulo, font_title, W - margin * 2)
    line_h = 62
    total_h = len(lines) * line_h
    # Centrar en la zona del panel
    panel_center_y = WAVE_Y + (H - WAVE_Y) // 2
    text_start_y = panel_center_y - total_h // 2 + 6

    for i, line in enumerate(lines):
        y = text_start_y + i * line_h
        # Sombra
        draw.text((margin+2, y+2), line, fill=(*dark, 80), font=font_title)
        # Texto
        draw.text((margin, y), line, fill=dark, font=font_title)

    # 6. Badge tipo lectura (esquina superior izquierda)
    badge_text = BADGES.get(nivel, 'Lectura')
    font_badge = load_font(21, bold=True)
    bb = draw.textbbox((0,0), badge_text, font=font_badge)
    bw, bh = bb[2]-bb[0]+26, bb[3]-bb[1]+14
    draw.rounded_rectangle([(16,16),(16+bw,16+bh)], radius=bh//2, fill=dark)
    draw.text((16+13, 16+7), badge_text, fill=(255,255,255), font=font_badge)

    # 7. Nivel en círculo (esquina superior derecha)
    font_nivel = load_font(28, bold=True)
    nivel_text = f'N°{nivel}'
    nb = draw.textbbox((0,0), nivel_text, font=font_nivel)
    nw, nh = nb[2]-nb[0], nb[3]-nb[1]
    nr = max(nw, nh)//2 + 16
    nx, ny = W - 20 - nr, 20 + nr
    circle(draw, nx, ny, nr, fill=dark)
    draw.text((nx - nw//2, ny - nh//2), nivel_text, fill=(255,255,255), font=font_nivel)

    # 8. Guardar
    filename = f"{nivel}_{slugify(titulo)}.png"
    img.convert('RGB').save(COVERS_DIR / filename, 'PNG', optimize=True)
    print(f'✓ {filename}')


def main():
    print(f'Generando {len(READINGS)} portadas en {COVERS_DIR}...\n')
    for nivel, titulo in READINGS:
        generate_cover(nivel, titulo)
    print(f'\n✓ {len(READINGS)} portadas generadas')


if __name__ == '__main__':
    main()
