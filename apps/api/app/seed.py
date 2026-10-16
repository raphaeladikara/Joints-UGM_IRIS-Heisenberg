"""Data demo FIKTIF (persona docs/stage-0/02_PRD.md §1). Tidak ada data pasien sungguhan.

Nomor telepon memakai blok +62800… yang tidak dipakai operator; RS & waktu tempuh berlabel simulasi
(ketersediaan CT 24 jam belum diverifikasi, Q-13).
"""

from __future__ import annotations

import random
from datetime import datetime, timedelta
from typing import Any

from . import config, db, nlu

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

# Jam minum per obat (untuk jadwal & stok obat).
MED_TIMES = {"amlodipin": ["07:00"], "kaptopril": ["07:00", "19:00"], "warfarin": ["19:00"]}

# Riwayat telepon harian yang di-seed (hari), cukup untuk rapor 30 hari.
HISTORY_DAYS = 29

PATIENTS: list[dict[str, Any]] = [
    {"id": "p-sri", "display_name": "Bu Sri", "full_name": "Sri Rahayu (fiktif)", "birth_year": 1954, "sex": "F",
     "village": "Kepek, Wonosari", "phone": "+62800000101", "lang": "id", "time": "07:00", "codeword": "melati putih",
     "meds": [AMLO], "bp_monitor": 1, "base_bp": (150, 90),
     "contacts": [("c-tini", "sahabat_tilik", "Bu Tini", "Tetangga sebelah, 5 menit jalan kaki", "+62800000102", 1, 0),
                  ("c-dika", "child", "Mas Dika", "Anak, bekerja di Jakarta", "+62800000103", 2, 1)],
     "today": None,
     "stock": {"amlodipin": 4}, "salt": 1.4, "water": 6, "child_calls_per_week": 3, "miss_rate": 0.1},
    {"id": "p-harjo", "display_name": "Pak Harjo", "full_name": "Harjo Sumarto (fiktif)", "birth_year": 1948, "sex": "M",
     "village": "Logandeng, Playen", "phone": "+62800000201", "lang": "jv", "time": "06:30", "codeword": "pari kuning",
     "meds": [CAPTO], "bp_monitor": 1, "base_bp": (158, 94),
     "contacts": [("c-slamet", "sahabat_tilik", "Pak Slamet", "Kader dusun", "+62800000202", 1, 0),
                  ("c-wulan", "child", "Mbak Wulan", "Anak, Yogyakarta", "+62800000203", 2, 1)],
     "today": "med_out",
     "stock": {"kaptopril": 0}, "salt": 2.1, "water": 5, "child_calls_per_week": 2, "miss_rate": 0.35},
    {"id": "p-painem", "display_name": "Mbah Painem", "full_name": "Painem (fiktif)", "birth_year": 1945, "sex": "F",
     "village": "Pacarejo, Semanu", "phone": "+62800000301", "lang": "jv", "time": "06:30", "codeword": "kendi biru",
     "meds": [AMLO], "bp_monitor": 0, "base_bp": None,
     "contacts": [("c-sumi", "sahabat_tilik", "Bu Sumi", "Tetangga", "+62800000302", 1, 0),
                  ("c-joko", "child", "Mas Joko", "Anak, Batam", "+62800000303", 2, 1)],
     "today": "no_answer",
     "stock": {"amlodipin": 12}, "salt": 1.2, "water": 4, "child_calls_per_week": 1, "miss_rate": 0.15},
    {"id": "p-wiryo", "display_name": "Pak Wiryo", "full_name": "Wiryo Atmojo (fiktif)", "birth_year": 1957, "sex": "M",
     "village": "Karangrejek, Wonosari", "phone": "+62800000401", "lang": "id", "time": "06:45", "codeword": "sepeda onthel",
     "meds": [AMLO], "bp_monitor": 1, "base_bp": (138, 86),
     "contacts": [("c-parmi", "sahabat_tilik", "Bu Parmi", "Tetangga depan", "+62800000402", 1, 0),
                  ("c-anton", "child", "Mas Anton", "Anak, Semarang", "+62800000403", 2, 1)],
     "today": "green",
     "stock": {"amlodipin": 21}, "salt": 0.9, "water": 8, "child_calls_per_week": 4, "miss_rate": 0.05},
    {"id": "p-lastri", "display_name": "Bu Lastri", "full_name": "Sulastri (fiktif)", "birth_year": 1951, "sex": "F",
     "village": "Bunder, Patuk", "phone": "+62800000501", "lang": "id", "time": "06:45", "codeword": "kupu kuning",
     "meds": [AMLO, CAPTO], "bp_monitor": 1, "base_bp": (165, 98),
     "contacts": [("c-yanto", "sahabat_tilik", "Pak Yanto", "Kader posyandu lansia", "+62800000502", 1, 0),
                  ("c-ratna", "child", "Mbak Ratna", "Anak, Bandung", "+62800000503", 2, 1)],
     "today": "bp_crisis",
     "stock": {"amlodipin": 9, "kaptopril": 14}, "salt": 2.4, "water": 5, "child_calls_per_week": 2, "miss_rate": 0.12},
    {"id": "p-darmo", "display_name": "Pak Darmo", "full_name": "Sudarmo (fiktif)", "birth_year": 1946, "sex": "M",
     "village": "Kemadang, Tanjungsari", "phone": "+62800000601", "lang": "id", "time": "09:00", "codeword": "gunung kidul",
     "meds": [AMLO, WARF], "bp_monitor": 1, "base_bp": (142, 84),
     "contacts": [("c-narti", "sahabat_tilik", "Bu Narti", "Tetangga", "+62800000602", 1, 0),
                  ("c-bayu", "child", "Mas Bayu", "Anak, Jakarta", "+62800000603", 2, 1)],
     "today": None,
     "stock": {"amlodipin": 25, "warfarin": 25}, "salt": 1.0, "water": 7, "child_calls_per_week": 3, "miss_rate": 0.1},
]

# Suasana hati harian (dari cerita pagi): peluang kesepian & murung per pasien. Painem paling sering kesepian (anak di Batam).
MOOD_PROFILE = {"p-sri": (0.05, 0.05), "p-harjo": (0.15, 0.15), "p-painem": (0.45, 0.15), "p-wiryo": (0.05, 0.05),
                "p-lastri": (0.15, 0.2), "p-darmo": (0.25, 0.1)}
HAPPY_LINES = ["Tadi ikut pengajian di masjid, senang ketemu teman.", "Cucu datang menginap, rumah jadi ramai.", "Panen cabai lumayan banyak.",
               "Ikut senam lansia di balai desa."]
PLAIN_LINES = ["Biasa saja, di rumah.", "Menyapu halaman lalu istirahat.", "Nonton TV sambil melipat baju."]
LONELY_LINES = ["Sepi, anak-anak jauh semua.", "Kangen sama anak, sudah lama tidak pulang.", "Sendirian di rumah, tidak ada teman ngobrol."]
SAD_LINES = ["Semalam susah tidur, kepikiran.", "Capek, badan pegal semua."]

# Jadwal (hari dari sekarang): kontrol Prolanis di Puskesmas & posyandu lansia di dusun. Darmo sengaja: stok habis sebelum kontrol.
VISITS = {"p-sri": (3, 1), "p-harjo": (9, 5), "p-painem": (12, 2), "p-wiryo": (16, 8), "p-lastri": (6, 0), "p-darmo": (27, 11)}

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
    mood_rng = random.Random(11)  # terpisah supaya data lain tetap sama seperti sebelumnya
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
                 db.dumps({"medication": True, "bp": True, "stories": True}), (today - timedelta(days=60)).isoformat()),
            )
            for cid, role, name, rel, phone, order, report in p["contacts"]:
                conn.execute("INSERT INTO contacts VALUES (?,?,?,?,?,?,?,?)", (cid, p["id"], role, name, rel, phone, order, report))
            for m in p["meds"]:
                conn.execute("""INSERT INTO med_stock (id, patient_id, name, schedule, times, per_dose, pills_left, refill_size, last_refill)
                                VALUES (?,?,?,?,?,1,?,30,?)""",
                             (db.new_id(), p["id"], m["name"], m["schedule"], db.dumps(MED_TIMES[m["name"]]), p["stock"].get(m["name"], 20),
                              (today - timedelta(days=24)).isoformat()))

            # Riwayat: hijau, sesekali lupa obat. Rapor WA hanya untuk 6 hari terakhir (supaya kotak pesan tidak penuh).
            for d in range(HISTORY_DAYS, 0, -1):
                day = today - timedelta(days=d)
                if p["id"] == "p-painem" and d in (1, 13):
                    _call(conn, p, _at(day, p["time"]), "no_answer", None, None, None, "", report=False)
                    continue
                missed = rng.random() < p["miss_rate"]
                bp = _bp(rng, p["base_bp"], trend=d)
                story = SRI_STORIES[d - 1] if p["id"] == "p-sri" and d <= 6 else ""
                sid = _call(conn, p, _at(day, p["time"]), "completed", "green", "belum" if missed else "sudah", bp, story,
                            reason="forgot" if missed else None, report=d <= 6)
                _mood(conn, p["id"], sid, _at(day, p["time"]), story or _mood_line(mood_rng, p["id"]))

            # Hari ini.
            t = _at(today, p["time"])
            kind = p["today"]
            if kind == "green":
                sid = _call(conn, p, t, "completed", "green", "sudah", _bp(rng, p["base_bp"]), "Cucu menginap akhir pekan ini.")
                _mood(conn, p["id"], sid, t, "Cucu menginap akhir pekan ini.")
            elif kind == "med_out":
                sid = _call(conn, p, t, "completed", "yellow", "belum", _bp(rng, p["base_bp"]), "", reason="out_of_stock")
                _alert(conn, p["id"], sid, t, [{"path": "rule", "code": "MED_OUT", "label": "Obat habis", "quote": "Obatipun sampun telas, Mbak."}])
            elif kind == "no_answer":
                # F-19: tidak diangkat → telepon ulang 15 menit → tetap tidak diangkat → Sahabat Kring diminta menengok.
                first = _call(conn, p, t, "no_answer", None, None, None, "")
                t2 = t + timedelta(minutes=config.RETRY_MINUTES)
                second = _call(conn, p, t2, "no_answer", None, None, None, "", trigger="retry")
                conn.execute("INSERT INTO call_retries (id, patient_id, origin_session_id, due_at, status, session_id, created_at) VALUES (?,?,?,?, 'missed', ?, ?)",
                             (db.new_id(), p["id"], first, t2.isoformat(), second, (t + timedelta(minutes=1)).isoformat()))
                aid = _alert(conn, p["id"], second, t2, [{"path": "rule", "code": "NO_ANSWER_RETRY",
                                                          "label": "Tidak diangkat, telepon ulang 15 menit juga tidak diangkat",
                                                          "quote": f"tidak diangkat pukul {t:%H.%M} dan {t2:%H.%M}"}], source="scheduler")
                _home_check(conn, p, aid, [t, t2])
            elif kind == "bp_crisis":
                sid = _call(conn, p, t, "completed", "yellow", "sudah", (184, 104), "")
                _alert(conn, p["id"], sid, t, [{"path": "rule", "code": "BP_CRISIS_ASYMPTOMATIC",
                                                "label": "Tensi krisis tanpa gejala (hubungi hari ini)", "quote": "seratus delapan puluh empat per seratus empat"}])

            # Asupan air & garam 30 hari (diisi keluarga/kader; hari ini baru separuh jalan).
            for d in range(HISTORY_DAYS, -1, -1):
                day = today - timedelta(days=d)
                frac = max(0.2, min(1.0, now.hour / 20)) if d == 0 else 1.0
                water = max(0, min(12, round((p["water"] + rng.randint(0, 3) - 1) * frac)))
                salt = max(0.0, round((p["salt"] + (rng.random() - 0.4) * 0.8) * frac * 2) / 2)
                conn.execute("INSERT INTO intake (id, patient_id, date, water, salt) VALUES (?,?,?,?,?)",
                             (db.new_id(), p["id"], day.date().isoformat(), water, salt))

            # Telepon anak ke orang tua (untuk streak & Nudge Kangen).
            child = next(c for c in p["contacts"] if c[1] == "child")
            for d in range(HISTORY_DAYS, 0, -1):
                if rng.random() < p["child_calls_per_week"] / 7:
                    at = _at(today - timedelta(days=d), f"19:{10 + rng.randint(0, 39)}")
                    conn.execute("INSERT INTO family_calls (id, patient_id, contact_id, at, minutes) VALUES (?,?,?,?,?)",
                                 (db.new_id(), p["id"], child[0], at.isoformat(), 3 + rng.randint(0, 14)))

        # Mas Dika rutin menelepon 4 malam terakhir (streak yang terlihat di demo).
        for d in range(4, 0, -1):
            day = today - timedelta(days=d)
            conn.execute("DELETE FROM family_calls WHERE contact_id = 'c-dika' AND at LIKE ?", (day.date().isoformat() + "%",))
            conn.execute("INSERT INTO family_calls (id, patient_id, contact_id, at, minutes) VALUES (?,?,?,?,?)",
                         (db.new_id(), "p-sri", "c-dika", _at(day, "19:30").isoformat(), 6 + d))

        # Data kesehatan DUMMY 30 hari untuk semua pasien: langkah, tidur, detak, SpO2. Sumbernya sengaja beragam
        # (jam simulasi, Apple Health, Health Connect) supaya semua jalur sinkron terlihat di demo.
        for pid, prof in WATCH.items():
            _watch(conn, rng, pid, today, now, **prof)

        # Jadwal kontrol Prolanis & posyandu lansia (+ satu kontrol bulan lalu yang sudah selesai).
        for p in PATIENTS:
            prolanis, posyandu = VISITS[p["id"]]
            dusun = p["village"].split(",")[0]
            for kind, title, place, offset, hm, status in (
                ("prolanis", "Kontrol Prolanis", config.PUSKESMAS_NAME, -25, "08:00", "done"),
                ("prolanis", "Kontrol Prolanis", config.PUSKESMAS_NAME, prolanis, "08:00", "scheduled"),
                ("posyandu", "Posyandu Lansia", f"Balai dusun {dusun}", posyandu, "09:00", "scheduled"),
            ):
                conn.execute("INSERT INTO appointments (id, patient_id, kind, title, place, date, time, note, status, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)",
                             (db.new_id(), p["id"], kind, title, place, (today + timedelta(days=offset)).date().isoformat(), hm,
                              "Bawa kartu BPJS & buku kontrol" if kind == "prolanis" else "Timbang, tensi, senam", status,
                              (today - timedelta(days=30)).isoformat()))

        # Memori & titip pesan untuk Bu Sri (babak 1 demo).
        conn.execute("INSERT INTO memories (id, patient_id, fact, category, created_at) VALUES (?,?,?,?,?)",
                     (db.new_id(), "p-sri", "Tomat di kebun belakang sudah merah, sebentar lagi panen", "hobby", (today - timedelta(days=1)).isoformat()))
        conn.execute("INSERT INTO family_messages (id, patient_id, from_contact_id, kind, text, status, created_at) VALUES (?,?,?,?,?,?,?)",
                     (db.new_id(), "p-sri", "c-dika", "text", "Bu, Rani minggu depan wisuda. Sabtu Dika jemput Ibu, ya. Jaga kesehatan.", "pending",
                      (now - timedelta(hours=10)).isoformat()))


# Profil jam tangan dummy per pasien: sumber, perangkat, rata-rata langkah, detak istirahat, SpO2, tidur (menit).
WATCH: dict[str, dict[str, Any]] = {
    "p-sri": {"source": "watch_sim", "device": "Jam tangan Bu Sri (simulasi)", "steps": 3100, "rhr": 70, "spo2": 96, "sleep": 360},
    "p-harjo": {"source": "apple_health", "device": "Apple Watch SE (dummy)", "steps": 2300, "rhr": 78, "spo2": 95, "sleep": 330},
    "p-painem": {"source": "health_connect", "device": "Mi Band 8 (dummy)", "steps": 1400, "rhr": 74, "spo2": 95, "sleep": 300},
    "p-wiryo": {"source": "health_connect", "device": "Galaxy Watch5 (dummy)", "steps": 5600, "rhr": 66, "spo2": 97, "sleep": 390},
    "p-lastri": {"source": "apple_health", "device": "Apple Watch Series 8 (dummy)", "steps": 2600, "rhr": 88, "spo2": 96, "sleep": 320},
    "p-darmo": {"source": "health_connect", "device": "Fitbit Inspire 3 (dummy)", "steps": 1900, "rhr": 72, "spo2": 94, "sleep": 345},
}


def _watch(conn, rng: random.Random, pid: str, today: datetime, now: datetime, *, source: str, device: str,
           steps: int, rhr: int, spo2: int, sleep: int) -> None:

    def obs(kind: str, value: dict[str, Any], at: datetime) -> None:
        conn.execute("INSERT INTO observations VALUES (?,?,?,?,?,?,?,?)", (db.new_id(), pid, None, kind, db.dumps(value), device, source, at.isoformat()))

    for d in range(HISTORY_DAYS, -1, -1):
        day = today - timedelta(days=d)
        # Hari ini baru separuh jalan: langkah dihitung sampai jam sekarang.
        frac = 1.0 if d else max(0.15, min(1.0, (now.hour * 60 + now.minute - 300) / 900))
        n = int((steps + rng.randint(-steps // 3, steps // 2)) * frac)
        obs("steps", {"value": n, "date": day.date().isoformat()}, day.replace(hour=12) if d else now)
        obs("sleep", {"value": sleep + rng.randint(-50, 60), "date": day.date().isoformat()}, day.replace(hour=5, minute=30))
        obs("resting_hr", {"value": float(rhr + rng.randint(-4, 5))}, day.replace(hour=6))
        obs("spo2", {"value": float(min(99, spo2 + rng.randint(-1, 2)))}, day.replace(hour=4))
        if d > 7:
            continue  # detak per jam hanya 7 hari terakhir
        last_hour = 21 if d else max(6, now.hour)
        for h in range(6, last_hour + 1, 2):
            obs("heart_rate", {"value": float(rhr + 2 + rng.randint(-6, 14) + (8 if 8 <= h <= 10 else 0))}, day.replace(hour=h, minute=10))
    conn.execute("INSERT INTO device_syncs (id, patient_id, source, device, sample_count, synced_at) VALUES (?,?,?,?,?,?)",
                 (db.new_id(), pid, source, device, 60, (now - timedelta(minutes=12)).isoformat()))


def _bp(rng: random.Random, base: tuple[int, int] | None, trend: int = 0) -> tuple[int, int] | None:
    if not base:
        return None
    # Tensi sedikit lebih tinggi sebulan lalu (obat mulai rutin) supaya tren di rapor bulanan terlihat.
    drift = int(trend / 3 + 0.5)
    return base[0] + drift + rng.randint(-8, 8), base[1] + drift // 2 + rng.randint(-5, 5)


def _mood_line(rng: random.Random, pid: str) -> str:
    lonely, sad = MOOD_PROFILE[pid]
    x = rng.random()
    pool = LONELY_LINES if x < lonely else SAD_LINES if x < lonely + sad else HAPPY_LINES if rng.random() < 0.5 else PLAIN_LINES
    return rng.choice(pool)


def _mood(conn, pid: str, sid: str, at: datetime, line: str) -> None:
    conn.execute("INSERT INTO observations VALUES (?,?,?,?,?,?,?,?)",
                 (db.new_id(), pid, sid, "mood", db.dumps(nlu.mood(line)), line, "nlu", (at + timedelta(minutes=3)).isoformat()))


def _home_check(conn, p: dict[str, Any], alert_id: str, missed: list[datetime]) -> None:
    sahabat = next(c for c in p["contacts"] if c[1] == "sahabat_tilik")
    child = next(c for c in p["contacts"] if c[1] == "child")
    hid = db.new_id()
    at = missed[-1] + timedelta(minutes=1)
    conn.execute("INSERT INTO home_checks (id, patient_id, contact_id, alert_id, status, missed_at, created_at) VALUES (?,?,?,?, 'requested', ?, ?)",
                 (hid, p["id"], sahabat[0], alert_id, db.dumps([m.isoformat() for m in missed]), at.isoformat()))
    j1, j2 = f"{missed[0]:%H.%M}", f"{missed[-1]:%H.%M}"
    for cid, kind, title, body in (
        (sahabat[0], "home_check", f"🏠 Mohon tengok {p['display_name']}",
         f"{sahabat[2]}, ini Kring dari {config.PUSKESMAS_NAME}. {p['display_name']} dua kali tidak mengangkat telepon pagi (pukul {j1} dan {j2}). "
         "Mohon tengok ke rumah beliau, lalu kabari lewat tombol di aplikasi."),
        (child[0], "home_check_sent", f"🏠 {sahabat[2]} diminta mengecek {p['display_name']}",
         f"KRING sudah menelepon pukul {j1} dan {j2}, belum diangkat. {sahabat[2]} ({sahabat[3]}) diminta menengok ke rumah dan akan mengabari di sini."),
    ):
        conn.execute(
            """INSERT INTO notifications (id, contact_id, patient_id, alert_id, kind, channel, title, body, payload, status, created_at)
               VALUES (?,?,?,?,?, 'whatsapp_sim', ?, ?, ?, 'sent', ?)""",
            (db.new_id(), cid, p["id"], alert_id, kind, title, body, db.dumps({"home_check_id": hid}), at.isoformat()))


def _call(conn, p: dict[str, Any], at: datetime, status: str, level: str | None, adherence: str | None,
          bp: tuple[int, int] | None, story: str, reason: str | None = None, report: bool = True, trigger: str = "daily") -> str:
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
           summary, family_talking_points) VALUES (?,?,?,?, 'ENDED', '{}', ?, ?, ?, ?, ?, ?, ?)""",
        (sid, p["id"], trigger, status, level, status, at.isoformat(), at.isoformat() if status == "completed" else None,
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
    if report and status == "completed" and level == "green" and p["contacts"]:
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


def _alert(conn, pid: str, sid: str, at: datetime, reasons: list[dict[str, Any]], source: str = "call") -> str:
    aid = db.new_id()
    conn.execute(
        """INSERT INTO alerts (id, patient_id, session_id, level, source, reasons, status, created_at, updated_at)
           VALUES (?,?,?, 'yellow', ?, ?, 'open', ?, ?)""",
        (aid, pid, sid, source, db.dumps(reasons), (at + timedelta(minutes=4)).isoformat(), (at + timedelta(minutes=4)).isoformat()),
    )
    return aid
