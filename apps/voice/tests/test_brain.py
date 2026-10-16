"""TilikBrain: transkrip → POST /turns → TTSSpeakFrame, tanpa audio sungguhan (frame VAD/STT disuntikkan)."""

import json

import httpx
import pytest
from pipecat.frames.frames import (
    BotStartedSpeakingFrame,
    EndFrame,
    TranscriptionFrame,
    TTSSpeakFrame,
    VADUserStartedSpeakingFrame,
    VADUserStoppedSpeakingFrame,
)
from pipecat.tests.utils import SleepFrame, run_test

from tilik_voice.api_client import TilikApi
from tilik_voice.brain import FALLBACK_TEXT, TilikBrain
from tilik_voice.latency import LatencyLog


def utterance(text: str | None, *, pause: float = 0.3) -> list:
    frames = [VADUserStartedSpeakingFrame(), SleepFrame(0.05), VADUserStoppedSpeakingFrame(stop_secs=0.7)]
    if text is not None:
        frames += [SleepFrame(0.05), TranscriptionFrame(text, "mbah", "")]
    return frames + [SleepFrame(pause)]


def fake_api(replies: list, seen: list[str]) -> TilikApi:
    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(json.loads(request.content)["text"])
        reply = replies.pop(0)
        if isinstance(reply, int):
            return httpx.Response(reply, json={"detail": "x"})
        return httpx.Response(200, json=reply)

    return TilikApi(client=httpx.AsyncClient(transport=httpx.MockTransport(handler), base_url="http://api"))


def spoken(frames) -> list[str]:
    return [f.text for f in frames if isinstance(f, TTSSpeakFrame)]


async def test_turn_goes_to_api_and_is_spoken(tmp_path):
    seen: list[str] = []
    api = fake_api([{"tilik_text": "Sudah minum obat?", "state": "MEDICATION", "level": "green", "ended": False}], seen)
    log = LatencyLog(tmp_path / "lat.jsonl")
    brain = TilikBrain(api, transport_name="test", latency_log=log)
    brain.session_id = "s1"
    down, _ = await run_test(brain, frames_to_send=[*utterance("iya saya sendiri"), BotStartedSpeakingFrame()])
    assert seen == ["iya saya sendiri"]
    assert spoken(down) == ["Sudah minum obat?"]
    row = log.rows()[0]
    assert row["state"] == "MEDICATION" and row["total_ms"] >= 700 and row["vad_wait_ms"] == 700


async def test_pause_mid_sentence_is_one_turn():
    seen: list[str] = []
    api = fake_api([{"tilik_text": "Baik.", "state": "BP_CONFIRM", "level": "green", "ended": False}], seen)
    brain = TilikBrain(api, transport_name="test")
    brain.session_id = "s1"
    frames = [
        VADUserStartedSpeakingFrame(), VADUserStoppedSpeakingFrame(stop_secs=0.7),
        VADUserStartedSpeakingFrame(),  # Mbah melanjutkan sebelum transkrip pertama datang
        TranscriptionFrame("seratus lima puluh", "mbah", ""),
        SleepFrame(0.05), VADUserStoppedSpeakingFrame(stop_secs=0.7),
        TranscriptionFrame("per sembilan puluh", "mbah", ""), SleepFrame(0.3),
    ]
    down, _ = await run_test(brain, frames_to_send=frames)
    assert seen == ["seratus lima puluh per sembilan puluh"]
    assert spoken(down) == ["Baik."]


async def test_ended_result_ends_pipeline():
    seen: list[str] = []
    api = fake_api([{"tilik_text": "Matur nuwun, sugeng enjang.", "state": "ENDED", "level": "green", "ended": True}], seen)
    brain = TilikBrain(api, transport_name="test")
    brain.session_id = "s1"
    down, _ = await run_test(brain, frames_to_send=utterance("tomatnya sudah panen"), send_end_frame=False)
    assert spoken(down) == ["Matur nuwun, sugeng enjang."]
    assert brain.ended and any(isinstance(f, EndFrame) for f in down)


async def test_api_error_falls_back_without_ending():
    seen: list[str] = []
    api = fake_api([500], seen)
    brain = TilikBrain(api, transport_name="test")
    brain.session_id = "s1"
    down, _ = await run_test(brain, frames_to_send=utterance("halo"))
    assert spoken(down) == [FALLBACK_TEXT] and not brain.ended


async def test_silence_without_transcript_sends_nothing():
    seen: list[str] = []
    brain = TilikBrain(fake_api([], seen), transport_name="test", flush_grace_s=0.1)
    brain.session_id = "s1"
    down, _ = await run_test(brain, frames_to_send=utterance(None))
    assert seen == [] and spoken(down) == []


# ---------- integrasi dengan apps/api sungguhan (docker compose up) ----------

BABAK_1 = [
    "Iya, saya sendiri",
    "Sampun, tadi habis sarapan",
    "seratus lima puluh per sembilan puluh",
    "iya betul",
    "tidak ada keluhan",
    "Tomatnya sudah panen dua keranjang, dibagi ke tetangga",
]


async def _api_up() -> bool:
    try:
        async with httpx.AsyncClient(timeout=2) as c:
            return (await c.get("http://127.0.0.1:8080/v1/health")).status_code == 200
    except httpx.HTTPError:
        return False


async def test_babak_1_against_real_api(tmp_path):
    if not await _api_up():
        pytest.skip("apps/api tidak jalan di :8080")
    api = TilikApi("http://127.0.0.1:8080")
    greeting = await api.start_call("p-sri", auto_answer=True)
    brain = TilikBrain(api, transport_name="test", latency_log=LatencyLog(tmp_path / "lat.jsonl"))
    brain.session_id = greeting["session_id"]
    frames = [f for line in BABAK_1 for f in utterance(line, pause=0.4)]
    down, _ = await run_test(brain, frames_to_send=frames, send_end_frame=False)
    texts = spoken(down)
    assert len(texts) == len(BABAK_1)
    # Titip pesan Mas Dika hanya dibacakan sekali per pesan; DB docker bisa sudah memakainya.
    assert "obat" in " ".join(texts[:2]).lower()
    assert "Seratus lima puluh per sembilan puluh" in texts[2]
    assert brain.ended and brain.last_result["level"] == "green" and brain.last_result["outcome"] == "completed"
    assert any(isinstance(f, EndFrame) for f in down)
    await api.close()
