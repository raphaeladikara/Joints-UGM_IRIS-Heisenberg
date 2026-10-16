"""Evaluasi E2 (audio): WER ElevenLabs Scribe pada audio kualitas telepon (8 kHz mu-law), Indonesia vs Jawa.

Ucapan "Mbah" dibuat sekali lewat ElevenLabs TTS (suara ELEVENLABS_SIM_VOICE_ID, cache di apps/voice/sim_audio/,
tidak di-commit), diturunkan ke 8 kHz mu-law dengan ffmpeg (seperti audio Twilio), lalu ditranskripsi Scribe dengan
pengaturan bahasa yang sama dengan pipeline (ELEVENLABS_STT_LANGUAGE, bawaan "id"). Angka dalam transkrip dibaca
ulang jadi kata (terbilang) sebelum WER dihitung, supaya "150/90" tidak dihitung salah.

Batasan: suara sintetis, bukan rekaman lansia sungguhan. Ini batas bawah kesulitan, bukan angka lapangan.

  py eval/run_wer.py      # butuh ELEVENLABS_API_KEY di .env dan ffmpeg di PATH; memakai kredit ElevenLabs
"""
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import wave
from datetime import datetime
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "apps" / "voice" / "sim_audio"
REPORTS = Path(__file__).resolve().parent / "reports"
sys.path.insert(0, str(ROOT / "apps" / "api"))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from run_eval import load_env  # noqa: E402

LINES = {
    "id": [
        "Iya, saya sendiri.",
        "Sampun, tadi habis sarapan.",
        "Seratus lima puluh per sembilan puluh.",
        "Iya, betul.",
        "Tidak ada keluhan.",
        "Tomatnya sudah panen dua keranjang, dibagi ke tetangga.",
        "Belum, saya lupa minum obat.",
        "Dada saya sakit seperti ditindih.",
        "Bicara saya jadi pelo sejak tadi pagi.",
        "Saya kangen sama anak saya.",
    ],
    "jv": [
        "Sampun, wau sasampunipun sarapan.",
        "Dereng, kula kesupen.",
        "Obatipun sampun telas.",
        "Mboten wonten keluhan, sehat.",
        "Ngomongku kok angel, tangan kiwa lemes.",
        "Sirahku lara banget wiwit esuk.",
        "Tomate wis panen rong kranjang.",
        "Kula kangen kaliyan Dika.",
    ],
}


def norm(text: str) -> list[str]:
    from app import nlu

    t = text.lower().replace("/", " per ")
    t = re.sub(r"\d+", lambda m: " " + nlu.terbilang(int(m.group())) + " ", t)
    t = re.sub(r"[^\w\s']", " ", t)
    return t.split()


def wer(ref: list[str], hyp: list[str]) -> tuple[int, int]:
    d = list(range(len(hyp) + 1))
    for i, r in enumerate(ref, 1):
        prev, d[0] = d[0], i
        for j, h in enumerate(hyp, 1):
            prev, d[j] = d[j], min(d[j] + 1, d[j - 1] + 1, prev + (r != h))
    return d[len(hyp)], len(ref)


def tts(text: str, voice: str, key: str, model: str) -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{hashlib.sha1(f'{voice}:{text}'.encode()).hexdigest()[:12]}.wav"
    if not path.exists():
        r = httpx.post(f"https://api.elevenlabs.io/v1/text-to-speech/{voice}", params={"output_format": "pcm_16000"},
                       headers={"xi-api-key": key}, json={"text": text, "model_id": model, "language_code": "id"}, timeout=60)
        r.raise_for_status()
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(16000)
            w.writeframes(r.content)
    return path


def to_phone(src: Path, dst: Path) -> None:
    """16 kHz PCM -> 8 kHz mu-law (kanal telepon) -> kembali ke WAV PCM supaya bisa diunggah."""
    ulaw = dst.with_suffix(".ulaw.wav")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-ar", "8000", "-ac", "1", "-c:a", "pcm_mulaw", str(ulaw)], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(ulaw), "-c:a", "pcm_s16le", str(dst)], check=True)


def stt(path: Path, key: str, lang: str) -> str:
    for model in ("scribe_v2", "scribe_v1"):
        with path.open("rb") as f:
            r = httpx.post("https://api.elevenlabs.io/v1/speech-to-text", headers={"xi-api-key": key},
                           data={"model_id": model, "language_code": lang}, files={"file": (path.name, f, "audio/wav")}, timeout=120)
        if r.status_code == 200:
            return r.json().get("text", ""), model
        if r.status_code not in (400, 422):
            r.raise_for_status()
    r.raise_for_status()


def main() -> None:
    load_env()
    key = os.environ.get("ELEVENLABS_API_KEY")
    if not key:
        sys.exit("ELEVENLABS_API_KEY kosong")
    voice = os.environ.get("ELEVENLABS_SIM_VOICE_ID") or os.environ["ELEVENLABS_VOICE_ID"]
    tts_model = os.environ.get("ELEVENLABS_TTS_MODEL") or "eleven_flash_v2_5"
    lang = os.environ.get("ELEVENLABS_STT_LANGUAGE") or "id"
    tmp = Path(tempfile.mkdtemp())
    rows, summary = [], {}
    for group, lines in LINES.items():
        err = n = 0
        for i, text in enumerate(lines):
            phone = tmp / f"{group}_{i}.wav"
            to_phone(tts(text, voice, key, tts_model), phone)
            hyp, model = stt(phone, key, lang)
            e, k = wer(norm(text), norm(hyp))
            err, n = err + e, n + k
            rows.append({"group": group, "ref": text, "hyp": hyp, "errors": e, "words": k, "model": model})
            print(f"[{group}] {text}  ->  {hyp}  ({e}/{k})")
        summary[group] = {"wer": round(err / n, 3), "errors": err, "words": n, "utterances": len(lines)}
    summary["stt_language"] = lang
    summary["waktu"] = datetime.now().isoformat(timespec="seconds")
    REPORTS.mkdir(exist_ok=True)
    out = REPORTS / f"e2_wer_{datetime.now():%Y%m%d}.json"
    out.write_text(json.dumps({"ringkasan": summary, "baris": rows}, ensure_ascii=False, indent=1), encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
