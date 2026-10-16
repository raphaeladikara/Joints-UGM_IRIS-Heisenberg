"""Data jam tangan & aplikasi kesehatan (Health Connect di Android, Apple Health di iOS, atau simulasi).

Aplikasi keluarga membaca data dari HP Mbah / jam tangan lalu mengirimnya ke sini. Disimpan sebagai `observations`
(kind = heart_rate | resting_hr | steps | sleep | spo2 | blood_pressure) dengan source = asal data.
Perangkat konsumen bukan alat diagnosis: data ini paling tinggi memicu 🟡 (Daftar Tilik), kecuali tensi yang lewat
aturan tensi yang sama dengan panggilan.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from . import config, content, db, escalation, safety

KINDS = ("heart_rate", "resting_hr", "steps", "sleep", "spo2", "blood_pressure")
SOURCE_LABEL = {
    "health_connect": "Health Connect",
    "apple_health": "Apple Health",
    "watch_sim": "Jam tangan (simulasi)",
}


def _cfg() -> dict[str, Any]:
    return content.red_flags()["wearable"]


def _at(raw: str | None) -> str:
    if not raw:
        return config.now().isoformat()
    t = datetime.fromisoformat(raw.replace("Z", "+00:00"))
    if t.tzinfo is None:
        t = t.replace(tzinfo=config.WIB)
    return t.astimezone(config.WIB).isoformat()


def _open_once(patient_id: str, code: str, quote: str) -> str | None:
    """Buka alert kuning sekali per kode per hari (sinkron berulang tidak membanjiri Daftar Tilik)."""
    since = config.now().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    for a in db.query("SELECT reasons FROM alerts WHERE patient_id = ? AND created_at >= ? AND status != 'closed'", (patient_id, since)):
        if any(r.get("code") == code for r in db.loads(a["reasons"], [])):
            return None
    reasons = [{"path": "event", "code": code, "label": content.label(code), "quote": quote}]
    return escalation.open_alert(patient_id, None, "yellow", "event:wearable", reasons)


def ingest(patient_id: str, source: str, device: str, samples: list[dict[str, Any]]) -> dict[str, Any]:
    cfg = _cfg()
    stored, alerts = 0, []
    rows = []
    for s in samples:
        kind = s["type"]
        at = _at(s.get("at"))
        if kind == "blood_pressure":
            value = {"systolic": int(s["systolic"]), "diastolic": int(s["diastolic"]), "confirmed": True}
        elif kind in ("steps", "sleep"):
            value = {"value": int(s["value"]), "date": at[:10]}
        else:
            value = {"value": float(s["value"])}
        rows.append((db.new_id(), patient_id, None, kind, db.dumps(value), device[:60], source, at))
        stored += 1

    with db.tx() as conn:
        # Langkah & tidur adalah total harian: ganti nilai lama di tanggal yang sama supaya sinkron ulang tidak menggandakan.
        for r in rows:
            if r[3] in ("steps", "sleep"):
                conn.execute("DELETE FROM observations WHERE patient_id = ? AND kind = ? AND substr(observed_at, 1, 10) = ?",
                             (patient_id, r[3], r[7][:10]))
        conn.executemany("INSERT INTO observations (id, patient_id, session_id, kind, value, verbatim, source, observed_at) VALUES (?,?,?,?,?,?,?,?)",
                         rows)
        conn.execute("INSERT INTO device_syncs (id, patient_id, source, device, sample_count, synced_at) VALUES (?,?,?,?,?,?)",
                     (db.new_id(), patient_id, source, device[:60], stored, config.now().isoformat()))

    # Hanya sampel terbaru per jenis yang dinilai: data lama yang tersinkron belakangan tidak memicu alert hari ini.
    latest: dict[str, dict[str, Any]] = {}
    for s in samples:
        if s["type"] not in latest or _at(s.get("at")) >= _at(latest[s["type"]].get("at")):
            latest[s["type"]] = s
    if (s := latest.get("spo2")) and float(s["value"]) < cfg["spo2_low"]:
        alerts.append(_open_once(patient_id, "SPO2_LOW", f"SpO2 {float(s['value']):.0f}% ({SOURCE_LABEL.get(source, source)})"))
    if (s := latest.get("resting_hr")) and float(s["value"]) >= cfg["hr_high_rest"]:
        alerts.append(_open_once(patient_id, "HR_HIGH_REST", f"detak istirahat {float(s['value']):.0f}/menit"))
    if (s := latest.get("heart_rate")) and float(s["value"]) <= cfg["hr_low"]:
        alerts.append(_open_once(patient_id, "HR_LOW", f"detak {float(s['value']):.0f}/menit"))
    if s := latest.get("blood_pressure"):
        sys_, dia = int(s["systolic"]), int(s["diastolic"])
        f = safety.assess_bp(sys_, dia, set(), f"{SOURCE_LABEL.get(source, source)}: {sys_}/{dia}")
        if f:
            alerts.append(_open_once(patient_id, f.code, f.quote))

    opened = [a for a in alerts if a]
    return {"stored": stored, "level": "yellow" if opened else "green", "alert_ids": opened}


def _series(patient_id: str, kind: str, days: int) -> list[dict[str, Any]]:
    since = (config.now() - timedelta(days=days)).isoformat()
    rows = db.query("SELECT value, observed_at, source FROM observations WHERE patient_id = ? AND kind = ? AND observed_at >= ? ORDER BY observed_at",
                    (patient_id, kind, since))
    return [{**db.loads(r["value"], {}), "at": r["observed_at"], "source": r["source"]} for r in rows]


def _daily(points: list[dict[str, Any]], days: int, agg: str) -> list[dict[str, Any]]:
    """Kelompokkan per tanggal WIB untuk `days` hari terakhir (hari kosong tetap muncul dengan value None)."""
    today = config.now().date()
    out = []
    for d in range(days - 1, -1, -1):
        date = (today - timedelta(days=d)).isoformat()
        vals = [p["value"] for p in points if p["at"][:10] == date and "value" in p]
        v = None
        if vals:
            v = sum(vals) / len(vals) if agg == "avg" else (min(vals) if agg == "min" else vals[-1])
        out.append({"date": date, "value": round(v, 1) if isinstance(v, float) else v})
    return out


def summary(patient_id: str, days: int = 7) -> dict[str, Any]:
    cfg = _cfg()
    last = db.one("SELECT source, device, synced_at, sample_count FROM device_syncs WHERE patient_id = ? ORDER BY synced_at DESC LIMIT 1",
                  (patient_id,))
    hr = _series(patient_id, "heart_rate", days)
    rhr = _series(patient_id, "resting_hr", days)
    spo2 = _series(patient_id, "spo2", days)
    steps = _series(patient_id, "steps", days)
    sleep = _series(patient_id, "sleep", days)
    bp = [p for p in _series(patient_id, "blood_pressure", days)]
    today = config.now().date().isoformat()

    def latest(points: list[dict[str, Any]]) -> dict[str, Any] | None:
        return points[-1] if points else None

    steps_today = next((p["value"] for p in reversed(steps) if p["at"][:10] == today), 0)
    sleep_last = latest(sleep)
    return {
        "connected": last is not None,
        "last_sync": {**last, "source_label": SOURCE_LABEL.get(last["source"], last["source"])} if last else None,
        "goals": {"steps": cfg["goal_steps"], "sleep_min": cfg["goal_sleep_min"]},
        "thresholds": {"spo2_low": cfg["spo2_low"], "hr_high_rest": cfg["hr_high_rest"], "hr_low": cfg["hr_low"]},
        "latest": {
            "heart_rate": latest(hr),
            "resting_hr": latest(rhr),
            "spo2": latest(spo2),
            "blood_pressure": latest(bp),
            "steps_today": steps_today,
            "sleep_last_min": sleep_last["value"] if sleep_last else None,
        },
        "daily": {
            "steps": _daily(steps, days, "last"),
            "sleep": _daily(sleep, days, "last"),
            "heart_rate": _daily(hr, days, "avg"),
            "resting_hr": _daily(rhr, days, "avg"),
            "spo2": _daily(spo2, days, "min"),
        },
        "heart_rate_today": [{"at": p["at"], "value": p["value"]} for p in hr if p["at"][:10] == today],
    }
