# 11 · Register Risiko

> **Pembaruan 16 Okt 2026 (prototipe & framing).** Nama produk: **KRING** (dulu TILIK). Framing utama: **teman bicara + jembatan keluarga dua arah**, kesehatan dan jalur cepat stroke sebagai lapis kedua dan ketiga. Kanal WhatsApp dan web Next.js digantikan **satu aplikasi KRING** (Flutter, 5 peran); lansia tetap lewat telepon biasa. Prototipe memakai FastAPI + SQLite (Supabase = rencana produksi). Lihat [03 §0](03_ARSITEKTUR_TEKNIS.md) dan [Laporan Konsep Kerja](../LAPORAN_KONSEP_KERJA.md).

Skala: Kemungkinan (K) dan Dampak (D) = Rendah / Sedang / Tinggi.

| ID | Risiko | K | D | Mitigasi | Pemicu rencana B | Job |
|---|---|---|---|---|---|---|
| R-01 | Twilio trial tidak bisa menelepon +62 | Sedang | Tinggi | Uji S-01 di Stage 0 | S-01 gagal → transport WebRTC + eskalasi via WA & Board IGD | WS-1 |
| R-02 | Pesan "trial account" Twilio merusak momen demo | Tinggi | Sedang | Diakui di narasi demo, atau demo babak telepon direkam. Upgrade = keputusan budget tim | Tim memutuskan saat persiapan final | WS-10 |
| R-03 | **Kredit ElevenLabs habis** sebelum demo final | Sedang | Tinggi | Alokasi + cadangan 15% + mode teks + cache TTS ([10](10_ANGGARAN_KUOTA.md)) | Sisa < cadangan sebelum 31 Okt → stop uji suara, hanya teks | WS-10 |
| R-04 | TTS/STT bahasa Jawa kurang bagus atau latensi tinggi | Sedang | Sedang | Uji S-02/S-03. Bahasa Indonesia sebagai default, frasa Jawa dari cache | Jawa diturunkan ke "sapaan saja" | WS-1/7 |
| R-05 | Latensi total > 1,5 s | Sedang | Sedang | Ukur sejak hari pertama. Pilih model cepat. Respons pendek | Pakai model OpenAI lebih cepat walau sedikit lebih mahal (keputusan tim) | WS-1/2 |
| R-06 | Waktu 3 hari tidak cukup untuk semua MUST | Tinggi | Tinggi | Prioritas P-A/P-B/P-C, gate harian, freeze fitur 18 Okt siang | G1/G2 gagal → potong P-B/P-C | Semua |
| R-07 | Deadline resmi panitia lebih awal dari 18 Okt | **Belum diketahui** | Tinggi | Tanyakan CP hari ini (Q-01) | Submit deliverable seadanya + lanjutkan MVP untuk final | WS-9 |
| R-08 | LLM melanggar guardrail (dosis/diagnosis/mengaku manusia) | Sedang | Tinggi | Guardrail prompt + validasi kode + persona uji P-13/14/15 | Tambah aturan deterministik pasca-filter | WS-2/6 |
| R-09 | Alarm palsu 🔴 terlalu sering | Sedang | Sedang | Kriteria 🔴 mayor saja + ukur di harness | Tuning aturan/prompt | WS-2/6 |
| R-10 | Konferensi Twilio gagal/rumit | Sedang | Tinggi | Spike S-05 | Eskalasi disederhanakan: telepon anak + briefing saja (tanpa konferensi) | WS-1 |
| R-11 | Sinyal/jaringan buruk di lokasi final | Sedang | Tinggi | Gladi di lokasi saat warm-up, hotspot cadangan, video cadangan per babak | Putar video | WS-9 |
| R-12 | Konten klinis salah (belum direview nakes) | Sedang | Tinggi | Label "draf" + cari reviewer (Q-08) + framing "skrining & percepatan rujukan" | Kurangi klaim di materi | WS-7 |
| R-13 | Secret bocor ke repo publik | Rendah | Tinggi | `.gitignore`, `.env.example` tanpa nilai, review sebelum push | Rotasi kunci segera | WS-10 |
| R-14 | Supabase free ter-pause saat demo | Sedang | Sedang | Aktifkan & cek H-1 | Restore project | WS-3 |
| R-15 | Juri menilai "wrapper API" | Sedang | Tinggi | Tonjolkan state machine, safety OR-gate, eskalasi, harness + angka | – | WS-9 |
| R-16 | Kritik etika ("AI menggantikan anak", dll.) | Tinggi | Sedang | Fitur ETH-xx + slide Etika by Design + jawaban QnA | – | WS-9 |
| R-17 | Laptop server mati/bermasalah saat demo | Rendah | Tinggi | Laptop cadangan yang sudah di-setup + video | Pindah laptop | WS-10 |
| R-18 | Data RS (CT 24 jam) ternyata salah | Sedang | Sedang | Verifikasi (Q-13), label "(simulasi)" | Ganti RS di data demo | WS-7 |
| R-19 | Persyaratan Python/library Pipecat bentrok di laptop (OS) | Sedang | Sedang | Spike S-08 lebih awal | Pakai WSL/laptop lain | WS-1 |
