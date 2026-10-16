"""Konfigurasi server TILIK dari environment variable (lihat .env.example di akar repo)."""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

DB_PATH = Path(os.getenv("TILIK_DB_PATH", str(ROOT / "data" / "tilik.db")))
CONTENT_DIR = Path(os.getenv("TILIK_CONTENT_DIR", str(ROOT.parents[1] / "content")))

# Mode demo: semua tujuan eskalasi hanya kanal simulasi di aplikasi. Tidak pernah menelepon 119 / RS sungguhan.
DEMO_MODE = os.getenv("DEMO_MODE", "true").lower() != "false"

OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "").strip()
OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1").rstrip("/")
OPENAI_MODEL_CLASSIFIER = os.getenv("OPENAI_MODEL_CLASSIFIER", "").strip() or "gpt-5.4-mini"
LLM_TIMEOUT_S = float(os.getenv("TILIK_LLM_TIMEOUT_S", "6"))

PUSKESMAS_NAME = os.getenv("TILIK_PUSKESMAS_NAME", "Puskesmas Wonosari I (simulasi)")

# Zona waktu demo: WIB. Offset tetap supaya image slim tidak butuh tzdata.
WIB = timezone(timedelta(hours=7), "WIB")

GOLDEN_PERIOD = timedelta(hours=4, minutes=30)


def now() -> datetime:
    return datetime.now(WIB)


def llm_enabled() -> bool:
    return bool(OPENAI_API_KEY)
