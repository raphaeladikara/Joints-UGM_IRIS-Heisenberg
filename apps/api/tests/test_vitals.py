"""Sinkron jam tangan / Health Connect / Apple Health."""


def test_seeded_watch_summary(client):
    v = client.get("/v1/patients/p-sri/vitals").json()
    assert v["connected"] and v["last_sync"]["source_label"] == "Jam tangan (simulasi)"
    assert len(v["daily"]["steps"]) == 7 and v["latest"]["spo2"]["value"] >= 90
    assert client.get("/v1/contacts/c-dika/feed").json()["vitals"]["connected"]
    # Semua pasien punya data dummy, dari sumber yang berbeda-beda.
    labels = {pid: client.get(f"/v1/patients/{pid}/vitals").json()["last_sync"]["source_label"] for pid in ("p-harjo", "p-wiryo")}
    assert labels == {"p-harjo": "Apple Health", "p-wiryo": "Health Connect"}


def test_normal_sync_stays_green_and_replaces_daily_totals(client):
    body = {"source": "health_connect", "device": "Galaxy Watch (tes)",
            "samples": [{"type": "steps", "value": 1200}, {"type": "heart_rate", "value": 78}, {"type": "spo2", "value": 97}]}
    r = client.post("/v1/patients/p-sri/vitals", json=body).json()
    assert r["level"] == "green" and r["stored"] == 3
    body["samples"] = [{"type": "steps", "value": 1500}]
    s = client.post("/v1/patients/p-sri/vitals", json=body).json()["summary"]
    assert s["latest"]["steps_today"] == 1500  # total harian diganti, bukan dijumlah
    assert s["last_sync"]["source_label"] == "Health Connect"


def test_low_spo2_opens_one_yellow_alert(client):
    body = {"source": "apple_health", "samples": [{"type": "spo2", "value": 86}]}
    r = client.post("/v1/patients/p-sri/vitals", json=body).json()
    assert r["level"] == "yellow" and len(r["alert_ids"]) == 1
    again = client.post("/v1/patients/p-sri/vitals", json=body).json()
    assert again["alert_ids"] == []  # tidak membanjiri Daftar Tilik
    a = client.get(f"/v1/alerts/{r['alert_ids'][0]}").json()
    assert a["level"] == "yellow" and a["reasons"][0]["code"] == "SPO2_LOW"


def test_watch_bp_crisis_uses_bp_rules(client):
    body = {"source": "watch_sim", "samples": [{"type": "blood_pressure", "systolic": 186, "diastolic": 102}]}
    r = client.post("/v1/patients/p-sri/vitals", json=body).json()
    assert r["level"] == "yellow"
    hist = client.get("/v1/patients/p-sri").json()["bp_history"]
    assert hist[-1]["systolic"] == 186


def test_invalid_samples_rejected(client):
    assert client.post("/v1/patients/p-sri/vitals", json={"source": "watch_sim", "samples": [{"type": "spo2"}]}).status_code == 422
    assert client.post("/v1/patients/p-sri/vitals", json={"source": "fitbit", "samples": [{"type": "spo2", "value": 97}]}).status_code == 422
