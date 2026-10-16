"""Bangun model 3D lansia (GLB) dari aset MakeHuman CC0.

Sumber (semua CC0, https://static.makehumancommunity.org/assets/assetpacks.html):
  - base.obj + target makro (repo makehumancommunity/makehuman, folder makehuman/data)
  - paket "MakeHuman system assets": kulit old_asian_*, baju, rambut, alis, mata.

Langkah: base mesh → target usia/gender/ras Asia (lansia ±70 th) → baju/rambut/alis/mata dipasang dengan aturan
fitting .mhclo → tekstur diperkecil → GLB (glTF 2.0) satu berkas. Tidak butuh Blender.

  py tool/build_elder_glb.py <folder_base_dan_target> <folder_system_assets> <folder_keluar>
"""

from __future__ import annotations

import io
import json
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SRC, ASSETS, OUT = (Path(a) for a in sys.argv[1:4])

AGE_YEARS = 72
OLD_W = (AGE_YEARS - 25) / (90 - 25)  # MakeHuman: 0.5 = 25 th, 1.0 = 90 th

VARIANTS = {
    "elder_female": {
        "gender": "female", "skin": "skins/old_asian_female/old_lightskinned_female_diffuse2.png",
        "weight": 0.25,  # sedikit di atas rata-rata
        "proxies": [
            ("clothes/female_elegantsuit01/female_elegantsuit01", (0.62, 0.78, 1.0)),
            ("clothes/shoes04/shoes04", None),
            ("hair/bob02/bob02", (0.86, 0.85, 0.83)),
            ("eyebrows/eyebrow010/eyebrow010", (0.75, 0.74, 0.72)),
            ("eyes/high-poly/high-poly", None),
        ],
    },
    "elder_male": {
        "gender": "male", "skin": "skins/old_asian_male/old_lightskinned_male_diffuse2.png",
        "weight": 0.2,
        "proxies": [
            ("clothes/male_casualsuit01/male_casualsuit01", None),
            ("clothes/shoes01/shoes01", None),
            ("hair/short02/short02", (0.80, 0.80, 0.80)),
            ("eyebrows/eyebrow001/eyebrow001", (0.70, 0.70, 0.70)),
            ("eyes/high-poly/high-poly", None),
        ],
    },
}


# ---------- OBJ ----------

def read_obj(path: Path):
    v, vt, faces, groups = [], [], [], []
    group = ""
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        if line.startswith("v "):
            v.append([float(x) for x in line.split()[1:4]])
        elif line.startswith("vt "):
            vt.append([float(x) for x in line.split()[1:3]])
        elif line.startswith("g "):
            group = line[2:].strip()
        elif line.startswith("f "):
            idx = []
            for tok in line.split()[1:]:
                parts = tok.split("/")
                idx.append((int(parts[0]) - 1, int(parts[1]) - 1 if len(parts) > 1 and parts[1] else -1))
            faces.append(idx)
            groups.append(group)
    return np.array(v, dtype=np.float64), np.array(vt, dtype=np.float64), faces, groups


def read_target(path: Path, n: int) -> np.ndarray:
    d = np.zeros((n, 3))
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line or line[0] == "#":
            continue
        p = line.split()
        d[int(p[0])] = [float(p[1]), float(p[2]), float(p[3])]
    return d


def read_mhclo(path: Path):
    refs, scales, delete = [], {}, set()
    mode = None
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        p = s.split()
        if p[0] in ("x_scale", "y_scale", "z_scale"):
            scales["xyz".index(p[0][0])] = (int(p[1]), int(p[2]), float(p[3]))
            continue
        if p[0] == "verts":
            mode = "verts"
            continue
        if p[0] == "delete_verts":
            mode = "delete"
            continue
        if p[0].isalpha() or p[0].startswith("weights"):
            mode = None if p[0] not in ("verts", "delete_verts") else mode
            continue
        if mode == "verts":
            if len(p) == 1:
                refs.append(((int(p[0]), 0, 0), (1.0, 0.0, 0.0), (0.0, 0.0, 0.0)))
            else:
                refs.append(((int(p[0]), int(p[1]), int(p[2])), tuple(map(float, p[3:6])), tuple(map(float, p[6:9]))))
        elif mode == "delete":
            i = 0
            while i < len(p):
                if i + 2 < len(p) and p[i + 1] == "-":
                    delete.update(range(int(p[i]), int(p[i + 2]) + 1))
                    i += 3
                else:
                    delete.add(int(p[i]))
                    i += 1
    return refs, scales, delete


def material_texture(mhmat: Path) -> Path | None:
    for line in mhmat.read_text(encoding="utf-8", errors="ignore").splitlines():
        if line.startswith("diffuseTexture"):
            return mhmat.parent / Path(line.split(None, 1)[1].strip()).name
    return None


# ---------- geometri ----------

def triangulate(faces):
    out = []
    for f in faces:
        for i in range(1, len(f) - 1):
            out.append((f[0], f[i], f[i + 1]))
    return out


def build_mesh(coords: np.ndarray, uvs: np.ndarray, tris):
    """Pisahkan verteks per pasangan (posisi, uv) seperti yang dibutuhkan glTF, dengan normal halus per posisi."""
    normals = np.zeros_like(coords)
    for t in tris:
        a, b, c = (coords[k[0]] for k in t)
        n = np.cross(b - a, c - a)
        for k in t:
            normals[k[0]] += n
    lens = np.linalg.norm(normals, axis=1, keepdims=True)
    normals = normals / np.where(lens == 0, 1, lens)
    key_index: dict[tuple[int, int], int] = {}
    pos, nor, tex, idx = [], [], [], []
    for t in tris:
        for vi, ti in t:
            k = (vi, ti)
            if k not in key_index:
                key_index[k] = len(pos)
                pos.append(coords[vi])
                nor.append(normals[vi])
                u, v = uvs[ti] if ti >= 0 else (0.0, 0.0)
                tex.append((u, 1.0 - v))
            idx.append(key_index[k])
    return np.array(pos, np.float32), np.array(nor, np.float32), np.array(tex, np.float32), np.array(idx, np.uint32)


def fit_proxy(refs, scales, body: np.ndarray) -> np.ndarray:
    scale = np.ones(3)
    for axis, (a, b, den) in scales.items():
        scale[axis] = abs(body[a][axis] - body[b][axis]) / den
    out = np.zeros((len(refs), 3))
    for i, (vs, ws, ds) in enumerate(refs):
        out[i] = ws[0] * body[vs[0]] + ws[1] * body[vs[1]] + ws[2] * body[vs[2]] + np.array(ds) * scale
    return out


# ---------- tekstur ----------

def encode_image(path: Path, max_px: int, tint=None) -> tuple[bytes, str, bool]:
    im = Image.open(path)
    has_alpha = im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info)
    im = im.convert("RGBA" if has_alpha else "RGB")
    if max(im.size) > max_px:
        im.thumbnail((max_px, max_px), Image.LANCZOS)
    if tint is not None:
        # Rambut/alis beruban: luminans dipertahankan, warna diganti abu keperakan.
        rgb = np.asarray(im.convert("RGB"), dtype=np.float32) / 255.0
        lum = (rgb @ np.array([0.299, 0.587, 0.114]))[..., None]
        lum = 0.35 + 0.65 * (lum / max(lum.max(), 1e-3))
        out = np.clip(lum * np.array(tint), 0, 1)
        img = Image.fromarray((out * 255).astype(np.uint8), "RGB")
        if has_alpha:
            img.putalpha(im.getchannel("A"))
        im = img
    buf = io.BytesIO()
    if has_alpha:
        im.save(buf, "PNG", optimize=True)
        return buf.getvalue(), "image/png", True
    im.save(buf, "JPEG", quality=84, optimize=True)
    return buf.getvalue(), "image/jpeg", False


# ---------- GLB ----------

class Glb:
    def __init__(self):
        self.bin = bytearray()
        self.j = {"asset": {"version": "2.0", "generator": "TILIK build_elder_glb.py (MakeHuman CC0)"},
                  "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [], "materials": [], "textures": [],
                  "images": [], "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
                  "accessors": [], "bufferViews": [], "buffers": [{"byteLength": 0}]}

    def _view(self, data: bytes, target: int | None = None) -> int:
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin += data
        view = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            view["target"] = target
        self.j["bufferViews"].append(view)
        return len(self.j["bufferViews"]) - 1

    def _acc(self, arr: np.ndarray, type_: str, comp: int, target: int, minmax=False) -> int:
        acc = {"bufferView": self._view(arr.tobytes(), target), "componentType": comp, "count": len(arr), "type": type_}
        if minmax:
            acc["min"] = arr.min(axis=0).tolist()
            acc["max"] = arr.max(axis=0).tolist()
        self.j["accessors"].append(acc)
        return len(self.j["accessors"]) - 1

    def material(self, name: str, image: tuple[bytes, str, bool] | None, color=(1, 1, 1), rough=0.85, double=False) -> int:
        pbr = {"baseColorFactor": [*color, 1.0], "metallicFactor": 0.0, "roughnessFactor": rough}
        mat = {"name": name, "pbrMetallicRoughness": pbr, "doubleSided": double}
        if image:
            data, mime, alpha = image
            self.j["images"].append({"bufferView": self._view(data), "mimeType": mime})
            self.j["textures"].append({"sampler": 0, "source": len(self.j["images"]) - 1})
            pbr["baseColorTexture"] = {"index": len(self.j["textures"]) - 1}
            if alpha:
                mat["alphaMode"] = "MASK"
                mat["alphaCutoff"] = 0.35
                mat["doubleSided"] = True
        self.j["materials"].append(mat)
        return len(self.j["materials"]) - 1

    def mesh(self, name: str, pos, nor, tex, idx, material: int) -> None:
        prim = {"attributes": {"POSITION": self._acc(pos, "VEC3", 5126, 34962, True),
                               "NORMAL": self._acc(nor, "VEC3", 5126, 34962),
                               "TEXCOORD_0": self._acc(tex, "VEC2", 5126, 34962)},
                "indices": self._acc(idx, "SCALAR", 5125, 34963), "material": material}
        self.j["meshes"].append({"name": name, "primitives": [prim]})
        self.j["nodes"].append({"name": name, "mesh": len(self.j["meshes"]) - 1})
        self.j["scenes"][0]["nodes"].append(len(self.j["nodes"]) - 1)

    def write(self, path: Path) -> None:
        while len(self.bin) % 4:
            self.bin.append(0)
        self.j["buffers"][0]["byteLength"] = len(self.bin)
        js = json.dumps(self.j, separators=(",", ":")).encode()
        js += b" " * (-len(js) % 4)
        total = 12 + 8 + len(js) + 8 + len(self.bin)
        with path.open("wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942) + self.bin)


def pose_arms(coords: np.ndarray, body_verts: np.ndarray, degrees: float = 37.0) -> None:
    """Turunkan lengan dari pose-A bawaan MakeHuman: rotasi di sendi bahu, sudut per verteks = sudut × bobot rig."""
    skel = json.loads((SRC / "default.mhskel").read_text(encoding="utf-8"))
    weights = json.loads((SRC / "default_weights.mhw").read_text(encoding="utf-8"))["weights"]
    bones = skel["bones"]
    children: dict[str, list[str]] = {}
    for b, info in bones.items():
        children.setdefault(info["parent"], []).append(b)

    def chain(root: str) -> list[str]:
        out, stack = [], [root]
        while stack:
            b = stack.pop()
            out.append(b)
            stack += children.get(b, [])
        return out

    for side, sign in (("L", -1.0), ("R", 1.0)):
        w = np.zeros(len(coords))
        for b in chain(f"upperarm01.{side}"):
            for vi, wt in weights.get(b, []):
                w[vi] += wt
        for vi, wt in weights.get(f"shoulder01.{side}", []):
            w[vi] += wt * 0.35
        w = np.clip(w, 0, 1)
        # Verteks helper (tempat baju menempel) tidak punya bobot rig: ambil dari verteks tubuh terdekat.
        helpers = np.setdiff1d(np.arange(len(coords)), body_verts)
        bpos = coords[body_verts]
        for start in range(0, len(helpers), 512):
            hs = helpers[start:start + 512]
            d = ((coords[hs][:, None, :] - bpos[None, :, :]) ** 2).sum(-1)
            w[hs] = w[body_verts[d.argmin(axis=1)]]
        pivot = coords[skel["joints"][f"upperarm01.{side}____head"]].mean(axis=0)
        ang = np.radians(degrees) * sign * w
        rel = coords - pivot
        c, s = np.cos(ang), np.sin(ang)
        x = rel[:, 0] * c - rel[:, 1] * s
        y = rel[:, 0] * s + rel[:, 1] * c
        moved = w > 0
        coords[moved, 0] = (x + pivot[0])[moved]
        coords[moved, 1] = (y + pivot[1])[moved]


def build(name: str, cfg: dict) -> None:
    coords, uvs, faces, groups = read_obj(SRC / "base.obj")
    n = len(coords)
    g, other = cfg["gender"], "male" if cfg["gender"] == "female" else "female"
    # Makro: ras Asia 100 %, gender penuh, usia lansia; berat badan sedikit di atas rata-rata.
    for age, w in (("old", OLD_W), ("young", 1 - OLD_W)):
        coords += read_target(SRC / f"asian-{g}-{age}.target", n) * w
        coords += read_target(SRC / f"universal-{g}-{age}-averagemuscle-maxweight.target", n) * w * cfg["weight"]
    _ = other

    # Sedikit membungkuk & lebih pendek: kepala/leher maju sedikit, sesuai postur lansia.
    y = coords[:, 1]
    top = y.max()
    bend = np.clip((y - (top - 4.0)) / 4.0, 0, 1)  # 4 dm teratas
    coords[:, 2] += bend ** 2 * 0.28
    coords[:, 1] -= bend ** 2 * 0.08

    body_verts = np.unique([v for f, gr in zip(faces, groups) if gr == "body" for v, _ in f])
    pose_arms(coords, body_verts)

    glb = Glb()
    deleted: set[int] = set()
    proxies = []
    for rel, tint in cfg["proxies"]:
        base = ASSETS / rel
        refs, scales, delete = read_mhclo(base.with_suffix(".mhclo"))
        deleted |= delete
        pv, pt, pf, _ = read_obj(base.with_suffix(".obj"))
        fitted = fit_proxy(refs, scales, coords)
        assert len(fitted) == len(pv), (rel, len(fitted), len(pv))
        mhmat = next(base.parent.glob("*.mhmat"), None)
        if rel.startswith("eyes/"):
            mhmat = ASSETS / "eyes/materials/brown.mhmat"
        proxies.append((rel, fitted, pt, pf, mhmat, tint))

    # Tubuh: hanya grup "body", tanpa verteks yang tertutup baju (mencegah kulit menembus kain).
    body_faces = [f for f, gr in zip(faces, groups) if gr == "body" and not any(v in deleted for v, _ in f)]
    skin = encode_image(ASSETS / cfg["skin"], 1024)
    m = glb.material("skin", skin, rough=0.7)
    glb.mesh("body", *build_mesh(coords, uvs, triangulate(body_faces)), m)

    for rel, fitted, pt, pf, mhmat, tint in proxies:
        tex_path = material_texture(mhmat) if mhmat else None
        img = encode_image(tex_path, 1024 if "clothes/" in rel and "shoes" not in rel else 512, tint) if tex_path and tex_path.exists() else None
        m = glb.material(Path(rel).name, img, rough=0.6 if rel.startswith("eyes/") else 0.9, double="hair/" in rel)
        glb.mesh(Path(rel).name, *build_mesh(fitted, pt, triangulate(pf)), m)

    # Skala MakeHuman = desimeter → meter.
    for node in glb.j["nodes"]:
        node["scale"] = [0.1, 0.1, 0.1]
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"{name}.glb"
    glb.write(out)
    print(f"{out.name}: {out.stat().st_size / 1e6:.2f} MB, tinggi {(coords[:, 1].max() - coords[:, 1].min()) / 10:.2f} m, "
          f"y min {coords[:, 1].min() / 10:.2f}")


if __name__ == "__main__":
    for k, c in VARIANTS.items():
        build(k, c)
