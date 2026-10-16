"""Jembatan Pipecat ↔ dialog manager apps/api.

Posisi di pipeline: VAD → STT → [TilikBrain] → TTS → output.
Tugasnya: kumpulkan transkrip final satu giliran Mbah, kirim ke POST /v1/calls/{sid}/turns,
lalu ucapkan `tilik_text` lewat TTS. Tidak ada LLM di sini; semua logika ada di API.
"""

from __future__ import annotations

import asyncio
import time
from collections.abc import Awaitable, Callable
from typing import Any

import httpx
from loguru import logger
from pipecat.frames.frames import (
    BotStartedSpeakingFrame,
    EndWorkerFrame,
    Frame,
    TranscriptionFrame,
    TTSSpeakFrame,
    VADUserStartedSpeakingFrame,
    VADUserStoppedSpeakingFrame,
)
from pipecat.processors.frame_processor import FrameDirection, FrameProcessor

from .api_client import TilikApi
from .latency import LatencyLog, TurnTiming

# Diucapkan kalau API gagal menjawab. Netral bahasa (Indonesia), tidak mengubah state percakapan.
FALLBACK_TEXT = "Maaf, suaranya kurang jelas. Bisa diulang sekali lagi?"


class TilikBrain(FrameProcessor):
    def __init__(
        self,
        api: TilikApi,
        *,
        transport_name: str,
        latency_log: LatencyLog | None = None,
        on_event: Callable[[dict[str, Any]], Awaitable[None]] | None = None,
        flush_grace_s: float = 1.5,
        **kwargs,
    ):
        super().__init__(**kwargs)
        self._api = api
        self._transport_name = transport_name
        self._latency = latency_log or LatencyLog()
        self._on_event = on_event
        self._flush_grace_s = flush_grace_s

        self.session_id: str | None = None
        self.ended = False
        self.last_result: dict[str, Any] | None = None
        self.turns: list[dict[str, Any]] = []  # baris latensi panggilan ini

        self._buffer: list[str] = []
        self._user_speaking = False
        self._speech_end: float | None = None
        self._vad_stop: float | None = None
        self._stt_final: float | None = None
        self._pending: TurnTiming | None = None
        self._lock = asyncio.Lock()
        self._flush_task: asyncio.Task | None = None

    # ---------- dipanggil server saat panggilan tersambung ----------

    async def announce(self, greeting: dict[str, Any]) -> None:
        """Catat salam pembuka (diucapkan oleh pipeline lewat queue_frames, bukan dari sini)."""
        self.last_result = greeting
        await self._emit(greeting)

    async def remote_hangup(self) -> None:
        """Mbah menutup telepon / browser ditutup sebelum percakapan selesai."""
        if self.session_id and not self.ended:
            self.ended = True
            try:
                await self._api.hangup(self.session_id)
            except httpx.HTTPError as exc:
                logger.warning(f"hangup ke API gagal: {exc}")

    # ---------- frame ----------

    async def process_frame(self, frame: Frame, direction: FrameDirection):
        await super().process_frame(frame, direction)

        if isinstance(frame, VADUserStartedSpeakingFrame):
            self._user_speaking = True
            self._cancel_flush()
        elif isinstance(frame, VADUserStoppedSpeakingFrame):
            self._user_speaking = False
            self._vad_stop = frame.timestamp
            self._speech_end = frame.timestamp - frame.stop_secs
            # Transkrip final biasanya datang sesaat setelah commit; kalau STT tidak mengembalikan
            # teks (mis. batuk), buffer yang tersisa tetap dikirim setelah masa tenggang.
            self._schedule_flush(self._flush_grace_s)
        elif isinstance(frame, TranscriptionFrame):
            text = (frame.text or "").strip()
            if text and not self.ended:
                self._buffer.append(text)
                self._stt_final = time.time()
                logger.info(f"[{self.session_id}] Mbah: {text}")
                if not self._user_speaking:
                    self._schedule_flush(0)
        elif isinstance(frame, BotStartedSpeakingFrame):
            if self._pending is not None:
                self._pending.audio_start = time.time()
                row = self._latency.write(self._pending)
                self.turns.append(row)
                logger.info(f"[{self.session_id}] latensi giliran: {row['total_ms']} ms "
                            f"(vad {row['vad_wait_ms']}, stt {row['stt_ms']}, api {row['api_ms']}, tts {row['tts_first_audio_ms']})")
                self._pending = None

        await self.push_frame(frame, direction)

    # ---------- giliran ----------

    def _cancel_flush(self) -> None:
        if self._flush_task and not self._flush_task.done():
            self._flush_task.cancel()
        self._flush_task = None

    def _schedule_flush(self, delay: float) -> None:
        self._cancel_flush()
        self._flush_task = self.create_task(self._flush_after(delay), name="tilik_flush")

    async def _flush_after(self, delay: float) -> None:
        if delay:
            await asyncio.sleep(delay)
        # Pemanggilan API berjalan di task sendiri supaya tidak ikut batal saat Mbah mulai bicara lagi.
        self.create_task(self._dispatch(), name="tilik_dispatch")

    async def _dispatch(self) -> None:
        async with self._lock:
            if not self._buffer or self.ended or not self.session_id:
                return
            text = " ".join(self._buffer)
            self._buffer.clear()
            now = time.time()
            timing = TurnTiming(session_id=self.session_id, transport=self._transport_name,
                                speech_end=self._speech_end or now, vad_stop=self._vad_stop or now,
                                stt_final=self._stt_final or now, text=text)
            try:
                result = await self._api.turn(self.session_id, text)
            except httpx.HTTPStatusError as exc:
                if exc.response.status_code in (404, 409):
                    # Sesi sudah selesai di sisi API (mis. ditutup dari konsol). Akhiri panggilan.
                    logger.warning(f"API menolak giliran ({exc.response.status_code}); panggilan diakhiri")
                    await self._finish()
                    return
                logger.error(f"API error: {exc}")
                result = {"tilik_text": FALLBACK_TEXT, "ended": False, "state": "?", "fallback": True}
            except httpx.HTTPError as exc:
                logger.error(f"API tidak terjangkau: {exc}")
                result = {"tilik_text": FALLBACK_TEXT, "ended": False, "state": "?", "fallback": True}
            timing.api_done = time.time()
            timing.state = result.get("state", "")
            timing.extra = {"level": result.get("level"), "fallback": bool(result.get("fallback"))}
            self._pending = timing if result.get("tilik_text") else None
            await self._speak(result)

    async def _speak(self, result: dict[str, Any]) -> None:
        self.last_result = result
        text = (result.get("tilik_text") or "").strip()
        await self._emit(result)
        if text:
            await self.push_frame(TTSSpeakFrame(text, append_to_context=False))
        if result.get("ended"):
            await self._finish()

    async def _emit(self, result: dict[str, Any]) -> None:
        logger.info(f"[{self.session_id}] TILIK ({result.get('state')}, {result.get('level')}): {result.get('tilik_text')}")
        if self._on_event:
            keys = ("tilik_text", "state", "state_label", "level", "ended", "hints")
            await self._on_event({"type": "tilik", "session_id": self.session_id, **{k: result.get(k) for k in keys}})

    async def _finish(self) -> None:
        """Akhiri pipeline setelah ucapan terakhir selesai diputar (EndWorkerFrame antre di belakang TTSSpeakFrame)."""
        self.ended = True
        self._cancel_flush()
        await self.push_frame(EndWorkerFrame(reason="tilik_call_ended"))
