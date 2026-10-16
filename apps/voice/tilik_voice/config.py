"""Konfigurasi server suara dari environment (.env di akar repo, lihat .env.example)."""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

VOICE_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = VOICE_ROOT.parents[1]

# .env di akar repo dipakai bersama; variabel yang sudah ada di environment menang.
load_dotenv(REPO_ROOT / ".env", override=False)


def _env(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


def _float(name: str, default: float) -> float:
    raw = _env(name)
    return float(raw) if raw else default


# Mode demo: hanya boleh menelepon nomor di allowlist. 119/112/RS tidak pernah ditelepon di mode apa pun.
DEMO_MODE = _env("DEMO_MODE", "true").lower() != "false"
DEMO_ALLOWLIST = {n.strip() for n in _env("DEMO_ALLOWLIST").split(",") if n.strip()}
# Nomor tujuan default panggilan Twilio (HP anggota tim yang berperan sebagai Mbah). Harus ada di allowlist.
DEMO_PATIENT_PHONE = _env("DEMO_PATIENT_PHONE")

TILIK_API_URL = _env("TILIK_API_URL", "http://127.0.0.1:8080").rstrip("/")
VOICE_HOST = _env("VOICE_HOST", "127.0.0.1")
VOICE_PORT = int(_env("VOICE_PORT", "7860"))
PUBLIC_BASE_URL = _env("PUBLIC_BASE_URL").rstrip("/")

ELEVENLABS_API_KEY = _env("ELEVENLABS_API_KEY")
ELEVENLABS_VOICE_ID = _env("ELEVENLABS_VOICE_ID")
ELEVENLABS_TTS_MODEL = _env("ELEVENLABS_TTS_MODEL") or "eleven_flash_v2_5"
ELEVENLABS_STT_MODEL = _env("ELEVENLABS_STT_MODEL") or "scribe_v2_realtime"
ELEVENLABS_STT_LANGUAGE = _env("ELEVENLABS_STT_LANGUAGE") or "id"

TWILIO_ACCOUNT_SID = _env("TWILIO_ACCOUNT_SID")
TWILIO_API_KEY_SID = _env("TWILIO_API_KEY_SID")
TWILIO_API_KEY_SECRET = _env("TWILIO_API_KEY_SECRET")
TWILIO_PHONE_NUMBER = _env("TWILIO_PHONE_NUMBER")
# Berapa lama Twilio menunggu diangkat sebelum dianggap no-answer.
TWILIO_RING_TIMEOUT_S = int(_env("TWILIO_RING_TIMEOUT_S", "30"))

# Jeda hening sebelum giliran Mbah dianggap selesai. Lansia butuh jeda lebih panjang (lihat 03 §4).
VAD_STOP_SECS = _float("TILIK_VAD_STOP_SECS", 0.7)
VAD_START_SECS = _float("TILIK_VAD_START_SECS", 0.2)
VAD_CONFIDENCE = _float("TILIK_VAD_CONFIDENCE", 0.7)

LATENCY_LOG = Path(_env("TILIK_LATENCY_LOG") or str(VOICE_ROOT / "logs" / "latency.jsonl"))


def missing_elevenlabs() -> list[str]:
    return [k for k, v in {"ELEVENLABS_API_KEY": ELEVENLABS_API_KEY, "ELEVENLABS_VOICE_ID": ELEVENLABS_VOICE_ID}.items() if not v]


def missing_twilio() -> list[str]:
    need = {"TWILIO_ACCOUNT_SID": TWILIO_ACCOUNT_SID, "TWILIO_API_KEY_SID": TWILIO_API_KEY_SID,
            "TWILIO_API_KEY_SECRET": TWILIO_API_KEY_SECRET, "TWILIO_PHONE_NUMBER": TWILIO_PHONE_NUMBER,
            "PUBLIC_BASE_URL": PUBLIC_BASE_URL}
    return [k for k, v in need.items() if not v]
