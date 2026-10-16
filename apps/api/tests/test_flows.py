"""Skenario demo PRD §4 lewat API: babak 1 (pagi biasa) dan babak 2 (darurat)."""


def _talk(client, sid, *lines):
    out = None
    for line in lines:
        r = client.post(f"/v1/calls/{sid}/turns", json={"text": line})
        assert r.status_code == 200, r.text
        out = r.json()
    return out


def _start(client, pid="p-sri"):
    r = client.post("/v1/calls", json={"patient_id": pid})
    assert r.json()["status"] == "ringing"
    sid = r.json()["session_id"]
    assert client.get(f"/v1/patients/{pid}/incoming").json()["ringing"]
    g = client.post(f"/v1/calls/{sid}/answer").json()
    return sid, g


def test_daily_green_call(client):
    sid, g = _start(client)
    assert "asisten AI" in g["tilik_text"] and "melati putih" in g["tilik_text"]

    r = _talk(client, sid, "Iya, saya sendiri")
    assert "Mas Dika titip pesan" in r["tilik_text"] and r["state"] == "MEDICATION"
    r = _talk(client, sid, "Sampun, tadi habis sarapan")
    assert r["state"] == "BLOOD_PRESSURE"
    r = _talk(client, sid, "seratus lima puluh per sembilan puluh")
    assert r["state"] == "BP_CONFIRM" and "Seratus lima puluh per sembilan puluh" in r["tilik_text"]
    r = _talk(client, sid, "iya betul")
    assert r["state"] == "SYMPTOMS"
    r = _talk(client, sid, "tidak ada keluhan")
    assert r["state"] == "STORY" and "tomat" in r["tilik_text"].lower()
    r = _talk(client, sid, "Tomatnya sudah panen dua keranjang, dibagi ke tetangga")
    assert r["ended"] and r["level"] == "green" and r["outcome"] == "completed"

    detail = client.get(f"/v1/calls/{sid}").json()
    assert "melati putih" not in " ".join(t["text"] for t in detail["turns"])  # kata sandi disamarkan
    feed = client.get("/v1/contacts/c-dika/feed").json()
    assert feed["latest_report"]["payload"]["talking_points"]
    assert feed["latest_report"]["payload"]["bp"] == {"systolic": 150, "diastolic": 90}
    rows = client.get("/v1/puskesmas/today").json()["rows"]
    sri = next(r for r in rows if r["patient"]["id"] == "p-sri")
    assert sri["status"] == "green"
    assert rows[0]["status"] in {"red", "yellow"}  # 🔴/🟡 di paling atas


def test_stroke_emergency(client):
    sid, _ = _start(client)
    _talk(client, sid, "inggih")
    r = _talk(client, sid, "Mbak, ngomongku kok angel, tangan kiwa lemes")
    assert r["state"] == "STROKE_SCREEN" and r["level"] == "red" and "escalation_started" in r["hints"]
    alert_id = r["alert_id"]

    board = client.get("/v1/alerts", params={"level": "red", "status": "open"}).json()
    assert board[0]["id"] == alert_id and board[0]["hospital"]["name"].startswith("RSUD Wonosari")

    tini = client.get("/v1/contacts/c-tini/feed").json()
    assert tini["incoming_call"] and tini["incoming_call"]["status"] == "ringing"

    r = _talk(client, sid, "langit... biru... desa")
    assert r["state"] == "STROKE_SCREEN"
    r = _talk(client, sid, "yang kiri turun, lemes")
    r = _talk(client, sid, "jam enam lewat empat puluh")
    assert r["ended"] and r["outcome"] == "escalated" and "conference" in r["hints"]

    a = client.get("/v1/alerts", params={"level": "red"}).json()[0]
    assert a["last_known_well"] and a["golden_period_deadline"]
    assert a["screening"]["speech_repeat"]["abnormal"] and a["screening"]["arm_drift"]["abnormal"]
    dika = client.get("/v1/contacts/c-dika/feed").json()
    assert dika["red_alert"]["id"] == alert_id
    assert any(n["kind"] == "red_update" for n in dika["notifications"])


def test_medication_out_goes_yellow(client):
    sid, _ = _start(client)
    r = _talk(client, sid, "iya", "belum", "obatnya habis")
    assert r["state"] == "BLOOD_PRESSURE" and r["level"] == "yellow"
    r = _talk(client, sid, "belum ngukur", "tidak ada", "biasa saja")
    assert r["ended"] and r["level"] == "yellow"
    sri = next(x for x in client.get("/v1/puskesmas/today").json()["rows"] if x["patient"]["id"] == "p-sri")
    assert sri["status"] == "yellow" and "Obat habis" in sri["follow_up"]


def test_wrong_person_reveals_nothing(client):
    sid, _ = _start(client)
    r = _talk(client, sid, "bukan, saya cucunya")
    assert r["ended"] and r["outcome"] == "wrong_person"
    assert "obat" not in r["tilik_text"].lower()


def test_ai_disclosure_on_question(client):
    sid, _ = _start(client)
    _talk(client, sid, "iya")
    r = _talk(client, sid, "Niki tiyang napa robot?")
    assert "bukan manusia" in r["tilik_text"] and r["state"] == "MEDICATION"


def test_fall_event_no_answer_escalates(client):
    r = client.post("/v1/events", json={"patient_id": "p-sri", "type": "fall_detected", "source": "wearable"}).json()
    assert r["action"] == "calling_patient"
    nr = client.post(f"/v1/calls/{r['session_id']}/no-answer").json()
    assert nr["level"] == "red" and nr["alert_id"]


def test_fall_event_ok(client):
    r = client.post("/v1/events", json={"patient_id": "p-sri", "type": "fall_detected"}).json()
    g = client.post(f"/v1/calls/{r['session_id']}/answer").json()
    assert "jatuh" in g["tilik_text"].lower()
    t = _talk(client, r["session_id"], "saya baik-baik saja, cuma kepleset sedikit")
    assert t["state"] == "SYMPTOMS"


def test_family_message_flow(client):
    r = client.post("/v1/patients/p-sri/family-messages", json={"contact_id": "c-dika", "text": "Bu, jangan lupa makan siang"})
    assert r.status_code == 200
    bad = client.post("/v1/patients/p-sri/family-messages", json={"contact_id": "c-wulan", "text": "x"})
    assert bad.status_code == 400
