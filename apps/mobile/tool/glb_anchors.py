"""Hitung titik status organ (hotspot) di permukaan depan model GLB lansia → assets/models/anchors.json.

Titik diberikan sebagai pecahan tinggi badan (0 = telapak, 1 = ubun-ubun) dan posisi x relatif lebar bahu;
skrip mencari verteks tubuh terdepan di sekitar titik itu supaya hotspot menempel di kulit/baju.
  py tool/glb_anchors.py assets/models
"""
import json, struct, sys
from pathlib import Path
import numpy as np

SPOTS = {  # id: (x sebagai pecahan setengah lebar bahu, +x = kiri pasien; tinggi pecahan; mesh)
    "brain": (0.0, 0.955, "body"),
    "heart": (0.22, 0.715, None),
    "lungs": (-0.32, 0.73, None),
    "arm": (0.86, 0.66, None),
    "meds": (0.0, 0.585, None),
    "legs": (-0.3, 0.27, None),
}

def meshes(path):
    data = path.read_bytes()
    jl = struct.unpack_from("<I", data, 12)[0]
    j = json.loads(data[20:20 + jl])
    binoff = 20 + jl + 8
    out = {}
    for node in j["nodes"]:
        prim = j["meshes"][node["mesh"]]["primitives"][0]
        acc = j["accessors"][prim["attributes"]["POSITION"]]
        view = j["bufferViews"][acc["bufferView"]]
        arr = np.frombuffer(data, np.float32, acc["count"] * 3, binoff + view.get("byteOffset", 0)).reshape(-1, 3) * node["scale"][0]
        out[node["name"]] = arr
    return out

res = {}
for f in sorted(Path(sys.argv[1]).glob("elder_*.glb")):
    m = meshes(f)
    allpts = np.concatenate(list(m.values()))
    ymin, ymax = allpts[:, 1].min(), allpts[:, 1].max()
    h = ymax - ymin
    body = m["body"]
    chest = allpts[np.abs(allpts[:, 1] - (ymin + 0.78 * h)) < 0.02]
    half_shoulder = (chest[:, 0].max() - chest[:, 0].min()) / 2
    spots = {}
    for sid, (fx, fy, only) in SPOTS.items():
        pts = m[only] if only else allpts
        tx, ty = fx * half_shoulder, ymin + fy * h
        near = pts[(np.abs(pts[:, 0] - tx) < 0.035) & (np.abs(pts[:, 1] - ty) < 0.035)]
        p = near[near[:, 2].argmax()] if len(near) else np.array([tx, ty, 0.1])
        spots[sid] = [round(float(p[0]), 4), round(float(p[1]), 4), round(float(p[2]) + 0.012, 4)]
    res[f.stem] = {"height": round(float(h), 3), "center_y": round(float((ymin + ymax) / 2), 3), "spots": spots}
    print(f.stem, res[f.stem])
(Path(sys.argv[1]) / "anchors.json").write_text(json.dumps(res, indent=1), encoding="utf-8")
