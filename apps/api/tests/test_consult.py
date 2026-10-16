"""Wali → dokter jaga: saran, permintaan, dan catatan dokter."""


def test_low_spo2_recommends_doctor_and_consult_flows(client):
    client.post("/v1/patients/p-sri/vitals", json={"source": "apple_health", "samples": [{"type": "spo2", "value": 86}]})
    feed = client.get("/v1/contacts/c-dika/feed").json()
    assert feed["doctor"]["suggest"]["recommended"]
    assert any("Oksigen rendah" in r for r in feed["doctor"]["suggest"]["reasons"])

    c = client.post("/v1/patients/p-sri/doctor-consults", json={"contact_id": "c-dika", "mode": "video"}).json()
    assert c["status"] == "ringing" and c["level"] == "yellow" and "Oksigen rendah" in c["reason"]
    assert c["context"]["spo2"]["value"] == 86
    # Permintaan kedua tidak membuat panggilan ganda.
    assert client.post("/v1/patients/p-sri/doctor-consults", json={"contact_id": "c-dika"}).json()["id"] == c["id"]
    assert [x["id"] for x in client.get("/v1/doctor-consults").json()] == [c["id"]]
    assert client.get("/v1/contacts/c-dika/feed").json()["doctor_consult"]["id"] == c["id"]

    assert client.post(f"/v1/doctor-consults/{c['id']}/status", json={"status": "in_call"}).json()["answered_at"]
    done = client.post(f"/v1/doctor-consults/{c['id']}/status", json={"status": "ended", "note": "Cek ulang oksigen 1 jam lagi."}).json()
    assert done["status"] == "ended" and done["doctor_note"].startswith("Cek ulang")
    feed = client.get("/v1/contacts/c-dika/feed").json()
    assert feed["doctor_consult"] is None
    assert any(n["kind"] == "doctor_note" for n in feed["notifications"])


def test_consult_rejects_foreign_contact(client):
    assert client.post("/v1/patients/p-sri/doctor-consults", json={"contact_id": "c-slamet"}).status_code == 400
