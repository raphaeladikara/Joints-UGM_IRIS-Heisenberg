"""Akses SQLite (modul standar, WAL). Skema mengikuti docs/stage-0/04_DATA_MODEL.md, disederhanakan untuk prototype.

Kolom JSON disimpan sebagai TEXT dan dibuka lewat `loads`. Waktu selalu ISO-8601 dengan offset (WIB).
"""

from __future__ import annotations

import json
import sqlite3
import threading
import uuid
from contextlib import contextmanager
from typing import Any, Iterator

from . import config

SCHEMA = """
CREATE TABLE IF NOT EXISTS patients (
  id TEXT PRIMARY KEY,
  display_name TEXT NOT NULL,
  full_name TEXT NOT NULL,
  birth_year INTEGER NOT NULL,
  sex TEXT NOT NULL,
  village TEXT NOT NULL,
  phone_e164 TEXT NOT NULL,
  preferred_language TEXT NOT NULL DEFAULT 'id',
  call_time_local TEXT NOT NULL DEFAULT '07:00',
  family_codeword TEXT NOT NULL,
  conditions TEXT NOT NULL DEFAULT '[]',
  medications TEXT NOT NULL DEFAULT '[]',
  has_bp_monitor INTEGER NOT NULL DEFAULT 0,
  share_scope TEXT NOT NULL DEFAULT '{}',
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS contacts (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(id),
  role TEXT NOT NULL,
  name TEXT NOT NULL,
  relation TEXT NOT NULL DEFAULT '',
  phone_e164 TEXT NOT NULL,
  escalation_order INTEGER NOT NULL DEFAULT 9,
  receives_daily_report INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS call_sessions (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(id),
  direction TEXT NOT NULL DEFAULT 'outbound',
  trigger TEXT NOT NULL DEFAULT 'daily',
  transport TEXT NOT NULL DEFAULT 'app_sim',
  status TEXT NOT NULL,
  state TEXT NOT NULL DEFAULT 'GREETING',
  ctx TEXT NOT NULL DEFAULT '{}',
  final_level TEXT,
  outcome TEXT,
  started_at TEXT NOT NULL,
  answered_at TEXT,
  ended_at TEXT,
  summary TEXT,
  family_talking_points TEXT NOT NULL DEFAULT '[]'
);
CREATE TABLE IF NOT EXISTS call_turns (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id TEXT NOT NULL REFERENCES call_sessions(id),
  speaker TEXT NOT NULL,
  state TEXT NOT NULL,
  text TEXT NOT NULL,
  ts TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS observations (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(id),
  session_id TEXT,
  kind TEXT NOT NULL,
  value TEXT NOT NULL,
  verbatim TEXT,
  source TEXT NOT NULL,
  observed_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS hospitals (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  regency TEXT NOT NULL,
  has_ct_24h INTEGER NOT NULL,
  code_stroke_network INTEGER NOT NULL,
  phone_display TEXT NOT NULL,
  lat REAL, lng REAL
);
CREATE TABLE IF NOT EXISTS travel_times (
  village TEXT NOT NULL,
  hospital_id TEXT NOT NULL REFERENCES hospitals(id),
  minutes INTEGER NOT NULL,
  source_note TEXT NOT NULL,
  PRIMARY KEY (village, hospital_id)
);
CREATE TABLE IF NOT EXISTS alerts (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(id),
  session_id TEXT,
  level TEXT NOT NULL,
  source TEXT NOT NULL,
  reasons TEXT NOT NULL DEFAULT '[]',
  screening TEXT NOT NULL DEFAULT '{}',
  last_known_well TEXT,
  lkw_note TEXT,
  golden_period_deadline TEXT,
  target_hospital_id TEXT,
  eta_minutes INTEGER,
  status TEXT NOT NULL DEFAULT 'open',
  acknowledged_by TEXT,
  acknowledged_at TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS memories (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(id),
  fact TEXT NOT NULL,
  category TEXT NOT NULL,
  source_session_id TEXT,
  created_at TEXT NOT NULL,
  last_used_at TEXT
);
CREATE TABLE IF NOT EXISTS family_messages (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(id),
  from_contact_id TEXT NOT NULL REFERENCES contacts(id),
  kind TEXT NOT NULL DEFAULT 'text',
  text TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  delivered_session_id TEXT,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  contact_id TEXT NOT NULL REFERENCES contacts(id),
  patient_id TEXT NOT NULL REFERENCES patients(id),
  alert_id TEXT,
  session_id TEXT,
  kind TEXT NOT NULL,
  channel TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  payload TEXT NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'sent',
  created_at TEXT NOT NULL,
  read_at TEXT
);
CREATE TABLE IF NOT EXISTS events (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(id),
  source TEXT NOT NULL,
  type TEXT NOT NULL,
  payload TEXT NOT NULL DEFAULT '{}',
  occurred_at TEXT NOT NULL,
  handled_level TEXT
);
CREATE TABLE IF NOT EXISTS device_syncs (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(id),
  source TEXT NOT NULL,
  device TEXT NOT NULL,
  sample_count INTEGER NOT NULL,
  synced_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS doctor_consults (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES patients(id),
  contact_id TEXT NOT NULL REFERENCES contacts(id),
  mode TEXT NOT NULL,
  reason TEXT NOT NULL,
  level TEXT NOT NULL,
  context TEXT NOT NULL DEFAULT '{}',
  status TEXT NOT NULL DEFAULT 'ringing',
  doctor_note TEXT,
  created_at TEXT NOT NULL,
  answered_at TEXT,
  ended_at TEXT
);
CREATE INDEX IF NOT EXISTS idx_obs_patient ON observations(patient_id, observed_at);
CREATE INDEX IF NOT EXISTS idx_calls_patient ON call_sessions(patient_id, started_at);
CREATE INDEX IF NOT EXISTS idx_notif_contact ON notifications(contact_id, created_at);
"""

TABLES = [
    "doctor_consults", "device_syncs", "notifications", "events", "family_messages", "memories", "alerts", "travel_times", "hospitals",
    "observations", "call_turns", "call_sessions", "contacts", "patients",
]

# Satu koneksi bersama + kunci: cukup untuk prototype satu proses uvicorn.
_lock = threading.RLock()
_conn: sqlite3.Connection | None = None


def _connect() -> sqlite3.Connection:
    global _conn
    if _conn is None:
        config.DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        _conn = sqlite3.connect(str(config.DB_PATH), check_same_thread=False, isolation_level=None)
        _conn.row_factory = sqlite3.Row
        _conn.execute("PRAGMA journal_mode=WAL")
        _conn.execute("PRAGMA foreign_keys=ON")
        _conn.executescript(SCHEMA)
    return _conn


def reset_connection() -> None:
    """Dipakai tes: tutup koneksi supaya DB_PATH baru terbaca."""
    global _conn
    with _lock:
        if _conn is not None:
            _conn.close()
        _conn = None


@contextmanager
def tx() -> Iterator[sqlite3.Connection]:
    with _lock:
        conn = _connect()
        conn.execute("BEGIN")
        try:
            yield conn
            conn.execute("COMMIT")
        except Exception:
            conn.execute("ROLLBACK")
            raise


def query(sql: str, params: tuple | list = ()) -> list[dict[str, Any]]:
    with _lock:
        return [dict(r) for r in _connect().execute(sql, params).fetchall()]


def one(sql: str, params: tuple | list = ()) -> dict[str, Any] | None:
    rows = query(sql, params)
    return rows[0] if rows else None


def execute(sql: str, params: tuple | list = ()) -> None:
    with _lock:
        _connect().execute(sql, params)


def new_id() -> str:
    return str(uuid.uuid4())


def dumps(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False)


def loads(value: str | None, default: Any = None) -> Any:
    if value is None or value == "":
        return default
    return json.loads(value)


def wipe() -> None:
    with tx() as conn:
        for t in TABLES:
            conn.execute(f"DELETE FROM {t}")
