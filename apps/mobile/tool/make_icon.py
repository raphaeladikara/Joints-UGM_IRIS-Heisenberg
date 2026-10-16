"""Logo KRING: piringan telepon putar (rotary dial) bergaya timbul di kotak hijau, palet "Daun & Tanah".

Kotak hijau bergradien dengan kilau kiri-atas, piringan krem bergradien + bayangan lembut, sembilan lubang jari hijau
dan satu lubang terakota (lubang pertama), poros terakota, dan penahan jari terakota. Menulis ikon Android, ikon web,
favicon, aset ikon di aplikasi, dan lockup logo + kata "KRING" (Nunito Black).

  py tool/make_icon.py
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

S = 2048  # kanvas kerja; diperkecil dengan LANCZOS supaya tepi halus

GREEN_HI, GREEN, GREEN_DEEP, GREEN_NIGHT = "#4C9073", "#1F6B4F", "#154D39", "#0F2E24"
TERRA_HI, TERRA = "#EDB08F", "#C0623B"
CREAM_HI, CREAM_LO = "#FFFCF4", "#E9DDC6"


def rgb(h: str) -> np.ndarray:
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float)


def gradient(size, c0, c1, angle_deg=90.0) -> Image.Image:
    """Gradien linear c0 → c1; 90° = atas ke bawah, 45° = kiri-atas ke kanan-bawah."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    a = math.radians(angle_deg)
    t = (xx / w - 0.5) * math.cos(a) + (yy / h - 0.5) * math.sin(a)
    t = (t - t.min()) / (t.max() - t.min())
    img = rgb(c0) * (1 - t[..., None]) + rgb(c1) * t[..., None]
    return Image.fromarray(img.astype(np.uint8), "RGB").convert("RGBA")


def disc_mask(cx, cy, r) -> Image.Image:
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
    return m


def shadow(canvas: Image.Image, mask: Image.Image, dx, dy, blur, color="#0A2219", alpha=0.45) -> None:
    sh = Image.new("RGBA", (S, S), (*rgb(color).astype(int), 0))
    a = mask.point(lambda v: int(v * alpha))
    sh.putalpha(a)
    sh = sh.transform((S, S), Image.AFFINE, (1, 0, -dx, 0, 1, -dy)).filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(sh)


def fill(canvas: Image.Image, mask: Image.Image, c0, c1, angle=90.0) -> None:
    g = gradient((S, S), c0, c1, angle)
    g.putalpha(mask)
    canvas.alpha_composite(g)


def mark(bg: bool = True, pad: float = 0.0) -> Image.Image:
    """Logo persegi S×S. bg=False → piringan saja (tanpa kotak hijau). pad = tepi kosong (ikon maskable)."""
    c = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    k = 1 - 2 * pad
    o = S * pad

    def P(x):  # pecahan kotak → piksel
        return o + x * S * k

    if bg:
        box = Image.new("L", (S, S), 0)
        ImageDraw.Draw(box).rounded_rectangle([P(0), P(0), P(1), P(1)], radius=S * k * 0.225, fill=255)
        fill(c, box, GREEN_HI, GREEN_NIGHT, 45)
        # kilau kiri-atas & garis tepi terang tipis, seperti gambar acuan
        yy, xx = np.mgrid[0:S, 0:S].astype(float)
        glow = np.clip(1 - np.hypot(xx - P(0.18), yy - P(0.12)) / (S * k * 0.75), 0, 1) ** 2 * 70
        gl = Image.fromarray(glow.astype(np.uint8), "L")
        layer = Image.new("RGBA", (S, S), (255, 255, 255, 0))
        layer.putalpha(Image.fromarray(np.minimum(np.asarray(gl), np.asarray(box)).astype(np.uint8)))
        c.alpha_composite(layer)
        rim = Image.new("L", (S, S), 0)
        ImageDraw.Draw(rim).rounded_rectangle([P(0), P(0), P(1), P(1)], radius=S * k * 0.225, outline=60, width=int(S * k * 0.008))
        lr = Image.new("RGBA", (S, S), (255, 255, 255, 0))
        lr.putalpha(rim)
        c.alpha_composite(lr)

    cx, cy = P(0.5), P(0.5)
    R = S * k * 0.355
    dial = disc_mask(cx, cy, R)
    shadow(c, dial, S * k * 0.014, S * k * 0.024, S * k * 0.03)
    fill(c, dial, CREAM_HI, CREAM_LO, 70)

    # Lubang jari: 10 lubang, lubang pertama (kanan-atas) terakota. Sudut matematis, berlawanan jarum jam.
    hr, ring = S * k * 0.05, S * k * 0.247
    for i in range(10):
        a = math.radians(60 + i * 28)
        hx, hy = cx + ring * math.cos(a), cy - ring * math.sin(a)
        m = disc_mask(hx, hy, hr)
        if i == 0:
            shadow(c, m, S * k * 0.004, S * k * 0.008, S * k * 0.008, alpha=0.35)
            fill(c, m, TERRA_HI, TERRA, 60)
        else:
            fill(c, m, GREEN_DEEP, GREEN, 90)  # gelap di atas → terlihat cekung
            inner = disc_mask(hx, hy + hr * 0.18, hr * 0.78)
            sh = Image.new("RGBA", (S, S), (*rgb(GREEN).astype(int), 0))
            sh.putalpha(Image.fromarray(np.minimum(np.asarray(inner), np.asarray(m)).astype(np.uint8)).point(lambda v: v // 2))
            c.alpha_composite(sh)

    # Penahan jari: busur terakota di kanan-bawah, di luar cincin lubang.
    stop = Image.new("L", (S, S), 0)
    sr, sw = S * k * 0.305, S * k * 0.034
    d = ImageDraw.Draw(stop)
    a0, a1 = -20, 16  # derajat PIL (searah jarum jam dari +x)
    d.arc([cx - sr, cy - sr, cx + sr, cy + sr], a0, a1, fill=255, width=int(sw))
    for a in (a0, a1):
        ex, ey = cx + (sr - sw / 2) * math.cos(math.radians(a)), cy + (sr - sw / 2) * math.sin(math.radians(a))
        d.ellipse([ex - sw / 2, ey - sw / 2, ex + sw / 2, ey + sw / 2], fill=255)
    shadow(c, stop, S * k * 0.004, S * k * 0.008, S * k * 0.008, alpha=0.3)
    fill(c, stop, TERRA_HI, TERRA, 45)

    # Poros: cincin hijau tua + inti terakota.
    hub = disc_mask(cx, cy, S * k * 0.112)
    shadow(c, hub, 0, S * k * 0.006, S * k * 0.01, alpha=0.25)
    fill(c, hub, GREEN, GREEN_DEEP, 90)
    core = disc_mask(cx, cy, S * k * 0.056)
    fill(c, core, TERRA_HI, TERRA, 60)
    return c


def save(img: Image.Image, px: int, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.resize((px, px), Image.LANCZOS).save(path, optimize=True)


def lockup(icon: Image.Image, font_path: Path, height: int = 400) -> Image.Image:
    """Ikon + kata KRING (Nunito Black, hijau tua), seperti gambar acuan."""
    f = ImageFont.truetype(str(font_path), int(height * 0.62))
    text = "KRING"
    tb = ImageDraw.Draw(Image.new("L", (1, 1))).textbbox((0, 0), text, font=f)
    gap = int(height * 0.18)
    W = height + gap + (tb[2] - tb[0]) + int(height * 0.05)
    out = Image.new("RGBA", (W, height), (0, 0, 0, 0))
    out.alpha_composite(icon.resize((height, height), Image.LANCZOS))
    ImageDraw.Draw(out).text((height + gap - tb[0], (height - (tb[3] - tb[1])) / 2 - tb[1]), text, font=f, fill=GREEN_DEEP)
    return out


if __name__ == "__main__":
    full, maskable, bare = mark(), mark(pad=0.1), mark(bg=False)
    res = Path("android/app/src/main/res")
    for folder, px in {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}.items():
        save(full, px, res / f"mipmap-{folder}" / "ic_launcher.png")
    web = Path("web")
    save(full, 192, web / "icons/Icon-192.png")
    save(full, 512, web / "icons/Icon-512.png")
    save(maskable, 192, web / "icons/Icon-maskable-192.png")
    save(maskable, 512, web / "icons/Icon-maskable-512.png")
    save(full, 32, web / "favicon.png")
    save(full, 512, Path("assets/kring_icon_512.png"))
    save(bare, 512, Path("../../docs/brand/kring_dial_512.png"))
    brand = Path("../../docs/brand")
    save(full, 1024, brand / "kring_icon_1024.png")
    lockup(full, Path("assets/fonts/Nunito-900.ttf")).save(brand / "kring_logo_lockup.png", optimize=True)
    print("ok")
