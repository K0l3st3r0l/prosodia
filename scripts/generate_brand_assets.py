"""Generate ProsodIA branding assets.

Outputs:
- prosodia_logo.png            full logo on navy gradient (in-app + launcher)
- prosodia_logo_foreground.png foreground only (transparent bg, adaptive icon)
- prosodia_logo_monochrome.png monochrome silhouette (themed icon)

Design: bold white "P" monogram on a navy gradient squircle, with a row of
five amber rounded bars below evoking an audio waveform. Optimised for
strong silhouette at small sizes (header chips at 42px) while looking sharp
on the launcher (1024px).
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / 'assets' / 'branding'
SIZE = 1024
RADIUS = 224
FONT_PATH = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

NAVY_LIGHT = (26, 79, 120)
NAVY_DARK = (9, 23, 38)
GLOW = (30, 114, 176)
WHITE = (255, 255, 255)
AMBER = (232, 162, 59)
MONO_FG = (24, 52, 74)


def _lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def _gradient_background():
    img = Image.new('RGB', (SIZE, SIZE), NAVY_LIGHT)
    pix = img.load()
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x + y) / (2 * (SIZE - 1))
            pix[x, y] = _lerp(NAVY_LIGHT, NAVY_DARK, t)
    return img.convert('RGBA')


def _add_glow(img, center, radius, color, max_alpha=110):
    overlay = Image.new('RGBA', img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(overlay)
    cx, cy = center
    steps = 40
    for i in range(steps, 0, -1):
        t = i / steps
        r = int(radius * t)
        a = int(max_alpha * (1 - t) ** 2)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color + (a,))
    overlay = overlay.filter(ImageFilter.GaussianBlur(radius=20))
    img.alpha_composite(overlay)


def _draw_mark(canvas, *, letter_color=WHITE, bar_color=AMBER):
    """Draw the 'P' + audio bars on the given RGBA canvas."""
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT_PATH, 720)
    bbox = draw.textbbox((0, 0), 'P', font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    px = (SIZE - tw) // 2 - bbox[0]
    py = (SIZE - th) // 2 - bbox[1] - 60
    draw.text((px, py), 'P', font=font, fill=letter_color)

    rel_heights = [0.08, 0.13, 0.18, 0.13, 0.08]
    bar_w = int(SIZE * 0.052)
    bar_gap = int(SIZE * 0.030)
    total_w = 5 * bar_w + 4 * bar_gap
    bars_left = (SIZE - total_w) // 2
    baseline = int(SIZE * 0.86)
    for i, rh in enumerate(rel_heights):
        bh = int(rh * SIZE)
        bx = bars_left + i * (bar_w + bar_gap)
        draw.rounded_rectangle(
            (bx, baseline - bh, bx + bar_w, baseline),
            radius=bar_w // 2,
            fill=bar_color,
        )


def _rounded_mask():
    mask = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, SIZE - 1, SIZE - 1), radius=RADIUS, fill=255,
    )
    return mask


def _build_full_logo():
    bg = _gradient_background()
    _add_glow(bg, (int(SIZE * 0.78), int(SIZE * 0.22)), int(SIZE * 0.55), GLOW)
    _draw_mark(bg)
    final = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    final.paste(bg, (0, 0), mask=_rounded_mask())
    return final


def _build_foreground():
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    _draw_mark(fg)
    return fg


def _build_monochrome():
    fg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    _draw_mark(fg, letter_color=WHITE, bar_color=WHITE)
    alpha = fg.getchannel('A')
    mono = Image.new('RGBA', (SIZE, SIZE), MONO_FG + (255,))
    mono.putalpha(alpha)
    return mono


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    _build_full_logo().save(OUT_DIR / 'prosodia_logo.png', optimize=True)
    _build_foreground().save(OUT_DIR / 'prosodia_logo_foreground.png', optimize=True)
    _build_monochrome().save(OUT_DIR / 'prosodia_logo_monochrome.png', optimize=True)
    print(f'Wrote logo assets to {OUT_DIR}')


if __name__ == '__main__':
    main()
