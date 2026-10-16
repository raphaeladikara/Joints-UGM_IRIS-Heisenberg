"""Data demo FIKTIF (persona docs/stage-0/02_PRD.md §1). Tidak ada data pasien sungguhan.

Nomor telepon memakai blok +62800… yang tidak dipakai operator; RS & waktu tempuh berlabel simulasi
(ketersediaan CT 24 jam belum diverifikasi, Q-13).
"""

from __future__ import annotations

import random
from datetime import datetime, timedelta
from typing import Any

from . import config, db

HOSPITALS = [
    ("h-wonosari", "RSUD Wonosari (simulasi)", "Gunungkidul", 1, 1, "(0274) xxx-xxxx", -7.9653, 110.6005),
    ("h-pantirahayu", "RS Panti Rahayu (simulasi)", "Gunungkidul", 0, 1, "(0274) xxx-xxxx", -7.9578, 110.6012),
    ("h-saptosari", "RSUD Saptosari (simulasi)", "Gunungkidul", 0, 1, "(0274) xxx-xxxx", -8.0806, 110.5050),
    ("h-rsaugm", "RS Akademik UGM (simulasi)", "Sleman", 1, 1, "(0274) xxx-xxxx", -7.7451, 110.3463),
    ("h-sardjito", "RSUP Dr. Sardjito (simulasi)", "Sleman", 1, 1, "(0274) xxx-xxxx", -7.7683, 110.3737),
]

# Menit tempuh statis (estimasi manual dari peta, label simulasi) per desa → RS.
TRAVEL = {
    "Kepek, Wonosari": {"h-wonosari": 8, "h-pantirahayu": 10, "h-saptosari": 38, "h-rsaugm": 75, "h-sardjito": 80},
    "Logandeng, Playen": {"h-wonosari": 15, "h-pantirahayu": 17, "h-saptosari": 40, "h-rsaugm": 65, "h-sardjito": 70},
    "Pacarejo, Semanu": {"h-wonosari": 20, "h-pantirahayu": 22, "h-saptosari": 45, "h-rsaugm": 85, "h-sardjito": 90},
    "Karangrejek, Wonosari": {"h-wonosari": 10, "h-pantirahayu": 12, "h-saptosari": 36, "h-rsaugm": 72, "h-sardjito": 77},
    "Bunder, Patuk": {"h-wonosari": 30, "h-pantirahayu": 32, "h-saptosari": 60, "h-rsaugm": 50, "h-sardjito": 55},
    "Kemadang, Tanjungsari": {"h-wonosari": 35, "h-pantirahayu": 37, "h-saptosari": 25, "h-rsaugm": 100, "h-sardjito": 105},
}

AMLO = {"name": "amlodipin", "schedule": "1× pagi", "is_anticoagulant": False}
CAPTO = {"name": "kaptopril", "schedule": "2× sehari", "is_anticoagulant": False}
WARF = {"name": "warfarin", "schedule": "1× malam", "is_anticoagulant": True}

PATIENTS: list[dict[str, Any]] = [
    {"id": "p-sri", "display_name": "Bu Sri", "full_name": "Sri Rahayu (fiktif)", "birth_year": 1954, "sex": "F",
     "village": "Kepek, Wonosari", "phone": "+62800000101", "lang": "id", "time": "07:00", "codeword": "melati putih",
     "meds": [AMLO], "bp_monitor": 1, "base_bp": (150, 90),
     "contacts": [("c-tini", "sahabat_tilik", "Bu Tini", "Tetangga sebelah, 5 menit jalan kaki", "+62800000102", 1, 0),
                  ("c-dika", "child", "Mas Dika", "Anak, bekerja di Jakarta", "+62800000103", 2, 1)],
     "today": None},
    {"id": "p-harjo", "display_name": "Pak Harjo", "full_name": "Harjo Sumarto (fiktif)", "birth_year": 1948, "sex": "M",
     "village": "Logandeng, Playen", "phone": "+62800000201", "lang": "jv", "time": "06:30", "codeword": "pari kuning",
     "meds": [CAPTO], "bp_monitor": 1, "base_bp": (158, 94),
     "contacts": [("c-slamet", "sahabat_tilik", "Pak Slamet", "Kader dusun", "+62800000202", 1, 0),
                  ("c-wulan", "child", "Mbak Wulan", "Anak, Yogyakarta", "+62800000203", 2, 1)],
     "today": "med_out"},
    {"id": "p-painem", "display_name": "Mbah Painem", "full_name": "Painem (fiktif)", "birth_year": 1945, "sex": "F",
     "village": "Pacarejo, Semanu", "phone": "+62800000301", "lang": "jv", "time": "06:30", "codeword": "kendi biru",
     "meds": [AMLO], "bp_monitor": 0, "base_bp": None,
     "contacts": [("c-sumi", "sahabat_tilik", "Bu Sumi", "Tetangga", "+62800000302", 1, 0),
                  ("c-joko", "child", "Mas Joko", "Anak, Batam", "+62800000303", 2, 1)],
     "today": "no_answer"},
    {"id": "p-wiryo", "display_name": "Pak Wiryo", "full_name": "Wiryo Atmojo (fiktif)", "birth_year": 1957, "sex": "M",
     "village": "Karangrejek, Wonosari", "phone": "+62800000401", "lang": "id", "time": "06:45", "codeword": "sepeda onthel",
     "meds": [AMLO], "bp_monitor": 1, "base_bp": (138, 86),
     "contacts": [("c-parmi", "sahabat_tilik", "Bu Parmi", "Tetangga depan", "+62800000402", 1, 0),
                  ("c-anton", "child", "Mas Anton", "Anak, Semarang", "+62800000403", 2, 1)],
     "today": "green"},
    {"id": "p-lastri", "display_name": "Bu Lastri", "full_name": "Sulastri (fiktif)", "birth_year": 1951, "sex": "F",
     "village": "Bunder, Patuk", "phone": "+62800000501", "lang": "id", "time": "06:45", "codeword": "kupu kuning",
     "meds": [AMLO, CAPTO], "bp_monitor": 1, "base_bp": (165, 98),
     "contacts": [("c-yanto", "sahabat_tilik", "Pak Yanto", "Kader posyandu lansia", "+62800000502", 1, 0),
                  ("c-ratna", "child", "Mbak Ratna", "Anak, Bandung", "+62800000503", 2, 1)],
     "today": "bp_crisis"},
    {"id": "p-darmo", "display_name": "Pak Darmo", "full_name": "Sudarmo (fiktif)", "birth_year": 1946, "sex": "M",
     "village": "Kemadang, Tanjungsari", "phone": "+62800000601", "lang": "id", "time": "09:00", "codeword": "gunung kidul",
     "meds": [AMLO, WARF], "bp_monitor": 1, "base_bp": (142, 84),
     "contacts": [("c-narti", "sahabat_tilik", "Bu Narti", "Tetangga", "+62800000602", 1, 0),
                  ("c-bayu", "child", "Mas Bayu", "Anak, Jakarta", "+62800000603", 2, 1)],
     "today": None},
]

SRI_STORIES = [
    "Tomat di kebun belakang sudah merah, sebentar lagi panen.",
    "Tadi ikut senam lansia di balai desa.",
    "Bikin tempe bacem buat arisan RT.",
    "Ayam Ibu bertelur tiga butir.",
    "Ditelepon Rani, cucu, katanya skripsinya selesai.",
    "Kemarin hujan deras, genteng dapur bocor sedikit.",
]


def _at(day: datetime, hhmm: str) -> datetime:
    h, m = map(int, hhmm.split(":"))
    return day.replace(hour=h, minute=m, second=0, microsecond=0)


def run() -> None:
    db.wipe()
    rng = random.Random(7)
    now = config.now()
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    with db.tx() as conn:
        for h in HOSPITALS:
            conn.execute("INSERT INTO hospitals VALUES (?,?,?,?,?,?,?,?)", h)
        for village, rows in TRAVEL.items():
            for hid, mins in rows.items():
                conn.execute("INSERT INTO travel_times VALUES (?,?,?,?)", (village, hid, mins, "estimasi manual dari peta (simulasi)"))

        for p in PATIENTS:
            conn.execute(
                """INSERT INTO patients (id, display_name, full_name, birth_year, sex, village, phone_e164, preferred_language,
                   call_time_local, family_codeword, conditions, medications, has_bp_monitor, share_scope, active, created_at)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,1,?)""",
                (p["id"], p["display_name"], p["full_name"], p["birth_year"], p["sex"], p["village"], p["phone"], p["lang"], p["time"],
                 p["codeword"], db.dumps(["hypertension"]), db.dumps(p["meds"]), p["bp_monitor"],
                 db.dumps({"medication": True, "bp": True, "stories": True}), (today - timedelta(days=30)).isoformat()),
            )
            for cid, role, name, rel, phone, order, report in p["contacts"]:
                conn.execute("INSERT INTO contacts VALUES (?,?,?,?,?,?,?,?)", (cid, p["id"], role, name, rel, phone, order, report))

            # Riwayat 6 hari lalu (hijau, sesekali lupa obat).
            for d in range(6, 0, -1):
                day = today - timedelta(days=d)
                if p["id"] == "p-painem" and d == 1:
                    _call(conn, p, _at(day, p["time"]), "no_answer", None, None, None, "")
                    continue
                missed = rng.random() < (0.35 if p["id"] == "p-harjo" else 0.12)
                bp = _bp(rng, p["base_bp"])
                story = SRI_STORIES[d - 1] if p["id"] == "p-sri" else ""
                _call(conn, p, _at(day, p["time"]), "completed", "green", "belum" if missed else "sudah", bp, story,
                      reason="forgot" if missed else None)

            # Hari ini.
            t = _at(today, p["time"])
            kind = p["today"]
            if kind == "green":
                _call(conn, p, t, "completed", "green", "sudah", _bp(rng, p["base_bp"]), "Cucu menginap akhir pekan ini.")
            elif kind == "med_out":
                sid = _call(conn, p, t, "completed", "yellow", "belum", _bp(rng, p["base_bp"]), "", reason="out_of_stock")
                _alert(conn, p["id"], sid, t, [{"path": "rule", "code": "MED_OUT", "label": "Obat habis", "quote": "Obatipun sampun telas, Mbak."}])
            elif kind == "no_answer":
                sid = _call(conn, p, t, "no_answer", None, None, None, "")
                _alert(conn, p["id"], sid, t, [{"path": "rule", "code": "NO_ANSWER_2X", "label": "2× tidak diangkat",
                                                "quote": "2 panggilan berturut-turut tidak diangkat"}], source="scheduler")
            elif kind == "bp_crisis":
                sid = _call(conn, p, t, "completed", "yellow", "sudah", (184, 104), "")
                _alert(conn, p["id"], sid, t, [{"path": "rule", "code": "BP_CRISIS_ASYMPTOMATIC",
                                                "label": "Tensi krisis tanpa gejala (hubungi hari ini)", "quote": "seratus delapan puluh empat per seratus empat"}])

        # Jam tangan Bu Sri (simulasi): 7 hari langkah, tidur, detak, SpO2. Pasien lain belum punya perangkat.
        _watch(conn, rng, "p-sri", today, now)

        # Memori & titip pesan untuk Bu Sri (babak 1 demo).
        conn.execute("INSERT INTO memories (id, patient_id, fact, category, created_at) VALUES (?,?,?,?,?)",
                     (db.new_id(), "p-sri", "Tomat di kebun belakang sudah merah, sebentar lagi panen", "hobby", (today - timedelta(days=1)).isoformat()))
        conn.execute("INSERT INTO family_messages (id, patient_id, from_contact_id, kind, text, status, created_at) VALUES (?,?,?,?,?,?,?)",
                     (db.new_id(), "p-sri", "c-dika", "text", "Bu, Rani minggu depan wisuda. Sabtu Dika jemput Ibu, ya. Jaga kesehatan.", "pending",
                      (now - timedelta(hours=10)).isoformat()))


def _watch(conn, rng: random.Random, pid: str, today: datetime, now: datetime) -> None:
    device, source = "Jam tangan Bu Sri (simulasi)", "watch_sim"

    def obs(kind: str, value: dict[str, Any], at: datetime) -> None:
        conn.execute("INSERT INTO observations VALUES (?,?,?,?,?,?,?,?)", (db.new_id(), pid, None, kind, db.dumps(value), device, source, at.isoformat()))

    for d in range(6, -1, -1):
        day = today - timedelta(days=d)
        # Hari ini baru separuh jalan: langkah dihitung sampai jam sekarang.
        frac = 1.0 if d else max(0.15, min(1.0, (now.hour * 60 + now.minute - 300) / 900))
        steps = int((3100 + rng.randint(-900, 1600)) * frac)
        obs("steps", {"value": steps, "date": day.date().isoformat()}, day.replace(hour=12) if d else now)
        obs("sleep", {"value": 360 + rng.randint(-50, 70), "date": day.date().isoformat()}, day.replace(hour=5, minute=30))
        obs("resting_hr", {"value": float(70 + rng.randint(-4, 5))}, day.replace(hour=6))
        obs("spo2", {"value": float(96 + rng.randint(-1, 2))}, day.replace(hour=4))
        last_hour = 21 if d else max(6, now.hour)
        for h in range(6, last_hour + 1, 2):
            obs("heart_rate", {"value": float(72 + rng.randint(-6, 14) + (8 if 8 <= h <= 10 else 0))}, day.replace(hour=h, minute=10))
    conn.execute("INSERT INTO device_syncs (id, patient_id, source, device, sample_count, synced_at) VALUES (?,?,?,?,?,?)",
                 (db.new_id(), pid, source, device, 60, (now - timedelta(minutes=12)).isoformat()))


def _bp(rng: random.Random, base: tuple[int, int] | None) -> tuple[int, int] | None:
    if not base:
        return None
    return base[0] + rng.randint(-8, 8), base[1] + rng.randint(-5, 5)


def _call(conn, p: dict[str, Any], at: datetime, status: str, level: str | None, adherence: str | None,
          bp: tuple[int, int] | None, story: str, reason: str | None = None) -> str:
    sid = db.new_id()
    points = [story.rstrip(".")] if story else []
    summary = None
    if status == "completed":
        bits = [f"Obat: {'sudah diminum' if adherence == 'sudah' else 'belum'}"]
        if bp:
            bits.append(f"Tensi {bp[0]}/{bp[1]} (terkonfirmasi)")
        summary = ". ".join(bits) + "."
    conn.execute(
        """INSERT INTO call_sessions (id, patient_id, trigger, status, state, ctx, final_level, outcome, started_at, answered_at, ended_at,
           summary, family_talking_points) VALUES (?,?, 'daily', ?, 'ENDED', '{}', ?, ?, ?, ?, ?, ?, ?)""",
        (sid, p["id"], status, level, status, at.isoformat(), at.isoformat() if status == "completed" else None,
         (at + timedelta(minutes=4)).isoformat(), summary, db.dumps(points)),
    )
    if adherence:
        val = {"status": adherence} | ({"reason": reason} if reason else {})
        conn.execute("INSERT INTO observations VALUES (?,?,?,?,?,?,?,?)",
                     (db.new_id(), p["id"], sid, "adherence", db.dumps(val), "", "patient_report", (at + timedelta(minutes=1)).isoformat()))
    if bp:
        conn.execute("INSERT INTO observations VALUES (?,?,?,?,?,?,?,?)",
                     (db.new_id(), p["id"], sid, "blood_pressure", db.dumps({"systolic": bp[0], "diastolic": bp[1], "confirmed": True}),
                      "", "patient_report", (at + timedelta(minutes=2)).isoformat()))
    if status == "completed" and level == "green" and p["contacts"]:
        child = next(c for c in p["contacts"] if c[1] == "child")
        body = f"💊 Obat: {'sudah diminum' if adherence == 'sudah' else 'belum diminum'}"
        if bp:
            body += f"\n🩺 Tensi: {bp[0]}/{bp[1]}"
        body += "\n🟢 Tidak ada tanda bahaya"
        if points:
            body += f"\n💬 Bahan obrolan: {points[0]}"
        conn.execute(
            """INSERT INTO notifications (id, contact_id, patient_id, session_id, kind, channel, title, body, payload, status, created_at, read_at)
               VALUES (?,?,?,?, 'daily_report', 'whatsapp_sim', ?, ?, ?, 'sent', ?, ?)""",
            (db.new_id(), child[0], p["id"], sid, f"Rapor pagi {p['display_name']}", body,
             db.dumps({"level": "green", "talking_points": points, "bp": {"systolic": bp[0], "diastolic": bp[1]} if bp else None,
                       "medication": adherence}),
             (at + timedelta(minutes=5)).isoformat(), (at + timedelta(minutes=30)).isoformat()),
        )
    return sid


def _alert(conn, pid: str, sid: str, at: datetime, reasons: list[dict[str, Any]], source: str = "call") -> None:
    conn.execute(
        """INSERT INTO alerts (id, patient_id, session_id, level, source, reasons, status, created_at, updated_at)
           VALUES (?,?,?, 'yellow', ?, ?, 'open', ?, ?)""",
        (db.new_id(), pid, sid, source, db.dumps(reasons), (at + timedelta(minutes=4)).isoformat(), (at + timedelta(minutes=4)).isoformat()),
    )
