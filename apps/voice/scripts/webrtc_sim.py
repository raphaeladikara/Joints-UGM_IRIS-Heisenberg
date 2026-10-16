"""Simulator "HP Mbah" lewat WebRTC: memutar ucapan Mbah (WAV) ke server suara dan merekam jawaban TILIK.

Dipakai untuk uji end-to-end babak 1 tanpa mikrofon:
    python scripts/webrtc_sim.py                     # babak 1, pasien p-sri
    python scripts/webrtc_sim.py --record out.wav    # simpan audio TILIK

Ucapan Mbah dibuat sekali lewat ElevenLabs TTS (pcm 16 kHz) dan disimpan di apps/voice/sim_audio/
(tidak di-commit). Alur giliran: tunggu TILIK selesai bicara (hening ≥ --gap detik), lalu putar baris berikutnya.
"""

from __future__ import annotations

import argparse
import asyncio
import fractions
import hashlib
import sys
import time
import wave
from pathlib import Path

import httpx
from urllib.parse import quote
import numpy as np
from aiortc import MediaStreamTrack, RTCPeerConnection, RTCSessionDescription
from av import AudioFrame

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tilik_voice import config  # noqa: E402

RATE = 16000
FRAME = 320  # 20 ms
BABAK_1 = [
    "Iya, saya sendiri.",
    "Sampun, tadi habis sarapan.",
    "Seratus lima puluh per sembilan puluh.",
    "Iya, betul.",
    "Tidak ada keluhan.",
    "Tomatnya sudah panen dua keranjang, dibagi ke tetangga.",
]
CACHE = config.VOICE_ROOT / "sim_audio"


class Mouth(MediaStreamTrack):
    """Track audio keluar: hening, kecuali saat ada ucapan yang diantrekan."""

    kind = "audio"

    def __init__(self):
        super().__init__()
        self._pcm = np.zeros(0, dtype=np.int16)
        self._t0: float | None = None
        self._pts = 0
        self.done_speaking = asyncio.Event()
        self.done_speaking.set()
        self.last_sample_at = 0.0

    def say(self, pcm: np.ndarray) -> None:
        self._pcm = np.concatenate([self._pcm, pcm])
        self.done_speaking.clear()

    async def recv(self) -> AudioFrame:
        if self._t0 is None:
            self._t0 = time.time()
        wait = self._t0 + self._pts / RATE - time.time()
        if wait > 0:
            await asyncio.sleep(wait)
        chunk, self._pcm = self._pcm[:FRAME], self._pcm[FRAME:]
        if len(chunk) and not len(self._pcm):
            self.last_sample_at = time.time()
            self.done_speaking.set()
        chunk = np.pad(chunk, (0, FRAME - len(chunk)))
        frame = AudioFrame.from_ndarray(chunk.reshape(1, -1), format="s16", layout="mono")
        frame.sample_rate = RATE
        frame.pts = self._pts
        frame.time_base = fractions.Fraction(1, RATE)
        self._pts += FRAME
        return frame


class Ear:
    """Dengarkan audio TILIK: catat kapan terakhir ada suara, dan rekam kalau diminta."""

    def __init__(self, record: Path | None):
        self.last_voice = 0.0
        self.first_voice_after: dict[float, float] = {}
        self.heard_any = False
        self._record = record
        self._chunks: list[np.ndarray] = []

    async def run(self, track) -> None:
        while True:
            try:
                frame = await track.recv()
            except Exception:
                return
            pcm = frame.to_ndarray().astype(np.int16).reshape(-1)
            if frame.layout.name == "stereo":
                pcm = pcm[::2]
            if self._record:
                self._chunks.append(pcm)
            if np.sqrt(np.mean(pcm.astype(np.float32) ** 2)) > 300:
                now = time.time()
                self.last_voice = now
                self.heard_any = True

    def save(self, rate: int = 48000) -> None:
        if not self._record or not self._chunks:
            return
        with wave.open(str(self._record), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(np.concatenate(self._chunks).tobytes())


def utterance_pcm(text: str, voice_id: str) -> np.ndarray:
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / f"{hashlib.sha1(f'{voice_id}:{text}'.encode()).hexdigest()[:12]}.wav"
    if not path.exists():
        if not config.ELEVENLABS_API_KEY:
            sys.exit("ELEVENLABS_API_KEY kosong: tidak bisa membuat audio ucapan Mbah")
        r = httpx.post(f"https://api.elevenlabs.io/v1/text-to-speech/{voice_id}", params={"output_format": "pcm_16000"},
                       headers={"xi-api-key": config.ELEVENLABS_API_KEY},
                       json={"text": text, "model_id": config.ELEVENLABS_TTS_MODEL, "language_code": "id"}, timeout=60)
        r.raise_for_status()
        with wave.open(str(path), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(r.content)
    with wave.open(str(path), "rb") as w:
        assert w.getframerate() == RATE and w.getnchannels() == 1
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16)


async def wait_tilik_done(ear: Ear, gap: float, timeout: float = 30) -> None:
    """Tunggu sampai TILIK mulai bicara lalu hening selama `gap` detik."""
    start = time.time()
    while not ear.heard_any or ear.last_voice < start:
        if time.time() - start > timeout:
            raise TimeoutError("TILIK tidak bersuara")
        await asyncio.sleep(0.05)
    while time.time() - ear.last_voice < gap:
        await asyncio.sleep(0.05)


async def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--server", default=f"http://127.0.0.1:{config.VOICE_PORT}")
    ap.add_argument("--patient", default="p-sri")
    ap.add_argument("--voice", default=config._env("ELEVENLABS_SIM_VOICE_ID") or config.ELEVENLABS_VOICE_ID,
                    help="voice ElevenLabs untuk suara Mbah (default ELEVENLABS_SIM_VOICE_ID)")
    ap.add_argument("--gap", type=float, default=1.2, help="hening (detik) yang menandakan TILIK selesai bicara")
    ap.add_argument("--record", type=Path)
    ap.add_argument("--smoke", action="store_true", help="hanya cek sinyal WebRTC + sesi API (tanpa ElevenLabs)")
    args = ap.parse_args()

    lines = [] if args.smoke else [(text, utterance_pcm(text, args.voice)) for text in BABAK_1]
    mouth, ear = Mouth(), Ear(args.record)
    pc = RTCPeerConnection()
    pc.addTrack(mouth)
    pc.createDataChannel("chat")  # pipecat menunggu data channel untuk pesan aplikasi
    listeners: list[asyncio.Task] = []

    @pc.on("track")
    def on_track(track):
        if track.kind == "audio":
            listeners.append(asyncio.create_task(ear.run(track)))

    await pc.setLocalDescription(await pc.createOffer())
    async with httpx.AsyncClient(base_url=args.server, timeout=20) as http:
        r = await http.post("/api/offer", json={"sdp": pc.localDescription.sdp, "type": pc.localDescription.type,
                                                "request_data": {"patient_id": args.patient}})
        r.raise_for_status()
        answer = r.json()
        await pc.setRemoteDescription(RTCSessionDescription(sdp=answer["sdp"], type=answer["type"]))
        print(f"tersambung (pc_id {answer['pc_id']}), menunggu salam TILIK…")

        since, ended = 0, False

        async def drain_events():
            nonlocal since, ended
            ev = (await http.get(f"/api/events/{quote(answer['pc_id'], safe='')}", params={"since": since})).json()
            since = ev["next"]
            for e in ev["events"]:
                if e["type"] == "tilik":
                    print(f"  TILIK [{e['state']}/{e['level']}]: {e['tilik_text']}")
                ended = ended or e["type"] == "ended" or bool(e.get("ended"))

        if args.smoke:
            for _ in range(40):
                await asyncio.sleep(0.25)
                await drain_events()
                if since:
                    break
            print("smoke OK" if since else "smoke GAGAL: tidak ada salam dari API")
            await pc.close()
            return

        for text, pcm in lines:
            await wait_tilik_done(ear, args.gap)
            await drain_events()
            if ended:
                break
            print(f"  Mbah: {text}")
            mouth.say(pcm)
            await mouth.done_speaking.wait()

        deadline = time.time() + 30
        while not ended and time.time() < deadline:
            await asyncio.sleep(0.5)
            await drain_events()
        lat = (await http.get("/latency", params={"transport": "webrtc", "last": len(lines)})).json()

    await pc.close()
    for t in listeners:
        t.cancel()
    ear.save()
    print("selesai" if ended else "TIMEOUT: panggilan belum selesai")
    print("latensi webrtc (semua giliran tercatat):", lat["summary"])


if __name__ == "__main__":
    asyncio.run(main())
