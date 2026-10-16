"""Pencatat latensi per giliran: akhir ucapan Mbah → suara TILIK mulai terdengar.

Akhir ucapan diperkirakan = waktu VAD memutuskan "berhenti bicara" dikurangi stop_secs
(VAD baru memutuskan setelah hening selama stop_secs). Satu baris JSON per giliran.
"""

from __future__ import annotations

import json
import math
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Any

from . import config


@dataclass
class TurnTiming:
    session_id: str
    transport: str
    speech_end: float  # perkiraan detik akhir ucapan (epoch)
    vad_stop: float
    stt_final: float | None = None
    api_done: float | None = None
    audio_start: float | None = None
    text: str = ""
    state: str = ""
    extra: dict[str, Any] = field(default_factory=dict)

    def breakdown_ms(self) -> dict[str, int | None]:
        def d(a: float | None, b: float | None) -> int | None:
            return round((b - a) * 1000) if a is not None and b is not None else None

        return {
            "total_ms": d(self.speech_end, self.audio_start),
            "vad_wait_ms": d(self.speech_end, self.vad_stop),
            "stt_ms": d(self.vad_stop, self.stt_final),
            "api_ms": d(self.stt_final, self.api_done),
            "tts_first_audio_ms": d(self.api_done, self.audio_start),
        }


def percentile(values: list[float], p: float) -> float | None:
    """Persentil dengan interpolasi linear (sama seperti numpy default)."""
    if not values:
        return None
    xs = sorted(values)
    k = (len(xs) - 1) * p / 100
    lo, hi = math.floor(k), math.ceil(k)
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


class LatencyLog:
    def __init__(self, path: Path | None = None):
        self.path = path or config.LATENCY_LOG

    def write(self, t: TurnTiming) -> dict[str, Any]:
        row = {"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), **{k: v for k, v in asdict(t).items() if k != "extra"},
               **t.breakdown_ms(), **t.extra}
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with self.path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")
        return row

    def rows(self) -> list[dict[str, Any]]:
        if not self.path.exists():
            return []
        out = []
        for line in self.path.read_text(encoding="utf-8").splitlines():
            if line.strip():
                out.append(json.loads(line))
        return out

    def summary(self, transport: str | None = None) -> dict[str, Any]:
        rows = [r for r in self.rows() if r.get("total_ms") is not None and (transport is None or r.get("transport") == transport)]
        res: dict[str, Any] = {"turns": len(rows)}
        for key in ("total_ms", "vad_wait_ms", "stt_ms", "api_ms", "tts_first_audio_ms"):
            vals = [r[key] for r in rows if r.get(key) is not None]
            res[key] = {"p50": _round(percentile(vals, 50)), "p95": _round(percentile(vals, 95))}
        return res


def _round(v: float | None) -> int | None:
    return None if v is None else round(v)
