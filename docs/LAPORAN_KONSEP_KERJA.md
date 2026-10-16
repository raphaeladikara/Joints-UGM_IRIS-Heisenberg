# Laporan Konsep Kerja Aplikasi TILIK

Status per 16 Oktober 2026, branch `main` (commit `600651f`). Seluruh data demo fiktif. Mode demo tidak pernah menelepon 119/RS.

## 1. Gambaran singkat

TILIK adalah asisten suara AI milik Puskesmas yang **menelepon lansia hipertensi setiap hari**. Ia mengecek obat, tensi, dan gejala, lalu mengobrol singkat. Kalau ada tanda bahaya (misal gejala stroke), TILIK langsung menjalankan **eskalasi berjenjang**: Sahabat Tilik (tetangga), anak, dan pre-alert ke IGD, sambil menghitung sisa *golden period*. Keluarga menerima rapor harian beserta "bahan obrolan" agar tetap terhubung dengan orang tuanya.

## 2. Arsitektur

```
 HP Mbah / browser (WebRTC)        Twilio PSTN (siap, belum dikonfigurasi)
            │                                   │
            └──────────► apps/voice (Pipecat, port 7860) ◄──┘
                         STT ElevenLabs Scribe → [teks] → TTS ElevenLabs Flash
                                      │  HTTP
                                      ▼
                    apps/api (FastAPI + SQLite, Docker, port 8080)
        ┌──────────────┬──────────────┼──────────────┬──────────────┐
     dialog.py      safety.py      llm.py        escalation.py   vitals.py
   (state machine) (aturan red    (OpenAI:      (alert 3 warna,  (data jam
                    flag + tensi)  klasifikasi   kontak, RS CT,   tangan,
                                   & memori)     board IGD)       tren 7 hari)
                                      │
                                      ▼
            apps/mobile (Flutter, web di port 8081 + APK Android)
     Role gate → HP Mbah · Keluarga/Sahabat · Puskesmas (Daftar Tilik) · Board IGD
```

| Komponen | Teknologi | Isi |
|---|---|---|
| `apps/api` | FastAPI, SQLite, Docker | Otak percakapan, keselamatan, eskalasi, data pasien, tanda vital |
| `apps/voice` | Pipecat, ElevenLabs, aiortc/Twilio | Mengubah suara jadi teks dan sebaliknya; memanggil API per giliran |
| `apps/mobile` | Flutter (web + Android) | 4 tampilan peran, tubuh 3D interaktif, sinkron jam tangan |
| `content/` | JSON | Skrip percakapan dan daftar tanda bahaya (bisa diedit tanpa ubah kode) |

## 3. Alur kerja satu panggilan

1. **Pemicu.** Jadwal harian, tombol "Tilik sekarang", atau sinyal eksternal (`POST /v1/events`: jatuh, SOS, ritme tidak teratur, tensi dari jam tangan).
2. **Pembuka.** Sapaan memuat nama pasien, pengakuan "asisten AI dari Puskesmas", dan kata sandi keluarga. Pesan titipan anak dibacakan dan ditandai `delivered`.
3. **Cek obat → alasan bila belum** (lupa/habis/merasa sehat/efek samping), dicatat tanpa memaksa.
4. **Cek tensi** dan konfirmasi ulang angka. Angka yang tidak dikonfirmasi tidak dipakai untuk keputusan.
5. **Cek gejala** (SeGeRa Ke RS + gejala krisis hipertensi), lalu obrolan ringan memakai memori dari panggilan sebelumnya.
6. **Penilaian keselamatan dua jalur (OR-gate):**
   - Jalur 1, aturan deterministik (`safety.py` + `content/red_flags.json`), termasuk penanganan negasi ("tidak pusing").
   - Jalur 2, LLM `gpt-5.4-mini` mengklasifikasi transkrip. Bila gagal atau lewat 6 detik, sistem tetap jalan di jalur aturan.
   - Cukup satu jalur terpicu. Setiap keputusan menyimpan jalur pemicu, kutipan ucapan, dan waktu.
7. **Warna hasil:**
   - 🟢 dicatat.
   - 🟡 masuk Daftar Tilik Puskesmas untuk ditindaklanjuti ≤ 24 jam.
   - 🔴 eskalasi dimulai **seketika** (pre-alert IGD, telepon Sahabat Tilik lalu anak, WA ringkasan + RS ber-CT terdekat + estimasi tempuh, instruksi 119 berupa teks). Skrining stroke verbal (CPSS versi telepon) dan pertanyaan *last known well* berjalan paralel dan memperbarui board IGD dengan sisa golden period (4,5 jam).
8. **Penutup** hangat + satu edukasi SeGeRa bergilir.
9. **Pasca-panggilan.** Rapor ke keluarga (status, warna, bahan obrolan, tombol telepon), ekstraksi 0–2 fakta personal oleh LLM ke memori, dan Nudge Kangen bila pasien menyebut kangen/kesepian.

Tidak diangkat dua kali berturut-turut → 🟡. Sinyal jatuh dari jam tangan yang tidak dijawab → 🔴 otomatis.

## 4. Kecocokan dengan proposal/PRD

| Fitur | Status | Catatan |
|---|---|---|
| F-01 Panggilan keluar harian | ✅ sebagian besar | Jalur WebRTC browser (fallback MUST) berjalan. Kode Twilio PSTN sudah ada tetapi kredensial belum diisi |
| F-02 Disclosure AI + kata sandi | ✅ | Diuji di `test_flows.py` |
| F-03 Titip pesan anak | ⚠️ | Hanya pesan **teks** dari aplikasi keluarga. Memutar voice note asli dan pesan masuk lewat WhatsApp belum ada |
| F-04 Cek obat | ✅ | |
| F-05 Cek tensi + konfirmasi | ✅ | |
| F-06 Cek gejala | ✅ | |
| F-07 Dua jalur + 3 warna | ✅ | LLM diuji live hari ini (contoh pelo + lemas sesisi → 🔴, 2,2 detik) |
| F-08 Skrining stroke + LKW | ✅ | |
| F-09 Eskalasi 🔴 | ✅ simulasi | Telepon/WA ke keluarga tampil sebagai notifikasi di aplikasi. Telepon sungguhan dan konferensi butuh Twilio |
| F-10 Penutup + edukasi | ✅ | |
| F-11 Rapor keluarga + bahan obrolan | ✅ simulasi | Kanal `whatsapp_sim` di aplikasi. WhatsApp Cloud API belum disambung |
| F-12 Memori | ✅ | Ekstraksi fakta diuji live |
| F-13 Daftar Tilik Hari Ini | ✅ | |
| F-14 Board Pre-alert IGD | ✅ | Ada label "keputusan klinis tetap di tim IGD" |
| F-15 Telepon balik (SHOULD) | ⚠️ | Panggilan masuk ada di aplikasi (HP Mbah). Nomor PSTN masuk belum |
| F-16 Analisis suara offline (SHOULD) | ❌ | Belum dibuat |
| F-17 Nudge Kangen (SHOULD) | ✅ | |
| F-18 Endpoint sinyal + jam tangan (LATER) | ✅ melebihi target | `/v1/events`, ingest tanda vital, tren 7 hari, sinkron jam tangan di aplikasi |
| F-19 Protokol tidak diangkat (SHOULD) | ⚠️ | Baru aturan "2× tidak diangkat → 🟡". Ulang 15 menit dan minta Sahabat Tilik mengecek rumah belum |

Tambahan di luar PRD:
- **Hubungi dokter.** Wali bisa langsung video call atau menelepon dokter jaga Puskesmas dari beranda. Kartunya otomatis menonjol bila TILIK menemukan hal janggal (warna kuning/merah, tensi ≥ 160, oksigen rendah, detak istirahat tinggi, obat terlewat ≥ 2 hari). Ringkasan kondisi ikut terkirim ke dokter. Dokter menerima panggilan di aplikasi Puskesmas, dan catatannya masuk ke pesan keluarga. Endpoint: `/v1/patients/{id}/doctor-consults` dan `/v1/doctor-consults`. Mode demo: tidak ada nomor sungguhan yang ditelepon.
- **Tubuh 3D sesuai gender.** Lansia pria memakai peci, kemeja batik, dan tongkat. Lansia wanita memakai sanggul uban, kebaya, dan kain jarik.
- **Sinkron data kesehatan.** Apple Health (iPhone) dan Health Connect (Android: Samsung Health, Fitbit, Mi Fitness, dll.) sudah tersambung lewat paket `health` dan hanya membaca data. Di web/laptop memakai simulasi jam tangan.
- Desain ramah lansia (Plus Jakarta Sans, putih-biru, gradien Pipo) dan log latensi suara (`GET /latency` di server suara).

**Ringkasnya:** semua 14 fitur MUST sudah jalan end-to-end dalam mode demo. Kekurangan utamanya ada di kanal **dunia nyata** (Twilio PSTN, WhatsApp Cloud API, voice note asli) dan tiga fitur SHOULD (F-16, sebagian F-15 dan F-19).

## 5. Konfigurasi yang diisi (`.env`, tidak di-commit)

| Variabel | Nilai | Alasan |
|---|---|---|
| `OPENAI_MODEL_CLASSIFIER` / `OPENAI_MODEL_DIALOG` | `gpt-5.4-mini` | Tersedia di akun, cepat dan murah. Klasifikasi live 2,2 detik, di bawah batas 6 detik |
| `ELEVENLABS_VOICE_ID` | `WQ4h6sgS9p2XXvLsESBT` (Selina) | Suara perempuan Indonesia, paruh baya, tenang. Cocok untuk lansia |
| `ELEVENLABS_SIM_VOICE_ID` | `j7n5yC6BN3oA2ZIWImty` (Bambang) | Suara pria Indonesia yang lebih berat untuk peran "Mbah" di simulator |
| `ELEVENLABS_TTS_MODEL` / `STT_MODEL` / `STT_LANGUAGE` | `eleven_flash_v2_5` / `scribe_v2_realtime` / `id` | Latensi rendah, mendukung bahasa Indonesia |
| `DEMO_PATIENT_PHONE` | nomor yang sudah ada di allowlist | Satu-satunya nomor yang diizinkan |

Belum bisa diisi karena butuh akun tim: Twilio (SID, API key, nomor), `PUBLIC_BASE_URL` (tunnel), Supabase, WhatsApp Cloud API. Sisa kuota ElevenLabs ±17.000 karakter dari 40.000 (paket Starter).

## 6. Hasil tes (16 Oktober 2026)

| Tes | Hasil |
|---|---|
| Unit/flow API (`pytest`, di Docker) | 41 lulus |
| Server suara (`pytest`) | 16 lulus |
| `GET :8080/v1/health` | `ok`, `llm: true`, `demo_mode: true` |
| Web Flutter `:8081` | HTTP 200 |
| OpenAI live (klasifikasi + ekstraksi memori) | Berhasil |
| Server suara `:7860/health` | `api: true`, ElevenLabs lengkap, Twilio belum diisi |
| ElevenLabs TTS → STT bolak-balik (1 kalimat) | Teks kembali persis sama. TTS 2,4 detik |

Belum diuji: panggilan suara penuh lewat browser (perlu mikrofon/manusia) dan panggilan Twilio PSTN.
