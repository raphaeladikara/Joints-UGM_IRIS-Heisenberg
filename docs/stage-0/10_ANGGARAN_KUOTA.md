# 10 · Anggaran & Kuota

Prinsip dari tim: **pakai yang paling hemat.** Yang berbayar hanya ElevenLabs Starter. OpenAI dipakai dari billing yang sudah ada dengan model termurah yang lolos uji. Twilio tetap trial. Sisanya free tier.

> Angka harga di dokumen ini berasal dari sumber sekunder dan **harus dicek ulang di dashboard/halaman pricing resmi** (Q-05). Tujuannya untuk perencanaan, bukan tagihan.

---

## 1. Ringkasan layanan

| Layanan | Plan | Biaya | Batas penting | Risiko |
|---|---|---|---|---|
| ElevenLabs | Starter | ±$6/bulan (sumber sekunder: $5–6) | ±**30.000 kredit/bulan**, dipakai **bersama** untuk TTS & STT. **Tidak ada overage**: kalau habis, berhenti sampai reset | 🔴 Kredit habis sebelum demo final |
| OpenAI | Billing yang ada | Per token | Batas yang kita pasang sendiri di dashboard | 🟠 Biaya bocor kalau tidak dibatasi |
| Twilio | Trial | Saldo trial (jumlah belum diketahui, Q-04) | Hanya ke **maksimal 5 nomor terverifikasi**. Ada pesan trial di awal panggilan. Panggilan internasional mungkin dibatasi (uji S-01) | 🔴 Tidak bisa ke +62 → fallback WebRTC |
| WhatsApp Cloud API | Nomor tes | Gratis untuk uji (cek ketentuan) | Jumlah penerima nomor tes terbatas. Pesan inisiatif bisnis di luar jendela 24 jam butuh template | 🟡 |
| Supabase | Free | 0 | Project free bisa di-*pause* kalau lama tidak aktif (cek ketentuan terbaru) | 🟡 Harus diaktifkan lagi sebelum demo |
| Vercel | Hobby | 0 | Penggunaan non-komersial | 🟢 |
| Cloudflare Quick Tunnel | Tanpa akun | 0 | URL berubah setiap dijalankan (sistem dirancang untuk itu) | 🟢 |

## 2. Rencana alokasi kredit ElevenLabs (30.000)

> Tarif kredit **per karakter TTS** dan **per menit STT** berbeda antar model dan **belum diverifikasi** (sumber sekunder menyebut sekitar 1 kredit/karakter dan ±330 kredit/menit Scribe). Ukur di spike S-02/S-03, lalu perbarui tabel ini.

| Pos | Porsi | Kredit | Catatan |
|---|---|---|---|
| Spike S-02 + S-03 | 10% | 3.000 | Sampel kecil saja |
| Cache frasa statis (sapaan, pertanyaan baku, edukasi, briefing) | 10% | 3.000 | Di-generate **sekali**, disimpan sebagai file audio |
| Pengembangan Stage 1 (panggilan uji live) | 25% | 7.500 | Sebagian besar pengembangan dilakukan dalam **mode teks** |
| Evaluasi audio E2 | 10% | 3.000 | 5–10 skenario |
| Rekaman video | 10% | 3.000 | Rekam per babak, ulang seperlunya |
| Stage 2 (fitur + uji lansia) | 20% | 6.000 | |
| **Cadangan demo final + gladi** | 15% | 4.500 | **Tidak boleh dipakai sebelum 31 Okt** |

**Pertanyaan kritis (Q-05):** kapan kredit di-reset? Kalau reset jatuh antara 18 Okt dan 1 Nov, alokasi Stage 2 bisa memakai kuota bulan berikutnya. Kalau tidak, tabel di atas adalah seluruh jatah sampai final.

## 3. Strategi hemat (wajib diterapkan)

| Strategi | Dampak |
|---|---|
| **Mode teks** untuk pengembangan dialog & safety (CLI tanpa STT/TTS) | Kredit ElevenLabs hanya dipakai saat uji suara |
| **Cache TTS**: kunci = hash(teks + voice + model + format). Frasa statis tidak pernah di-generate ulang | Hemat besar untuk sapaan/pertanyaan baku |
| Respons TILIK pendek (1–2 kalimat per giliran) | Hemat karakter TTS + lebih ramah lansia |
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
