"""API TILIK (FastAPI). Dipakai aplikasi Flutter (semua peran) dan nanti oleh server suara Pipecat.

Mode demo (DEMO_MODE=true): telepon/WA ke keluarga adalah kanal simulasi di aplikasi; tidak ada panggilan ke 119/RS.
"""

from __future__ import annotations

from contextlib import asynccontextmanager
from datetime import timedelta
from typing import Any, Literal

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field

from . import config, db, dialog, escalation, safety, seed

@asynccontextmanager
async def lifespan(_: FastAPI):
    if not db.one("SELECT id FROM patients LIMIT 1"):
        seed.run()
    yield


app = FastAPI(title="TILIK API", version="0.1.0", lifespan=lifespan,
              description="Prototype TILIK: agen telepon harian lansia hipertensi (data fiktif).")
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
    text: str = Field(min_length=1, max_length=300)


class NotificationAction(Strict):
    action: Literal["answer", "decline", "read"]


class AckIn(Strict):
    by: str = Field(min_length=1, max_length=60)


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
    rows = db.query("SELECT value, observed_at FROM observations WHERE patient_id = ? AND kind = 'blood_pressure' AND observed_at >= ? ORDER BY observed_at",
                    (pid, since))
    return [{**db.loads(r["value"], {}), "at": r["observed_at"]} for r in rows]


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
        "sessions": sessions,
        "alerts": [_alert_view(a) for a in db.query("SELECT * FROM alerts WHERE patient_id = ? ORDER BY created_at DESC LIMIT 5", (pid,))],
    }


@app.get("/v1/puskesmas/today")
def daftar_tilik() -> dict[str, Any]:
    """F-13 Daftar Tilik Hari Ini: 🔴/🟡 di paling atas."""
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
        rows.append({
            "patient": _public_patient(p), "status": status,
            "call": {k: call[k] for k in ("id", "status", "final_level", "outcome", "started_at", "ended_at", "summary")} if call else None,
            "last_bp": bp[-1] if bp else None, "adherence_7d": {"taken": adh["taken"], "total": adh["total"]},
            "follow_up": reasons, "open_alerts": [a["id"] for a in alerts],
        })
    order = {"red": 0, "yellow": 1, "no_answer": 2, "in_progress": 3, "scheduled": 4, "green": 5}
    rows.sort(key=lambda r: (order.get(r["status"], 9), r["patient"]["display_name"]))
    counts = {k: sum(1 for r in rows if r["status"] == k) for k in order}
    return {"date": config.now().date().isoformat(), "puskesmas": config.PUSKESMAS_NAME, "counts": counts, "rows": rows}


# ---------- panggilan ----------

@app.post("/v1/calls")
def start_call(body: StartCall) -> dict[str, Any]:
    """Tombol 'Tilik sekarang' (F-01). HP Mbah (simulator) berdering; auto_answer=true langsung mengangkat."""
    _patient_or_404(body.patient_id)
    for old in db.query("SELECT id FROM call_sessions WHERE patient_id = ? AND status = 'ringing'", (body.patient_id,)):
        db.execute("UPDATE call_sessions SET status = 'failed', outcome = 'superseded', ended_at = ? WHERE id = ?", (config.now().isoformat(), old["id"]))
    s = dialog.create_session(body.patient_id)
    if body.auto_answer:
        return dialog.answer(s["id"]).as_dict()
    return {"session_id": s["id"], "state": "RINGING", "status": "ringing"}


@app.get("/v1/patients/{pid}/incoming")
def incoming(pid: str) -> dict[str, Any]:
    """Dipoll oleh simulator HP Mbah: apakah ada panggilan TILIK yang sedang berdering?"""
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
    return db.query("""SELECT c.id, c.patient_id, p.display_name, c.status, c.state, c.trigger, c.started_at FROM call_sessions c
                       JOIN patients p ON p.id = c.patient_id WHERE c.status IN ('ringing','in_progress') ORDER BY c.started_at DESC""")


# ---------- event eksternal (F-18) ----------

@app.post("/v1/events")
def post_event(body: EventIn) -> dict[str, Any]:
    _patient_or_404(body.patient_id)
    if body.type == "fall_detected":
        # TILIK menelepon pasien dulu. Tidak diangkat / tidak ada jawaban jelas → 🔴 otomatis.
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


# ---------- keluarga & Sahabat Tilik ----------

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
    notes = [_notification_view(n) for n in db.query("SELECT * FROM notifications WHERE contact_id = ? ORDER BY created_at DESC LIMIT 40", (cid,))]
    report = next((n for n in notes if n["kind"] == "daily_report"), None)
    red = db.one("SELECT * FROM alerts WHERE patient_id = ? AND level = 'red' AND status != 'closed' ORDER BY created_at DESC LIMIT 1", (p["id"],))
    ringing = next((n for n in notes if n["channel"] == "call_sim" and n["status"] == "ringing"), None)
    today = db.one("SELECT status, final_level FROM call_sessions WHERE patient_id = ? AND started_at >= ? ORDER BY started_at DESC LIMIT 1",
                   (p["id"], _today_start()))
    return {
        "contact": {k: c[k] for k in ("id", "role", "name", "relation")},
        "patient": {**_public_patient(p), "phone": p["phone_e164"]},  # nomor hanya untuk keluarga & Sahabat Tilik
        "today": today,
        "latest_report": report,
        "bp_history": _bp_history(p["id"], 7),
        "adherence_7d": _adherence(p["id"]),
        "red_alert": _alert_view(red) if red else None,
        "incoming_call": ringing,
        "notifications": notes,
        "pending_messages": db.query("SELECT id, text, status, created_at FROM family_messages WHERE from_contact_id = ? ORDER BY created_at DESC LIMIT 5",
                                     (cid,)),
    }


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
    """F-03 Titip pesan: dibacakan TILIK di panggilan berikutnya."""
    _patient_or_404(pid)
    c = db.one("SELECT * FROM contacts WHERE id = ? AND patient_id = ?", (body.contact_id, pid))
    if not c:
        raise HTTPException(400, "Kontak bukan keluarga pasien ini")
    mid = db.new_id()
    db.execute("INSERT INTO family_messages (id, patient_id, from_contact_id, kind, text, status, created_at) VALUES (?,?,?, 'text', ?, 'pending', ?)",
               (mid, pid, body.contact_id, body.text.strip(), config.now().isoformat()))
    return {"id": mid, "status": "pending"}

