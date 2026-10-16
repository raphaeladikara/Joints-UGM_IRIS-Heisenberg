"""Bangun model 3D lansia bergaya kartun (senada maskot Kiki) → assets/models/elder_{female,male}.glb + anchors.json.

Semua bentuk dibuat di sini dari bentuk dasar (elipsoid, tabung, torus, bubutan) dan tekstur prosedural: kebaya
kutubaru brokat + jarik batik kawung untuk Nenek, kemeja batik parang + sarung kotak-kotak + peci untuk Kakek.
Tidak ada aset pihak ketiga, jadi bebas dipakai. Titik organ (hotspot) dihitung dari permukaan model yang sama.

  py tool/build_toon_elder_glb.py assets/models
"""

from __future__ import annotations

import io
import json
import math
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("assets/models")
RNG = np.random.default_rng(7)


def lin(hexstr: str) -> tuple[float, float, float]:
    """Warna sRGB → linear (glTF baseColorFactor linear)."""
    c = [int(hexstr[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


# ---------- geometri ----------

def rot_to(b) -> np.ndarray:
    """Matriks rotasi yang memetakan sumbu +y ke arah b."""
    a = np.array([0.0, 1.0, 0.0])
    b = np.asarray(b, float) / np.linalg.norm(b)
    v, c = np.cross(a, b), float(a @ b)
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3) if c > 0 else np.diag([1.0, -1.0, -1.0])
    k = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + k + k @ k * (1 / (1 + c))


def rot_y(deg: float) -> np.ndarray:
    a = math.radians(deg)
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])


def rot_z(deg: float) -> np.ndarray:
    a = math.radians(deg)
    return np.array([[math.cos(a), -math.sin(a), 0], [math.sin(a), math.cos(a), 0], [0, 0, 1]])


class Part:
    """Satu bagian mesh: posisi, uv, segitiga yang sudah diorientasikan keluar, normal halus (dilas per posisi)."""

    def __init__(self, pos, uv, tris, ref):
        pos = np.asarray(pos, float)
        tris = np.asarray(tris, np.int64)
        ref = np.asarray(ref, float)  # titik acuan "dalam" per segitiga
        a, b, c = pos[tris[:, 0]], pos[tris[:, 1]], pos[tris[:, 2]]
        n = np.cross(b - a, c - a)
        flip = ((n * ((a + b + c) / 3 - ref)).sum(1)) < 0
        tris[flip] = tris[flip][:, [0, 2, 1]]
        n[flip] *= -1
        nor = np.zeros_like(pos)
        for k in range(3):
            np.add.at(nor, tris[:, k], n)
        key = np.round(pos / 1e-5).astype(np.int64)
        _, inv = np.unique(key, axis=0, return_inverse=True)
        inv = inv.reshape(-1)
        acc = np.zeros((inv.max() + 1, 3))
        np.add.at(acc, inv, nor)
        nor = acc[inv]
        ln = np.linalg.norm(nor, axis=1, keepdims=True)
        self.pos, self.uv, self.tris = pos, np.asarray(uv, float), tris
        self.nor = nor / np.where(ln == 0, 1, ln)


def grid(P, U, V, row_ref, cap_top=False, cap_bot=False) -> Part:
    """Kisi baris×kolom (kolom terakhir = jahitan) → Part. row_ref: titik acuan dalam per baris."""
    rows, cols = P.shape[:2]
    pos = P.reshape(-1, 3)
    uv = np.stack([U.reshape(-1), V.reshape(-1)], 1)
    tris, ref = [], []
    for r in range(rows - 1):
        mid = (np.asarray(row_ref[r]) + np.asarray(row_ref[r + 1])) / 2
        for c in range(cols - 1):
            a, b = r * cols + c, r * cols + c + 1
            d, e = a + cols, b + cols
            tris += [(a, d, b), (b, d, e)]
            ref += [mid, mid]
    centroid = np.mean(np.asarray(row_ref, float), axis=0)
    extra = []
    for flag, r in ((cap_top, 0), (cap_bot, rows - 1)):
        if not flag:
            continue
        ring = P[r, :-1]
        ci = len(pos) + len(extra)
        extra.append(ring.mean(axis=0))
        for c in range(cols - 1):
            tris.append((ci, r * cols + c, r * cols + c + 1))
            ref.append(centroid)
    if extra:
        pos = np.concatenate([pos, np.array(extra)])
        uv = np.concatenate([uv, np.full((len(extra), 2), 0.5)])
    return Part(pos, uv, tris, ref)


def ellipsoid(c, r, nu=56, nv=36, R=None, scale_fn=None) -> Part:
    """Elipsoid. u = 0,5 menghadap depan (+z) bila R = None. R memutar arah kutub (+y) lokal."""
    U, V = np.meshgrid(np.linspace(0, 1, nu + 1), np.linspace(0, 1, nv + 1))
    phi, th = (U - 0.5) * 2 * np.pi, V * np.pi
    d = np.stack([np.sin(th) * np.sin(phi), np.cos(th), np.sin(th) * np.cos(phi)], -1)
    if R is not None:
        d = d @ np.asarray(R).T
    s = scale_fn(d) if scale_fn else 1.0
    P = np.asarray(c) + d * np.asarray(r) * (s[..., None] if scale_fn else 1.0)
    return grid(P, U, V, [c] * (nv + 1))


def lathe(profile, nu=72, cap_top=False, cap_bot=True) -> Part:
    """Bubutan berpenampang elips. profile: (y, rx, rz, zoff) dari atas ke bawah. u = 0,5 di depan."""
    pr = np.array(profile, float)
    phi = (np.linspace(0, 1, nu + 1) - 0.5) * 2 * np.pi
    P = np.stack([pr[:, 1, None] * np.sin(phi)[None], np.repeat(pr[:, 0, None], nu + 1, 1),
                  pr[:, 3, None] + pr[:, 2, None] * np.cos(phi)[None]], -1)
    U = np.tile(np.linspace(0, 1, nu + 1), (len(pr), 1))
    V = np.repeat(((pr[0, 0] - pr[:, 0]) / (pr[0, 0] - pr[-1, 0]))[:, None], nu + 1, 1)
    return grid(P, U, V, [(0, y, z) for y, _, _, z in pr], cap_top, cap_bot)


def lathe_at(profile, y: float):
    """(rx, rz, zoff) bubutan pada ketinggian y (interpolasi linear)."""
    pr = np.array(profile, float)[::-1]
    return tuple(float(np.interp(y, pr[:, 0], pr[:, k])) for k in (1, 2, 3))


def tube(path, radii, nseg=20, caps=True) -> list[Part]:
    """Tabung menyusuri titik-titik path (bingkai transport sejajar), ujung bulat."""
    path = np.asarray(path, float)
    radii = np.broadcast_to(np.asarray(radii, float), (len(path),))
    t = np.gradient(path, axis=0)
    t /= np.linalg.norm(t, axis=1, keepdims=True)
    up = np.array([0.0, 0.0, 1.0]) if abs(t[0][2]) < 0.9 else np.array([1.0, 0.0, 0.0])
    n = np.cross(t[0], up)
    n /= np.linalg.norm(n)
    rings = []
    for i in range(len(path)):
        if i:
            n = n - t[i] * (n @ t[i])
            n /= np.linalg.norm(n)
        bnorm = np.cross(t[i], n)
        ang = np.linspace(0, 2 * np.pi, nseg + 1)
        rings.append(path[i] + radii[i] * (np.cos(ang)[:, None] * n + np.sin(ang)[:, None] * bnorm))
    P = np.array(rings)
    U, V = np.meshgrid(np.linspace(0, 1, nseg + 1), np.linspace(0, 1, len(path)))
    parts = [grid(P, U, V, list(path))]
    if caps:
        parts += [ellipsoid(path[0], [radii[0]] * 3, 16, 10), ellipsoid(path[-1], [radii[-1]] * 3, 16, 10)]
    return parts


def torus(c, R_major, r_minor, axis=(0, 1, 0), nu=48, nv=18, swap_uv=False) -> Part:
    Rm = rot_to(axis)
    u, v = np.linspace(0, 2 * np.pi, nu + 1), np.linspace(0, 2 * np.pi, nv + 1)
    Vv, Uu = np.meshgrid(v, u)  # baris = u (lingkar besar)
    loc = np.stack([(R_major + r_minor * np.cos(Vv)) * np.cos(Uu), r_minor * np.sin(Vv), (R_major + r_minor * np.cos(Vv)) * np.sin(Uu)], -1)
    P = np.asarray(c) + loc @ Rm.T
    centers = [np.asarray(c) + Rm @ np.array([R_major * math.cos(a), 0, R_major * math.sin(a)]) for a in u]
    U, V = (Vv / (2 * np.pi), Uu / (2 * np.pi))
    if swap_uv:
        U, V = V, U
    return grid(P, U, V, centers)


def head_z(hc, hr, x, y, inset=0.0) -> float:
    """z permukaan depan kepala elipsoid di (x, y)."""
    k = 1 - ((x - hc[0]) / hr[0]) ** 2 - ((y - hc[1]) / hr[1]) ** 2
    return hc[2] + hr[2] * math.sqrt(max(k, 0.0)) - inset


# ---------- tekstur prosedural ----------

def png(im: Image.Image) -> tuple[bytes, str]:
    buf = io.BytesIO()
    im.convert("RGB").save(buf, "PNG", optimize=True)
    return buf.getvalue(), "image/png"


def hexrgb(h: str):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def tex_kawung(w=1024, h=512, cell=78) -> Image.Image:
    """Jarik batik kawung warna sogan + lipatan wiru di depan (u ≈ 0,56)."""
    bg, cream, dark = hexrgb("#6B4325"), hexrgb("#ECD7AC"), hexrgb("#2A190D")
    im = Image.new("RGB", (w, h), bg)
    dr = ImageDraw.Draw(im)
    for gy in range(-1, h // cell + 2):
        for gx in range(-1, w // cell + 2):
            cx, cy = gx * cell, gy * cell
            for ang in (45, 135, 225, 315):
                a = math.radians(ang)
                ox, oy = cx + math.cos(a) * cell * 0.27, cy + math.sin(a) * cell * 0.27
                pts = []
                for t in np.linspace(0, 2 * np.pi, 28, endpoint=False):
                    ex, ey = math.cos(t) * cell * 0.24, math.sin(t) * cell * 0.13
                    pts.append((ox + ex * math.cos(a) - ey * math.sin(a), oy + ex * math.sin(a) + ey * math.cos(a)))
                dr.polygon(pts, fill=cream, outline=dark, width=3)
                dr.ellipse([ox - 3, oy - 3, ox + 3, oy + 3], fill=dark)
            dr.regular_polygon((cx + cell / 2, cy + cell / 2, 5), 4, fill=cream)
    # Wiru: lipatan kain di depan, pinggiran krem bergaris.
    x0 = int(w * 0.555)
    dr.rectangle([x0, 0, x0 + 46, h], fill=cream)
    for k in range(5):
        dr.line([x0 + 6 + k * 9, 0, x0 + 6 + k * 9, h], fill=bg, width=3)
    dr.line([x0, 0, x0, h], fill=dark, width=3)
    return im.filter(ImageFilter.GaussianBlur(0.6))


def tex_plaid(w=1024, h=512) -> Image.Image:
    """Sarung kotak-kotak: terakota + hijau tua + garis krem."""
    x = np.arange(w)[None, :, None]
    y = np.arange(h)[:, None, None]
    base = np.array(hexrgb("#A04A2A"), float)
    green = np.array(hexrgb("#154D39"), float)
    cream = np.array(hexrgb("#F7F3EA"), float)
    img = np.broadcast_to(base, (h, w, 3)).copy()
    for coord, period in ((x, 128), (y, 128)):
        band = ((coord % period) < 44).astype(float)
        img = img * (1 - 0.5 * band) + green * 0.5 * band
        line = (np.abs((coord % period) - 86) < 2).astype(float)
        img = img * (1 - 0.8 * line) + cream * 0.8 * line
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.5))


def tex_parang(w=1024, h=512, period=64) -> Image.Image:
    """Kemeja batik parang hijau tua + plaket kancing di depan."""
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    s = (xx + yy) / period
    f = (s + 0.13 * np.sin(2 * np.pi * (xx - yy) / (period * 0.9))) % 1.0
    navy, light, gold = np.array(hexrgb("#154D39")), np.array(hexrgb("#9CC5B0")), np.array(hexrgb("#E9A27E"))
    img = np.broadcast_to(navy, (h, w, 3)).astype(float).copy()
    stripe = (np.abs(f - 0.5) < 0.07)[..., None]
    img = np.where(stripe, light, img)
    dot = ((np.abs(f - 0.08) < 0.035) & (((xx - yy) / (period * 0.45)) % 1.0 < 0.35))[..., None]
    img = np.where(dot, gold, img)
    x0 = int(w * 0.5)
    img[:, x0 - 9:x0 + 9] = navy * 0.8
    img[:, x0 - 10:x0 - 8] = light
    return Image.fromarray(img.astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.6))


def tex_brokat(w=1024, h=512, bef=True) -> Image.Image:
    """Kebaya kutubaru: brokat hijau daun muda + bef krem di depan (u = 0,5)."""
    base, flower, cream, trim = hexrgb("#6FA88A"), hexrgb("#A9CDB9"), hexrgb("#F7F3EA"), hexrgb("#1F6B4F")
    im = Image.new("RGB", (w, h), base)
    dr = ImageDraw.Draw(im)
    for gy in range(0, h + 40, 40):
        for gx in range(0, w + 40, 40):
            cx, cy = gx + RNG.uniform(-10, 10) + (20 if (gy // 40) % 2 else 0), gy + RNG.uniform(-8, 8)
            r = RNG.uniform(5, 8)
            for k in range(5):
                a = k * 2 * math.pi / 5
                px, py = cx + math.cos(a) * r, cy + math.sin(a) * r
                dr.ellipse([px - r * 0.6, py - r * 0.6, px + r * 0.6, py + r * 0.6], fill=flower)
            dr.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=cream)
    if not bef:
        return im.filter(ImageFilter.GaussianBlur(0.5))
    bw = int(w * 0.034)
    x0 = w // 2
    dr.rectangle([x0 - bw, 0, x0 + bw, h], fill=cream)
    dr.line([x0 - bw, 0, x0 - bw, h], fill=trim, width=4)
    dr.line([x0 + bw, 0, x0 + bw, h], fill=trim, width=4)
    return im.filter(ImageFilter.GaussianBlur(0.5))


def tex_hair(w=512, h=256) -> Image.Image:
    """Uban: garis helai searah u (memancar dari sanggul / kutub)."""
    n = RNG.normal(0, 1, w)
    k = np.exp(-np.linspace(-2, 2, 9) ** 2)
    n = np.convolve(np.concatenate([n[-8:], n, n[:8]]), k / k.sum(), "same")[8:-8]
    lum = 0.9 + 0.05 * n / n.std()
    streak = RNG.random(w) < 0.06
    lum = np.where(streak, lum - 0.12, lum)
    col = np.array([236, 233, 227], float) / 255
    img = np.clip(lum[None, :, None] * col[None, None, :], 0, 1) * 255
    return Image.fromarray(np.repeat(img, h, axis=0).astype(np.uint8))


# ---------- GLB ----------

class Glb:
    def __init__(self):
        self.bin = bytearray()
        self.j = {"asset": {"version": "2.0", "generator": "KRING build_toon_elder_glb.py"},
                  "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [], "materials": [], "textures": [],
                  "images": [], "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
                  "accessors": [], "bufferViews": [], "buffers": [{"byteLength": 0}]}

    def _view(self, data: bytes, target: int | None = None) -> int:
        while len(self.bin) % 4:
            self.bin.append(0)
        view = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        self.bin += data
        if target:
            view["target"] = target
        self.j["bufferViews"].append(view)
        return len(self.j["bufferViews"]) - 1

    def _acc(self, arr: np.ndarray, type_: str, comp: int, target: int, minmax=False) -> int:
        acc = {"bufferView": self._view(arr.tobytes(), target), "componentType": comp, "count": len(arr), "type": type_}
        if minmax:
            acc["min"], acc["max"] = arr.min(axis=0).tolist(), arr.max(axis=0).tolist()
        self.j["accessors"].append(acc)
        return len(self.j["accessors"]) - 1

    def material(self, name, color, rough=0.75, metal=0.0, image=None) -> int:
        pbr = {"baseColorFactor": [*color, 1.0], "metallicFactor": metal, "roughnessFactor": rough}
        if image:
            self.j["images"].append({"bufferView": self._view(image[0]), "mimeType": image[1]})
            self.j["textures"].append({"sampler": 0, "source": len(self.j["images"]) - 1})
            pbr["baseColorTexture"] = {"index": len(self.j["textures"]) - 1}
        self.j["materials"].append({"name": name, "pbrMetallicRoughness": pbr})
        return len(self.j["materials"]) - 1

    def mesh(self, name, parts: list[Part], material: int) -> None:
        pos, nor, uv, idx, off = [], [], [], [], 0
        for p in parts:
            pos.append(p.pos)
            nor.append(p.nor)
            uv.append(p.uv)
            idx.append(p.tris.reshape(-1) + off)
            off += len(p.pos)
        prim = {"attributes": {"POSITION": self._acc(np.concatenate(pos).astype(np.float32), "VEC3", 5126, 34962, True),
                               "NORMAL": self._acc(np.concatenate(nor).astype(np.float32), "VEC3", 5126, 34962),
                               "TEXCOORD_0": self._acc(np.concatenate(uv).astype(np.float32), "VEC2", 5126, 34962)},
                "indices": self._acc(np.concatenate(idx).astype(np.uint32), "SCALAR", 5125, 34963), "material": material}
        self.j["meshes"].append({"name": name, "primitives": [prim]})
        self.j["nodes"].append({"name": name, "mesh": len(self.j["meshes"]) - 1})
        self.j["scenes"][0]["nodes"].append(len(self.j["nodes"]) - 1)

    def write(self, path: Path) -> None:
        while len(self.bin) % 4:
            self.bin.append(0)
        self.j["buffers"][0]["byteLength"] = len(self.bin)
        js = json.dumps(self.j, separators=(",", ":")).encode()
        js += b" " * (-len(js) % 4)
        with path.open("wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(self.bin)))
            f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942) + self.bin)


# ---------- karakter ----------

SKIN, SKIN_DEEP = "#CF9466", "#B97C52"
HC = np.array([0.0, 1.12, 0.0])  # pusat kepala
HR = np.array([0.19, 0.18, 0.175])


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def hair_scale(line_pts, out=1.07, inner=0.93, top_boost=0.03):
    """Skala radial rambut: di luar garis rambut tenggelam ke dalam kepala, di dalamnya menggembung."""
    xs, ys = zip(*line_pts)

    def fn(d):
        t = np.interp(d[..., 2], xs, ys)
        k = smoothstep(-0.05, 0.05, d[..., 1] - t)
        return inner + k * (out - inner + top_boost * np.clip(d[..., 1], 0, 1))
    return fn


def face(parts: dict, glasses: bool, moustache: bool) -> None:
    def zf(x, y, inset=0.0):
        return head_z(HC, HR, x, y, inset)

    parts["skin"] += [ellipsoid(HC, HR, 64, 44)]
    parts["skin"] += [ellipsoid((s * 0.186, 1.105, -0.01), (0.022, 0.042, 0.03), 20, 14) for s in (-1, 1)]
    parts["skin_deep"] += [ellipsoid((0, 1.083, zf(0, 1.083) - 0.006), (0.021, 0.018, 0.02), 20, 14)]
    for s in (-1, 1):
        ex, ey = s * 0.062, 1.118
        parts["eye"] += [ellipsoid((ex, ey, zf(ex, ey) - 0.002), (0.0155, 0.021, 0.01), 18, 12)]
        parts["white"] += [ellipsoid((ex - 0.005, ey + 0.008, zf(ex, ey) + 0.0065), (0.0048,) * 3, 10, 8)]
        parts["blush"] += [ellipsoid((s * 0.106, 1.066, zf(s * 0.106, 1.066) - 0.007), (0.03, 0.019, 0.011), 20, 12)]
        brow = [(s * x, 1.168 + 0.012 * math.sin(math.pi * (x - 0.034) / 0.06), 0) for x in np.linspace(0.034, 0.094, 8)]
        brow = [(x, y, zf(x, y) + 0.003) for x, y, _ in brow]
        parts["brow"] += tube(brow, np.linspace(0.0065, 0.0045, 8) if not moustache else 0.0085, 10)
    smile = [(x, 1.043 - 0.013 * (1 - (x / 0.036) ** 2), 0) for x in np.linspace(-0.036, 0.036, 11)]
    parts["mouth"] += tube([(x, y, zf(x, y) + 0.001) for x, y, _ in smile], 0.0055, 10)
    if glasses:
        for s in (-1, 1):
            gx, gy = s * 0.064, 1.114
            parts["frame"] += [torus((gx, gy, zf(gx, gy) + 0.02), 0.042, 0.0058, axis=rot_y(s * 14) @ np.array([0, 0, 1.0]), nu=40, nv=10)]
            temple = [(s * 0.104, 1.118, zf(0.104, 1.118) + 0.006), (s * 0.165, 1.122, 0.06), (s * 0.19, 1.12, -0.01)]
            parts["frame"] += tube(temple, 0.005, 8)
        bridge = [(x, 1.122 + 0.006 * (1 - (x / 0.023) ** 2), zf(0, 1.12) + 0.022) for x in np.linspace(-0.023, 0.023, 6)]
        parts["frame"] += tube(bridge, 0.005, 8)
    if moustache:
        for s in (-1, 1):
            parts["hair_plain"] += [ellipsoid((s * 0.026, 1.061, zf(s * 0.026, 1.061) - 0.002), (0.031, 0.011, 0.012), 20, 12,
                                              R=rot_z(-s * 14))]


def legs_and_feet(parts: dict, sole_color_key: str) -> None:
    for s in (-1, 1):
        parts["skin"] += tube([(s * 0.052, 0.025, 0.02), (s * 0.052, 0.11, 0.0)], 0.03, 16)
        parts["skin"] += [ellipsoid((s * 0.055, 0.03, 0.045), (0.038, 0.026, 0.062), 24, 14)]
        parts[sole_color_key] += [ellipsoid((s * 0.055, 0.008, 0.042), (0.05, 0.011, 0.082), 28, 12)]
        strap = [(s * 0.055 + x, 0.036 + 0.018 * (1 - (x / 0.042) ** 2), 0.062) for x in np.linspace(-0.042, 0.042, 9)]
        parts[sole_color_key] += tube(strap, 0.0095, 10)


def arms(parts: dict, sleeve_key: str, shoulder_x: float, sleeve_r: float, cuff_key: str | None = None) -> None:
    for s in (-1, 1):
        path = [(s * shoulder_x, 0.885, 0.0), (s * (shoulder_x + 0.045), 0.80, 0.003), (s * (shoulder_x + 0.065), 0.70, 0.018),
                (s * (shoulder_x + 0.075), 0.61, 0.036), (s * (shoulder_x + 0.078), 0.548, 0.046)]
        sleeve = tube(path, np.linspace(sleeve_r, sleeve_r * 0.8, len(path)), 24)
        for q in sleeve:
            q.uv = q.uv * (0.32, 0.75)  # skala motif kain di lengan ≈ skala di badan
        parts[sleeve_key] += sleeve
        wx = s * (shoulder_x + 0.08)
        if cuff_key:
            parts[cuff_key] += [torus((wx, 0.552, 0.046), sleeve_r * 0.8, 0.007, axis=(s * 0.05, 1, 0.12), nu=32, nv=8)]
        parts["skin"] += [ellipsoid((wx, 0.5, 0.05), (0.031, 0.05, 0.029), 20, 14)]
        parts["skin"] += [ellipsoid((wx - s * 0.022, 0.515, 0.068), (0.012, 0.022, 0.012), 12, 10, R=rot_z(s * 25))]


def build_female():
    p = {k: [] for k in ("skin", "skin_deep", "eye", "white", "blush", "brow", "mouth", "frame", "hair", "hair_plain",
                         "gold", "kebaya", "kebaya_sleeve", "jarik", "sandal")}
    face(p, glasses=True, moustache=False)
    # Rambut uban disisir ke belakang; kutub tekstur di sanggul supaya helai memancar ke sana.
    line = [(-1, -0.85), (-0.45, -0.6), (-0.15, 0.08), (0.15, 0.2), (0.45, 0.3), (0.75, 0.46), (1, 0.52)]
    p["hair"] += [ellipsoid(HC + (0, 0.008, -0.004), HR, 96, 64, R=rot_to((0, 0.35, -1)), scale_fn=hair_scale(line))]
    bun_c = np.array([0.0, HC[1] + 0.06, -0.205])
    p["hair"] += [torus(bun_c, 0.052, 0.037, axis=(0, 0.35, -1), nu=48, nv=20, swap_uv=True)]
    p["hair"] += [ellipsoid(bun_c + (0, 0.004, -0.012), (0.045, 0.045, 0.04), 32, 20, R=rot_to((0, 0.35, -1)))]
    pin = [bun_c + (-0.085, 0.045, -0.02), bun_c + (0.085, -0.03, -0.02)]
    p["gold"] += tube(pin, 0.0055, 8, caps=False)
    p["gold"] += [ellipsoid(pin[0], (0.013,) * 3, 14, 10), ellipsoid(pin[1], (0.009,) * 3, 12, 8)]
    for s in (-1, 1):
        p["gold"] += [ellipsoid((s * 0.19, 1.066, 0.0), (0.0085,) * 3, 12, 8)]  # subang

    p["skin"] += tube([(0, 0.9, 0.0), (0, 1.0, 0.0)], 0.05, 20, caps=False)
    torso = [(0.958, 0.058, 0.052, 0), (0.945, 0.11, 0.08, 0), (0.918, 0.152, 0.1, 0), (0.88, 0.168, 0.115, 0),
             (0.8, 0.165, 0.126, 0.012), (0.72, 0.156, 0.121, 0.01), (0.64, 0.152, 0.12, 0.006), (0.56, 0.17, 0.13, 0),
             (0.5, 0.186, 0.142, 0), (0.494, 0.17, 0.128, 0)]
    p["kebaya"] += [lathe(torso, 80, cap_top=True, cap_bot=False)]
    for y in (0.865, 0.79, 0.715):  # tiga bros kutubaru
        rx, rz, zo = lathe_at(torso, y)
        p["gold"] += [ellipsoid((0, y, zo + rz + 0.002), (0.0135, 0.0135, 0.008), 18, 12)]
    arms(p, "kebaya_sleeve", 0.15, 0.054)
    skirt = [(0.6, 0.15, 0.115, 0), (0.5, 0.18, 0.137, 0), (0.4, 0.177, 0.136, 0), (0.28, 0.162, 0.13, 0.004),
             (0.16, 0.143, 0.121, 0.008), (0.09, 0.132, 0.116, 0.01)]
    p["jarik"] += [lathe(skirt, 80)]
    legs_and_feet(p, "sandal")
    return p, {"kebaya": tex_brokat(), "kebaya_sleeve": tex_brokat(bef=False), "jarik": tex_kawung(), "hair": tex_hair()}, torso


def build_male():
    p = {k: [] for k in ("skin", "skin_deep", "eye", "white", "blush", "brow", "mouth", "frame", "hair", "hair_plain",
                         "peci", "shirt", "shirt_plain", "button", "sarung", "sandal")}
    face(p, glasses=False, moustache=True)
    line = [(-1, -0.7), (-0.45, -0.5), (-0.15, 0.1), (0.15, 0.22), (0.45, 0.4), (0.75, 0.55), (1, 0.6)]
    p["hair"] += [ellipsoid(HC + (0, 0.004, -0.004), HR, 96, 64, R=rot_to((0, 1, -0.2)), scale_fn=hair_scale(line, out=1.035, top_boost=0))]
    y0 = HC[1] + 0.082
    peci = [(y0 + 0.125, 0.0, 0.0, -0.004), (y0 + 0.124, 0.12, 0.11, -0.004), (y0 + 0.118, 0.158, 0.146, -0.004),
            (y0 + 0.1, 0.168, 0.156, -0.004), (y0, 0.178, 0.166, -0.004), (y0 - 0.006, 0.172, 0.16, -0.004)]
    p["peci"] += [lathe(peci, 72, cap_bot=False)]

    p["skin"] += tube([(0, 0.9, 0.0), (0, 1.0, 0.0)], 0.054, 20, caps=False)
    torso = [(0.958, 0.062, 0.056, 0), (0.945, 0.12, 0.085, 0), (0.92, 0.17, 0.105, 0), (0.88, 0.185, 0.118, 0),
             (0.8, 0.178, 0.124, 0.006), (0.72, 0.168, 0.123, 0.008), (0.64, 0.165, 0.124, 0.008), (0.56, 0.172, 0.128, 0),
             (0.5, 0.18, 0.134, 0), (0.494, 0.168, 0.124, 0)]
    p["shirt"] += [lathe(torso, 80, cap_top=True, cap_bot=False)]
    p["shirt_plain"] += [torus((0, 0.952, 0.004), 0.06, 0.016, nu=40, nv=12)]  # kerah
    for y in (0.88, 0.8, 0.72, 0.64):
        rx, rz, zo = lathe_at(torso, y)
        p["button"] += [ellipsoid((0, y, zo + rz + 0.001), (0.009, 0.009, 0.005), 14, 10)]
    arms(p, "shirt", 0.165, 0.056)
    skirt = [(0.6, 0.158, 0.118, 0), (0.5, 0.18, 0.135, 0), (0.3, 0.172, 0.132, 0.004), (0.09, 0.16, 0.126, 0.008)]
    p["sarung"] += [lathe(skirt, 80)]
    legs_and_feet(p, "sandal")
    return p, {"shirt": tex_parang(), "sarung": tex_plaid(), "hair": tex_hair()}, torso


MATS = {  # nama: (warna sRGB, kekasaran, logam)
    "skin": (SKIN, 0.62, 0), "skin_deep": (SKIN_DEEP, 0.62, 0), "eye": ("#2A211C", 0.25, 0), "white": ("#FFFFFF", 0.2, 0),
    "blush": ("#E98C7A", 0.7, 0), "brow": ("#D9D5CE", 0.85, 0), "mouth": ("#7A3226", 0.6, 0), "frame": ("#7B4A2C", 0.35, 0),
    "hair": ("#FFFFFF", 0.82, 0), "hair_plain": ("#ECE9E3", 0.82, 0), "gold": ("#E2B14A", 0.32, 0.75),
    "kebaya": ("#FFFFFF", 0.78, 0), "kebaya_sleeve": ("#FFFFFF", 0.78, 0), "jarik": ("#FFFFFF", 0.85, 0),
    "sandal": ("#6A4632", 0.7, 0), "peci": ("#1E2A24", 0.95, 0), "shirt": ("#FFFFFF", 0.8, 0),
    "shirt_plain": ("#154D39", 0.8, 0), "button": ("#F2E6CC", 0.4, 0), "sarung": ("#FFFFFF", 0.85, 0),
}

# Titik organ: (x, y) target di depan tubuh; +x = kiri pasien (model menghadap +z). Diproyeksikan ke permukaan terdepan.
SPOTS = {
    "brain": (0.0, HC[1] + 0.088),
    "heart": (0.082, 0.80),
    "lungs": (-0.082, 0.81),
    "arm": (None, 0.70),  # x diisi dari posisi siku
    "meds": (0.0, 0.625),
    "legs": (-0.075, 0.3),
}


def build(name: str, maker) -> dict:
    parts, textures, _ = maker()
    glb = Glb()
    allpts = []
    for key, plist in parts.items():
        if not plist:
            continue
        col, rough, metal = MATS[key]
        img = png(textures[key]) if key in textures else None
        glb.mesh(key, plist, glb.material(key, lin(col), rough, metal, img))
        allpts += [q.pos for q in plist]
    pts = np.concatenate(allpts)
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"{name}.glb"
    glb.write(out)

    shoulder = 0.15 if "kebaya" in parts else 0.165
    spots = {}
    for sid, (x, y) in SPOTS.items():
        x = shoulder + 0.065 if x is None else x
        near = pts[(np.abs(pts[:, 0] - x) < 0.018) & (np.abs(pts[:, 1] - y) < 0.018)]
        q = near[near[:, 2].argmax()] if len(near) else np.array([x, y, 0.15])
        spots[sid] = [round(float(q[0]), 4), round(float(q[1]), 4), round(float(q[2]) + 0.01, 4)]
    ymin, ymax = float(pts[:, 1].min()), float(pts[:, 1].max())
    info = {"height": round(ymax - ymin, 3), "center_y": round((ymin + ymax) / 2, 3), "spots": spots}
    print(f"{out.name}: {out.stat().st_size / 1e6:.2f} MB, {len(pts)} verteks, {info}")
    return info


if __name__ == "__main__":
    anchors = {"elder_female": build("elder_female", build_female), "elder_male": build("elder_male", build_male)}
    (OUT / "anchors.json").write_text(json.dumps(anchors, indent=1), encoding="utf-8")
