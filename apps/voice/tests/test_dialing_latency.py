"""Pagar nomor DEMO_MODE dan hitungan persentil latensi."""

import pytest

from tilik_voice.dialing import DialBlocked, check_destination
from tilik_voice.latency import LatencyLog, TurnTiming, percentile

ALLOW = {"+6281200000001"}


@pytest.mark.parametrize("number", ["119", "112", "+62119", "+62112", "1 1 9"])
def test_emergency_numbers_never_dialed(number):
    for demo in (True, False):
        with pytest.raises(DialBlocked):
            check_destination(number, demo_mode=demo, allowlist=ALLOW | {number})


def test_demo_mode_allowlist():
    assert check_destination("+62 812-0000-0001", demo_mode=True, allowlist=ALLOW) == "+6281200000001"
    with pytest.raises(DialBlocked):
        check_destination("+6281299999999", demo_mode=True, allowlist=ALLOW)
    assert check_destination("+6281299999999", demo_mode=False, allowlist=ALLOW) == "+6281299999999"
    with pytest.raises(DialBlocked):
        check_destination("", demo_mode=True, allowlist=ALLOW)


def test_percentile_and_summary(tmp_path):
    assert percentile([], 50) is None
    assert percentile([100, 200, 300, 400], 50) == 250
    assert percentile([100, 200, 300, 400], 95) == pytest.approx(385)
    log = LatencyLog(tmp_path / "lat.jsonl")
    for total in (900, 1100, 1300):
        t = TurnTiming("s1", "webrtc", speech_end=0.0, vad_stop=0.7, stt_final=0.8, api_done=0.85, audio_start=total / 1000)
        log.write(t)
    s = log.summary()
    assert s["turns"] == 3 and s["total_ms"]["p50"] == 1100 and s["vad_wait_ms"]["p50"] == 700
