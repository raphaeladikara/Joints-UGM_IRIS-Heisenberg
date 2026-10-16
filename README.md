# KRING

> **Jalur cepat stroke dimulai dari rumah Mbah, bukan dari pintu IGD.**

KRING adalah agen suara AI yang setiap pagi menelepon lansia penderita hipertensi lewat **telepon biasa** (tanpa aplikasi, tanpa internet). KRING mengecek obat, tensi, dan gejala, lalu menyaring tanda stroke saat itu juga. Kalau ada tanda bahaya, KRING menggerakkan tetangga, anak, dan IGD dengan informasi jam onset. Di hari-hari biasa, KRING memberi anak bahan obrolan supaya mereka lebih sering menelepon orang tuanya.

*(Sebelumnya bernama TILIK; dokumen Stage 0 dan paper masih memakai nama lama.)*

**Tim IRIS-Heisenberg** · Hackathon JOINTS x INSPIRE 2026 · Tema **Healthcare**

---

## APK demo (offline, tanpa server)

APK bawaan memakai **mode offline**: logika server (dialog, Safety Agent, eskalasi, data demo 30 hari) berjalan di dalam
aplikasi (`apps/mobile/lib/core/local/`), jadi bisa dipasang di HP Android mana pun tanpa internet atau laptop. Data demo
otomatis diisi ulang tiap hari; tombol **Ulang data demo** mengembalikannya. Server FastAPI tetap bisa dipakai lewat ⚙
(pilih "Server") untuk LLM dan suara asli.

```bash
cd apps/mobile
flutter build apk --release        # build/app/outputs/flutter-apk/app-release.apk (universal)
```

Fitur baru di aplikasi keluarga: ringkasan harian + skor sehat, streak obat & telepon, jadwal & stok obat, air & garam,
menu rendah garam (kirim resep ke Mbah), rapor 30 hari untuk dokter, model 3D nenek/kakek bergaya kartun (kebaya & jarik batik, peci & sarung), dan
maskot Kiki. Endpoint fitur baru (`/care`, `/meds/*`, `/intake`, `/family-calls`, `/report`) baru ada di mode offline.

## Status: Stage 1 (prototype aplikasi berjalan)

Sudah ada **prototype yang bisa dijalankan**: API "otak" TILIK (dialog manager, Safety Agent, mesin eskalasi) di Docker,
dan aplikasi HP Flutter dengan lima peran. Pipeline telepon sungguhan (Pipecat + Twilio + ElevenLabs) belum dipasang;
di prototype, telepon Mbah disimulasikan di aplikasi (suara TTS/STT perangkat). Lihat [Prototype](#prototype-aplikasi-hp).

| Stage | Periode | Status |
|---|---|---|
| Stage 0: Persiapan | 15 Okt 2026 | ✅ |
| Stage 1: MVP | 16–18 Okt 2026 | 🟡 Prototype aplikasi + API jalan; pipeline telepon belum |
| Stage 2: Menuju Grand Final | 19–31 Okt 2026 | ⏳ |
| Grand Final | 1 Nov 2026 | ⏳ |

## Cara membaca repo ini

Kalau baru bergabung, baca dengan urutan ini:
1. [Project Charter](docs/stage-0/01_PROJECT_CHARTER.md): masalah, solusi, scope, batasan
2. [Checklist Stage 0](docs/stage-0/09_STAGE0_CHECKLIST.md): yang harus dikerjakan **sekarang**
3. [Keputusan & Pertanyaan Terbuka](docs/stage-0/12_KEPUTUSAN_DAN_PERTANYAAN.md): yang sudah diputuskan & yang belum
4. [Roadmap & Job Breakdown](docs/stage-0/08_ROADMAP.md): rencana harian per workstream

### Dokumen Stage 0 lengkap
| No | Dokumen |
|---|---|
| 01 | [Project Charter](docs/stage-0/01_PROJECT_CHARTER.md) |
| 02 | [PRD: fitur & acceptance criteria](docs/stage-0/02_PRD.md) |
| 03 | [Arsitektur Teknis](docs/stage-0/03_ARSITEKTUR_TEKNIS.md) |
| 04 | [Data Model](docs/stage-0/04_DATA_MODEL.md) |
| 05 | [Desain Percakapan & Keselamatan Klinis](docs/stage-0/05_DESAIN_PERCAKAPAN.md) |
| 06 | [Etika, Privasi & Regulasi](docs/stage-0/06_ETIKA_PRIVASI_REGULASI.md) |
| 07 | [Rencana Evaluasi](docs/stage-0/07_EVALUASI.md) |
| 08 | [Roadmap & Job Breakdown](docs/stage-0/08_ROADMAP.md) |
| 09 | [Checklist Stage 0](docs/stage-0/09_STAGE0_CHECKLIST.md) |
| 10 | [Anggaran & Kuota](docs/stage-0/10_ANGGARAN_KUOTA.md) |
| 11 | [Register Risiko](docs/stage-0/11_RISIKO.md) |
| 12 | [Keputusan & Pertanyaan Terbuka](docs/stage-0/12_KEPUTUSAN_DAN_PERTANYAAN.md) |
| 13 | [Konvensi Repo](docs/stage-0/13_KONVENSI_REPO.md) |
| 14 | [Rencana Deliverable](docs/stage-0/14_DELIVERABLE.md) |
| 15 | [Defense Bank: pertanyaan sulit juri & jawabannya](docs/stage-0/15_DEFENSE_BANK.md) |

### Riset
| Dokumen | Isi |
|---|---|
| [Ideas Breakdown v1](docs/research/Ideas_Breakdown.md) | Penilaian ide awal (penerjemah BISINDO) |
| [Ideas Breakdown v2](docs/research/Ideas_Breakdown_v2.md) | Pencarian ide 95+ dan lahirnya TILIK |
| [Ideas Breakdown v3](docs/research/Ideas_Breakdown_v3.md) | Cek kebaruan global + optimasi rubrik |
| [Ideas Breakdown v4 (FINAL)](docs/research/Ideas_Breakdown_v4_FINAL.md) | ATM, momen WOW, plafon teknis |
| [Audit Celah Etika & Defense](docs/research/TILIK_Celah_Etika_dan_Defense.md) | 22 celah + pembelaannya |
| [Ringkasan ketentuan lomba](penjelasan_lomba.md) | Timeline, deliverable, rubrik |

## Stack (rencana)
Pipecat (Python) · ElevenLabs (Scribe STT + TTS) · OpenAI · Twilio · WhatsApp Cloud API · Supabase · Next.js. Detail dan alasannya ada di [03_ARSITEKTUR_TEKNIS.md](docs/stage-0/03_ARSITEKTUR_TEKNIS.md).

## Prototype aplikasi HP

```
apps/mobile (Flutter, Android + web) ──HTTP/JSON, polling 2 dtk──▶ apps/api (FastAPI + SQLite, Docker)
  ├─ HP Mbah (simulator telepon biasa)                               ├─ dialog.py      state machine percakapan
  ├─ Keluarga (rapor, bahan obrolan, titip pesan, darurat)           ├─ safety.py      jalur aturan ∥ LLM (OR-gate)
  ├─ Sahabat Tilik (panggilan darurat, langkah tolong)               ├─ nlu.py         angka/tensi/jam ID + Jawa
  ├─ Puskesmas (Daftar Tilik Hari Ini, Tilik sekarang, simulasi)     ├─ escalation.py  event-driven, 3 warna
  └─ IGD (Board pre-alert: LKW, golden period, skrining, ETA)        └─ content/       skrip & aturan (sumber tunggal)
```

### Alur yang bisa didemokan
| Babak | Langkah di aplikasi | Yang terjadi |
|---|---|---|
| 1. Pagi biasa | **HP Mbah** → "minta TILIK menelepon" → Angkat → jawab (mikrofon, ketik, atau tombol jawaban) | Disclosure AI + kata sandi → titip pesan Mas Dika → obat → tensi dikonfirmasi ulang → gejala → cerita (memori kemarin dipakai) → penutup + edukasi SeGeRa Ke RS |
| 1b. Hasil | **Keluarga** · **Puskesmas** | Rapor + bahan obrolan + tombol "Telepon Bu Sri"; Daftar Tilik ter-update, 🔴/🟡 di atas |
| 2. Darurat | Di panggilan, jawab "Ngomongku kok angel, tangan kiwa lemes" | 🔴 seketika: pre-alert IGD + HP Bu Tini & Mas Dika berdering → skrining (ulang kalimat, angkat tangan, jam terakhir normal) → konferensi |
| 2b. Eskalasi | **Keluarga** / **Sahabat Tilik** / **IGD** | Panggilan darurat layar penuh, hitung mundur golden period 4,5 jam, RS ber-CT terdekat + ETA, board IGD dengan tombol terima |
| 3. Di luar jam telepon | **Puskesmas** → pasien → "Jam tangan: jatuh" | TILIK langsung menelepon Mbah; tidak diangkat → 🔴 otomatis (F-18) |

Jalur aturan jalan **tanpa API key apa pun**. Bila `OPENAI_API_KEY` diisi, jalur LLM ikut mengklasifikasi tanda bahaya
(OR-gate, tidak bisa menurunkan level) dan mengekstrak fakta untuk memori.

## Cara menjalankan

Prasyarat: Docker Desktop, Flutter 3.47 (Dart 3.13). Windows: cukup jalankan **`start.bat`**
(`start.bat rebuild` · `start.bat apk` · `start.bat test` · `start.bat stop`). `.env` dibuat otomatis dari
`.env.example`; prototype jalan tanpa mengisi apa pun, `OPENAI_API_KEY` opsional untuk jalur LLM.

```bash
docker compose up -d --build api            # API: http://127.0.0.1:8080  (dokumentasi: /docs)
docker compose run --rm api pytest -q        # 36 tes: parser, aturan tanda bahaya, skenario demo
```

Aplikasi versi web (cepat untuk demo di laptop/proyektor):

```bash
cd apps/mobile
flutter build web --release --dart-define=TILIK_API=http://127.0.0.1:8080
cd ../.. && docker compose --profile web up -d web   # http://127.0.0.1:8081
```

APK Android (HP dan laptop di Wi-Fi yang sama; pakai IP laptop, bukan `localhost`):

```bash
cd apps/mobile
flutter build apk --release --split-per-abi --dart-define=TILIK_API=http://<IP-laptop>:8080
```

Alamat server juga bisa diganti dari ikon ⚙ di layar awal. Emulator Android memakai `http://10.0.2.2:8080`.
Tombol **Ulang data demo** mengembalikan semua data fiktif ke kondisi awal.

### Jam tangan & aplikasi kesehatan
Aplikasi keluarga bisa menyinkronkan data jam tangan Mbah (langkah, tidur, detak jantung, oksigen darah, tensi) ke
`POST /v1/patients/{id}/vitals`. Angka di luar batas (SpO2 < 90%, detak istirahat ≥ 120, tensi krisis) membuka 🟡 di
Daftar Tilik sekali per hari; ambangnya ada di `content/red_flags.json` → `wearable` (draf, perlu review nakes).

| Platform | Sumber | Catatan |
|---|---|---|
| Android | **Health Connect** | Samsung Health, Wear OS, Fitbit, Mi Fitness, Huawei Health menyalin data ke sini. Butuh Android 8+ dan aplikasi Health Connect. |
| iPhone | **Apple Health** | Folder `apps/mobile/ios` sudah berisi izin HealthKit; build di Mac (Xcode → Signing & Capabilities → HealthKit). |
| Web / laptop | Simulasi jam tangan | Tombol "Simulasi jam tangan": hari biasa, oksigen turun, tensi tinggi. |

Data jam tangan juga menghidupkan tab **Tubuh**: model 3D (digambar langsung oleh Flutter, tanpa file model) dengan
titik otak, jantung, paru, lengan (tensi), perut (obat), dan kaki (langkah) yang berwarna sesuai status.
Setelah memperbarui server, tekan **Ulang data demo** supaya data jam tangan contoh Bu Sri ikut terisi.

### Batasan prototype (jujur)
- Telepon Mbah disimulasikan di aplikasi; belum PSTN. Suara memakai TTS/STT perangkat, belum ElevenLabs.
- WhatsApp dan konferensi telepon keluarga disimulasikan sebagai notifikasi di aplikasi.
- Realtime memakai polling, belum Supabase Realtime. Belum ada autentikasi (prototype lokal, data fiktif).
- Pengenalan ucapan berbasis aturan sederhana; frasa Jawa belum divalidasi penutur asli (Q-07).
- Aturan klinis **draf**, belum direview nakes (Q-08). RS & waktu tempuh berlabel simulasi (Q-13).

## Catatan penting
- Semua data di prototype adalah **data fiktif**.
- Aturan klinis masih **draf** dan belum direview tenaga kesehatan.
- Mode demo **tidak pernah** menelepon 119 atau nomor RS sungguhan.
