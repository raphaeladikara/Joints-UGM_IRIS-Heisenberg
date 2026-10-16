# apps/voice: server suara KRING (Pipecat)

Telinga dan mulut KRING. Otak percakapan (state machine, Safety Agent, eskalasi) tetap di `apps/api`;
server ini tidak menulis ulang logikanya, hanya mengubah suara jadi teks dan sebaliknya.

```
Twilio Media Streams (μ-law 8 kHz)  ─┐
                                      ├→ Silero VAD → ElevenLabs Scribe realtime (STT)
Browser / SmallWebRTC (16 kHz)      ─┘        → TilikBrain ── POST /v1/calls/{sid}/turns ──→ apps/api
                                              ← tilik_text ←───────────────────────────────┘
                                      → ElevenLabs TTS (eleven_flash_v2_5) → Twilio / browser
```

| Berkas | Isi |
|---|---|
| `tilik_voice/brain.py` | Processor Pipecat: kumpulkan transkrip final satu giliran → API → `TTSSpeakFrame`. Catat latensi |
| `tilik_voice/pipeline.py` | Rakit pipeline satu panggilan (VAD, STT, brain, TTS) untuk transport apa pun |
| `tilik_voice/server.py` | FastAPI: halaman HP Mbah + `/api/offer` (WebRTC), `/calls` + `/twilio/ws` + `/twilio/status` (Twilio), `/latency` |
| `tilik_voice/dialing.py` | Pagar nomor: DEMO_MODE hanya allowlist; 119/112 dan nomor darurat lain tidak pernah ditelepon |
| `tilik_voice/latency.py` | Log JSONL per giliran + ringkasan p50/p95 |
| `scripts/webrtc_sim.py` | "HP Mbah" otomatis: memutar ucapan babak 1 lewat WebRTC dan merekam jawaban KRING |

Alur panggilan:
- **Twilio:** `POST /calls` → API `POST /v1/calls` (berdering) → Twilio menelepon nomor allowlist dengan TwiML
  `<Connect><Stream>` → saat diangkat, WebSocket tersambung → API `/answer` → salam. Tidak diangkat / sibuk / gagal
  → status callback → API `/no-answer`. Saat percakapan selesai WebSocket ditutup dan panggilan ikut berakhir.
- **WebRTC (fallback kalau trial Twilio tidak bisa ke +62):** browser membuka `/`, menekan "Angkat" →
  API `POST /v1/calls` dengan `auto_answer=true` → salam.
- Mbah menutup telepon di tengah jalan → API `/hangup`. Mbah diam 2 menit → panggilan ditutup.

## Menjalankan

Prasyarat: Docker (untuk `apps/api`), [uv](https://docs.astral.sh/uv/), Python 3.12.

```bash
docker compose up --build -d
```

```bash
cd apps/voice
uv venv -p 3.12 .venv
uv pip install -p .venv -r requirements.txt
```

Isi `.env` di **akar repo** (salin dari `.env.example`, jangan di-commit). Minimal untuk WebRTC:
`ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID`.

```bash
.venv/Scripts/python -m tilik_voice.server
```

(Linux/macOS: `.venv/bin/python`.) Cek `http://127.0.0.1:7860/health`: menunjukkan API tersambung dan kunci yang belum diisi.

### Babak 1 lewat browser (WebRTC)

Buka `http://127.0.0.1:7860/` di Chrome, pilih **Bu Sri**, tekan **Angkat telepon KRING**, izinkan mikrofon,
pakai headset. Jawab seperti skenario babak 1:

1. "Iya, saya sendiri"
2. "Sampun, tadi habis sarapan"
3. "Seratus lima puluh per sembilan puluh"
4. "Iya, betul"
5. "Tidak ada keluhan"
6. "Tomatnya sudah panen dua keranjang, dibagi ke tetangga"

Teks KRING, state, dan level tampil di halaman. Hasilnya ikut muncul di aplikasi Flutter (Daftar Kring, rapor keluarga).

### Babak 1 otomatis (tanpa mikrofon)

```bash
.venv/Scripts/python scripts/webrtc_sim.py --record tilik_babak1.wav
```

Ucapan Mbah dibuat sekali lewat ElevenLabs TTS lalu disimpan di `sim_audio/` (tidak di-commit). Skrip mencetak
transkrip dan ringkasan latensi. `--smoke` hanya mengecek sinyal WebRTC + sesi API, tanpa ElevenLabs.

### Twilio (panggilan telepon sungguhan)

1. Isi `TWILIO_ACCOUNT_SID`, `TWILIO_API_KEY_SID`, `TWILIO_API_KEY_SECRET`, `TWILIO_PHONE_NUMBER`,
   `DEMO_ALLOWLIST`, dan `DEMO_PATIENT_PHONE` (nomor HP yang jadi "Mbah"). Pada akun trial nomor itu harus
   sudah diverifikasi di konsol Twilio.
2. Buka tunnel ke server suara dan salin URL `https://….trycloudflare.com` ke `PUBLIC_BASE_URL`, lalu restart server:

   ```bash
   cloudflared tunnel --url http://127.0.0.1:7860
   ```

3. Mulai panggilan:

   ```bash
   curl -X POST http://127.0.0.1:7860/calls -H "Content-Type: application/json" -d "{\"patient_id\": \"p-sri\"}"
   ```

Nomor di luar allowlist ditolak `403` sebelum Twilio dihubungi. Pesan error Twilio (mis. nomor belum
terverifikasi) diteruskan apa adanya dengan status `502`.

## Latensi

Setiap giliran dicatat di `logs/latency.jsonl` (tidak di-commit). Ringkasan: `GET /latency?transport=webrtc`.

| Kolom | Arti |
|---|---|
| `total_ms` | akhir ucapan Mbah → audio KRING pertama keluar dari server (target p50 ≤ 1,5 s) |
| `vad_wait_ms` | hening yang ditunggu VAD sebelum memutuskan giliran selesai (`TILIK_VAD_STOP_SECS`) |
| `stt_ms` | commit VAD → transkrip final Scribe |
| `api_ms` | `POST /turns` (dialog manager + Safety Agent) |
| `tts_first_audio_ms` | teks dikirim ke TTS → audio pertama diputar |

Akhir ucapan diperkirakan sebagai waktu keputusan VAD dikurangi `stop_secs`. Jaringan Twilio ↔ HP dan buffer
jitter browser tidak ikut terukur; tambahkan ±100–300 ms untuk latensi yang dirasakan Mbah.

Hasil pengukuran (diisi setelah tiap uji):

| Tanggal | Transport | Giliran | p50 total | p95 total | Catatan |
|---|---|---|---|---|---|
| 2026-10-16 | teks (tes integrasi) | 6 | – | – | Hanya `api_ms`: 20–60 ms per giliran, jalur aturan tanpa LLM |
| 2026-10-16 | WebRTC (`webrtc_sim.py`, babak 1 ×2, LLM aktif) | 12 | 1.780 ms | 5.101 ms | VAD 700 · STT 343 · API 8 (p95 1.970, LLM) · TTS pertama 162 (p95 4.006, pesan keluarga panjang) |

## Tes

```bash
.venv/Scripts/python -m pytest -q
```

Tes memakai frame VAD/STT tiruan (tanpa audio dan tanpa kredit ElevenLabs). `test_babak_1_against_real_api`
menjalankan babak 1 lewat `TilikBrain` ke `apps/api` sungguhan di :8080 dan dilewati kalau API mati.

## Batasan saat ini

- Belum ada barge-in: kalau Mbah bicara saat KRING masih bicara, ucapannya dikirim sebagai giliran berikutnya
  setelah KRING selesai, bukan memotong KRING.
- Eskalasi 🔴 lewat suara (alihkan ke `<Conference>`, telepon Sahabat Kring dan anak) belum disambungkan. API tetap
  membuat alert dan notifikasi simulasi seperti biasa.
- Panggilan Twilio juga membuat HP Mbah di aplikasi Flutter berdering. Jangan diangkat dari aplikasi saat
  panggilan telepon sungguhan sedang berjalan.
- Status callback Twilio tidak divalidasi tanda tangan (butuh auth token, sedangkan kita memakai API key).
  Sebagai gantinya URL callback dan WebSocket memakai token acak per panggilan.
