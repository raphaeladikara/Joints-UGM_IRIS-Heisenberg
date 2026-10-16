"""Fitur keluarga (jadwal & stok obat, air & garam, streak, rapor): bentuk JSON sama dengan backend offline Flutter."""


def _care(client, pid):
    r = client.get(f"/v1/patients/{pid}/care")
    assert r.status_code == 200, r.text
    return r.json()


def _med(care, name):
    return next(m for m in care["meds"] if m["name"] == name)


def _talk(client, pid, *lines):
    sid = client.post("/v1/calls", json={"patient_id": pid}).json()["session_id"]
    client.post(f"/v1/calls/{sid}/answer")
    for line in lines:
        r = client.post(f"/v1/calls/{sid}/turns", json={"text": line})
        assert r.status_code == 200, r.text
    return sid


def test_care_shape_from_seed(client):
    c = _care(client, "p-sri")
    assert set(c) == {"meds", "doses_today", "intake", "streaks", "schedule", "mood"}
    amlo = _med(c, "amlodipin")
    assert amlo == {**amlo, "pills_left": 4, "per_day": 1, "days_left": 4, "times": ["07:00"], "refill_size": 30, "schedule": "1× pagi"}
    assert [d["time"] for d in c["doses_today"]] == ["07:00"]
    assert c["intake"]["goals"] == {"water": 8, "salt_max": 1.0}
    assert len(c["intake"]["last7"]) == 7 and c["intake"]["last7"][-1]["water"] == c["intake"]["today"]["water"]
    s = c["streaks"]
    assert set(s) == {"medication_days", "family_call_days", "family_calls_week", "called_today", "green_days_30", "child_name"}
    assert s["child_name"] == "Mas Dika" and s["family_call_days"] >= 4 and s["called_today"] is False

    lastri = _care(client, "p-lastri")
    assert _med(lastri, "kaptopril")["per_day"] == 2 and _med(lastri, "kaptopril")["days_left"] == 7
    assert [d["time"] for d in lastri["doses_today"]] == ["07:00", "07:00", "19:00"]


def test_care_in_feed_and_patient_detail(client):
    feed = client.get("/v1/contacts/c-dika/feed").json()
    assert feed["care"]["meds"][0]["name"] == "amlodipin"
    detail = client.get("/v1/patients/p-harjo").json()
    assert _med(detail["care"], "kaptopril")["pills_left"] == 0


def test_harjo_med_out_then_refill_closes_alert(client):
    c = _care(client, "p-harjo")
    doses = {d["time"]: d for d in c["doses_today"]}
    # Telepon pagi menjawab "belum (obat habis)" → dosis pagi terlewat, dosis malam habis stok.
    assert doses["07:00"] == {"name": "kaptopril", "time": "07:00", "status": "missed", "by": "telepon KRING"}
    assert doses["19:00"]["status"] == "out"
    open_ids = [a["id"] for a in client.get("/v1/alerts?status=open").json() if a["patient"]["id"] == "p-harjo"]
    assert open_ids

    c = client.post("/v1/patients/p-harjo/meds/refill", json={}).json()
    assert _med(c, "kaptopril")["pills_left"] == 30 and _med(c, "kaptopril")["last_refill"]
    assert all(client.get(f"/v1/alerts/{aid}").json()["status"] == "closed" for aid in open_ids)


def test_refill_keeps_other_alerts_and_named_med(client):
    c = client.post("/v1/patients/p-lastri/meds/refill", json={"name": "kaptopril"}).json()
    assert _med(c, "kaptopril")["pills_left"] == 44 and _med(c, "amlodipin")["pills_left"] == 9
    lastri = [a for a in client.get("/v1/alerts").json() if a["patient"]["id"] == "p-lastri"]
    assert lastri and all(a["status"] == "open" for a in lastri)  # alert tensi krisis tidak ikut tertutup


def test_dose_by_family_reduces_stock(client):
    c = client.post("/v1/patients/p-lastri/meds/dose", json={"name": "kaptopril", "time": "19:00"}).json()
    assert _med(c, "kaptopril")["pills_left"] == 13
    evening = next(d for d in c["doses_today"] if d["time"] == "19:00")
    assert evening["status"] == "taken" and evening["by"] == "keluarga"
    c = client.post("/v1/patients/p-lastri/meds/dose", json={"name": "amlodipin", "time": "07:00", "status": "missed"}).json()
    assert _med(c, "amlodipin")["pills_left"] == 9
    assert client.post("/v1/patients/p-nobody/meds/dose", json={"name": "x", "time": "07:00"}).status_code == 404


def test_morning_call_yes_takes_dose(client):
    _talk(client, "p-sri", "Iya, saya sendiri", "Sampun, tadi habis sarapan")
    c = _care(client, "p-sri")
    assert _med(c, "amlodipin")["pills_left"] == 3
    assert c["doses_today"][0] == {"name": "amlodipin", "time": "07:00", "status": "taken", "by": "telepon KRING"}


def test_morning_call_med_out_empties_stock(client):
    assert _med(_care(client, "p-darmo"), "amlodipin")["pills_left"] == 25
    _talk(client, "p-darmo", "iya", "belum", "obatnya habis")
    c = _care(client, "p-darmo")
    assert all(m["pills_left"] == 0 for m in c["meds"])


def test_intake_water_and_salt_limits(client):
    before = _care(client, "p-sri")["intake"]["today"]
    c = client.post("/v1/patients/p-sri/intake", json={"kind": "water", "delta": 1}).json()
    assert c["intake"]["today"]["water"] == before["water"] + 1
    c = client.post("/v1/patients/p-sri/intake", json={"kind": "salt", "delta": 10}).json()
    assert c["intake"]["today"]["salt"] == 6.0  # dibatasi 0..6 sdt
    c = client.post("/v1/patients/p-sri/intake", json={"kind": "salt", "delta": -16}).json()
    assert c["intake"]["today"]["salt"] == 0.0
    assert client.post("/v1/patients/p-sri/intake", json={"kind": "kopi", "delta": 1}).status_code == 422


def test_family_call_extends_streak(client):
    before = _care(client, "p-sri")["streaks"]
    c = client.post("/v1/patients/p-sri/family-calls", json={"contact_id": "c-dika"}).json()
    s = c["streaks"]
    assert s["called_today"] is True
    assert s["family_call_days"] == before["family_call_days"] + 1
    assert s["family_calls_week"] == before["family_calls_week"] + 1


def test_report_30_days(client):
    r = client.get("/v1/patients/p-sri/report?days=30")
    assert r.status_code == 200, r.text
    rep = r.json()
    assert rep["days"] == 30 and len(rep["bp_daily"]) == 30 and len(rep["adherence"]) == 30
    assert rep["from"] == rep["bp_daily"][0]["date"] and rep["to"] == rep["bp_daily"][-1]["date"]
    assert rep["bp_avg"]["systolic"] > 100 and rep["bp_trend"]["first_half"] is not None
    assert 0 <= rep["adherence_pct"] <= 100
    assert rep["calls"]["completed"] >= 25
    assert len(rep["vitals"]["steps_daily"]) == 30 and rep["vitals"]["steps_avg"] > 0 and rep["vitals"]["spo2_min"] > 80
    assert rep["intake"]["water_avg"] > 0 and isinstance(rep["intake"]["salt_over_days"], int)
    assert rep["family_calls"]["count"] >= 4 and rep["family_calls"]["minutes"] > 0
    assert rep["streaks"]["child_name"] == "Mas Dika"

    painem = client.get("/v1/patients/p-painem/report").json()
    assert painem["bp_avg"] is None and painem["calls"]["no_answer"] == 4
    assert client.get("/v1/patients/p-sri/report?days=3").json()["days"] == 7
    assert client.get("/v1/patients/p-nobody/report").status_code == 404
