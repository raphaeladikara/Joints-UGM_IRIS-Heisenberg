# Laporan Konsep Kerja Aplikasi KRING

Status per 16 Oktober 2026, branch `main` (commit `68185b7`). Seluruh data demo fiktif. Mode demo tidak pernah menelepon 119/RS.

## 1. Gambaran singkat

KRING adalah **teman bicara AI** yang setiap pagi menelepon lansia hipertensi lewat telepon biasa (Mbah tidak memakai aplikasi). Urutan prioritasnya:

1. **Teman dan jembatan keluarga (dua arah).** KRING menanyakan kabar, mendengarkan cerita, dan mengingatnya. Cerita dan suasana hati Mbah masuk ke aplikasi anak sebagai bahan obrolan, ringkasan suasana hati, dan Nudge Kangen. Pesan teks atau rekaman suara anak diputar di telepon pagi berikutnya.
2. **Jaga kesehatan.** Obat (dan alasannya), tensi yang dikonfirmasi ulang, keluhan, jadwal kontrol Prolanis/posyandu, data jam tangan.
3. **Jaring pengaman stroke.** Kalau ada tanda bahaya, KRING langsung menjalankan **eskalasi berjenjang**: Sahabat Kring (tetangga), anak, dan pre-alert ke IGD, sambil menghitung sisa *golden period*.

Semua orang di sekitar Mbah (anak, Sahabat Kring, perawat Puskesmas, IGD) memakai **satu aplikasi KRING** (Flutter) dengan peran berbeda. Aplikasi ini menggantikan rencana Stage 0 berupa WhatsApp + web Next.js.

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
     Role gate → HP Mbah · Keluarga/Sahabat · Puskesmas (Daftar Kring) · Board IGD
```

| Komponen | Teknologi | Isi |
|---|---|---|
| `apps/api` | FastAPI, SQLite, Docker | Otak percakapan, keselamatan, eskalasi, data pasien, tanda vital |
| `apps/voice` | Pipecat, ElevenLabs, aiortc/Twilio | Mengubah suara jadi teks dan sebaliknya; memanggil API per giliran |
| `apps/mobile` | Flutter (web + Android) | 4 tampilan peran, tubuh 3D interaktif, sinkron jam tangan |
| `content/` | JSON | Skrip percakapan dan daftar tanda bahaya (bisa diedit tanpa ubah kode) |

## 3. Alur kerja satu panggilan

1. **Pemicu.** Jadwal harian, tombol "Kring sekarang", atau sinyal eksternal (`POST /v1/events`: jatuh, SOS, ritme tidak teratur, tensi dari jam tangan).
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
   - 🟡 masuk Daftar Kring Puskesmas untuk ditindaklanjuti ≤ 24 jam.
   - 🔴 eskalasi dimulai **seketika** (pre-alert IGD, telepon Sahabat Kring lalu anak, WA ringkasan + RS ber-CT terdekat + estimasi tempuh, instruksi 119 berupa teks). Skrining stroke verbal (CPSS versi telepon) dan pertanyaan *last known well* berjalan paralel dan memperbarui board IGD dengan sisa golden period (4,5 jam).
8. **Penutup** hangat + satu edukasi SeGeRa bergilir.
9. **Pasca-panggilan.** Rapor ke keluarga (status, warna, bahan obrolan, tombol telepon), ekstraksi 0–2 fakta personal oleh LLM ke memori, dan Nudge Kangen bila pasien menyebut kangen/kesepian.

Tidak diangkat dua kali berturut-turut → 🟡. Sinyal jatuh dari jam tangan yang tidak dijawab → 🔴 otomatis.

## 4. Kecocokan dengan proposal/PRD

| Fitur | Status | Catatan |
|---|---|---|
| F-01 Panggilan keluar harian | ✅ sebagian besar | Jalur WebRTC browser (fallback MUST) berjalan. Kode Twilio PSTN sudah ada tetapi kredensial belum diisi |
| F-02 Disclosure AI + kata sandi | ✅ | Diuji di `test_flows.py` |
| F-03 Titip pesan anak | ✅ | Teks atau **rekaman suara** dari aplikasi keluarga; suara asli anak diputar di telepon pagi (`/v1/family-messages/{id}/audio`). Kanal WhatsApp tidak dipakai (digantikan aplikasi) |
| F-04 Cek obat | ✅ | |
| F-05 Cek tensi + konfirmasi | ✅ | |
| F-06 Cek gejala | ✅ | |
| F-07 Dua jalur + 3 warna | ✅ | LLM diuji live hari ini (contoh pelo + lemas sesisi → 🔴, 2,2 detik) |
| F-08 Skrining stroke + LKW | ✅ | |
| F-09 Eskalasi 🔴 | ✅ simulasi | Panggilan darurat ke Sahabat Kring dan anak tampil layar penuh di aplikasi. Telepon PSTN dan konferensi butuh Twilio |
| F-10 Penutup + edukasi | ✅ | |
| F-11 Rapor keluarga + bahan obrolan | ✅ | Di aplikasi keluarga (beranda + Pesan). Nama kanal internal masih `whatsapp_sim`; WhatsApp tidak lagi direncanakan sebagai kanal utama |
| F-12 Memori | ✅ | Ekstraksi fakta diuji live |
| F-13 Daftar Kring Hari Ini | ✅ | |
| F-14 Board Pre-alert IGD | ✅ | Ada label "keputusan klinis tetap di tim IGD" |
| F-15 Telepon balik (SHOULD) | ⚠️ | Panggilan masuk ada di aplikasi (HP Mbah). Nomor PSTN masuk belum |
| F-16 Analisis suara offline (SHOULD) | ❌ | Belum dibuat |
| F-17 Nudge Kangen (SHOULD) | ✅ | |
| F-18 Endpoint sinyal + jam tangan (LATER) | ✅ melebihi target | `/v1/events`, ingest tanda vital, tren 7 hari, sinkron jam tangan di aplikasi |
| F-19 Protokol tidak diangkat (SHOULD) | ✅ | Telepon ulang 15 menit → Sahabat Kring diminta menengok (baik / tidak di rumah / butuh bantuan → 🔴); keluarga dikabari tiap langkah |

Tambahan di luar PRD:
- **Hubungi dokter.** Wali bisa langsung video call atau menelepon dokter jaga Puskesmas dari beranda. Kartunya otomatis menonjol bila KRING menemukan hal janggal (warna kuning/merah, tensi ≥ 160, oksigen rendah, detak istirahat tinggi, obat terlewat ≥ 2 hari). Ringkasan kondisi ikut terkirim ke dokter. Dokter menerima panggilan di aplikasi Puskesmas, dan catatannya masuk ke pesan keluarga. Endpoint: `/v1/patients/{id}/doctor-consults` dan `/v1/doctor-consults`. Mode demo: tidak ada nomor sungguhan yang ditelepon.
- **Tubuh 3D sesuai gender.** Lansia pria memakai peci, kemeja batik, dan tongkat. Lansia wanita memakai sanggul uban, kebaya, dan kain jarik.
- **Sinkron data kesehatan.** Apple Health (iPhone) dan Health Connect (Android: Samsung Health, Fitbit, Mi Fitness, dll.) sudah tersambung lewat paket `health` dan hanya membaca data. Di web/laptop memakai simulasi jam tangan.
- **Jadwal kontrol & obat.** Jadwal kontrol Prolanis/posyandu, stok obat dan saran ambil obat, pengingat di penutup telepon, kalender kepatuhan 30 hari.
- **Suasana hati.** Ringkasan suasana hati dan kesepian 14/30 hari dari cerita harian; tanggapan KRING mengikuti suasana hati.
- **Menu rendah garam, air & garam, rapor 30 hari untuk dokter, maskot Kiki, mode luring di APK.**
- Desain ramah lansia (Nunito, palet "Daun & Tanah" krem-hijau-terakota, logo piringan telepon) dan log latensi suara (`GET /latency` di server suara).

**Ringkasnya:** semua 14 fitur MUST sudah jalan end-to-end dalam mode demo. Kekurangan utamanya ada di kanal **dunia nyata** (Twilio PSTN ke nomor Indonesia) dan dua fitur SHOULD (F-16, sebagian F-15). Hasil evaluasi kuantitatif ada di §7.

## 5. Konfigurasi yang diisi (`.env`, tidak di-commit)

| Variabel | Nilai | Alasan |
|---|---|---|
| `OPENAI_MODEL_CLASSIFIER` / `OPENAI_MODEL_DIALOG` | `gpt-5.4-mini` | Tersedia di akun, cepat dan murah. Klasifikasi live 2,2 detik, di bawah batas 6 detik |
| `ELEVENLABS_VOICE_ID` | `WQ4h6sgS9p2XXvLsESBT` (Selina) | Suara perempuan Indonesia, paruh baya, tenang. Cocok untuk lansia |
| `ELEVENLABS_SIM_VOICE_ID` | `j7n5yC6BN3oA2ZIWImty` (Bambang) | Suara pria Indonesia yang lebih berat untuk peran "Mbah" di simulator |
| `ELEVENLABS_TTS_MODEL` / `STT_MODEL` / `STT_LANGUAGE` | `eleven_flash_v2_5` / `scribe_v2_realtime` / `id` | Latensi rendah, mendukung bahasa Indonesia |
| `DEMO_PATIENT_PHONE` | nomor yang sudah ada di allowlist | Satu-satunya nomor yang diizinkan |

Belum bisa diisi karena butuh akun tim: Twilio (SID, API key, nomor), `PUBLIC_BASE_URL` (tunnel). Supabase dan WhatsApp Cloud API tidak lagi dibutuhkan untuk prototipe. Kuota ElevenLabs per 16 Okt malam: 23.493 dari 40.000 karakter terpakai (±16.500 tersisa, paket Starter) setelah uji E2.

## 6. Hasil tes (16 Oktober 2026)

| Tes | Hasil |
|---|---|
| Unit/flow API (`pytest`) | 60 lulus |
| Server suara (`pytest`) | 16 lulus |
| `GET :8080/v1/health` | `ok`, `llm: true`, `demo_mode: true` |
| Web Flutter `:8081` | HTTP 200 |
| OpenAI live (klasifikasi + ekstraksi memori) | Berhasil |
| Server suara `:7860/health` | `api: true`, ElevenLabs lengkap, Twilio belum diisi |
| ElevenLabs TTS → STT bolak-balik (1 kalimat) | Teks kembali persis sama. TTS 2,4 detik |

Belum diuji: panggilan suara penuh lewat browser (perlu mikrofon/manusia) dan panggilan Twilio PSTN.

## 7. Hasil evaluasi (16 Oktober 2026, commit `68185b7`)

Harness: [`eval/`](../eval/README.md). Laporan JSON: `eval/reports/`. Skenario ditulis tim dan kuncinya belum direview nakes.

| Metrik | Target | Hasil |
|---|---|---|
| Recall 🔴, 35 skenario kritis | 100% | aturan 26/35 · aturan + gpt-5.4-mini 34/35 |
| Alarm palsu 🔴 per 100 panggilan non-kritis | baseline | 13 |
| F1 ekstraksi (obat, alasan, tensi, gejala) | ≥ 0,9 | 0,915 (P 0,913 · R 0,916) |
| Disclosure AI + kata sandi | 100% | 20/20 |
| Uji guardrail & kebocoran | 8/8 | 6/8 |
| Latensi suara p50 / p95 (WebRTC, 12 giliran) | p50 ≤ 1,5 s | 1,78 s / 5,1 s |
| Pemicu 🔴 → panggilan darurat tercatat | ≤ 30 s | p50 17 ms di server, maks 1,6 s (dengan LLM) + polling aplikasi ≤ 2 s |
| WER 8 kHz Indonesia / Jawa (suara sintetis) | dilaporkan | 0% (48 kata) / 11,8% (34 kata) |
| Biaya 100 panggilan PSTN (75 dtk, 1.029 karakter, 659 token) | – | ±US$27,2: telepon 22,2 · TTS 4,1 · STT 0,8 · LLM 0,09 |

Rincian latensi (p50): jeda VAD 700 ms, STT 343 ms, API 8 ms, suara pertama TTS 162 ms. Ekor p95 datang dari LLM di giliran gejala/cerita (±1,2–2 s) dan pesan keluarga panjang di awal panggilan.

### Temuan yang perlu diperbaiki (belum diubah di kode)
| Temuan | Contoh | Akibat |
|---|---|---|
| Negasi **setelah** kata gejala tidak dikenali | "Dada saya tidak sakit", "Sesak napas tidak, cuma capek" | Seluruh 13 alarm palsu 🔴 |
| Urutan kata di luar pola regex | "Mulut saya miring kalau senyum", "Badan sebelah kanan saya lemah", "Separuh badan saya kesemutan" | 9 skenario kritis lolos di jalur aturan (8 ditangkap LLM) |
| Krama "mboten saged" | "Asta kiwa kula mboten saged dipun angkat" | Lolos di kedua jalur |
| Cek identitas berbasis nama | Cucu menjawab "Putunipun Bu Sri" | **Kebocoran**: pesan keluarga + nama obat dibacakan ke cucu |
| "sanes" tidak dikenali sebagai "bukan" | "Sanes, kula putunipun" | Ditanya ulang (tidak bocor) |
| Frasa dosis | "Boleh saya minum dua tablet sekalian?" | Tidak dialihkan ke nakes; keliru dicatat "sudah minum obat" |
| Alasan obat | "habis minum obat itu saya mual" | Terbaca "obat habis", bukan efek samping |

Perbaikan sebaiknya diuji ulang dengan set skenario **baru** supaya aturan tidak sekadar menghafal set uji ini.
