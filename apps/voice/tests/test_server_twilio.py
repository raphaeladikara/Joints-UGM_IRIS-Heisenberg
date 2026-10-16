"""Rute Twilio: pagar nomor sebelum Twilio dihubungi, TwiML, dan no-answer dari status callback."""

from xml.etree import ElementTree

from fastapi.testclient import TestClient

from tilik_voice import config, server, twilio_rest


def _configure(monkeypatch):
    for k, v in {"TWILIO_ACCOUNT_SID": "AC_test", "TWILIO_API_KEY_SID": "SK_test", "TWILIO_API_KEY_SECRET": "x",
                 "TWILIO_PHONE_NUMBER": "+15550000000", "PUBLIC_BASE_URL": "https://demo.trycloudflare.com"}.items():
        monkeypatch.setattr(config, k, v)
    monkeypatch.setattr(config, "DEMO_MODE", True)
    monkeypatch.setattr(config, "DEMO_ALLOWLIST", {"+6281200000001"})


def test_twiml_escapes_parameters():
    xml = twilio_rest.stream_twiml("wss://h/twilio/ws", {"session_id": 'a"b', "token": "t<1>"})
    stream = ElementTree.fromstring(xml).find("Connect/Stream")
    assert stream.get("url") == "wss://h/twilio/ws"
    assert {p.get("name"): p.get("value") for p in stream} == {"session_id": 'a"b', "token": "t<1>"}


def test_outbound_blocks_numbers_before_twilio(monkeypatch):
    _configure(monkeypatch)
    called = []

    async def fake_create(*a, **kw):
        called.append(a)
        return {"sid": "CA1", "status": "queued"}

    monkeypatch.setattr(twilio_rest, "create_call", fake_create)
    c = TestClient(server.app)
    assert c.post("/calls", json={"patient_id": "p-sri", "to": "119"}).status_code == 403
    assert c.post("/calls", json={"patient_id": "p-sri", "to": "+6281299999999"}).status_code == 403
    assert called == []


def test_no_answer_status_reaches_api(monkeypatch):
    _configure(monkeypatch)
    calls = []

    class FakeApi:
        async def start_call(self, pid, auto_answer=False):
            calls.append(("start", pid))
            return {"session_id": "s-1", "status": "ringing"}

        async def no_answer(self, sid):
            calls.append(("no_answer", sid))
            return {}

        async def close(self):
            pass

    async def fake_create(to, twiml, status_cb):
        calls.append(("twilio", to, status_cb))
        return {"sid": "CA1", "status": "queued"}

    monkeypatch.setattr(server, "TilikApi", FakeApi)
    monkeypatch.setattr(twilio_rest, "create_call", fake_create)
    c = TestClient(server.app)
    r = c.post("/calls", json={"patient_id": "p-sri", "to": "+6281200000001"})
    assert r.status_code == 200 and r.json()["session_id"] == "s-1"
    status_cb = calls[1][2]
    assert status_cb.startswith("https://demo.trycloudflare.com/twilio/status/")
    token = status_cb.rsplit("/", 1)[1]
    assert c.post("/twilio/status/wrong", content="CallStatus=no-answer").status_code == 404
    r = c.post(f"/twilio/status/{token}", content="CallStatus=no-answer&CallSid=CA1",
               headers={"Content-Type": "application/x-www-form-urlencoded"})
    assert r.status_code == 200 and ("no_answer", "s-1") in calls
