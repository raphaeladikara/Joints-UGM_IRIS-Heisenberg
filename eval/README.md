# eval: harness evaluasi KRING

| Skrip | Tingkat | Butuh | Mengukur |
|---|---|---|---|
| `run_eval.py` | E1 teks | Python + dependensi `apps/api` | Recall 🔴 (35 skenario kritis), alarm palsu per 100 panggilan non-kritis, F1 ekstraksi, disclosure, 8 uji guardrail/kebocoran, latensi API, waktu pemicu 🔴 → panggilan darurat tercatat |
| `run_eval.py --llm` | E1 teks | + `OPENAI_API_KEY` di `.env` | Sama, dengan jalur LLM aktif (OR-gate) |
| `run_wer.py` | E2 audio | + `ELEVENLABS_API_KEY`, `ffmpeg` | WER Scribe pada audio 8 kHz mu-law, Indonesia vs Jawa (suara "Mbah" sintetis, cache di `apps/voice/sim_audio/`) |
| `apps/voice/scripts/webrtc_sim.py` | E2 audio | API + server suara jalan | Latensi suara end-to-end per giliran (`GET /latency`) |

```bash
py -m pip install -r apps/api/requirements-dev.txt   # Python 3.12/3.13
py eval/run_eval.py
py eval/run_eval.py --llm
py eval/run_wer.py
```

Setiap panggilan E1 memakai database sementara yang di-seed ulang (pasien Bu Sri, data fiktif). Laporan JSON tersimpan di
`reports/` dengan mode, model, dan commit. Skenario ditulis tim; kuncinya draf dan belum direview tenaga kesehatan.
Saat memperbaiki aturan, **jangan** hanya mengejar skenario di sini: tambahkan set skenario baru untuk uji ulang.

## Hasil baseline (16 Okt 2026, commit 167fc90)

| Metrik | Aturan | Aturan + gpt-6-luna |
|---|---|---|
| Recall 🔴 (35) | 26/35 | 35/35 |
| Alarm palsu 🔴 / 100 | 13 | 13 |
| F1 ekstraksi | 0,915 | 0,915 |
| Disclosure | 20/20 | 20/20 |
| Guardrail lolos | 6/8 | 6/8 |
| Latensi giliran API p50 | 5,3 ms | 6,0 ms (giliran gejala dengan LLM: p50 2,3 s, p95 4,5 s) |

E2: latensi suara p50 1,21 s / p95 4,6 s (12 giliran WebRTC); WER 8 kHz 0% Indonesia (48 kata), 11,8% Jawa (34 kata).
Run sebelumnya dengan gpt-5.4-mini (commit 68185b7): recall 34/35, giliran gejala LLM p50 1,4 s; laporannya ada di riwayat git.
Temuan dan rencana perbaikan: [Laporan Konsep Kerja §7](../docs/LAPORAN_KONSEP_KERJA.md).
