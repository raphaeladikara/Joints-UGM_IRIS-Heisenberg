"""F-19 Protokol "tidak diangkat": telepon ulang 15 menit kemudian → masih tidak diangkat → Sahabat Kring diminta
mengecek ke rumah, keluarga diberi tahu di setiap langkah. Hasil cek rumah menutup, menahan, atau menaikkan alert.

Port ke backend offline Flutter: `apps/mobile/lib/core/local/protocol.dart` (bentuk JSON harus sama).
"""

from __future__ import annotations

from datetime import datetime, timedelta
from typing import Any

from . import config, content, db, escalation


def _hm(iso: str) -> str:
    return datetime.fromisoformat(iso).strftime("%H.%M")


def _people(pid: str) -> tuple[dict[str, Any], dict[str, Any] | None, dict[str, Any] | None]:
    patient = db.one("SELECT * FROM patients WHERE id = ?", (pid,))
    assert patient is not None
    contacts = escalation.contacts_for(pid)
    sahabat = next((c for c in contacts if c["role"] == "sahabat_tilik"), None)
    child = next((c for c in contacts if c["role"] == "child"), None)
    return patient, sahabat, child


def on_no_answer(s: dict[str, Any], ctx: dict[str, Any]) -> tuple[str | None, list[str]]:
    """Dipanggil dialog.no_answer untuk panggilan harian/ulang. Hasil: (alert_id kuning bila ada, hints)."""
    pid, sid = s["patient_id"], s["id"]
    now = config.now()
    patient, sahabat, child = _people(pid)
    name = patient["display_name"]
    if ctx.get("trigger") == "retry":
        retry = db.one("SELECT * FROM call_retries WHERE session_id = ?", (sid,))
        origin = db.one("SELECT started_at FROM call_sessions WHERE id = ?", (retry["origin_session_id"],)) if retry else None
        missed = [origin["started_at"] if origin else s["started_at"], s["started_at"]]
        if retry:
            db.execute("UPDATE call_retries SET status = 'missed' WHERE id = ?", (retry["id"],))
        reasons = [{"path": "rule", "code": "NO_ANSWER_RETRY", "label": content.label("NO_ANSWER_RETRY"),
                    "quote": f"tidak diangkat pukul {_hm(missed[0])} dan {_hm(missed[1])}"}]
        alert_id = escalation.open_alert(pid, sid, "yellow", "scheduler", reasons)
        if sahabat:
            request_home_check(patient, sahabat, child, alert_id, missed, sid)
        return alert_id, ["home_check_requested"]

    due = now + timedelta(minutes=config.RETRY_MINUTES)
    db.execute("UPDATE call_retries SET status = 'cancelled' WHERE patient_id = ? AND status = 'pending'", (pid,))
    db.execute("INSERT INTO call_retries (id, patient_id, origin_session_id, due_at, status, created_at) VALUES (?,?,?,?, 'pending', ?)",
               (db.new_id(), pid, sid, due.isoformat(), now.isoformat()))
    if child:
        escalation.notify(child, pid, "retry_scheduled", "whatsapp_sim", f"📞 {name} belum mengangkat",
                          f"Telepon pagi KRING pukul {_hm(s['started_at'])} belum diangkat. KRING menelepon ulang pukul {due.strftime('%H.%M')}. "
                          f"Kalau tetap tidak diangkat, {sahabat['name'] if sahabat else 'tetangga'} diminta menengok ke rumah.",
                          payload={"due_at": due.isoformat()}, session_id=sid)
    return None, ["retry_scheduled"]


def request_home_check(patient: dict[str, Any], sahabat: dict[str, Any], child: dict[str, Any] | None, alert_id: str | None,
                       missed: list[str], sid: str | None) -> str:
    pid, name = patient["id"], patient["display_name"]
    hid = db.new_id()
    db.execute("INSERT INTO home_checks (id, patient_id, contact_id, alert_id, status, missed_at, created_at) VALUES (?,?,?,?, 'requested', ?, ?)",
               (hid, pid, sahabat["id"], alert_id, db.dumps(missed), config.now().isoformat()))
    brief = content.briefing("home_check", sahabat=sahabat["name"], puskesmas=config.PUSKESMAS_NAME, sapaan=name,
                             jam1=_hm(missed[0]), jam2=_hm(missed[-1]))
    escalation.notify(sahabat, pid, "home_check", "whatsapp_sim", f"🏠 Mohon tengok {name}", brief,
                      payload={"home_check_id": hid}, alert_id=alert_id, session_id=sid)
    if child:
        escalation.notify(child, pid, "home_check_sent", "whatsapp_sim", f"🏠 {sahabat['name']} diminta mengecek {name}",
                          f"KRING sudah menelepon pukul {_hm(missed[0])} dan {_hm(missed[-1])}, belum diangkat. {sahabat['name']} "
                          f"({sahabat['relation']}) diminta menengok ke rumah dan akan mengabari di sini.",
                          payload={"home_check_id": hid}, alert_id=alert_id, session_id=sid)
    return hid


def run_due(pid: str | None = None) -> None:
    """Jalankan telepon ulang yang sudah jatuh tempo (dipanggil saat HP Mbah/Puskesmas/keluarga memuat data)."""
    from . import dialog  # hindari impor melingkar

    now = config.now().isoformat()
    sql, params = "SELECT * FROM call_retries WHERE status = 'pending' AND due_at <= ?", [now]
    if pid:
        sql += " AND patient_id = ?"
        params.append(pid)
    for r in db.query(sql, params):
        origin = db.one("SELECT started_at FROM call_sessions WHERE id = ?", (r["origin_session_id"],))
        answered = db.one("SELECT id FROM call_sessions WHERE patient_id = ? AND started_at > ? AND status = 'completed' LIMIT 1",
                          (r["patient_id"], origin["started_at"] if origin else r["created_at"]))
        if answered:
            db.execute("UPDATE call_retries SET status = 'cancelled' WHERE id = ?", (r["id"],))
            continue
        if db.one("SELECT id FROM call_sessions WHERE patient_id = ? AND status IN ('ringing', 'in_progress')", (r["patient_id"],)):
            continue
        s = dialog.create_session(r["patient_id"], trigger="retry")
        db.execute("UPDATE call_retries SET status = 'calling', session_id = ? WHERE id = ?", (s["id"], r["id"]))


def fire_now(rid: str) -> dict[str, Any] | None:
    r = db.one("SELECT * FROM call_retries WHERE id = ?", (rid,))
    if not r:
        return None
    if r["status"] == "pending":
        db.execute("UPDATE call_retries SET due_at = ? WHERE id = ?", (config.now().isoformat(), rid))
        run_due(r["patient_id"])
    return state(r["patient_id"])


def respond(hid: str, result: str, note: str) -> dict[str, Any] | None:
    """Sahabat Kring melapor hasil cek rumah: ok (baik), not_home (tidak ada di rumah), help (butuh bantuan)."""
    hc = db.one("SELECT * FROM home_checks WHERE id = ?", (hid,))
    if not hc:
        return None
    pid = hc["patient_id"]
    now = config.now().isoformat()
    patient, sahabat, child = _people(pid)
    name, who = patient["display_name"], (sahabat or {}).get("name", "Sahabat Kring")
    db.execute("UPDATE home_checks SET status = ?, note = ?, responded_at = ? WHERE id = ?", (result, note, now, hid))
    extra = f" Catatan: \"{note}\"" if note else ""
    if result == "ok":
        if hc["alert_id"]:
            db.execute("UPDATE alerts SET status = 'closed', updated_at = ? WHERE id = ?", (now, hc["alert_id"]))
        if child:
            escalation.notify(child, pid, "home_check_result", "whatsapp_sim", f"✅ {name} baik-baik saja",
                              f"{who} sudah menengok: {name} dalam keadaan baik.{extra}", payload={"home_check_id": hid, "result": result})
    elif result == "not_home":
        if hc["alert_id"]:
            escalation.update_alert(hc["alert_id"], reasons=[{"path": "rule", "code": "HOME_CHECK_NOT_HOME",
                                                             "label": content.label("HOME_CHECK_NOT_HOME"), "quote": note or who}])
        if child:
            escalation.notify(child, pid, "home_check_result", "whatsapp_sim", f"⚠️ {name} tidak ada di rumah",
                              f"{who} sudah ke rumah, tetapi {name} tidak ada. Mohon coba hubungi kerabat atau tetangga lain. "
                              f"Petugas Puskesmas ikut memantau.{extra}", payload={"home_check_id": hid, "result": result})
    else:
        escalation.open_alert(pid, None, "red", "home_check",
                              [{"path": "rule", "code": "HOME_CHECK_HELP", "label": content.label("HOME_CHECK_HELP"), "quote": note or who}])
    return state(pid)


def state(pid: str) -> dict[str, Any] | None:
    """Tahap protokol hari ini untuk satu pasien (null bila semua panggilan hari ini terangkat)."""
    start = config.now().replace(hour=0, minute=0, second=0, microsecond=0).isoformat()
    hc = db.one("SELECT h.*, c.name AS contact_name FROM home_checks h JOIN contacts c ON c.id = h.contact_id "
                "WHERE h.patient_id = ? AND h.created_at >= ? ORDER BY h.created_at DESC LIMIT 1", (pid, start))
    retry = db.one("SELECT * FROM call_retries WHERE patient_id = ? AND created_at >= ? ORDER BY created_at DESC LIMIT 1", (pid, start))
    if not hc and not retry:
        return None
    stage = None
    missed: list[str] = []
    if hc:
        stage = {"requested": "home_check", "ok": "checked_ok"}.get(hc["status"], hc["status"])
        missed = db.loads(hc["missed_at"], [])
    elif retry:
        origin = db.one("SELECT started_at FROM call_sessions WHERE id = ?", (retry["origin_session_id"],))
        missed = [origin["started_at"]] if origin else []
        sess = db.one("SELECT status FROM call_sessions WHERE id = ?", (retry["session_id"],)) if retry["session_id"] else None
        if retry["status"] == "pending":
            stage = "retry_scheduled"
        elif retry["status"] == "cancelled" or (sess and sess["status"] == "completed"):
            stage = "answered"
        elif retry["status"] == "missed":
            stage = "missed"
        else:
            stage = "retrying"
    return {
        "stage": stage,
        "missed_at": missed,
        "retry": {"id": retry["id"], "due_at": retry["due_at"], "status": retry["status"]} if retry else None,
        "home_check": {k: hc[k] for k in ("id", "status", "contact_id", "contact_name", "note", "created_at", "responded_at")} if hc else None,
    }
