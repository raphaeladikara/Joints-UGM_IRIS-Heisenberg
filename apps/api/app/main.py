"""API KRING (FastAPI). Dipakai aplikasi Flutter (semua peran) dan nanti oleh server suara Pipecat.

Mode demo (DEMO_MODE=true): telepon/WA ke keluarga adalah kanal simulasi di aplikasi; tidak ada panggilan ke 119/RS.
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import timedelta
from typing import Any, Literal

import base64
import binascii

from fastapi import FastAPI, HTTPException, Response
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field

from . import care, config, db, dialog, escalation, protocol, safety, seed, vitals

@asynccontextmanager
async def lifespan(_: FastAPI):
    # DB lama (sebelum fitur keluarga & jadwal kontrol) belum punya datanya: isi ulang data demo.
    if not db.one("SELECT id FROM patients LIMIT 1") or not db.one("SELECT id FROM appointments LIMIT 1"):
        seed.run()
    yield


app = FastAPI(title="KRING API", version="0.1.0", lifespan=lifespan,
              description="Prototype KRING: agen telepon harian lansia hipertensi (data fiktif).")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class StartCall(Strict):
    patient_id: str
    auto_answer: bool = False


class Turn(Strict):
    text: str = Field(min_length=1, max_length=600)


class EventIn(Strict):
    patient_id: str
    source: Literal["call", "inbound_call", "sos_button", "wearable", "sensor", "scheduler"] = "wearable"
    type: Literal["fall_detected", "sos_pressed", "irregular_rhythm", "bp_reading", "missed_checkin"]
    payload: dict[str, Any] = Field(default_factory=dict)


class FamilyMessageIn(Strict):
    contact_id: str
    text: str = Field(default="", max_length=300)
    # F-03 pesan suara asli: rekaman (AAC/M4A, WebM/Opus, WAV) dikirim base64, maks. ±60 detik.
    audio_b64: str | None = Field(default=None, max_length=900_000)
    audio_mime: str = Field(default="audio/mp4", pattern=r"^audio/[a-z0-9.+-]+$")
    duration_s: int = Field(default=0, ge=0, le=90)


class NotificationAction(Strict):
    action: Literal["answer", "decline", "read"]


class VitalSample(Strict):
    type: Literal["heart_rate", "resting_hr", "steps", "sleep", "spo2", "blood_pressure"]
    value: float | None = Field(default=None, ge=0, le=100000)
    systolic: int | None = Field(default=None, ge=40, le=300)
    diastolic: int | None = Field(default=None, ge=20, le=200)
    at: str | None = None


class VitalsIn(Strict):
    source: Literal["health_connect", "apple_health", "watch_sim"]
    device: str = Field(default="", max_length=60)
    samples: list[VitalSample] = Field(min_length=1, max_length=2000)


class AckIn(Strict):
    by: str = Field(min_length=1, max_length=60)


class ConsultIn(Strict):
    contact_id: str
    mode: Literal["video", "voice"] = "video"
    reason: str = Field(default="", max_length=300)


class ConsultUpdate(Strict):
    status: Literal["in_call", "ended", "declined"]
    note: str = Field(default="", max_length=500)


class DoseIn(Strict):
    name: str = Field(min_length=1, max_length=60)
    time: str = Field(pattern=r"^\d{2}:\d{2}$")
    status: Literal["taken", "missed"] = "taken"


class RefillIn(Strict):
    name: str | None = Field(default=None, max_length=60)


class IntakeIn(Strict):
    kind: Literal["water", "salt"]
    delta: float = Field(default=1, ge=-16, le=16)


class HomeCheckIn(Strict):
    result: Literal["ok", "not_home", "help"]
    note: str = Field(default="", max_length=300)


class AppointmentIn(Strict):
    kind: Literal["prolanis", "posyandu"]
    date: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$")
    time: str = Field(default="08:00", pattern=r"^\d{2}:\d{2}$")
    place: str = Field(default="", max_length=80)
    note: str = Field(default="", max_length=200)


class AppointmentStatusIn(Strict):
    status: Literal["done", "missed"]
    picked_up_meds: bool = False


class FamilyCallIn(Strict):
    contact_id: str | None = None
    minutes: int = Field(default=5, ge=0, le=600)


# ---------- util ----------

def _age(birth_year: int) -> int:
    return config.now().year - birth_year


def _today_start() -> str:
    return config.now().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()


def _patient_or_404(pid: str) -> dict[str, Any]:
    p = db.one("SELECT * FROM patients WHERE id = ?", (pid,))
    if not p:
        raise HTTPException(404, "Pasien tidak ditemukan")
    return p


def _public_patient(p: dict[str, Any]) -> dict[str, Any]:
    """Profil tanpa kata sandi keluarga (tidak pernah tampil di UI)."""
    return {
        "id": p["id"], "display_name": p["display_name"], "full_name": p["full_name"], "age": _age(p["birth_year"]), "sex": p["sex"],
        "village": p["village"], "preferred_language": p["preferred_language"], "call_time_local": p["call_time_local"],
        "conditions": db.loads(p["conditions"], []), "medications": db.loads(p["medications"], []),
        "has_bp_monitor": bool(p["has_bp_monitor"]),
    }


def _bp_history(pid: str, days: int = 7) -> list[dict[str, Any]]:
    since = (config.now() - timedelta(days=days)).isoformat()
    rows = db.query("SELECT value, observed_at, source FROM observations WHERE patient_id = ? AND kind = 'blood_pressure' AND observed_at >= ? ORDER BY observed_at",
                    (pid, since))
    return [{**db.loads(r["value"], {}), "at": r["observed_at"], "source": r["source"]} for r in rows]


def _adherence(pid: str, days: int = 7) -> dict[str, Any]:
    since = (config.now() - timedelta(days=days)).isoformat()
    rows = db.query("SELECT value, observed_at FROM observations WHERE patient_id = ? AND kind = 'adherence' AND observed_at >= ? ORDER BY observed_at",
                    (pid, since))
    items = [{**db.loads(r["value"], {}), "at": r["observed_at"]} for r in rows]
    return {"taken": sum(1 for i in items if i.get("status") == "sudah"), "total": len(items), "days": items}


def _alert_view(a: dict[str, Any]) -> dict[str, Any]:
    p = db.one("SELECT * FROM patients WHERE id = ?", (a["patient_id"],))
    assert p is not None
    hospital = db.one("SELECT * FROM hospitals WHERE id = ?", (a["target_hospital_id"],)) if a["target_hospital_id"] else None
    contacts = escalation.contacts_for(p["id"])
    meds = db.loads(p["medications"], [])
    initials = "".join(w[0] for w in p["full_name"].replace("(fiktif)", "").split()[:2]).upper()
    return {
        "id": a["id"], "level": a["level"], "status": a["status"], "source": a["source"], "session_id": a["session_id"],
        "reasons": db.loads(a["reasons"], []), "screening": db.loads(a["screening"], {}),
        "last_known_well": a["last_known_well"], "lkw_note": a["lkw_note"], "golden_period_deadline": a["golden_period_deadline"],
        "hospital": {"id": hospital["id"], "name": hospital["name"], "has_ct_24h": bool(hospital["has_ct_24h"])} if hospital else None,
        "eta_minutes": a["eta_minutes"], "acknowledged_by": a["acknowledged_by"], "acknowledged_at": a["acknowledged_at"],
        "created_at": a["created_at"], "updated_at": a["updated_at"],
        "patient": {"id": p["id"], "display_name": p["display_name"], "initials": initials, "age": _age(p["birth_year"]), "sex": p["sex"],
                    "village": p["village"], "medications": meds, "anticoagulant": any(m.get("is_anticoagulant") for m in meds)},
        "contacts": [{"name": c["name"], "role": c["role"], "relation": c["relation"], "phone": c["phone_e164"]} for c in contacts],
    }


def _notification_view(n: dict[str, Any]) -> dict[str, Any]:
    return {**n, "payload": db.loads(n["payload"], {})}


def _mask_codeword(text: str, codeword: str) -> str:
    return text.replace(codeword, "•••••") if codeword else text


# ---------- sistem ----------

@app.get("/v1/health")
def health() -> dict[str, Any]:
    return {"ok": True, "demo_mode": config.DEMO_MODE, "llm": config.llm_enabled(), "time": config.now().isoformat()}


@app.post("/v1/demo/reset")
def demo_reset() -> dict[str, Any]:
    seed.run()
    return {"ok": True}


# ---------- pasien & puskesmas ----------

@app.get("/v1/patients")
def patients() -> list[dict[str, Any]]:
    return [_public_patient(p) for p in db.query("SELECT * FROM patients WHERE active = 1 ORDER BY display_name")]


@app.get("/v1/patients/{pid}")
def patient_detail(pid: str) -> dict[str, Any]:
    p = _patient_or_404(pid)
    sessions = db.query("SELECT id, trigger, status, final_level, outcome, started_at, ended_at, summary, family_talking_points "
                        "FROM call_sessions WHERE patient_id = ? ORDER BY started_at DESC LIMIT 10", (pid,))
    for s in sessions:
        s["family_talking_points"] = db.loads(s["family_talking_points"], [])
    return {
        **_public_patient(p),
        "contacts": [{"id": c["id"], "role": c["role"], "name": c["name"], "relation": c["relation"]} for c in escalation.contacts_for(pid)],
        "bp_history": _bp_history(pid, 14),
        "adherence_7d": _adherence(pid),
        "memories": db.query("SELECT fact, category, created_at FROM memories WHERE patient_id = ? ORDER BY created_at DESC LIMIT 5", (pid,)),
        "vitals": vitals.summary(pid),
        "sessions": sessions,
        "alerts": [_alert_view(a) for a in db.query("SELECT * FROM alerts WHERE patient_id = ? ORDER BY created_at DESC LIMIT 5", (pid,))],
        "care": care.care(pid),
    }


@app.get("/v1/puskesmas/today")
def daftar_tilik() -> dict[str, Any]:
    """F-13 Daftar Kring Hari Ini: 🔴/🟡 di paling atas."""
    protocol.run_due()
    start = _today_start()
    rows = []
    for p in db.query("SELECT * FROM patients WHERE active = 1"):
        call = db.one("SELECT * FROM call_sessions WHERE patient_id = ? AND started_at >= ? ORDER BY started_at DESC LIMIT 1", (p["id"], start))
        alerts = db.query("SELECT * FROM alerts WHERE patient_id = ? AND status != 'closed' AND created_at >= ? ORDER BY created_at DESC",
                          (p["id"], start))
        bp = _bp_history(p["id"], 30)
        adh = _adherence(p["id"])
        if any(a["level"] == "red" for a in alerts):
            status = "red"
        elif any(a["level"] == "yellow" for a in alerts):
            status = "yellow"
        elif call and call["status"] in {"ringing", "in_progress"}:
            status = "in_progress"
        elif call and call["status"] == "no_answer":
            status = "no_answer"
        elif call and call["status"] == "completed":
            status = call["final_level"] or "green"
        else:
            status = "scheduled"
        reasons = [r["label"] for a in alerts for r in db.loads(a["reasons"], [])]
        c = care.care(p["id"])
        rows.append({
            "patient": _public_patient(p), "status": status,
            "call": {k: call[k] for k in ("id", "status", "final_level", "outcome", "started_at", "ended_at", "summary")} if call else None,
            "last_bp": bp[-1] if bp else None, "adherence_7d": {"taken": adh["taken"], "total": adh["total"]},
            "follow_up": reasons, "open_alerts": [a["id"] for a in alerts],
            "protocol": protocol.state(p["id"]),
            "mood": {k: c["mood"][k] for k in ("level", "lonely_days_7", "summary")},
            "next_visit": c["schedule"]["upcoming"][0] if c["schedule"]["upcoming"] else None,
            "pickup": c["schedule"]["pickup"],
        })
    order = {"red": 0, "yellow": 1, "no_answer": 2, "in_progress": 3, "scheduled": 4, "green": 5}
    rows.sort(key=lambda r: (order.get(r["status"], 9), r["patient"]["display_name"]))
    counts = {k: sum(1 for r in rows if r["status"] == k) for k in order}
    return {"date": config.now().date().isoformat(), "puskesmas": config.PUSKESMAS_NAME, "counts": counts, "rows": rows}


# ---------- panggilan ----------

@app.post("/v1/calls")
def start_call(body: StartCall) -> dict[str, Any]:
    """Tombol 'Kring sekarang' (F-01). HP Mbah (simulator) berdering; auto_answer=true langsung mengangkat."""
    _patient_or_404(body.patient_id)
    for old in db.query("SELECT id FROM call_sessions WHERE patient_id = ? AND status = 'ringing'", (body.patient_id,)):
        db.execute("UPDATE call_sessions SET status = 'failed', outcome = 'superseded', ended_at = ? WHERE id = ?", (config.now().isoformat(), old["id"]))
    s = dialog.create_session(body.patient_id)
    if body.auto_answer:
        return dialog.answer(s["id"]).as_dict()
    return {"session_id": s["id"], "state": "RINGING", "status": "ringing"}


@app.get("/v1/patients/{pid}/incoming")
def incoming(pid: str) -> dict[str, Any]:
    """Dipoll oleh simulator HP Mbah: apakah ada panggilan KRING yang sedang berdering?"""
    protocol.run_due(pid)
    s = db.one("SELECT id, trigger, started_at FROM call_sessions WHERE patient_id = ? AND status = 'ringing' ORDER BY started_at DESC LIMIT 1", (pid,))
    return {"ringing": s is not None, "session": s}


def _turn_or_400(fn, *args):
    try:
        return fn(*args).as_dict()
    except KeyError:
        raise HTTPException(404, "Sesi tidak ditemukan")
    except ValueError as exc:
        raise HTTPException(409, str(exc))


@app.post("/v1/calls/{sid}/answer")
def answer_call(sid: str) -> dict[str, Any]:
    return _turn_or_400(dialog.answer, sid)


@app.post("/v1/calls/{sid}/turns")
def call_turn(sid: str, body: Turn) -> dict[str, Any]:
    return _turn_or_400(dialog.handle, sid, body.text)


@app.post("/v1/calls/{sid}/no-answer")
def call_no_answer(sid: str) -> dict[str, Any]:
    return _turn_or_400(dialog.no_answer, sid)


@app.post("/v1/calls/{sid}/hangup")
def call_hangup(sid: str) -> dict[str, Any]:
    return _turn_or_400(dialog.hangup, sid)


@app.get("/v1/calls/{sid}")
def call_detail(sid: str) -> dict[str, Any]:
    s = db.one("SELECT * FROM call_sessions WHERE id = ?", (sid,))
    if not s:
        raise HTTPException(404, "Sesi tidak ditemukan")
    p = _patient_or_404(s["patient_id"])
    ctx = db.loads(s["ctx"], {})
    turns = db.query("SELECT speaker, state, text, ts FROM call_turns WHERE session_id = ? ORDER BY id", (sid,))
    for t in turns:
        t["text"] = _mask_codeword(t["text"], p["family_codeword"])
    obs = db.query("SELECT kind, value, verbatim, source, observed_at FROM observations WHERE session_id = ? ORDER BY observed_at", (sid,))
    return {
        "id": sid, "patient": _public_patient(p), "status": s["status"], "state": s["state"],
        "state_label": dialog.STATE_LABELS.get(s["state"], s["state"]), "level": ctx.get("level", s["final_level"] or "green"),
        "final_level": s["final_level"], "outcome": s["outcome"], "summary": s["summary"],
        "talking_points": db.loads(s["family_talking_points"], []), "findings": ctx.get("findings", []), "screen": ctx.get("screen", {}),
        "alert_id": ctx.get("alert_id"), "turns": turns, "observations": [{**o, "value": db.loads(o["value"], {})} for o in obs],
        "started_at": s["started_at"], "ended_at": s["ended_at"],
    }


@app.get("/v1/calls")
def calls_live() -> list[dict[str, Any]]:
    protocol.run_due()
    return db.query("""SELECT c.id, c.patient_id, p.display_name, c.status, c.state, c.trigger, c.started_at FROM call_sessions c
                       JOIN patients p ON p.id = c.patient_id WHERE c.status IN ('ringing','in_progress') ORDER BY c.started_at DESC""")


# ---------- event eksternal (F-18) ----------

@app.post("/v1/events")
def post_event(body: EventIn) -> dict[str, Any]:
    _patient_or_404(body.patient_id)
    if body.type == "fall_detected":
        # KRING menelepon pasien dulu. Tidak diangkat / tidak ada jawaban jelas → 🔴 otomatis.
        db.execute("INSERT INTO events (id, patient_id, source, type, payload, occurred_at, handled_level) VALUES (?,?,?,?,?,?, 'pending')",
                   (db.new_id(), body.patient_id, body.source, body.type, db.dumps(body.payload), config.now().isoformat()))
        s = dialog.create_session(body.patient_id, trigger="fall")
        return {"action": "calling_patient", "session_id": s["id"], "level": "green"}
    if body.type == "bp_reading":
        sys_, dia = int(body.payload.get("systolic", 0)), int(body.payload.get("diastolic", 0))
        f = safety.assess_bp(sys_, dia, set(), f"tensimeter: {sys_}/{dia}")
        db.execute("INSERT INTO observations (id, patient_id, session_id, kind, value, verbatim, source, observed_at) VALUES (?,?,?,?,?,?,?,?)",
                   (db.new_id(), body.patient_id, None, "blood_pressure", db.dumps({"systolic": sys_, "diastolic": dia, "confirmed": True}),
                    "perangkat", body.source, config.now().isoformat()))
        if f:
            aid = escalation.open_alert(body.patient_id, None, f.level, f"event:{body.source}", [f.as_reason()])
            return {"action": "follow_up", "level": f.level, "alert_id": aid}
        return {"action": "logged", "level": "green"}
    return escalation.handle_event(body.patient_id, body.source, body.type, body.payload)


# ---------- jam tangan & aplikasi kesehatan ----------

@app.post("/v1/patients/{pid}/vitals")
def post_vitals(pid: str, body: VitalsIn) -> dict[str, Any]:
    """Sinkron dari Health Connect (Android), Apple Health (iOS), atau simulasi jam tangan."""
    _patient_or_404(pid)
    samples = []
    for s in body.samples:
        if s.type == "blood_pressure":
            if s.systolic is None or s.diastolic is None:
                raise HTTPException(422, "Tensi butuh systolic dan diastolic")
        elif s.value is None:
            raise HTTPException(422, f"Sampel {s.type} butuh value")
        samples.append(s.model_dump())
    result = vitals.ingest(pid, body.source, body.device or vitals.SOURCE_LABEL[body.source], samples)
    return {**result, "summary": vitals.summary(pid)}


@app.get("/v1/patients/{pid}/vitals")
def get_vitals(pid: str, days: int = 7) -> dict[str, Any]:
    _patient_or_404(pid)
    return vitals.summary(pid, max(1, min(days, 30)))


# ---------- IGD ----------

@app.get("/v1/alerts")
def alerts(level: str | None = None, status: str | None = None) -> list[dict[str, Any]]:
    sql, params = "SELECT * FROM alerts WHERE 1=1", []
    if level:
        sql += " AND level = ?"
        params.append(level)
    if status:
        sql += " AND status = ?"
        params.append(status)
    sql += " ORDER BY created_at DESC LIMIT 50"
    return [_alert_view(a) for a in db.query(sql, params)]


@app.get("/v1/alerts/{aid}")
def alert_detail(aid: str) -> dict[str, Any]:
    a = db.one("SELECT * FROM alerts WHERE id = ?", (aid,))
    if not a:
        raise HTTPException(404, "Alert tidak ditemukan")
    return _alert_view(a)


@app.post("/v1/alerts/{aid}/ack")
def ack_alert(aid: str, body: AckIn) -> dict[str, Any]:
    if not db.one("SELECT id FROM alerts WHERE id = ?", (aid,)):
        raise HTTPException(404, "Alert tidak ditemukan")
    db.execute("UPDATE alerts SET status = 'acknowledged', acknowledged_by = ?, acknowledged_at = ?, updated_at = ? WHERE id = ?",
               (body.by, config.now().isoformat(), config.now().isoformat(), aid))
    return {"ok": True}


@app.post("/v1/alerts/{aid}/close")
def close_alert(aid: str) -> dict[str, Any]:
    db.execute("UPDATE alerts SET status = 'closed', updated_at = ? WHERE id = ?", (config.now().isoformat(), aid))
    return {"ok": True}


@app.get("/v1/hospitals")
def hospitals() -> list[dict[str, Any]]:
    return db.query("SELECT id, name, regency, has_ct_24h, code_stroke_network FROM hospitals ORDER BY name")


# ---------- keluarga & Sahabat Kring ----------

@app.get("/v1/contacts")
def contacts() -> list[dict[str, Any]]:
    return db.query("""SELECT c.id, c.role, c.name, c.relation, c.patient_id, p.display_name AS patient_name FROM contacts c
                       JOIN patients p ON p.id = c.patient_id ORDER BY p.display_name, c.escalation_order""")


@app.get("/v1/contacts/{cid}/feed")
def contact_feed(cid: str) -> dict[str, Any]:
    c = db.one("SELECT * FROM contacts WHERE id = ?", (cid,))
    if not c:
        raise HTTPException(404, "Kontak tidak ditemukan")
    p = _patient_or_404(c["patient_id"])
    protocol.run_due(p["id"])
    notes = [_notification_view(n) for n in db.query("SELECT * FROM notifications WHERE contact_id = ? ORDER BY created_at DESC LIMIT 40", (cid,))]
    report = next((n for n in notes if n["kind"] == "daily_report"), None)
    red = db.one("SELECT * FROM alerts WHERE patient_id = ? AND level = 'red' AND status != 'closed' ORDER BY created_at DESC LIMIT 1", (p["id"],))
    ringing = next((n for n in notes if n["channel"] == "call_sim" and n["status"] == "ringing"), None)
    today = db.one("SELECT status, final_level FROM call_sessions WHERE patient_id = ? AND started_at >= ? ORDER BY started_at DESC LIMIT 1",
                   (p["id"], _today_start()))
    return {
        "contact": {k: c[k] for k in ("id", "role", "name", "relation")},
        "patient": {**_public_patient(p), "phone": p["phone_e164"]},  # nomor hanya untuk keluarga & Sahabat Kring
        "today": today,
        "latest_report": report,
        "bp_history": _bp_history(p["id"], 7),
        "adherence_7d": _adherence(p["id"]),
        "vitals": vitals.summary(p["id"]),
        "red_alert": _alert_view(red) if red else None,
        "incoming_call": ringing,
        "notifications": notes,
        "pending_messages": db.query("""SELECT m.id, m.kind, m.text, m.status, m.created_at, a.duration_s FROM family_messages m
                                        LEFT JOIN message_audio a ON a.message_id = m.id WHERE m.from_contact_id = ? ORDER BY m.created_at DESC LIMIT 5""",
                                     (cid,)),
        "no_answer": protocol.state(p["id"]),
        "doctor": {**config.DOCTOR, "suggest": _health_concerns(p["id"])},
        "doctor_consult": _consult_view(dc) if (dc := db.one(
            "SELECT * FROM doctor_consults WHERE contact_id = ? AND status IN ('ringing', 'in_call') ORDER BY created_at DESC LIMIT 1", (cid,))) else None,
        "care": care.care(p["id"]),
    }


# ---------- telekonsultasi dokter (wali → dokter jaga Puskesmas) ----------

def _health_concerns(pid: str) -> dict[str, Any]:
    """Hal yang janggal hari ini: dasar saran "hubungi dokter" di aplikasi wali dan ringkasan yang dikirim ke dokter."""
    reasons: list[str] = []
    level = "green"
    today = db.one("SELECT final_level FROM call_sessions WHERE patient_id = ? AND started_at >= ? ORDER BY started_at DESC LIMIT 1",
                   (pid, _today_start()))
    if today and today["final_level"] in ("yellow", "red"):
        level = safety.max_level(level, today["final_level"])
        reasons.append("Telepon pagi menandai " + ("darurat" if today["final_level"] == "red" else "perlu tindak lanjut"))
    alert = db.one("SELECT level, reasons FROM alerts WHERE patient_id = ? AND status != 'closed' ORDER BY created_at DESC LIMIT 1", (pid,))
    if alert:
        level = safety.max_level(level, alert["level"])
        reasons += [r.get("label", "") for r in db.loads(alert["reasons"], []) if r.get("label")][:3]
    v = vitals.summary(pid, 7)
    th, latest = v["thresholds"], v["latest"]
    bp = latest.get("blood_pressure") or (_bp_history(pid, 7) or [None])[-1]
    if bp and bp.get("systolic") and bp["systolic"] >= 160:
        level = safety.max_level(level, "yellow")
        reasons.append(f"Tensi tinggi {bp['systolic']}/{bp.get('diastolic')} mmHg")
    if (s := latest.get("spo2")) and s["value"] < th["spo2_low"]:
        level = safety.max_level(level, "yellow")
        reasons.append(f"Oksigen rendah {round(s['value'])}%")
    if (r := latest.get("resting_hr")) and r["value"] >= th["hr_high_rest"]:
        level = safety.max_level(level, "yellow")
        reasons.append(f"Detak istirahat tinggi {round(r['value'])}/menit")
    adh = _adherence(pid, 7)
    if adh["total"] and adh["total"] - adh["taken"] >= 2:
        level = safety.max_level(level, "yellow")
        reasons.append(f"Obat terlewat {adh['total'] - adh['taken']} hari minggu ini")
    seen: set[str] = set()
    reasons = [r for r in reasons if not (r in seen or seen.add(r))]
    return {"level": level, "reasons": reasons, "recommended": level != "green"}


def _consult_view(c: dict[str, Any]) -> dict[str, Any]:
    p = db.one("SELECT display_name, birth_year FROM patients WHERE id = ?", (c["patient_id"],))
    who = db.one("SELECT name, relation FROM contacts WHERE id = ?", (c["contact_id"],))
    return {
        **{k: c[k] for k in ("id", "patient_id", "contact_id", "mode", "reason", "level", "status", "doctor_note", "created_at", "answered_at", "ended_at")},
        "context": db.loads(c["context"], {}),
        "patient_name": p["display_name"] if p else None,
        "patient_age": _age(p["birth_year"]) if p else None,
        "requested_by": who["name"] if who else None,
        "doctor": config.DOCTOR,
    }


@app.post("/v1/patients/{pid}/doctor-consults")
def request_consult(pid: str, body: ConsultIn) -> dict[str, Any]:
    """Wali menekan "Hubungi dokter": dokter jaga ditelepon dengan ringkasan kondisi terbaru. Mode demo: simulasi."""
    p = _patient_or_404(pid)
    c = db.one("SELECT * FROM contacts WHERE id = ? AND patient_id = ?", (body.contact_id, pid))
    if not c:
        raise HTTPException(400, "Kontak bukan wali pasien ini")
    active = db.one("SELECT * FROM doctor_consults WHERE patient_id = ? AND status IN ('ringing', 'in_call')", (pid,))
    if active:
        return _consult_view(active)
    concern = _health_concerns(pid)
    v = vitals.summary(pid, 7)["latest"]
    context = {
        "concerns": concern["reasons"],
        "conditions": db.loads(p["conditions"], []),
        "medications": db.loads(p["medications"], []),
        "blood_pressure": (_bp_history(pid, 7) or [None])[-1],
        "heart_rate": v.get("heart_rate"),
        "spo2": v.get("spo2"),
        "adherence_7d": {k: _adherence(pid, 7)[k] for k in ("taken", "total")},
    }
    cid = db.new_id()
    now = config.now().isoformat()
    db.execute("""INSERT INTO doctor_consults (id, patient_id, contact_id, mode, reason, level, context, status, created_at)
                  VALUES (?,?,?,?,?,?,?, 'ringing', ?)""",
               (cid, pid, c["id"], body.mode, body.reason.strip() or "; ".join(concern["reasons"]) or "Wali ingin berkonsultasi",
                concern["level"], db.dumps(context), now))
    return _consult_view(db.one("SELECT * FROM doctor_consults WHERE id = ?", (cid,)))


@app.get("/v1/doctor-consults")
def list_consults(active: bool = True) -> list[dict[str, Any]]:
    where = "WHERE status IN ('ringing', 'in_call')" if active else ""
    return [_consult_view(c) for c in db.query(f"SELECT * FROM doctor_consults {where} ORDER BY created_at DESC LIMIT 30")]


@app.get("/v1/doctor-consults/{cid}")
def get_consult(cid: str) -> dict[str, Any]:
    c = db.one("SELECT * FROM doctor_consults WHERE id = ?", (cid,))
    if not c:
        raise HTTPException(404, "Konsultasi tidak ditemukan")
    return _consult_view(c)


@app.post("/v1/doctor-consults/{cid}/status")
def update_consult(cid: str, body: ConsultUpdate) -> dict[str, Any]:
    c = get_consult(cid)
    now = config.now().isoformat()
    if body.status == "in_call":
        db.execute("UPDATE doctor_consults SET status = 'in_call', answered_at = COALESCE(answered_at, ?) WHERE id = ?", (now, cid))
    else:
        db.execute("UPDATE doctor_consults SET status = ?, ended_at = ?, doctor_note = COALESCE(NULLIF(?, ''), doctor_note) WHERE id = ?",
                   (body.status, now, body.note, cid))
        if body.note.strip():
            contact = db.one("SELECT * FROM contacts WHERE id = ?", (c["contact_id"],))
            if contact:
                escalation.notify(contact, c["patient_id"], "doctor_note", "app", f"🩺 Catatan {config.DOCTOR['name']}", body.note.strip())
    return get_consult(cid)


@app.post("/v1/notifications/{nid}/action")
def notification_action(nid: str, body: NotificationAction) -> dict[str, Any]:
    n = db.one("SELECT * FROM notifications WHERE id = ?", (nid,))
    if not n:
        raise HTTPException(404, "Notifikasi tidak ditemukan")
    now = config.now().isoformat()
    if body.action == "answer":
        db.execute("UPDATE notifications SET status = 'joined', read_at = ? WHERE id = ?", (now, nid))
    elif body.action == "decline":
        db.execute("UPDATE notifications SET status = 'declined', read_at = ? WHERE id = ?", (now, nid))
    else:
        db.execute("UPDATE notifications SET read_at = COALESCE(read_at, ?) WHERE id = ?", (now, nid))
    return {"ok": True}


@app.post("/v1/patients/{pid}/family-messages")
def family_message(pid: str, body: FamilyMessageIn) -> dict[str, Any]:
    """F-03 Titip pesan: dibacakan KRING di panggilan berikutnya."""
    _patient_or_404(pid)
    c = db.one("SELECT * FROM contacts WHERE id = ? AND patient_id = ?", (body.contact_id, pid))
    if not c:
        raise HTTPException(400, "Kontak bukan keluarga pasien ini")
    audio: bytes | None = None
    if body.audio_b64:
        try:
            audio = base64.b64decode(body.audio_b64, validate=True)
        except (binascii.Error, ValueError):
            raise HTTPException(422, "Rekaman tidak valid")
    if not audio and not body.text.strip():
        raise HTTPException(422, "Pesan kosong")
    mid = db.new_id()
    with db.tx() as conn:
        conn.execute("INSERT INTO family_messages (id, patient_id, from_contact_id, kind, text, status, created_at) VALUES (?,?,?,?,?, 'pending', ?)",
                     (mid, pid, body.contact_id, "audio" if audio else "text", body.text.strip(), config.now().isoformat()))
        if audio:
            conn.execute("INSERT INTO message_audio (message_id, mime, data_b64, duration_s) VALUES (?,?,?,?)",
                         (mid, body.audio_mime, body.audio_b64, body.duration_s))
    return {"id": mid, "status": "pending", "kind": "audio" if audio else "text"}


@app.get("/v1/family-messages/{mid}/audio")
def family_message_audio(mid: str) -> Response:
    a = db.one("SELECT mime, data_b64 FROM message_audio WHERE message_id = ?", (mid,))
    if not a:
        raise HTTPException(404, "Rekaman tidak ditemukan")
    return Response(base64.b64decode(a["data_b64"]), media_type=a["mime"])


# ---------- F-19 protokol tidak diangkat ----------

@app.post("/v1/retries/{rid}/now")
def retry_now(rid: str) -> dict[str, Any]:
    """Demo: jalankan telepon ulang sekarang tanpa menunggu 15 menit."""
    st = protocol.fire_now(rid)
    if st is None:
        raise HTTPException(404, "Jadwal telepon ulang tidak ditemukan")
    return st


@app.post("/v1/home-checks/{hid}")
def home_check(hid: str, body: HomeCheckIn) -> dict[str, Any]:
    """Sahabat Kring melapor hasil menengok rumah."""
    st = protocol.respond(hid, body.result, body.note.strip())
    if st is None:
        raise HTTPException(404, "Permintaan cek rumah tidak ditemukan")
    return st


# ---------- jadwal kontrol Prolanis & posyandu ----------

@app.post("/v1/patients/{pid}/appointments")
def add_appointment(pid: str, body: AppointmentIn) -> dict[str, Any]:
    _patient_or_404(pid)
    care.add_appointment(pid, body.kind, body.date, body.time, body.place.strip(), body.note.strip())
    return care.care(pid)


@app.post("/v1/appointments/{aid}/status")
def appointment_status(aid: str, body: AppointmentStatusIn) -> dict[str, Any]:
    pid = care.mark_appointment(aid, body.status, body.picked_up_meds)
    if pid is None:
        raise HTTPException(404, "Jadwal tidak ditemukan")
    return care.care(pid)



# ---------- fitur keluarga: obat, asupan, streak, rapor ----------

@app.get("/v1/patients/{pid}/care")
def get_care(pid: str) -> dict[str, Any]:
    _patient_or_404(pid)
    return care.care(pid)


@app.post("/v1/patients/{pid}/meds/dose")
def log_dose(pid: str, body: DoseIn) -> dict[str, Any]:
    """Keluarga mencentang dosis (mis. obat malam). Dosis 'taken' mengurangi stok obat itu."""
    _patient_or_404(pid)
    care.log_dose(pid, body.name, body.time, body.status)
    return care.care(pid)


@app.post("/v1/patients/{pid}/meds/refill")
def refill_meds(pid: str, body: RefillIn) -> dict[str, Any]:
    """Obat sudah diambil/ditebus: stok bertambah satu kemasan, alert yang hanya 'obat habis' ditutup."""
    _patient_or_404(pid)
    care.refill(pid, body.name)
    return care.care(pid)


@app.post("/v1/patients/{pid}/intake")
def log_intake(pid: str, body: IntakeIn) -> dict[str, Any]:
    """Air (gelas) & garam (sdt) hari ini; batas garam 1 sdt."""
    _patient_or_404(pid)
    care.log_intake(pid, body.kind, body.delta)
    return care.care(pid)


@app.post("/v1/patients/{pid}/family-calls")
def log_family_call(pid: str, body: FamilyCallIn) -> dict[str, Any]:
    _patient_or_404(pid)
    care.log_family_call(pid, body.contact_id, body.minutes)
    return care.care(pid)


@app.get("/v1/patients/{pid}/report")
def patient_report(pid: str, days: int = 30) -> dict[str, Any]:
    p = _patient_or_404(pid)
    days = max(7, min(days, 30))
    return care.report(p, _public_patient(p), _bp_history(pid, days), days)
