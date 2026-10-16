"""Mesin eskalasi event-driven (D-33). Semua sumber sinyal (panggilan, jam tangan, SOS, scheduler) masuk ke sini.

Mode demo: telepon & WhatsApp ke Sahabat Tilik/anak adalah kanal SIMULASI yang tampil di aplikasi (notifications).
Sistem tidak pernah memanggil 119 atau nomor RS sungguhan.
"""

from __future__ import annotations

from datetime import datetime
from typing import Any

from . import config, content, db


def fmt_time(iso: str | None) -> str:
    if not iso:
        return "belum diketahui"
    return datetime.fromisoformat(iso).astimezone(config.WIB).strftime("%H.%M")


def nearest_ct_hospital(village: str) -> tuple[dict[str, Any] | None, int | None]:
    row = db.one(
        """SELECT h.*, t.minutes FROM travel_times t JOIN hospitals h ON h.id = t.hospital_id
           WHERE t.village = ? AND h.has_ct_24h = 1 ORDER BY t.minutes LIMIT 1""",
        (village,),
    )
    if not row:
        return None, None
    return row, row.pop("minutes")


def contacts_for(patient_id: str) -> list[dict[str, Any]]:
    return db.query("SELECT * FROM contacts WHERE patient_id = ? ORDER BY escalation_order", (patient_id,))


def _notify(conn, contact: dict[str, Any], patient_id: str, kind: str, channel: str, title: str, body: str,
            payload: dict[str, Any] | None = None, alert_id: str | None = None, session_id: str | None = None,
            status: str = "sent") -> str:
    nid = db.new_id()
    conn.execute(
        """INSERT INTO notifications (id, contact_id, patient_id, alert_id, session_id, kind, channel, title, body, payload, status, created_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
        (nid, contact["id"], patient_id, alert_id, session_id, kind, channel, title, body, db.dumps(payload or {}), status,
         config.now().isoformat()),
    )
    return nid


def notify(contact: dict[str, Any], patient_id: str, kind: str, channel: str, title: str, body: str, **kw: Any) -> str:
    with db.tx() as conn:
        return _notify(conn, contact, patient_id, kind, channel, title, body, **kw)


def open_alert(patient_id: str, session_id: str | None, level: str, source: str, reasons: list[dict[str, Any]]) -> str:
    """Buat alert. Untuk 🔴: pre-alert Board IGD + telepon Sahabat Tilik lalu anak + WA keduanya (semua simulasi)."""
    patient = db.one("SELECT * FROM patients WHERE id = ?", (patient_id,))
    assert patient is not None
    now = config.now()
    hospital, eta = nearest_ct_hospital(patient["village"]) if level == "red" else (None, None)
    alert_id = db.new_id()
    contacts = contacts_for(patient_id)
    sahabat = next((c for c in contacts if c["role"] == "sahabat_tilik"), None)
    child = next((c for c in contacts if c["role"] == "child"), None)
    summary = ", ".join(r["label"] for r in reasons) or "tanda bahaya"
    with db.tx() as conn:
        conn.execute(
            """INSERT INTO alerts (id, patient_id, session_id, level, source, reasons, target_hospital_id, eta_minutes, status, created_at, updated_at)
               VALUES (?,?,?,?,?,?,?,?, 'open', ?, ?)""",
            (alert_id, patient_id, session_id, level, source, db.dumps(reasons), hospital["id"] if hospital else None, eta,
             now.isoformat(), now.isoformat()),
        )
        if level != "red":
            if child:
                _notify(conn, child, patient_id, "yellow_notice", "whatsapp_sim",
                        f"🟡 {patient['display_name']} perlu tindak lanjut",
                        f"TILIK mencatat: {summary}. Petugas Puskesmas akan menghubungi hari ini. Tidak darurat.",
                        {"reasons": reasons}, alert_id=alert_id, session_id=session_id)
            return alert_id

        rs = f"{hospital['name']} (±{eta} menit)" if hospital else "RS ber-CT terdekat"
        wa_body = (f"🔴 DARURAT: {patient['display_name']} menunjukkan tanda bahaya ({summary}). "
                   f"Terakhir normal: menunggu jawaban. RS ber-CT terdekat: {rs}. "
                   f"Hubungi 119 / ambulans desa. (Mode demo: TILIK tidak menelepon 119.)")
        payload = {"reasons": reasons, "hospital": hospital, "eta_minutes": eta}
        # Urutan: Sahabat Tilik (paling dekat) lalu anak, sesuai escalation_order.
        for c in [sahabat, child]:
            if not c:
                continue
            key = "sahabat_tilik" if c["role"] == "sahabat_tilik" else "child"
            brief = content.briefing(key, sahabat=sahabat["name"] if sahabat else "tetangga", anak=child["name"] if child else "keluarga",
                                     sapaan=patient["display_name"], puskesmas=config.PUSKESMAS_NAME, lkw="belum diketahui (skrining berjalan)",
                                     ringkas=summary, rs=hospital["name"] if hospital else "RS terdekat", eta=eta or "?")
            _notify(conn, c, patient_id, "red_call", "call_sim", f"📞 TILIK menelepon: darurat {patient['display_name']}",
                    brief, {**payload, "conference": f"tilik-{alert_id[:8]}"}, alert_id=alert_id, session_id=session_id, status="ringing")
            _notify(conn, c, patient_id, "red_alert", "whatsapp_sim", f"🔴 Darurat {patient['display_name']}", wa_body, payload,
                    alert_id=alert_id, session_id=session_id)
    return alert_id


def update_alert(alert_id: str, *, lkw: datetime | None = None, lkw_note: str | None = None,
                 screening: dict[str, Any] | None = None, reasons: list[dict[str, Any]] | None = None) -> None:
    alert = db.one("SELECT * FROM alerts WHERE id = ?", (alert_id,))
    if not alert:
        return
    now = config.now().isoformat()
    with db.tx() as conn:
        if screening is not None:
            merged = {**db.loads(alert["screening"], {}), **screening}
            conn.execute("UPDATE alerts SET screening = ?, updated_at = ? WHERE id = ?", (db.dumps(merged), now, alert_id))
        if reasons:
            existing = db.loads(alert["reasons"], [])
            codes = {r["code"] for r in existing}
            merged_r = existing + [r for r in reasons if r["code"] not in codes]
            conn.execute("UPDATE alerts SET reasons = ?, updated_at = ? WHERE id = ?", (db.dumps(merged_r), now, alert_id))
        if lkw_note is not None:
            deadline = (lkw + config.GOLDEN_PERIOD).isoformat() if lkw else None
            conn.execute(
                "UPDATE alerts SET last_known_well = ?, lkw_note = ?, golden_period_deadline = ?, updated_at = ? WHERE id = ?",
                (lkw.isoformat() if lkw else None, lkw_note, deadline, now, alert_id),
            )
            patient = db.one("SELECT * FROM patients WHERE id = ?", (alert["patient_id"],))
            assert patient is not None
            if lkw:
                remaining = int((lkw + config.GOLDEN_PERIOD - config.now()).total_seconds() // 60)
                body = (f"Update: {patient['display_name']} terakhir normal jam {fmt_time(lkw.isoformat())}. "
                        f"Sisa golden period ±{max(remaining, 0) // 60} jam {max(remaining, 0) % 60} menit. Pre-alert sudah dikirim ke IGD.")
            else:
                body = f"Update: jam terakhir normal {patient['display_name']} tidak diketahui. Pre-alert sudah dikirim ke IGD."
            for c in contacts_for(alert["patient_id"]):
                if c["role"] in {"child", "sahabat_tilik"}:
                    _notify(conn, c, alert["patient_id"], "red_update", "whatsapp_sim", f"⏱️ Jam onset {patient['display_name']}", body,
                            {"last_known_well": lkw.isoformat() if lkw else None}, alert_id=alert_id, session_id=alert["session_id"])


def handle_event(patient_id: str, source: str, type_: str, payload: dict[str, Any]) -> dict[str, Any]:
    """Pintu masuk sinyal eksternal (POST /v1/events). Mengembalikan aksi yang diambil."""
    now = config.now().isoformat()
    event_id = db.new_id()
    db.execute("INSERT INTO events (id, patient_id, source, type, payload, occurred_at) VALUES (?,?,?,?,?,?)",
               (event_id, patient_id, source, type_, db.dumps(payload), now))
    result: dict[str, Any] = {"event_id": event_id, "action": "logged", "level": "green"}

    if type_ == "sos_pressed":
        reasons = [{"path": "event", "code": "SOS_PRESSED", "label": content.label("SOS_PRESSED"), "quote": source}]
        result.update(action="escalated", level="red", alert_id=open_alert(patient_id, None, "red", f"event:{source}", reasons))
    elif type_ == "irregular_rhythm":
        reasons = [{"path": "event", "code": "IRREGULAR_RHYTHM", "label": content.label("IRREGULAR_RHYTHM"), "quote": source}]
        result.update(action="follow_up", level="yellow", alert_id=open_alert(patient_id, None, "yellow", f"event:{source}", reasons))
    elif type_ == "missed_checkin":
        reasons = [{"path": "event", "code": "NO_ANSWER_2X", "label": content.label("NO_ANSWER_2X"), "quote": source}]
        result.update(action="follow_up", level="yellow", alert_id=open_alert(patient_id, None, "yellow", f"event:{source}", reasons))
    # fall_detected ditangani di main.py: TILIK langsung menelepon pasien dulu (F-18).
    db.execute("UPDATE events SET handled_level = ? WHERE id = ?", (result["level"], event_id))
    return result
