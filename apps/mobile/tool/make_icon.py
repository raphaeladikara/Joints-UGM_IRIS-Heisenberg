"""Ikon peluncur KRING: kotak biru bergradien + simbol telepon berdering (Material Icons ring_volume).
  py tool/make_icon.py <MaterialIcons-Regular.otf>
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

FONT = sys.argv[1]
GLYPH = chr(0xF010E)  # ring_volume_rounded (kode Flutter Icons)


def icon(size: int, rounded: bool = True, pad: float = 0.0) -> Image.Image:
    S = size * 4
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    grad = Image.new("RGBA", (S, S))
    top, bot = (47, 134, 246), (11, 77, 176)
    for y in range(S):
        t = y / S
        ImageDraw.Draw(grad).line([(0, y), (S, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bot)) + (255,))
    mask = Image.new("L", (S, S), 0)
    m = int(S * pad)
    ImageDraw.Draw(mask).rounded_rectangle([m, m, S - m, S - m], radius=int(S * (0.23 if rounded else 0)), fill=255)
    img.paste(grad, (0, 0), mask)
    d = ImageDraw.Draw(img)
    f = ImageFont.truetype(FONT, int(S * 0.62))
    box = d.textbbox((0, 0), GLYPH, font=f)
    w, h = box[2] - box[0], box[3] - box[1]
    d.text(((S - w) / 2 - box[0], (S - h) / 2 - box[1] + S * 0.02), GLYPH, font=f, fill=(255, 255, 255, 255))
    return img.resize((size, size), Image.LANCZOS)


res = Path("android/app/src/main/res")
for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
    icon(px).save(res / f"mipmap-{folder}" / "ic_launcher.png")
web = Path("web")
icon(192).save(web / "icons/Icon-192.png")
icon(512).save(web / "icons/Icon-512.png")
icon(192, pad=0.1).save(web / "icons/Icon-maskable-192.png")
icon(512, pad=0.1).save(web / "icons/Icon-maskable-512.png")
icon(32).save(web / "favicon.png")
icon(512).save("assets/kring_icon_512.png")
print("ok")
