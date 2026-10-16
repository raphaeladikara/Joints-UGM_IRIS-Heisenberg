# 10 · Anggaran & Kuota

> **Pembaruan 16 Okt 2026 (prototipe & framing).** Nama produk: **KRING** (dulu TILIK). Framing utama: **teman bicara + jembatan keluarga dua arah**, kesehatan dan jalur cepat stroke sebagai lapis kedua dan ketiga. Kanal WhatsApp dan web Next.js digantikan **satu aplikasi KRING** (Flutter, 5 peran); lansia tetap lewat telepon biasa. Prototipe memakai FastAPI + SQLite (Supabase = rencana produksi). Lihat [03 §0](03_ARSITEKTUR_TEKNIS.md) dan [Laporan Konsep Kerja](../LAPORAN_KONSEP_KERJA.md).

Prinsip dari tim: **pakai yang paling hemat.** Yang berbayar hanya ElevenLabs Starter. OpenAI dipakai dari billing yang sudah ada dengan model termurah yang lolos uji. Twilio tetap trial. Sisanya free tier.

> Angka harga di dokumen ini berasal dari sumber sekunder dan **harus dicek ulang di dashboard/halaman pricing resmi** (Q-05). Tujuannya untuk perencanaan, bukan tagihan.

---

## 1. Ringkasan layanan

| Layanan | Plan | Biaya | Batas penting | Risiko |
|---|---|---|---|---|
| ElevenLabs | Starter | ±$6/bulan (sumber sekunder: $5–6) | ±30.000 kredit/bulan, dipakai **bersama** untuk TTS & STT. **Sisa per 15 Okt: ±15.000.** **Tidak ada overage**: kalau habis, berhenti sampai reset | 🔴 Kredit habis sebelum video/demo final |
| OpenAI | Billing yang ada | Per token | Batas yang kita pasang sendiri di dashboard | 🟠 Biaya bocor kalau tidak dibatasi |
| Twilio | Trial | Saldo trial (jumlah belum diketahui, Q-04) | Hanya ke **maksimal 5 nomor terverifikasi**. Ada pesan trial di awal panggilan. Panggilan internasional mungkin dibatasi (uji S-01) | 🔴 Tidak bisa ke +62 → fallback WebRTC |
| WhatsApp Cloud API | Nomor tes | Gratis untuk uji (cek ketentuan) | Jumlah penerima nomor tes terbatas. Pesan inisiatif bisnis di luar jendela 24 jam butuh template | 🟡 |
| Supabase | Free | 0 | Project free bisa di-*pause* kalau lama tidak aktif (cek ketentuan terbaru) | 🟡 Harus diaktifkan lagi sebelum demo |
| Vercel | Hobby | 0 | Penggunaan non-komersial | 🟢 |
| Cloudflare Quick Tunnel | Tanpa akun | 0 | URL berubah setiap dijalankan (sistem dirancang untuk itu) | 🟢 |

## 2. Rencana alokasi kredit ElevenLabs (sisa ±15.000 per 15 Okt)

**Fakta (dari tim, 15 Okt):** sisa kredit ±**15.000**. **Prioritas tim: kredit harus cukup supaya demo di video benar-benar berjalan.**
Tanggal reset kredit **belum diketahui** (Q-05). Sampai diketahui, anggap 15.000 ini adalah **seluruh jatah sampai final**.

> Tarif kredit **per karakter TTS** dan **per menit STT** berbeda antar model dan **belum diverifikasi** (sumber sekunder menyebut sekitar 1 kredit/karakter dan ±330 kredit/menit Scribe). Ukur di spike S-02/S-03, lalu perbarui tabel ini.

| Pos | Kredit | Catatan |
|---|---|---|
| Spike S-02 + S-03 | 800 | Sampel minimal: 3 kalimat TTS per model kandidat, ±1 menit audio STT |
| Cache frasa statis (sapaan, pertanyaan baku, edukasi, briefing) | 1.200 | Di-generate **sekali** setelah skrip final, disimpan sebagai file audio |
| Pengembangan Stage 1 (panggilan uji live) | 3.000 | Dialog & safety dikembangkan dalam **mode teks**. Uji suara hanya untuk integrasi |
| Evaluasi audio E2 | 700 | 3–5 skenario saja (evaluasi utama tetap mode teks) |
| **Rekaman video demo (babak 1 + 2, termasuk retake)** | **4.000** | **Prioritas utama.** Gladi dulu dalam mode teks, lalu rekam suara. Maksimal ±3 take per babak |
| Stage 2 (fitur + uji lansia) | 2.300 | Dipakai hanya kalau lolos final (23 Okt) |
| **Cadangan demo final + gladi** | 3.000 | **Tidak boleh dipakai sebelum 31 Okt** |
| **Total** | **15.000** | |

### Credit guard (wajib di Stage 1)
- Sebelum memulai panggilan suara, server membaca sisa kredit (dashboard / endpoint subscription API ElevenLabs, dicek di dokumentasi saat implementasi).
- Kalau sisa ≤ **batas cadangan** (awal: 7.000 = video + cadangan final), panggilan uji **non-demo ditolak**, dan pengembangan wajib pindah ke mode teks.
- Batas ini diturunkan setelah video selesai direkam.

## 3. Strategi hemat (wajib diterapkan)

| Strategi | Dampak |
|---|---|
| **Mode teks** untuk pengembangan dialog & safety (CLI tanpa STT/TTS) | Kredit ElevenLabs hanya dipakai saat uji suara |
| **Cache TTS**: kunci = hash(teks + voice + model + format). Frasa statis tidak pernah di-generate ulang | Hemat besar untuk sapaan/pertanyaan baku |
| Respons KRING pendek (1–2 kalimat per giliran) | Hemat karakter TTS + lebih ramah lansia |
| Harness evaluasi E1 tanpa audio | 0 kredit ElevenLabs |
| Audio uji E2 direkam sekali, dipakai ulang | STT hanya untuk skenario terpilih |
| Pantau kredit setiap hari (dashboard / endpoint subscription API ElevenLabs) | Hindari kehabisan mendadak |
| Pengembangan dengan WebRTC lokal | Hemat saldo trial Twilio |
| Batas pemakaian di dashboard OpenAI | Mencegah biaya tak terduga |

## 4. Perkiraan biaya OpenAI (rumus)

```
biaya_per_panggilan ≈ Σ_giliran (token_input × harga_input + token_output × harga_output)
                     + klasifikasi safety + ekstraksi memori
```
- Isi `harga_input/output` dari halaman pricing resmi untuk model yang terpilih di S-04.
- Ukur rata-rata token per panggilan di harness E1 → hitung biaya per 100 panggilan → masuk ke slide model bisnis.

## 5. Log pemakaian (isi setiap hari)

| Tanggal | ElevenLabs kredit terpakai / sisa | OpenAI biaya | Twilio saldo | Catatan |
|---|---|---|---|---|
| 15 Okt | | | | |
| 16 Okt | | | | |
| 17 Okt | | | | |
| 18 Okt | | | | |

## Biaya terukur (16 Okt 2026)

Diukur dari satu panggilan pagi di uji E2 (75 detik, 1.029 karakter TTS, 564 token masuk + 95 token keluar, diukur dengan gpt-5.4-mini; token penalaran gpt-6-luna bisa menambah sedikit) dengan harga
publik per 16 Okt: gpt-6-luna US$0,10/0,50 per juta token, ElevenLabs Flash US$0,04/1.000 karakter, Scribe Realtime
US$0,39/jam, Twilio ke ponsel Indonesia US$0,1066/menit + Media Streams US$0,0044/menit (dibulatkan 2 menit).

| Pos | Per 100 panggilan |
|---|---|
| Telepon (Twilio) | US$22,2 |
| TTS | US$4,1 |
| STT | US$0,8 |
| LLM | ±US$0,01 |
| **Total** | **±US$27,1** (tanpa PSTN/WebRTC: ±US$5,0) |

Pemakaian kredit ElevenLabs per 16 Okt malam: 23.493 dari 40.000 karakter (paket Starter).
