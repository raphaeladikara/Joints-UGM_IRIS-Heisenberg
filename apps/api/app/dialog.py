"""Dialog Manager KRING: state machine eksplisit (docs/stage-0/05_DESAIN_PERCAKAPAN.md §2).

GREETING → MEDICATION (→ MED_REASON) → BLOOD_PRESSURE (→ BP_CONFIRM) → SYMPTOMS → STORY → CLOSING
Darurat dari state mana pun: STROKE_SCREEN (speech → arms → lkw) → ESCALATING, atau langsung ESCALATING.

Semua data medis hanya disimpan lewat fungsi `_observe` yang memvalidasi nilai (pengganti tool call tervalidasi
pada pipeline suara Pipecat nanti). Kalimat diambil dari content/scripts.json, tidak di-hardcode.
"""

from __future__ import annotations

import re
from datetime import timedelta
from dataclasses import dataclass, field
from typing import Any

from . import care, config, content, db, escalation, llm, nlu, protocol, safety

SCREEN_SENTENCE = "Langit biru di atas desa"

STATE_LABELS = {
    "RINGING": "Berdering",
    "GREETING": "Pembuka & kata sandi",
    "MEDICATION": "Cek obat",
    "MED_REASON": "Alasan obat",
    "BLOOD_PRESSURE": "Cek tensi",
    "BP_CONFIRM": "Konfirmasi tensi",
    "SYMPTOMS": "Cek gejala",
    "STORY": "Cerita hari ini",
    "CLOSING": "Penutup",
    "STROKE_SCREEN": "Skrining stroke",
    "ESCALATING": "Eskalasi darurat",
    "ENDED": "Selesai",
}


@dataclass
class TurnResult:
    session_id: str
    tilik_text: str
    state: str
    level: str
    ended: bool = False
    outcome: str | None = None
    alert_id: str | None = None
    hints: list[str] = field(default_factory=list)
    # Urutan putar di telepon bila ada pesan suara keluarga: [{"say": teks} | {"play": message_id, ...}]. Kosong = ucapkan tilik_text.
    segments: list[dict[str, Any]] = field(default_factory=list)

    def as_dict(self) -> dict[str, Any]:
        return {
            "session_id": self.session_id, "tilik_text": self.tilik_text, "state": self.state,
            "state_label": STATE_LABELS.get(self.state, self.state), "level": self.level, "ended": self.ended,
            "outcome": self.outcome, "alert_id": self.alert_id, "hints": self.hints, "segments": self.segments,
        }


# ---------- penyimpanan sesi ----------

def create_session(patient_id: str, trigger: str = "daily", direction: str = "outbound") -> dict[str, Any]:
    patient = _patient(patient_id)
    sid = db.new_id()
    ctx = {"lang": patient["preferred_language"], "trigger": trigger, "retries": 0, "findings": [], "symptom_codes": [],
           "level": "green", "step": None, "edu_index": _call_count(patient_id)}
    db.execute(
        """INSERT INTO call_sessions (id, patient_id, direction, trigger, status, state, ctx, started_at)
           VALUES (?,?,?,?, 'ringing', 'RINGING', ?, ?)""",
        (sid, patient_id, direction, trigger, db.dumps(ctx), config.now().isoformat()),
    )
    return session(sid)


def session(sid: str) -> dict[str, Any]:
    row = db.one("SELECT * FROM call_sessions WHERE id = ?", (sid,))
    if row is None:
        raise KeyError(sid)
    return row


def _patient(pid: str) -> dict[str, Any]:
    row = db.one("SELECT * FROM patients WHERE id = ?", (pid,))
    if row is None:
        raise KeyError(pid)
    row["medications"] = db.loads(row["medications"], [])
    row["share_scope"] = db.loads(row["share_scope"], {})
    return row


def _call_count(pid: str) -> int:
    row = db.one("SELECT COUNT(*) AS n FROM call_sessions WHERE patient_id = ?", (pid,))
    return row["n"] if row else 0


def _save(sid: str, state: str, ctx: dict[str, Any], **cols: Any) -> None:
    sets = ["state = ?", "ctx = ?"] + [f"{k} = ?" for k in cols]
    db.execute(f"UPDATE call_sessions SET {', '.join(sets)} WHERE id = ?", (state, db.dumps(ctx), *cols.values(), sid))


def _turn(sid: str, speaker: str, state: str, text: str) -> None:
    db.execute("INSERT INTO call_turns (session_id, speaker, state, text, ts) VALUES (?,?,?,?,?)",
               (sid, speaker, state, text, config.now().isoformat()))


def _observe(pid: str, sid: str, kind: str, value: dict[str, Any], verbatim: str, source: str = "patient_report") -> None:
    if kind == "blood_pressure":
        bp = content.red_flags()["bp"]
        s, d = int(value["systolic"]), int(value["diastolic"])
        if not (bp["valid_systolic"][0] <= s <= bp["valid_systolic"][1] and bp["valid_diastolic"][0] <= d <= bp["valid_diastolic"][1]):
            return  # angka di luar rentang masuk akal tidak pernah disimpan
    db.execute(
        "INSERT INTO observations (id, patient_id, session_id, kind, value, verbatim, source, observed_at) VALUES (?,?,?,?,?,?,?,?)",
        (db.new_id(), pid, sid, kind, db.dumps(value), verbatim, source, config.now().isoformat()),
    )


# ---------- konteks bahasa ----------

class Speaker:
    """Pembantu menyusun kalimat untuk satu pasien."""

    def __init__(self, patient: dict[str, Any], ctx: dict[str, Any]):
        self.p = patient
        self.ctx = ctx
        contacts = escalation.contacts_for(patient["id"])
        self.child = next((c for c in contacts if c["role"] == "child"), None)
        self.sahabat = next((c for c in contacts if c["role"] == "sahabat_tilik"), None)

    def __call__(self, key: str, **extra: Any) -> str:
        meds = self.p["medications"]
        values = {
            "sapaan": self.p["display_name"], "puskesmas": config.PUSKESMAS_NAME, "codeword": self.p["family_codeword"],
            "obat": meds[0]["name"] if meds else "", "anak": self.child["name"] if self.child else "keluarga",
            "sahabat": self.sahabat["name"] if self.sahabat else "tetangga", **extra,
        }
        return re.sub(r"\s+", " ", content.line(key, self.ctx.get("lang", "id"), **values)).replace(" ,", ",").strip()


# ---------- alur utama ----------

def answer(sid: str) -> TurnResult:
    s = session(sid)
    if s["status"] != "ringing":
        raise ValueError("Panggilan sudah tidak berdering")
    ctx = db.loads(s["ctx"], {})
    patient = _patient(s["patient_id"])
    say = Speaker(patient, ctx)
    text = say("greeting_event_fall" if ctx["trigger"] == "fall" else "greeting")
    ctx["last_question"] = text
    _save(sid, "GREETING", ctx, status="in_progress", answered_at=config.now().isoformat())
    _turn(sid, "tilik", "GREETING", text)
    return TurnResult(sid, text, "GREETING", ctx["level"])


def no_answer(sid: str) -> TurnResult:
    s = session(sid)
    ctx = db.loads(s["ctx"], {})
    outcome = "no_answer"
    alert_id = None
    _save(sid, "ENDED", ctx, status="no_answer", outcome=outcome, ended_at=config.now().isoformat(), final_level="green")
    if ctx.get("trigger") == "fall":
        # F-18: jam tangan mendeteksi jatuh dan pasien tidak mengangkat → 🔴 otomatis.
        reasons = [{"path": "event", "code": "FALL_NO_RESPONSE", "label": content.label("FALL_NO_RESPONSE"), "quote": "panggilan tidak diangkat"}]
        alert_id = escalation.open_alert(s["patient_id"], sid, "red", "event:wearable", reasons)
        db.execute("UPDATE call_sessions SET final_level = 'red' WHERE id = ?", (sid,))
        return TurnResult(sid, "", "ENDED", "red", ended=True, outcome=outcome, alert_id=alert_id, hints=["escalation_started"])
    # F-19: telepon ulang 15 menit → masih tidak diangkat → Sahabat Kring mengecek rumah.
    retry_alert, hints = protocol.on_no_answer(s, ctx)
    level = "green"
    if retry_alert:
        alert_id, level = retry_alert, "yellow"
        db.execute("UPDATE call_sessions SET final_level = 'yellow' WHERE id = ?", (sid,))
    else:
        prev = db.query(
            "SELECT status FROM call_sessions WHERE patient_id = ? AND id != ? AND status != 'ringing' ORDER BY started_at DESC LIMIT 1",
            (s["patient_id"], sid),
        )
        if prev and prev[0]["status"] == "no_answer":
            reasons = [{"path": "rule", "code": "NO_ANSWER_2X", "label": content.label("NO_ANSWER_2X"), "quote": "2 panggilan berturut-turut tidak diangkat"}]
            alert_id = escalation.open_alert(s["patient_id"], sid, "yellow", "scheduler", reasons)
            level = "yellow"
            db.execute("UPDATE call_sessions SET final_level = 'yellow' WHERE id = ?", (sid,))
    return TurnResult(sid, "", "ENDED", level, ended=True, outcome=outcome, alert_id=alert_id, hints=hints)


def hangup(sid: str) -> TurnResult:
    s = session(sid)
    if s["status"] in {"completed", "no_answer"}:
        return TurnResult(sid, "", "ENDED", s["final_level"] or "green", ended=True, outcome=s["outcome"])
    ctx = db.loads(s["ctx"], {})
    return _finish(s, ctx, "", outcome="hung_up")


def handle(sid: str, text: str) -> TurnResult:
    s = session(sid)
    if s["status"] != "in_progress":
        raise ValueError("Panggilan tidak sedang berlangsung")
    text = text.strip()
    ctx = db.loads(s["ctx"], {})
    state = s["state"]
    patient = _patient(s["patient_id"])
    say = Speaker(patient, ctx)
    _turn(sid, "patient", state, text)
    hints: list[str] = []

    # 1) Safety Agent jalur aturan, setiap giliran.
    found = safety.scan_text(text)
    for f in found.findings:
        if f.code not in ctx["symptom_codes"]:
            ctx["symptom_codes"].append(f.code)
    new_red = [f for f in found.red if f.code not in {r["code"] for r in ctx["findings"]}]
    _record_findings(ctx, found.findings)

    if new_red and state not in {"STROKE_SCREEN", "ESCALATING"}:
        for f in new_red:
            _observe(patient["id"], sid, "symptom", {"code": f.code, "label": content.label(f.code)}, text, source="rule")
        return _start_emergency(s, ctx, patient, say, new_red, text)
    if new_red and ctx.get("alert_id"):
        escalation.update_alert(ctx["alert_id"], reasons=[f.as_reason() for f in new_red])

    # 2) Pertanyaan meta: identitas AI & dosis (guardrail).
    if state not in {"STROKE_SCREEN", "ESCALATING"}:
        if nlu.asks_if_ai(text):
            reply = f"{say('ai_disclosure')} {ctx.get('last_question', '')}".strip()
            return _reply(sid, state, ctx, reply, hints)
        if nlu.asks_dosage(text):
            _record_findings(ctx, [safety.Finding("DOSAGE_QUESTION", "yellow", "follow_up", text)])
            reply = f"{say('dosage_refusal')} {ctx.get('last_question', '')}".strip()
            return _reply(sid, state, ctx, reply, hints)

    handler = {
        "GREETING": _greeting, "MEDICATION": _medication, "MED_REASON": _med_reason, "BLOOD_PRESSURE": _blood_pressure,
        "BP_CONFIRM": _bp_confirm, "SYMPTOMS": _symptoms, "STORY": _story, "STROKE_SCREEN": _stroke_screen,
    }.get(state)
    if handler is None:
        raise ValueError(f"State {state} tidak menerima giliran")
    return handler(s, ctx, patient, say, text)


def _record_findings(ctx: dict[str, Any], findings: list[safety.Finding]) -> None:
    known = {r["code"] for r in ctx["findings"]}
    for f in findings:
        if f.level == "green" or f.code in known:
            continue
        ctx["findings"].append(f.as_reason() | {"level": f.level})
        known.add(f.code)
    ctx["level"] = safety.max_level(ctx["level"], *(r["level"] for r in ctx["findings"]))


def _reply(sid: str, state: str, ctx: dict[str, Any], text: str, hints: list[str] | None = None, *, question: bool = True,
           alert_id: str | None = None) -> TurnResult:
    if question:
        ctx["last_question"] = text
    _save(sid, state, ctx)
    _turn(sid, "tilik", state, text)
    return TurnResult(sid, text, state, ctx["level"], alert_id=alert_id or ctx.get("alert_id"), hints=hints or [])


def _retry(s: dict[str, Any], ctx: dict[str, Any], say: Speaker, key: str = "not_understood") -> TurnResult | None:
    """Ulangi pertanyaan sekali. Kembalikan None kalau jatah ulang habis (pemanggil memilih jalan aman)."""
    if ctx.get("retries", 0) >= 1:
        ctx["retries"] = 0
        return None
    ctx["retries"] = ctx.get("retries", 0) + 1
    last = ctx.get("last_question", "")
    text = say(key) if key != "not_understood" else f"{say('not_understood')} {last}".strip()
    return _reply(s["id"], s["state"], ctx, text, question=False)


def _greeting(s, ctx, patient, say, text) -> TurnResult:
    t = nlu.normalize(text)
    if ctx["trigger"] == "fall":
        if re.search(r"(baik|tidak apa|nggak papa|gapapa|ora popo|mboten napa|aman|sehat|ndak papa)", t) and not re.search(r"(tolong|sakit|tidak bisa bangun|ora iso tangi)", t):
            ctx["retries"] = 0
            return _reply(s["id"], "SYMPTOMS", ctx, f"Syukurlah. {say('ask_symptoms')}")
        if re.search(r"(tolong|sakit|tidak bisa|ora iso|jatuh|aduh)", t) or nlu.yes_no(text) is False:
            f = safety.Finding("SYNCOPE_FALL", "red", "escalate", text)
            return _start_emergency(s, ctx, patient, say, [f], text)
        retry = _retry(s, ctx, say)
        if retry:
            return retry
        f = safety.Finding("FALL_NO_RESPONSE", "red", "escalate", text or "tidak ada jawaban jelas")
        return _start_emergency(s, ctx, patient, say, [f], text)

    first_name = patient["display_name"].split()[-1].lower()
    yn = nlu.yes_no(text)
    if yn is True or first_name in t:
        ctx["retries"] = 0
        return _after_identity(s, ctx, patient, say)
    if yn is False:
        return _finish(s, ctx, say("wrong_person"), outcome="wrong_person")
    retry = _retry(s, ctx, say, "identity_retry")
    if retry:
        return retry
    return _finish(s, ctx, say("wrong_person"), outcome="wrong_person")


def _after_identity(s, ctx, patient, say) -> TurnResult:
    parts: list[str] = []
    hints: list[str] = []
    msgs = db.query(
        """SELECT m.*, c.name AS sender FROM family_messages m JOIN contacts c ON c.id = m.from_contact_id
           WHERE m.patient_id = ? AND m.status = 'pending' ORDER BY m.created_at""",
        (patient["id"],),
    )
    segments: list[dict[str, Any]] = []
    played: list[str] = []
    for m in msgs[:2]:
        if m["kind"] == "audio":
            # F-03: suara asli anak diputar apa adanya, diapit kalimat pengantar & penutup KRING.
            audio = db.one("SELECT duration_s FROM message_audio WHERE message_id = ?", (m["id"],))
            intro, outro = say("family_message_audio", pengirim=m["sender"]), say("family_message_audio_end", pengirim=m["sender"])
            parts += [intro, outro]
            segments += [{"say": intro}, {"play": m["id"], "sender": m["sender"], "duration_s": audio["duration_s"] if audio else 0}, {"say": outro}]
            played.append(f"🔊 Pesan suara {m['sender']} diputar ({audio['duration_s'] if audio else 0} detik)")
            if "family_voice" not in hints:
                hints.append("family_voice")
        else:
            line = say("family_message_text", pengirim=m["sender"], pesan=m["text"])
            parts.append(line)
            segments.append({"say": line})
    if msgs:
        ctx["delivered_messages"] = [m["id"] for m in msgs[:2]]
        hints.append("family_message")
    ask = say("ask_medication")
    parts.append(ask)
    result = _reply(s["id"], "MEDICATION", ctx, " ".join(parts), hints)
    for line in played:
        _turn(s["id"], "family", "MEDICATION", line)
    if "family_voice" in hints:
        result.segments = segments + [{"say": ask}]
    return result


def _next_after_med(s, ctx, patient, say, prefix: str) -> TurnResult:
    if patient["has_bp_monitor"]:
        return _reply(s["id"], "BLOOD_PRESSURE", ctx, f"{prefix} {say('ask_bp')}".strip())
    _observe(patient["id"], s["id"], "blood_pressure_skipped", {"reason": "no_monitor"}, "", source="system")
    return _reply(s["id"], "SYMPTOMS", ctx, f"{prefix} {say('ask_symptoms')}".strip())


def _medication(s, ctx, patient, say, text) -> TurnResult:
    status = nlu.adherence(text)
    if status is None and nlu.yes_no(text) is True:
        status = "sudah"
    if status is None:
        retry = _retry(s, ctx, say)
        if retry:
            return retry
        status = "tidak_tahu"
    ctx["retries"] = 0
    if status == "belum":
        reason = nlu.med_reason(text)
        if reason != "other":
            return _apply_med_reason(s, ctx, patient, say, text, reason)
        ctx["med"] = {"status": "belum"}
        return _reply(s["id"], "MED_REASON", ctx, say("ask_med_reason"))
    ctx["med"] = {"status": status}
    _observe(patient["id"], s["id"], "adherence", {"status": status}, text)
    _take_dose(patient["id"], status)
    return _next_after_med(s, ctx, patient, say, say("med_ack_yes") if status == "sudah" else "")


def _take_dose(pid: str, status: str) -> None:
    """Obat pagi yang diminum mengurangi stok (fitur Jadwal & stok obat)."""
    if status != "sudah":
        return
    for m in db.query("SELECT id, times FROM med_stock WHERE patient_id = ?", (pid,)):
        if any(t < "12:00" for t in db.loads(m["times"], [])):
            db.execute("UPDATE med_stock SET pills_left = MAX(0, pills_left - per_dose) WHERE id = ?", (m["id"],))


def _med_reason(s, ctx, patient, say, text) -> TurnResult:
    return _apply_med_reason(s, ctx, patient, say, text, nlu.med_reason(text))


def _apply_med_reason(s, ctx, patient, say, text, reason: str) -> TurnResult:
    ctx["med"] = {"status": "belum", "reason": reason}
    _observe(patient["id"], s["id"], "adherence", {"status": "belum", "reason": reason}, text)
    key = {"out_of_stock": "med_reason_out", "forgot": "med_reason_forgot", "feel_healthy": "med_reason_feel_healthy",
           "side_effect": "med_reason_side_effect"}.get(reason, "med_reason_other")
    if reason == "out_of_stock":
        _record_findings(ctx, [safety.Finding("MED_OUT", "yellow", "follow_up", text)])
        db.execute("UPDATE med_stock SET pills_left = 0 WHERE patient_id = ?", (patient["id"],))
    elif reason == "side_effect":
        _record_findings(ctx, [safety.Finding("MED_SIDE_EFFECT", "yellow", "follow_up", text)])
    missed = _missed_days(patient["id"])
    if missed >= 3:
        _record_findings(ctx, [safety.Finding("MED_MISSED", "yellow", "follow_up", f"{missed} hari tidak minum obat dalam 7 hari")])
    return _next_after_med(s, ctx, patient, say, say(key))


def _missed_days(pid: str) -> int:
    since = (config.now() - timedelta(days=7)).isoformat()
    rows = db.query("SELECT value FROM observations WHERE patient_id = ? AND kind = 'adherence' AND observed_at >= ?", (pid, since))
    return sum(1 for r in rows if db.loads(r["value"], {}).get("status") == "belum")


def _blood_pressure(s, ctx, patient, say, text) -> TurnResult:
    bp = nlu.parse_bp(text)
    if bp:
        ctx["bp_pending"] = {"systolic": bp.systolic, "diastolic": bp.diastolic, "verbatim": text}
        ctx["retries"] = 0
        return _reply(s["id"], "BP_CONFIRM", ctx,
                      say("confirm_bp", sistolik_kata=nlu.terbilang(bp.systolic).capitalize(), diastolik_kata=nlu.terbilang(bp.diastolic)))
    if nlu.not_measured(text):
        _observe(patient["id"], s["id"], "blood_pressure_skipped", {"reason": "not_measured"}, text)
        return _reply(s["id"], "SYMPTOMS", ctx, f"{say('bp_skip')} {say('ask_symptoms')}")
    retry = _retry(s, ctx, say, "bp_retry")
    if retry:
        return retry
    _observe(patient["id"], s["id"], "blood_pressure_skipped", {"reason": "not_understood"}, text)
    return _reply(s["id"], "SYMPTOMS", ctx, f"{say('bp_skip')} {say('ask_symptoms')}")


def _bp_confirm(s, ctx, patient, say, text) -> TurnResult:
    corrected = nlu.parse_bp(text)
    pending = ctx.get("bp_pending")
    if corrected and pending and (corrected.systolic, corrected.diastolic) != (pending["systolic"], pending["diastolic"]):
        return _blood_pressure(s, ctx, patient, say, text)
    yn = nlu.yes_no(text)
    if yn is True and pending:
        sys_, dia = pending["systolic"], pending["diastolic"]
        ctx["bp"] = {"systolic": sys_, "diastolic": dia}
        _observe(patient["id"], s["id"], "blood_pressure", {"systolic": sys_, "diastolic": dia, "confirmed": True}, pending["verbatim"])
        ack = say("bp_ack")
        if safety.is_high(sys_, dia):
            ack = f"{ack} {say('bp_high_note')}"
        f = safety.assess_bp(sys_, dia, set(ctx["symptom_codes"]), pending["verbatim"])
        if f and f.level == "red":
            return _start_emergency(s, ctx, patient, say, [f], text)
        if f:
            _record_findings(ctx, [f])
        ctx.pop("bp_pending", None)
        return _reply(s["id"], "SYMPTOMS", ctx, f"{ack} {say('ask_symptoms')}")
    # Angka tidak terkonfirmasi tidak pernah dipakai untuk keputusan.
    ctx.pop("bp_pending", None)
    return _reply(s["id"], "BLOOD_PRESSURE", ctx, say("bp_retry"))


def _symptoms(s, ctx, patient, say, text) -> TurnResult:
    codes = set(ctx["symptom_codes"])
    # Jalur 2 (LLM), bila dikonfigurasi: OR-gate dengan jalur aturan.
    turns = db.query("SELECT speaker, text FROM call_turns WHERE session_id = ? ORDER BY id", (s["id"],))
    llm_findings = safety.from_llm(llm.classify(turns, [ctx.get("bp") or {}, ctx.get("med") or {}]))
    llm_red = [f for f in llm_findings if f.level == "red"]
    if llm_red:
        return _start_emergency(s, ctx, patient, say, llm_red, text)
    _record_findings(ctx, llm_findings)

    bp = ctx.get("bp")
    if bp:
        f = safety.assess_bp(bp["systolic"], bp["diastolic"], codes, text)
        if f and f.level == "red":
            return _start_emergency(s, ctx, patient, say, [f], text)
        if f:
            _record_findings(ctx, [f])
    mild = [c for c in codes if c in {"MILD_SYMPTOM", "CONFUSION"}]
    if mild:
        _observe(patient["id"], s["id"], "symptom", {"codes": mild, "label": "keluhan ringan"}, text)
        ack = say("symptom_ack_mild")
    else:
        _observe(patient["id"], s["id"], "symptom", {"codes": [], "label": "tidak ada keluhan"}, text)
        ack = say("symptom_ack_none")
    memory = db.one("SELECT * FROM memories WHERE patient_id = ? ORDER BY created_at DESC LIMIT 1", (patient["id"],))
    if memory:
        db.execute("UPDATE memories SET last_used_at = ? WHERE id = ?", (config.now().isoformat(), memory["id"]))
        ask = say("memory_opener", fakta=memory["fact"][0].lower() + memory["fact"][1:])
    else:
        ask = say("ask_story")
    return _reply(s["id"], "STORY", ctx, f"{ack} {ask}")


def _story(s, ctx, patient, say, text) -> TurnResult:
    ctx["story"] = text
    ctx["mood"] = nlu.mood(text)
    if nlu.mentions_missing_family(text):
        ctx["kangen"] = True
    # Tanggapan ikut suasana hati: jangan bilang "senang mendengarnya" kepada Mbah yang sedang kangen.
    ack = "story_ack_lonely" if ctx["mood"]["lonely"] else "story_ack_sad" if ctx["mood"]["mood"] == "sedih" else "story_ack"
    reminders = " ".join(say(k, **v) for k, v in care.reminders(patient["id"]))
    key = "closing_yellow" if ctx["level"] == "yellow" else "closing"
    closing = say(key, edukasi=content.education(ctx.get("edu_index", 0)))
    return _finish(s, ctx, " ".join(x for x in (say(ack), reminders, closing) if x), outcome="completed")


# ---------- darurat ----------

def _start_emergency(s, ctx, patient, say, findings: list[safety.Finding], text: str) -> TurnResult:
    _record_findings(ctx, findings)
    ctx["level"] = "red"
    reasons = [f.as_reason() for f in findings]
    if not ctx.get("alert_id"):
        # Skrining tidak menunda eskalasi: pre-alert IGD & panggilan ke Sahabat Kring/anak dimulai sekarang.
        ctx["alert_id"] = escalation.open_alert(patient["id"], s["id"], "red", "call", reasons)
    hints = ["escalation_started"]
    if any(f.action == "stroke_screen" for f in findings):
        ctx["step"] = "speech"
        ctx["retries"] = 0
        return _reply(s["id"], "STROKE_SCREEN", ctx, f"{say('stroke_calm')} {say('stroke_speech')}", hints)
    _observe(patient["id"], s["id"], "escalation", {"codes": [f.code for f in findings]}, text, source="rule")
    return _finish(s, ctx, say("urgent_transfer"), outcome="escalated", hints=hints + ["conference"])


def _stroke_screen(s, ctx, patient, say, text) -> TurnResult:
    step = ctx.get("step") or "speech"
    alert_id = ctx.get("alert_id")
    if step == "speech":
        score = nlu.sentence_similarity(text, SCREEN_SENTENCE)
        slurred = bool(safety.scan_text(text).red) or score < 0.6
        result = {"speech_repeat": {"said": text, "match": round(score, 2), "abnormal": slurred}}
        ctx.setdefault("screen", {}).update(result)
        _observe(patient["id"], s["id"], "stroke_screen", result, text)
        if alert_id:
            escalation.update_alert(alert_id, screening=result)
        ctx["step"] = "arms"
        return _reply(s["id"], "STROKE_SCREEN", ctx, say("stroke_arms"))
    if step == "arms":
        t = nlu.normalize(text)
        weak = bool(re.search(r"(turun|lemas|lemes|lemah|tidak bisa|ora iso|mboten saged|berat|abot|jatuh|ngglewer|kiri|kanan|kiwa|tengen)", t))
        if re.search(r"^(tidak|nggak|mboten|ora|ndak)( ada)?\b", t) and not re.search(r"(tidak bisa|ora iso|mboten saged)", t):
            weak = False
        result = {"arm_drift": {"said": text, "abnormal": weak}}
        ctx["screen"].update(result)
        _observe(patient["id"], s["id"], "stroke_screen", result, text)
        if alert_id:
            escalation.update_alert(alert_id, screening=result)
        ctx["step"] = "lkw"
        return _reply(s["id"], "STROKE_SCREEN", ctx, say("stroke_lkw"))
    # step == "lkw"
    parsed = nlu.parse_time_of_day(text)
    if not parsed:
        retry = _retry(s, ctx, say, "stroke_lkw_retry")
        if retry:
            return retry
    note = parsed.note if parsed else "tidak diketahui"
    _observe(patient["id"], s["id"], "last_known_well",
             {"time": parsed.when.isoformat() if parsed else None, "approx": parsed.approx if parsed else None}, text)
    meds = patient["medications"]
    anticoag = "ya" if any(m.get("is_anticoagulant") for m in meds) else "tidak (menurut profil)"
    if alert_id:
        escalation.update_alert(alert_id, lkw=parsed.when if parsed else None, lkw_note=note,
                                screening={"anticoagulant": anticoag, "medications": [m["name"] for m in meds]})
    return _finish(s, ctx, say("stroke_transfer"), outcome="escalated", hints=["conference"])


# ---------- penutupan panggilan ----------

def _finish(s, ctx, text: str, *, outcome: str, hints: list[str] | None = None) -> TurnResult:
    sid, pid = s["id"], s["patient_id"]
    patient = _patient(pid)
    state = "ESCALATING" if outcome == "escalated" else "CLOSING"
    if text:
        _turn(sid, "tilik", state, text)
    level = ctx["level"]
    summary = _summary(ctx, outcome)
    points = _talking_points(ctx, patient) if outcome == "completed" else []
    _save(sid, state, ctx, status="completed", outcome=outcome, ended_at=config.now().isoformat(), final_level=level,
          summary=summary, family_talking_points=db.dumps(points))

    for mid in ctx.get("delivered_messages", []):
        db.execute("UPDATE family_messages SET status = 'delivered', delivered_session_id = ? WHERE id = ?", (sid, mid))

    alert_id = ctx.get("alert_id")
    if outcome == "completed":
        if ctx.get("mood"):
            _observe(pid, sid, "mood", ctx["mood"], ctx.get("story", ""), source="nlu")
        if level == "yellow":
            alert_id = escalation.open_alert(pid, sid, "yellow", "call", [r for r in ctx["findings"] if r["level"] == "yellow"])
        _daily_report(patient, sid, ctx, summary, points)
    return TurnResult(sid, text, state, level, ended=True, outcome=outcome, alert_id=alert_id, hints=hints or [])


def _summary(ctx: dict[str, Any], outcome: str) -> str:
    med = ctx.get("med") or {}
    reason_label = {"out_of_stock": "obat habis", "forgot": "lupa", "feel_healthy": "merasa sehat", "side_effect": "efek samping",
                    "other": "alasan lain"}
    parts = []
    if med:
        parts.append("Obat: " + ("sudah diminum" if med.get("status") == "sudah" else
                                 f"belum ({reason_label.get(med.get('reason', ''), 'tanpa alasan')})" if med.get("status") == "belum" else "tidak tahu"))
    if ctx.get("bp"):
        parts.append(f"Tensi {ctx['bp']['systolic']}/{ctx['bp']['diastolic']} (terkonfirmasi)")
    flags = [r["label"] for r in ctx["findings"]]
    parts.append("Tanda: " + ", ".join(flags) if flags else "Tidak ada keluhan berarti")
    if outcome == "escalated":
        parts.append("Dieskalasi ke Sahabat Kring, keluarga, dan IGD")
    elif outcome == "wrong_person":
        parts = ["Yang mengangkat bukan pasien, tidak ada data medis dibahas"]
    return ". ".join(parts) + "."


def _talking_points(ctx: dict[str, Any], patient: dict[str, Any]) -> list[str]:
    story = (ctx.get("story") or "").strip()
    if not story or nlu.no_complaint(story) and len(story.split()) < 4:
        return []
    facts = llm.extract_facts(story)
    if facts is None:
        facts = [story[0].upper() + story[1:140].rstrip(".") if story else ""]
    facts = [f for f in facts if f]
    for f in facts:
        db.execute("INSERT INTO memories (id, patient_id, fact, category, source_session_id, created_at) VALUES (?,?,?,?,?,?)",
                   (db.new_id(), patient["id"], f, "story", None, config.now().isoformat()))
    return facts


def _daily_report(patient: dict[str, Any], sid: str, ctx: dict[str, Any], summary: str, points: list[str]) -> None:
    scope = patient["share_scope"]
    for c in escalation.contacts_for(patient["id"]):
        if not c["receives_daily_report"]:
            continue
        lines = []
        med = ctx.get("med") or {}
        if scope.get("medication", True) and med:
            lines.append("💊 Obat: " + ("sudah diminum" if med.get("status") == "sudah" else "belum diminum"))
        if scope.get("bp", True) and ctx.get("bp"):
            lines.append(f"🩺 Tensi: {ctx['bp']['systolic']}/{ctx['bp']['diastolic']}")
        if ctx["level"] == "yellow":
            lines.append("🟡 Perlu tindak lanjut Puskesmas: " + ", ".join(r["label"] for r in ctx["findings"] if r["level"] == "yellow"))
        else:
            lines.append("🟢 Tidak ada tanda bahaya")
        shared_points = points if scope.get("stories", True) else []
        if shared_points:
            lines.append("💬 Bahan obrolan: " + "; ".join(shared_points))
        sched = care.care(patient["id"])["schedule"]
        soon = next((a for a in sched["upcoming"] if a["days_until"] <= 1), None)
        if soon:
            lines.append(f"📅 {'Hari ini' if soon['days_until'] == 0 else 'Besok'} {soon['title']} pukul {soon['time'].replace(':', '.')} di {soon['place']}")
        if sched["pickup"] and sched["pickup"]["status"] in ("now", "before_visit") and sched["pickup"]["days_left"] <= 7:
            lines.append("💊 " + sched["pickup"]["message"])
        escalation.notify(c, patient["id"], "daily_report", "whatsapp_sim", f"Rapor pagi {patient['display_name']}", "\n".join(lines),
                          payload={"level": ctx["level"], "talking_points": shared_points, "bp": ctx.get("bp") if scope.get("bp", True) else None,
                                   "medication": med.get("status") if scope.get("medication", True) else None},
                          session_id=sid)
        _nudge(c, patient, sid, ctx)


def _nudge(c: dict[str, Any], patient: dict[str, Any], sid: str, ctx: dict[str, Any]) -> None:
    """Nudge Kangen, diperkuat ringkasan suasana hati: kangen hari ini, atau kesepian berulang minggu ini (maks. 1×/hari)."""
    m = care.mood(patient["id"])
    name = patient["display_name"]
    if not ctx.get("kangen") and m["level"] != "nudge":
        return
    start = config.now().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    if db.one("SELECT id FROM notifications WHERE contact_id = ? AND kind = 'nudge' AND created_at >= ?", (c["id"], start)):
        return
    first = f"{name} tadi bilang kangen." if ctx.get("kangen") else f"{name} beberapa hari ini terdengar kesepian."
    detail = []
    if m["lonely_days_7"] >= 2:
        detail.append(f"Seminggu ini {m['lonely_days_7']}× menyebut kangen/sepi")
    if m["days_since_family_call"] is not None and m["days_since_family_call"] >= 2:
        detail.append(f"telepon keluarga terakhir {m['days_since_family_call']} hari lalu")
    body = first + (" " + ", ".join(detail) + "." if detail else "") + " Telepon 5 menit hari ini?"
    escalation.notify(c, patient["id"], "nudge", "whatsapp_sim", "💛 Nudge Kangen", body,
                      payload={"mood": {k: m[k] for k in ("level", "lonely_days_7", "days_since_family_call", "summary")}}, session_id=sid)
