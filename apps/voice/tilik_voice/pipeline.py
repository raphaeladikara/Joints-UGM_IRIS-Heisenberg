"""Satu panggilan = satu pipeline Pipecat:

    transport.input → Silero VAD → ElevenLabs Scribe (realtime) → TilikBrain (apps/api) → ElevenLabs TTS → transport.output

Dipakai bersama oleh Twilio Media Streams (8 kHz) dan SmallWebRTC (browser, 16 kHz).
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable
from typing import Any

from loguru import logger
from pipecat.audio.vad.silero import SileroVADAnalyzer
from pipecat.audio.vad.vad_analyzer import VADParams
from pipecat.frames.frames import TTSSpeakFrame
from pipecat.pipeline.pipeline import Pipeline
from pipecat.pipeline.worker import PipelineParams, PipelineWorker
from pipecat.processors.audio.vad_processor import VADProcessor
from pipecat.processors.frame_processor import FrameProcessor
from pipecat.services.elevenlabs.stt import ElevenLabsRealtimeSTTService
from pipecat.services.elevenlabs.tts import ElevenLabsTTSService
from pipecat.transcriptions.language import Language
from pipecat.transports.base_transport import BaseTransport
from pipecat.workers.runner import WorkerRunner

from . import config
from .api_client import TilikApi
from .brain import TilikBrain
from .latency import LatencyLog

# start(api) → (session_id, hasil answer dari API berisi salam pembuka)
StartFn = Callable[[TilikApi], Awaitable[tuple[str, dict[str, Any]]]]
EventFn = Callable[[dict[str, Any]], Awaitable[None]]


def make_stt() -> FrameProcessor:
    return ElevenLabsRealtimeSTTService(
        api_key=config.ELEVENLABS_API_KEY,
        settings=ElevenLabsRealtimeSTTService.Settings(
            model=config.ELEVENLABS_STT_MODEL,
            language=Language(config.ELEVENLABS_STT_LANGUAGE),
        ),
    )


def make_tts() -> FrameProcessor:
    return ElevenLabsTTSService(
        api_key=config.ELEVENLABS_API_KEY,
        settings=ElevenLabsTTSService.Settings(
            voice=config.ELEVENLABS_VOICE_ID,
            model=config.ELEVENLABS_TTS_MODEL,
            language=Language.ID,
        ),
    )


def make_vad() -> VADProcessor:
    return VADProcessor(vad_analyzer=SileroVADAnalyzer(params=VADParams(
        confidence=config.VAD_CONFIDENCE, start_secs=config.VAD_START_SECS, stop_secs=config.VAD_STOP_SECS)))


async def run_call(
    transport: BaseTransport,
    *,
    transport_name: str,
    sample_rate: int,
    start: StartFn,
    on_event: EventFn | None = None,
    stt: FrameProcessor | None = None,
    tts: FrameProcessor | None = None,
    vad: FrameProcessor | None = None,
    api: TilikApi | None = None,
    latency_log: LatencyLog | None = None,
) -> TilikBrain:
    """Jalankan satu panggilan sampai selesai. Mengembalikan brain (berisi hasil terakhir & latensi)."""
    own_api = api is None
    api = api or TilikApi()
    brain = TilikBrain(api, transport_name=transport_name, latency_log=latency_log, on_event=on_event)
    pipeline = Pipeline([
        transport.input(),
        vad or make_vad(),
        stt or make_stt(),
        brain,
        tts or make_tts(),
        transport.output(),
    ])
    worker = PipelineWorker(
        pipeline,
        params=PipelineParams(audio_in_sample_rate=sample_rate, audio_out_sample_rate=sample_rate, enable_metrics=True),
        idle_timeout_secs=120,  # Mbah diam 2 menit → panggilan ditutup
    )

    @transport.event_handler("on_client_connected")
    async def _connected(_transport, _client):
        try:
            sid, greeting = await start(api)
        except Exception as exc:  # API mati / pasien tidak ada: jangan biarkan panggilan menggantung
            logger.exception(f"gagal memulai sesi di API: {exc}")
            await worker.cancel()
            return
        brain.session_id = sid
        logger.info(f"[{sid}] panggilan tersambung lewat {transport_name}")
        await brain.announce(greeting)
        if greeting.get("tilik_text"):
            await worker.queue_frames([TTSSpeakFrame(greeting["tilik_text"], append_to_context=False)])

    @transport.event_handler("on_client_disconnected")
    async def _disconnected(_transport, _client):
        await brain.remote_hangup()
        await worker.cancel()

    runner = WorkerRunner(handle_sigint=False)
    try:
        await runner.run(worker)
    finally:
        await brain.remote_hangup()
        if brain.turns:
            totals = sorted(r["total_ms"] for r in brain.turns if r.get("total_ms") is not None)
            logger.info(f"[{brain.session_id}] selesai: {len(brain.turns)} giliran, latensi total (ms) {totals}")
        if own_api:
            await api.close()
    return brain
