"""Fitur keluarga: jadwal & stok obat, air & garam, streak, rapor bulanan.

Port dari backend offline Flutter (`apps/mobile/lib/core/local/backend.dart`); bentuk JSON harus sama persis.
"""

from __future__ import annotations

from datetime import date, timedelta
from typing import Any

from . import config, db, escalation, vitals

SALT_LIMIT = 1.0  # sdt garam per hari (±5 g, anjuran Kemenkes untuk hipertensi)
WATER_GOAL = 8  # gelas


def _today_start():
    return config.now().replace(hour=0, minute=0, second=0, microsecond=0)


def _adherence_on(pid: str, date: str) -> str | None:
    row = db.one("SELECT value FROM observations WHERE patient_id = ? AND kind = 'adherence' AND observed_at LIKE ? "
                 "ORDER BY observed_at DESC LIMIT 1", (pid, date + "%"))
    return db.loads(row["value"], {}).get("status") if row else None


def _add_hours(hhmm: str, h: int) -> str:
    hh, mm = map(int, hhmm.split(":"))
    return f"{max(0, min(23, hh + h)):02d}:{mm:02d}"


def care(pid: str) -> dict[str, Any]:
    now = config.now()
    today = now.date().isoformat()
    hm = now.strftime("%H:%M")
    morning = _adherence_on(pid, today)
    doses_logged = [db.loads(o["value"], {}) for o in db.query(
        "SELECT value FROM observations WHERE patient_id = ? AND kind = 'dose' AND observed_at LIKE ? ORDER BY observed_at", (pid, today + "%"))]
    doses: list[dict[str, Any]] = []
    meds: list[dict[str, Any]] = []
    for st in db.query("SELECT * FROM med_stock WHERE patient_id = ? ORDER BY rowid", (pid,)):
        times = db.loads(st["times"], [])
        per_day = len(times) * st["per_dose"]
        left = st["pills_left"]
        meds.append({
            "name": st["name"], "schedule": st["schedule"], "times": times, "pills_left": left, "per_day": per_day,
            "days_left": None if per_day == 0 else left // per_day, "refill_size": st["refill_size"], "last_refill": st["last_refill"],
        })
        for t in times:
            logged = next((v for v in reversed(doses_logged) if v.get("name") == st["name"] and v.get("time") == t), None)
            by = None
            if logged is not None:
                status = "taken" if logged.get("status") == "taken" else "missed"
                by = "keluarga"
            elif t < "12:00" and morning is not None:
                status = "taken" if morning == "sudah" else "missed"
                by = "telepon KRING"
            elif left <= 0:
                status = "out"
            elif hm > _add_hours(t, 3):
                status = "late"
            else:
                status = "due" if hm >= t else "upcoming"
            doses.append({"name": st["name"], "time": t, "status": status, "by": by})
    doses.sort(key=lambda d: d["time"])

    rows = db.query("SELECT date, water, salt FROM intake WHERE patient_id = ? ORDER BY date", (pid,))
    today_row = next((r for r in rows if r["date"] == today), {"water": 0, "salt": 0.0})
    return {
        "meds": meds,
        "doses_today": doses,
        "intake": {
            "today": {"water": today_row["water"], "salt": today_row["salt"]},
            "goals": {"water": WATER_GOAL, "salt_max": SALT_LIMIT},
            "last7": [{"date": r["date"], "water": r["water"], "salt": r["salt"]} for r in rows[-7:]],
        },
        "streaks": streaks(pid),
        "schedule": schedule(pid, meds),
        "mood": mood(pid),
    }


# ---------- jadwal kontrol Prolanis & posyandu lansia + pengingat ambil obat ----------

PROLANIS_EVERY_DAYS = 28
_DAYS = ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]
_MONTHS = ["Jan", "Feb", "Mar", "Apr", "Mei", "Jun", "Jul", "Agu", "Sep", "Okt", "Nov", "Des"]
APPT_TITLES = {"prolanis": "Kontrol Prolanis", "posyandu": "Posyandu Lansia"}


def day_label(d: date) -> str:
    return f"{_DAYS[d.weekday()]}, {d.day} {_MONTHS[d.month - 1]}"


def _appt_view(a: dict[str, Any], today: date) -> dict[str, Any]:
    return {**{k: a[k] for k in ("id", "kind", "title", "place", "date", "time", "note", "status")},
            "days_until": (date.fromisoformat(a["date"]) - today).days}


def schedule(pid: str, meds: list[dict[str, Any]]) -> dict[str, Any]:
    today = config.now().date()
    upcoming = [_appt_view(a, today) for a in db.query(
        "SELECT * FROM appointments WHERE patient_id = ? AND status = 'scheduled' AND date >= ? ORDER BY date, time", (pid, today.isoformat()))]
    past = [_appt_view(a, today) for a in db.query(
        "SELECT * FROM appointments WHERE patient_id = ? AND (status != 'scheduled' OR date < ?) ORDER BY date DESC, time DESC LIMIT 3",
        (pid, today.isoformat()))]
    return {"upcoming": upcoming[:4], "past": past, "pickup": _pickup(meds, upcoming, today)}


def _pickup(meds: list[dict[str, Any]], upcoming: list[dict[str, Any]], today: date) -> dict[str, Any] | None:
    """Kapan obat harus diambil: disambungkan ke sisa stok dan jadwal kontrol Prolanis berikutnya."""
    active = [m for m in meds if m["per_day"]]
    if not active:
        return None
    low = min(active, key=lambda m: m["days_left"])
    left = low["days_left"]
    runs_out = today + timedelta(days=left)
    visit = next((a for a in upcoming if a["kind"] == "prolanis"), None)
    name = low["name"]
    if left == 0:
        status, by = "now", today
        msg = f"Obat {name} habis. Ambil hari ini di Puskesmas, tidak perlu menunggu jadwal kontrol."
    elif visit and visit["days_until"] <= left:
        status, by = "at_visit", date.fromisoformat(visit["date"])
        msg = f"Stok {name} cukup sampai kontrol Prolanis {day_label(by)}. Ambil obat sekalian saat kontrol."
    elif visit or left <= 7:
        status, by = "before_visit", today + timedelta(days=max(0, left - 1))
        sebelum = f", sebelum kontrol Prolanis {day_label(date.fromisoformat(visit['date']))}" if visit else ""
        msg = f"Stok {name} habis {day_label(runs_out)}{sebelum}. Ambil obat paling lambat {day_label(by)}."
    else:
        status, by = "ok", runs_out
        msg = f"Stok {name} aman untuk {left} hari."
    return {"status": status, "med": name, "days_left": left, "runs_out_on": runs_out.isoformat(), "pickup_by": by.isoformat(),
            "visit_id": visit["id"] if visit else None, "message": msg}


def add_appointment(pid: str, kind: str, day: str, time: str, place: str, note: str) -> None:
    db.execute("INSERT INTO appointments (id, patient_id, kind, title, place, date, time, note, status, created_at) VALUES (?,?,?,?,?,?,?,?, 'scheduled', ?)",
               (db.new_id(), pid, kind, APPT_TITLES[kind], place or config.PUSKESMAS_NAME, day, time, note, config.now().isoformat()))


def mark_appointment(aid: str, status: str, picked_up_meds: bool) -> str | None:
    """Tandai kontrol selesai/terlewat. Selesai + ambil obat → stok bertambah. Prolanis selesai → jadwal berikutnya 28 hari lagi."""
    a = db.one("SELECT * FROM appointments WHERE id = ?", (aid,))
    if not a:
        return None
    db.execute("UPDATE appointments SET status = ? WHERE id = ?", (status, aid))
    if status == "done" and picked_up_meds:
        refill(a["patient_id"], None)
    if status == "done" and a["kind"] == "prolanis" and not db.one(
            "SELECT id FROM appointments WHERE patient_id = ? AND kind = 'prolanis' AND status = 'scheduled' AND date > ?", (a["patient_id"], a["date"])):
        nxt = date.fromisoformat(a["date"]) + timedelta(days=PROLANIS_EVERY_DAYS)
        add_appointment(a["patient_id"], "prolanis", max(nxt, config.now().date() + timedelta(days=1)).isoformat(), a["time"], a["place"], "")
    return a["patient_id"]


def reminders(pid: str) -> list[tuple[str, dict[str, Any]]]:
    """Kalimat pengingat untuk penutup telepon pagi: jadwal hari ini/besok, ambil obat sebelum habis."""
    c = care(pid)
    sched = c["schedule"]
    out: list[tuple[str, dict[str, Any]]] = []
    soon = next((a for a in sched["upcoming"] if a["days_until"] <= 1), None)
    pickup = sched["pickup"]
    if soon:
        out.append(("appointment_reminder", {"hari": "hari ini" if soon["days_until"] == 0 else "besok", "jenis": soon["title"].lower(),
                                             "jam": soon["time"].replace(":", "."), "tempat": soon["place"]}))
        if soon["kind"] == "prolanis" or (pickup and pickup["status"] != "ok"):
            out.append(("appointment_bring_meds", {}))
    elif pickup and pickup["status"] == "before_visit" and pickup["days_left"] <= 3:
        out.append(("pickup_reminder", {"obat": pickup["med"], "sisa": pickup["days_left"]}))
    return out


# ---------- suasana hati & kesepian dari obrolan harian (penguat Nudge Kangen) ----------

_MOOD_SCORE = {"senang": 1.0, "biasa": 0.0, "sedih": -1.0}
_MOOD_WORD = {"senang": "ceria", "biasa": "tenang", "sedih": "murung"}


def mood(pid: str, days: int = 14) -> dict[str, Any]:
    today = _today_start()
    dates = [(today - timedelta(days=d)).date().isoformat() for d in range(days - 1, -1, -1)]
    rows = db.query("SELECT value, verbatim, observed_at FROM observations WHERE patient_id = ? AND kind = 'mood' AND observed_at >= ? ORDER BY observed_at",
                    (pid, dates[0]))
    by_day: dict[str, dict[str, Any]] = {}
    for r in rows:
        by_day[r["observed_at"][:10]] = {**db.loads(r["value"], {}), "quote": r["verbatim"]}
    daily = [{"date": d, "mood": by_day.get(d, {}).get("mood"), "lonely": bool(by_day.get(d, {}).get("lonely"))} for d in dates]
    recorded = [d for d in daily if d["mood"]]
    counts = {k: sum(1 for d in recorded if d["mood"] == k) for k in ("senang", "biasa", "sedih")}
    week = daily[-7:]
    lonely_7 = sum(1 for d in week if d["lonely"])
    sad_7 = sum(1 for d in week if d["mood"] == "sedih")

    def score(ds: list[dict[str, Any]]) -> float | None:
        xs = [_MOOD_SCORE[d["mood"]] - (0.5 if d["lonely"] else 0) for d in ds if d["mood"]]
        return sum(xs) / len(xs) if xs else None

    prev, last = score(daily[:-7]), score(week)
    trend = None if prev is None or last is None else ("membaik" if last - prev >= 0.3 else "menurun" if last - prev <= -0.3 else "stabil")
    call = db.one("SELECT at FROM family_calls WHERE patient_id = ? ORDER BY at DESC LIMIT 1", (pid,))
    since_call = (today.date() - date.fromisoformat(call["at"][:10])).days if call else None
    lonely_quote = next(({"date": d, "quote": v["quote"]} for d, v in sorted(by_day.items(), reverse=True) if v.get("lonely") and v.get("quote")), None)
    if lonely_7 >= 2 or (lonely_7 >= 1 and since_call is not None and since_call >= 4):
        level = "nudge"
    elif lonely_7 == 1 or sad_7 >= 2:
        level = "watch"
    else:
        level = "ok"
    p = db.one("SELECT display_name FROM patients WHERE id = ?", (pid,))
    name = p["display_name"] if p else "Mbah"
    dominant = max(counts, key=lambda k: counts[k]) if recorded else None
    parts = [f"Seminggu ini {name} {lonely_7}× menyebut kangen atau sepi." if lonely_7 else f"Seminggu ini {name} tidak menyebut kangen atau sepi."]
    if dominant:
        parts.append(f"Dari obrolan pagi, suasana hatinya umumnya {_MOOD_WORD[dominant]}" + (f" dan {trend}." if trend and trend != "stabil" else "."))
    if since_call is not None:
        parts.append("Keluarga sudah menelepon hari ini." if since_call == 0 else f"Telepon keluarga terakhir {since_call} hari lalu.")
    return {
        "days": days, "daily": daily, "counts": counts, "lonely_days_7": lonely_7, "lonely_days": sum(1 for d in daily if d["lonely"]),
        "sad_days_7": sad_7, "trend": trend, "days_since_family_call": since_call, "last_lonely": lonely_quote, "level": level,
        "summary": " ".join(parts),
    }


def streaks(pid: str) -> dict[str, Any]:
    today = _today_start()
    # Obat: hitung mundur hari berturut-turut "sudah" (hari ini ikut bila sudah tercatat).
    med = 0
    for d in range(60):
        st = _adherence_on(pid, (today - timedelta(days=d)).date().isoformat())
        if d == 0 and st is None:
            continue
        if st != "sudah":
            break
        med += 1
    child = next((c for c in escalation.contacts_for(pid) if c["role"] == "child"), None)
    calls = db.query("SELECT at FROM family_calls WHERE patient_id = ?", (pid,))
    call_dates = {c["at"][:10] for c in calls}
    family = 0
    for d in range(60):
        called = (today - timedelta(days=d)).date().isoformat() in call_dates
        if d == 0 and not called:
            continue
        if not called:
            break
        family += 1
    week_ago = (today - timedelta(days=6)).isoformat()
    green = db.query("SELECT DISTINCT substr(started_at, 1, 10) AS d FROM call_sessions WHERE patient_id = ? AND started_at >= ? "
                     "AND status = 'completed' AND final_level = 'green'", (pid, (today - timedelta(days=29)).isoformat()))
    return {
        "medication_days": med,
        "family_call_days": family,
        "family_calls_week": sum(1 for c in calls if c["at"] >= week_ago),
        "called_today": today.date().isoformat() in call_dates,
        "green_days_30": len(green),
        "child_name": child["name"] if child else None,
    }


def report(p: dict[str, Any], public: dict[str, Any], bp_rows: list[dict[str, Any]], days: int) -> dict[str, Any]:
    """Rapor `days` hari. `public` = profil publik pasien, `bp_rows` = riwayat tensi `days` hari (dari main)."""
    pid = p["id"]
    today = _today_start()
    dates = [(today - timedelta(days=d)).date().isoformat() for d in range(days - 1, -1, -1)]
    bp_daily = []
    for date in dates:
        last = next((r for r in reversed(bp_rows) if r["at"].startswith(date)), None)
        bp_daily.append({"date": date, "systolic": last.get("systolic") if last else None, "diastolic": last.get("diastolic") if last else None})
    adherence = [{"date": date, "status": _adherence_on(pid, date)} for date in dates]
    taken = sum(1 for a in adherence if a["status"] == "sudah")
    recorded = sum(1 for a in adherence if a["status"] is not None)
    since = (today - timedelta(days=days - 1)).isoformat()
    sessions = db.query("SELECT status FROM call_sessions WHERE patient_id = ? AND started_at >= ?", (pid, since))
    alerts = db.query("SELECT level, created_at, reasons FROM alerts WHERE patient_id = ? AND created_at >= ? ORDER BY created_at DESC", (pid, since))
    v = vitals.summary(pid, days)

    def avg(points: list[dict[str, Any]]) -> float | None:
        xs = [x["value"] for x in points if x.get("value") is not None]
        return sum(xs) / len(xs) if xs else None

    def rnd(x: float | None) -> int | None:
        return None if x is None else int(x + 0.5) if x >= 0 else round(x)

    def mean(xs: list[int]) -> float | None:
        return sum(xs) / len(xs) if xs else None

    intake = db.query("SELECT water, salt FROM intake WHERE patient_id = ? AND date >= ? AND date <= ?", (pid, dates[0], dates[-1]))
    calls = db.query("SELECT minutes FROM family_calls WHERE patient_id = ? AND at >= ?", (pid, since))
    half = len(bp_daily) // 2
    sys_ = lambda rows: [r["systolic"] for r in rows if r["systolic"] is not None]  # noqa: E731
    all_sys = sys_(bp_daily)
    all_dia = [r["diastolic"] for r in bp_daily if r["diastolic"] is not None]
    spo2 = [x["value"] for x in v["daily"]["spo2"] if x.get("value") is not None]
    return {
        "patient": public,
        "days": days,
        "from": dates[0],
        "to": dates[-1],
        "bp_daily": bp_daily,
        "bp_avg": {"systolic": rnd(mean(all_sys)), "diastolic": rnd(mean(all_dia))} if all_sys else None,
        "bp_trend": {"first_half": rnd(mean(sys_(bp_daily[:half]))), "second_half": rnd(mean(sys_(bp_daily[half:])))},
        "bp_high_days": sum(1 for s in all_sys if s >= 160),
        "adherence": adherence,
        "adherence_pct": None if recorded == 0 else rnd(taken * 100 / recorded),
        "calls": {"completed": sum(1 for s in sessions if s["status"] == "completed"),
                  "no_answer": sum(1 for s in sessions if s["status"] == "no_answer"), "total": len(sessions)},
        "alerts": [{"level": a["level"], "created_at": a["created_at"], "labels": [r.get("label") for r in db.loads(a["reasons"], [])]} for a in alerts],
        "vitals": {
            "steps_avg": rnd(avg(v["daily"]["steps"])),
            "sleep_avg_min": rnd(avg(v["daily"]["sleep"])),
            "resting_hr_avg": rnd(avg(v["daily"]["resting_hr"])),
            "spo2_min": min(spo2) if spo2 else None,
            "steps_daily": v["daily"]["steps"],
        },
        "intake": {
            "water_avg": sum(r["water"] for r in intake) / len(intake) if intake else None,
            "salt_avg": sum(r["salt"] for r in intake) / len(intake) if intake else None,
            "salt_over_days": sum(1 for r in intake if r["salt"] > SALT_LIMIT),
        },
        "family_calls": {"count": len(calls), "minutes": sum(c["minutes"] for c in calls)},
        "streaks": streaks(pid),
        "mood": mood(pid, days),
        "appointments": [{k: a[k] for k in ("kind", "title", "date", "status")} for a in db.query(
            "SELECT * FROM appointments WHERE patient_id = ? AND date >= ? AND date <= ? ORDER BY date", (pid, dates[0], dates[-1]))],
    }


# ---------- tulis ----------

def log_dose(pid: str, name: str, time: str, status: str) -> None:
    db.execute("INSERT INTO observations (id, patient_id, session_id, kind, value, verbatim, source, observed_at) VALUES (?,?,?,?,?,?,?,?)",
               (db.new_id(), pid, None, "dose", db.dumps({"name": name, "time": time, "status": status}), "dicatat keluarga", "family",
                config.now().isoformat()))
    if status == "taken":
        db.execute("UPDATE med_stock SET pills_left = MAX(0, pills_left - per_dose) WHERE patient_id = ? AND name = ?", (pid, name))


def refill(pid: str, name: str | None) -> None:
    now = config.now().isoformat()
    with db.tx() as conn:
        conn.execute("UPDATE med_stock SET pills_left = pills_left + refill_size, last_refill = ? WHERE patient_id = ? AND (? IS NULL OR name = ?)",
                     (now, pid, name, name))
        # Obat sudah diambil: tindak lanjut "obat habis" hari ini selesai.
        for a in conn.execute("SELECT id, reasons FROM alerts WHERE patient_id = ? AND status != 'closed'", (pid,)).fetchall():
            if all(r.get("code") == "MED_OUT" for r in db.loads(a["reasons"], [])):
                conn.execute("UPDATE alerts SET status = 'closed', updated_at = ? WHERE id = ?", (now, a["id"]))


def log_intake(pid: str, kind: str, delta: float) -> None:
    today = config.now().date().isoformat()
    with db.tx() as conn:
        row = conn.execute("SELECT id, water, salt FROM intake WHERE patient_id = ? AND date = ?", (pid, today)).fetchone()
        if row is None:
            rid, water, salt = db.new_id(), 0, 0.0
            conn.execute("INSERT INTO intake (id, patient_id, date, water, salt) VALUES (?,?,?,0,0)", (rid, pid, today))
        else:
            rid, water, salt = row["id"], row["water"], row["salt"]
        if kind == "water":
            conn.execute("UPDATE intake SET water = ? WHERE id = ?", (int(max(0, min(16, water + delta))), rid))
        else:
            conn.execute("UPDATE intake SET salt = ? WHERE id = ?", (float(max(0.0, min(6.0, salt + delta))), rid))


def log_family_call(pid: str, contact_id: str | None, minutes: int) -> None:
    db.execute("INSERT INTO family_calls (id, patient_id, contact_id, at, minutes) VALUES (?,?,?,?,?)",
               (db.new_id(), pid, contact_id, config.now().isoformat(), minutes))
