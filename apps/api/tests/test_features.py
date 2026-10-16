"""Fitur tambahan: pesan suara anak (F-03), protokol tidak diangkat (F-19), jadwal Prolanis/posyandu + ambil obat,
ringkasan suasana hati & Nudge Kangen. Bentuk JSON sama dengan backend offline Flutter."""

import base64

AUDIO = base64.b64encode(b"\x00\x00\x00\x18ftypM4A fake-audio-bytes").decode()


def _start(client, pid):
    return client.post("/v1/calls", json={"patient_id": pid}).json()["session_id"]


def _feed(client, cid):
    return client.get(f"/v1/contacts/{cid}/feed").json()


def _say(client, sid, *lines):
    r = None
    for line in lines:
        r = client.post(f"/v1/calls/{sid}/turns", json={"text": line})
        assert r.status_code == 200, r.text
        r = r.json()
    return r


# ---------- F-03 pesan suara asli ----------

def test_voice_message_played_in_call(client):
    r = client.post("/v1/patients/p-sri/family-messages", json={"contact_id": "c-dika", "audio_b64": AUDIO, "audio_mime": "audio/mp4", "duration_s": 7})
    assert r.status_code == 200 and r.json()["kind"] == "audio"
    mid = r.json()["id"]
    audio = client.get(f"/v1/family-messages/{mid}/audio")
    assert audio.status_code == 200 and audio.headers["content-type"] == "audio/mp4" and audio.content.endswith(b"fake-audio-bytes")
    pending = _feed(client, "c-dika")["pending_messages"]
    assert pending[0]["kind"] == "audio" and pending[0]["duration_s"] == 7

    sid = _start(client, "p-sri")
    client.post(f"/v1/calls/{sid}/answer")
    t = _say(client, sid, "Iya, saya sendiri")
    assert "family_voice" in t["hints"] and "titip pesan suara" in t["tilik_text"]
    plays = [s for s in t["segments"] if "play" in s]
    assert plays == [{"play": mid, "sender": "Mas Dika", "duration_s": 7}]
    assert t["segments"][-1]["say"].startswith("Obat tensi")  # pertanyaan obat diucapkan setelah rekaman
    assert "Rani minggu depan wisuda" in t["segments"][0]["say"]  # pesan teks tetap dibacakan
    turns = client.get(f"/v1/calls/{sid}").json()["turns"]
    assert any(x["speaker"] == "family" and "Pesan suara Mas Dika" in x["text"] for x in turns)
    _say(client, sid, "Sampun", "Belum ngukur", "Tidak ada keluhan", "Biasa saja")
    assert all(m["status"] == "delivered" for m in _feed(client, "c-dika")["pending_messages"][:2])


def test_voice_message_validation(client):
    assert client.post("/v1/patients/p-sri/family-messages", json={"contact_id": "c-dika"}).status_code == 422
    assert client.post("/v1/patients/p-sri/family-messages", json={"contact_id": "c-dika", "audio_b64": "%%%"}).status_code == 422
    assert client.get("/v1/family-messages/nope/audio").status_code == 404
    t = client.post("/v1/patients/p-sri/family-messages", json={"contact_id": "c-dika", "text": "Halo Bu"}).json()
    assert t["kind"] == "text"


# ---------- F-19 tidak diangkat → ulang 15 menit → Sahabat Kring cek rumah ----------

def test_no_answer_retry_then_home_check_ok(client):
    sid = _start(client, "p-sri")
    r = client.post(f"/v1/calls/{sid}/no-answer").json()
    assert r["level"] == "green" and r["hints"] == ["retry_scheduled"]
    st = _feed(client, "c-dika")["no_answer"]
    assert st["stage"] == "retry_scheduled" and st["retry"]["status"] == "pending"
    assert any(n["kind"] == "retry_scheduled" for n in _feed(client, "c-dika")["notifications"])
    assert client.get("/v1/patients/p-sri/incoming").json()["ringing"] is False  # belum 15 menit

    st = client.post(f"/v1/retries/{st['retry']['id']}/now").json()
    assert st["stage"] == "retrying"
    inc = client.get("/v1/patients/p-sri/incoming").json()
    assert inc["ringing"] and inc["session"]["trigger"] == "retry"
    r = client.post(f"/v1/calls/{inc['session']['id']}/no-answer").json()
    assert r["level"] == "yellow" and "home_check_requested" in r["hints"]

    tini = _feed(client, "c-tini")
    hc = tini["no_answer"]["home_check"]
    assert tini["no_answer"]["stage"] == "home_check" and hc["contact_id"] == "c-tini" and len(tini["no_answer"]["missed_at"]) == 2
    assert any(n["kind"] == "home_check" for n in tini["notifications"])
    assert any(n["kind"] == "home_check_sent" for n in _feed(client, "c-dika")["notifications"])
    row = next(x for x in client.get("/v1/puskesmas/today").json()["rows"] if x["patient"]["id"] == "p-sri")
    assert row["status"] == "yellow" and row["protocol"]["stage"] == "home_check"

    st = client.post(f"/v1/home-checks/{hc['id']}", json={"result": "ok", "note": "Sedang di sawah"}).json()
    assert st["stage"] == "checked_ok" and st["home_check"]["note"] == "Sedang di sawah"
    assert client.get(f"/v1/alerts/{r['alert_id']}").json()["status"] == "closed"
    note = next(n for n in _feed(client, "c-dika")["notifications"] if n["kind"] == "home_check_result")
    assert "baik" in note["title"] and "Sedang di sawah" in note["body"]


def test_retry_answered_and_home_check_help(client):
    sid = _start(client, "p-wiryo")
    client.post(f"/v1/calls/{sid}/no-answer")
    rid = _feed(client, "c-anton")["no_answer"]["retry"]["id"]
    client.post(f"/v1/retries/{rid}/now")
    retry_sid = client.get("/v1/patients/p-wiryo/incoming").json()["session"]["id"]
    client.post(f"/v1/calls/{retry_sid}/answer")
    client.post(f"/v1/calls/{retry_sid}/hangup")
    assert _feed(client, "c-anton")["no_answer"]["stage"] == "answered"

    # Painem (seed): sudah 2× tidak diangkat, Bu Sumi diminta menengok → menemukan Mbah butuh bantuan → 🔴.
    st = _feed(client, "c-sumi")["no_answer"]
    assert st["stage"] == "home_check" and st["home_check"]["contact_id"] == "c-sumi"
    st = client.post(f"/v1/home-checks/{st['home_check']['id']}", json={"result": "help", "note": "Mbah jatuh di dapur"}).json()
    assert st["stage"] == "help"
    red = _feed(client, "c-joko")["red_alert"]
    assert red and red["reasons"][0]["code"] == "HOME_CHECK_HELP"
    assert client.post("/v1/home-checks/nope", json={"result": "ok"}).status_code == 404


# ---------- jadwal Prolanis & posyandu + ambil obat tersambung stok ----------

def test_schedule_and_pickup_linked_to_stock(client):
    sri = client.get("/v1/patients/p-sri/care").json()["schedule"]
    assert [(a["kind"], a["days_until"]) for a in sri["upcoming"]] == [("posyandu", 1), ("prolanis", 3)]
    assert sri["pickup"]["status"] == "at_visit" and sri["pickup"]["visit_id"] == sri["upcoming"][1]["id"]
    assert sri["past"][0]["status"] == "done"
    assert client.get("/v1/patients/p-harjo/care").json()["schedule"]["pickup"]["status"] == "now"
    darmo = client.get("/v1/patients/p-darmo/care").json()["schedule"]["pickup"]
    assert darmo["status"] == "before_visit" and "sebelum kontrol Prolanis" in darmo["message"]

    # Kontrol Prolanis selesai + obat diambil → stok +30, jadwal berikutnya otomatis 28 hari kemudian.
    prolanis = sri["upcoming"][1]
    c = client.post(f"/v1/appointments/{prolanis['id']}/status", json={"status": "done", "picked_up_meds": True}).json()
    assert c["meds"][0]["pills_left"] == 34
    nxt = [a for a in c["schedule"]["upcoming"] if a["kind"] == "prolanis"]
    assert nxt and nxt[0]["days_until"] == 31

    c = client.post("/v1/patients/p-sri/appointments", json={"kind": "posyandu", "date": "2099-01-05", "time": "09:30", "place": "Balai RW"}).json()
    assert any(a["place"] == "Balai RW" and a["title"] == "Posyandu Lansia" for a in c["schedule"]["upcoming"])
    assert client.post("/v1/appointments/nope/status", json={"status": "done"}).status_code == 404
    assert client.post("/v1/patients/p-sri/appointments", json={"kind": "dokter", "date": "2099-01-05"}).status_code == 422


# ---------- suasana hati & Nudge Kangen ----------

def test_lonely_story_drives_mood_nudge_and_reminder(client):
    before = client.get("/v1/patients/p-sri/care").json()["mood"]
    assert set(before) >= {"daily", "counts", "lonely_days_7", "level", "summary", "trend", "days_since_family_call"}
    assert len(before["daily"]) == 14
    sid = _start(client, "p-sri")
    client.post(f"/v1/calls/{sid}/answer")
    r = _say(client, sid, "Iya, saya sendiri", "Sampun", "Belum ngukur", "Tidak ada keluhan", "Sepi, kangen sama Dika")
    assert r["ended"] and "Wajar kalau merasa kangen" in r["tilik_text"]
    assert "besok ada posyandu lansia" in r["tilik_text"].lower()  # pengingat jadwal di penutup
    after = client.get("/v1/patients/p-sri/care").json()["mood"]
    assert after["daily"][-1] == {"date": after["daily"][-1]["date"], "mood": "sedih", "lonely": True}
    assert after["lonely_days_7"] == before["lonely_days_7"] + 1
    notes = _feed(client, "c-dika")["notifications"]
    nudge = next(n for n in notes if n["kind"] == "nudge")
    assert "kangen" in nudge["body"] and nudge["payload"]["mood"]["summary"]
    report = next(n for n in notes if n["kind"] == "daily_report")
    assert "📅 Besok Posyandu Lansia" in report["body"]


def test_mood_in_daftar_and_report(client):
    rows = client.get("/v1/puskesmas/today").json()["rows"]
    painem = next(x for x in rows if x["patient"]["id"] == "p-painem")
    assert painem["mood"]["level"] in {"ok", "watch", "nudge"} and painem["next_visit"]["kind"] == "posyandu"
    rep = client.get("/v1/patients/p-painem/report").json()
    assert len(rep["mood"]["daily"]) == 30 and rep["mood"]["lonely_days"] >= 3
    assert any(a["status"] == "done" for a in rep["appointments"])
