"""Server suara TILIK.

    python -m tilik_voice.server

Rute:
  GET  /                    halaman "HP Mbah" di browser (fallback SmallWebRTC)
  POST /api/offer           sinyal WebRTC dari halaman itu
  POST /calls               panggilan keluar Twilio ke nomor di allowlist DEMO_MODE
  WS   /twilio/ws           audio Twilio Media Streams (μ-law 8 kHz)
  POST /twilio/status/{t}   hasil akhir panggilan dari Twilio (no-answer, busy, ...)
  GET  /latency             ringkasan p50/p95 akhir ucapan → suara TILIK
"""

from __future__ import annotations

import asyncio
import secrets
from contextlib import asynccontextmanager
from typing import Any
from urllib.parse import parse_qs

from fastapi import FastAPI, HTTPException, Request, WebSocket
from fastapi.responses import FileResponse
from loguru import logger
from pydantic import BaseModel, Field
from pipecat.runner.utils import parse_telephony_websocket
from pipecat.serializers.twilio import TwilioFrameSerializer
from pipecat.transports.base_transport import TransportParams
from pipecat.transports.smallwebrtc.connection import IceServer, SmallWebRTCConnection
from pipecat.transports.smallwebrtc.request_handler import (
    SmallWebRTCPatchRequest,
    SmallWebRTCRequest,
    SmallWebRTCRequestHandler,
)
from pipecat.transports.smallwebrtc.transport import SmallWebRTCTransport
from pipecat.transports.websocket.fastapi import FastAPIWebsocketParams, FastAPIWebsocketTransport

from . import config, dialing, twilio_rest
from .api_client import TilikApi
from .latency import LatencyLog
from .pipeline import run_call

STATIC = config.VOICE_ROOT / "static"
FAILED_STATUSES = {"no-answer", "busy", "failed", "canceled"}

webrtc = SmallWebRTCRequestHandler(ice_servers=[IceServer(urls="stun:stun.l.google.com:19302")])
# Panggilan Twilio yang sedang berdering/berjalan: session_id → {token, answered, call_sid}
twilio_calls: dict[str, dict[str, Any]] = {}
# Teks TILIK per koneksi WebRTC, dipoll halaman browser: pc_id → [event]
webrtc_events: dict[str, list[dict[str, Any]]] = {}
background: set[asyncio.Task] = set()


@asynccontextmanager
async def lifespan(_: FastAPI):
    if config.missing_elevenlabs():
        logger.warning(f"ElevenLabs belum diisi di .env: {config.missing_elevenlabs()} (STT/TTS akan gagal)")
    logger.info(f"DEMO_MODE={config.DEMO_MODE}, allowlist {len(config.DEMO_ALLOWLIST)} nomor, API {config.TILIK_API_URL}")
    yield
    await webrtc.close()


app = FastAPI(title="TILIK Voice", lifespan=lifespan)


def _spawn(coro) -> None:
    t = asyncio.create_task(coro)
    background.add(t)
    t.add_done_callback(background.discard)


# ---------- sistem ----------

@app.get("/health")
async def health() -> dict[str, Any]:
    api_ok = True
    try:
        async with _api() as api:
            await api.health()
    except Exception:
        api_ok = False
    return {"ok": True, "api": api_ok, "demo_mode": config.DEMO_MODE, "elevenlabs_missing": config.missing_elevenlabs(),
            "twilio_missing": config.missing_twilio()}


@app.get("/latency")
async def latency(transport: str | None = None, last: int = 20) -> dict[str, Any]:
    log = LatencyLog()
    return {"summary": log.summary(transport), "recent": log.rows()[-last:]}


# ---------- WebRTC (fallback: panggilan lewat browser) ----------

@app.get("/", include_in_schema=False)
async def index() -> FileResponse:
    return FileResponse(STATIC / "index.html")


@app.get("/api/patients")
async def patients() -> list[dict[str, Any]]:
    async with _api() as api:
        return [{k: p[k] for k in ("id", "display_name", "preferred_language")} for p in await api.patients()]


@app.post("/api/offer")
async def offer(request: Request) -> dict[str, Any]:
    body = await request.json()
    req = SmallWebRTCRequest.from_dict(body)
    patient_id = ((req.request_data or {}).get("patient_id") or "p-sri")

    async def on_connection(connection: SmallWebRTCConnection):
        events = webrtc_events.setdefault(connection.pc_id, [])
        transport = SmallWebRTCTransport(connection, TransportParams(audio_in_enabled=True, audio_out_enabled=True))

        async def start(api: TilikApi):
            # Browser = HP Mbah yang langsung diangkat.
            res = await api.start_call(patient_id, auto_answer=True)
            return res["session_id"], res

        async def on_event(ev: dict[str, Any]):
            events.append(ev)

        async def run():
            try:
                await run_call(transport, transport_name="webrtc", sample_rate=16000, start=start, on_event=on_event)
            finally:
                events.append({"type": "ended"})

        _spawn(run())

    answer = await webrtc.handle_web_request(req, on_connection)
    if not answer:
        raise HTTPException(500, "Gagal membuat jawaban WebRTC")
    return answer


@app.patch("/api/offer")
async def offer_patch(request: Request) -> dict[str, Any]:
    await webrtc.handle_patch_request(SmallWebRTCPatchRequest(**await request.json()))
    return {"ok": True}


@app.get("/api/events/{pc_id}")
async def events(pc_id: str, since: int = 0) -> dict[str, Any]:
    evs = webrtc_events.get(pc_id, [])
    return {"events": evs[since:], "next": len(evs)}


# ---------- Twilio ----------

class OutboundCall(BaseModel):
    patient_id: str = "p-sri"
    to: str | None = Field(default=None, description="E.164. Default DEMO_PATIENT_PHONE dari .env")


class _api:
    """Context manager kecil supaya klien API selalu ditutup."""

    async def __aenter__(self) -> TilikApi:
        self.api = TilikApi()
        return self.api

    async def __aexit__(self, *exc) -> None:
        await self.api.close()


@app.post("/calls")
async def outbound_call(body: OutboundCall) -> dict[str, Any]:
    missing = config.missing_twilio()
    if missing:
        raise HTTPException(503, f"Twilio belum dikonfigurasi: {missing}")
    try:
        to = dialing.check_destination(body.to or config.DEMO_PATIENT_PHONE)
    except dialing.DialBlocked as exc:
        raise HTTPException(403, str(exc))

    async with _api() as api:
        res = await api.start_call(body.patient_id)
        sid = res["session_id"]
        token = secrets.token_urlsafe(16)
        ws_url = config.PUBLIC_BASE_URL.replace("https://", "wss://").replace("http://", "ws://") + "/twilio/ws"
        twiml = twilio_rest.stream_twiml(ws_url, {"session_id": sid, "token": token})
        twilio_calls[sid] = {"token": token, "answered": False}
        try:
            call = await twilio_rest.create_call(to, twiml, f"{config.PUBLIC_BASE_URL}/twilio/status/{token}")
        except twilio_rest.TwilioError as exc:
            twilio_calls.pop(sid, None)
            await api.hangup(sid)
            raise HTTPException(502, exc.message)
    twilio_calls[sid]["call_sid"] = call.get("sid")
    logger.info(f"[{sid}] Twilio menelepon {to[:-4]}xxxx (call {call.get('sid')})")
    return {"session_id": sid, "call_sid": call.get("sid"), "status": call.get("status")}


@app.post("/twilio/status/{token}")
async def twilio_status(token: str, request: Request) -> dict[str, Any]:
    form = {k: v[0] for k, v in parse_qs((await request.body()).decode()).items()}
    sid = next((s for s, c in twilio_calls.items() if secrets.compare_digest(c["token"], token)), None)
    if not sid:
        raise HTTPException(404, "Panggilan tidak dikenal")
    status = form.get("CallStatus", "")
    call = twilio_calls.pop(sid)
    logger.info(f"[{sid}] status akhir Twilio: {status}")
    if status in FAILED_STATUSES and not call["answered"]:
        async with _api() as api:
            await api.no_answer(sid)
    return {"ok": True}


@app.websocket("/twilio/ws")
async def twilio_ws(ws: WebSocket) -> None:
    await ws.accept()
    _, call_data = await parse_telephony_websocket(ws)
    params = call_data.get("body", {}) or {}
    sid = params.get("session_id", "")
    call = twilio_calls.get(sid)
    if not call or not secrets.compare_digest(call["token"], params.get("token", "")):
        logger.warning("WebSocket Twilio ditolak: session/token tidak cocok")
        await ws.close()
        return

    serializer = TwilioFrameSerializer(
        stream_sid=call_data["stream_id"], call_sid=call_data["call_id"],
        # Panggilan selesai sendiri saat WebSocket ditutup (tidak ada verb TwiML setelah <Connect>),
        # jadi tidak perlu auth token untuk auto hang-up.
        params=TwilioFrameSerializer.InputParams(auto_hang_up=False),
    )
    transport = FastAPIWebsocketTransport(ws, FastAPIWebsocketParams(
        audio_in_enabled=True, audio_out_enabled=True, add_wav_header=False, serializer=serializer))

    async def start(api: TilikApi):
        call["answered"] = True
        return sid, await api.answer(sid)

    await run_call(transport, transport_name="twilio", sample_rate=8000, start=start)


def main() -> None:
    import uvicorn

    uvicorn.run(app, host=config.VOICE_HOST, port=config.VOICE_PORT)


if __name__ == "__main__":
    main()
