# 01 · Project Charter: KRING

> **Pembaruan 16 Okt 2026 (prototipe & framing).** Nama produk: **KRING** (dulu TILIK). Framing utama: **teman bicara + jembatan keluarga dua arah**, kesehatan dan jalur cepat stroke sebagai lapis kedua dan ketiga. Kanal WhatsApp dan web Next.js digantikan **satu aplikasi KRING** (Flutter, 5 peran); lansia tetap lewat telepon biasa. Prototipe memakai FastAPI + SQLite (Supabase = rencana produksi). Lihat [03 §0](03_ARSITEKTUR_TEKNIS.md) dan [Laporan Konsep Kerja](../LAPORAN_KONSEP_KERJA.md).

| | |
|---|---|
| **Produk** | KRING |
| **Tim** | IRIS-Heisenberg |
| **Lomba** | Hackathon JOINTS x INSPIRE 2026 (HIMAKOM & HMEI UGM) |
| **Tema** | Healthcare |
| **Subtema utama** | Keluarga yang merawat lansia dan sulit memantau kondisi, kepatuhan obat, dan bantuan sehari-hari |
| **Subtema pendukung** | Usia produktif/kronis yang jarang periksa · Puskesmas kewalahan administrasi |
| **Status dokumen** | Stage 0 (persiapan sebelum menulis kode) |
| **Dibuat** | 15 Oktober 2026 |

---

## 1. Masalah

**Akar masalah: tidak ada yang menanyakan kabar lansia setiap hari.** Banyak lansia tinggal sendiri sementara anaknya merantau. Akibatnya tiga: **sepi** (WHO 2025: 1 dari 6 orang kesepian; kesepian dan isolasi sosial terkait risiko stroke +32%, Valtorta dkk. 2016), **kesehatan luput** (obat terhenti, keluhan tidak tercatat), dan **stroke terlambat ditolong**.

Stroke adalah penyebab kematian nomor satu di Indonesia (18,5% dari total kematian, SKI 2023). Peluang pasien selamat ditentukan oleh *golden period* ±4,5 jam, tetapi:

- Median kedatangan pasien stroke ke RS adalah **16,5 jam** (RSHS Bandung), dan hanya **10,1%** yang tiba dalam golden period (RSOMH Bukittinggi, 2024).
- Salah satu faktor keterlambatan adalah **pasien yang tinggal sendiri** dan keluarga yang tidak mengenali gejalanya.
- **32,3%** penderita hipertensi tidak rutin minum obat, dan **59,8%** di antaranya beralasan "merasa sudah sehat" (Riskesdas 2018).
- DIY adalah provinsi dengan proporsi lansia tertinggi di Indonesia (**17,83%**, SUPAS 2025).
- Hanya ±26% lansia yang memakai internet, sehingga aplikasi kesehatan sulit menjangkau mereka. Telepon biasa bisa dipakai hampir semua lansia.

Program **Code Stroke Lintas Sektor RS Akademik UGM** di Gunungkidul memperbaiki alur *di dalam* RS. Dokumen program itu sendiri menyebut "keterlambatan identifikasi gejala" sebagai hambatan. **Jalur dari rumah ke IGD masih kosong.**

Sumber lengkap ada di [`docs/research/Ideas_Breakdown_v4_FINAL.md`](../research/Ideas_Breakdown_v4_FINAL.md) §7.

## 2. Solusi (satu kalimat)

**KRING adalah teman bicara AI yang setiap pagi menelepon lansia penderita hipertensi lewat telepon biasa, menyambungkan cerita dan rasa kangennya ke anak (dan pesan suara anak kembali ke Mbah) lewat aplikasi KRING, sekaligus mengecek obat, tensi, dan gejala serta menggerakkan tetangga, anak, dan IGD ketika muncul tanda stroke.**

Kerangka produk (16 Okt): **tiga lapis dalam satu panggilan.**
1. **Teman & jembatan keluarga**: mendengarkan cerita, memori, suasana hati, Nudge Kangen, bahan obrolan untuk anak, pesan suara anak diputar ke Mbah.
2. **Jaga kesehatan (Cegah)**: obat, tensi, gejala, jadwal kontrol, data jam tangan.
3. **Jaring pengaman stroke (Deteksi + Arahkan)**: pemicu tanda bahaya (aturan + LLM, ditambah analisis suara di tahap berikutnya) + skrining stroke verbal.
   **Arahkan**: eskalasi 3 warna, konferensi telepon dengan tetangga dan anak, pre-alert ke IGD, dan arahan ke RS ber-CT terdekat.

## 3. Pengguna

| Pengguna | Antarmuka | Nilai yang didapat |
|---|---|---|
| Lansia ("Mbah") | Telepon biasa, tanpa layar | Ditemani, diingatkan, ditolong cepat |
| Anak/keluarga | Aplikasi KRING (peran Keluarga) | Rapor, bahan obrolan, Nudge Kangen, titip pesan teks/suara, kesehatan & jam tangan, alert darurat |
| Tetangga/kader ("Sahabat Kring") | Aplikasi KRING + telepon | Dipanggil pertama saat darurat (paling dekat secara fisik) |
| Puskesmas | Aplikasi KRING: "Daftar Kring Hari Ini" | Daftar prioritas tindak lanjut, data tensi & kepatuhan |
| IGD RS | Aplikasi KRING: "Board Pre-alert" | Info onset, hasil skrining, dan obat sebelum pasien tiba |

## 4. Tujuan

### 4.1 Tujuan lomba
| Target | Ukuran |
|---|---|
| MVP berfungsi end-to-end | Selesai **18 Oktober 2026** (deadline efektif yang ditetapkan tim) |
| Lolos ke Grand Final | Pengumuman 23 Oktober 2026 |
| Skor Grand Final ≥ 95 | Rubrik: Inovasi 25 · Teknis 30 · Fungsi & Desain 20 · Dampak 15 · Presentasi 10 |

### 4.2 Metrik produk (diukur lewat harness evaluasi, lihat [07_EVALUASI.md](07_EVALUASI.md))
| Metrik | Kenapa penting |
|---|---|
| Recall tanda bahaya 🔴 pada skenario kritis | Keselamatan |
| Alarm palsu 🔴 per 100 panggilan | Kepercayaan & beban IGD |
| Akurasi ekstraksi (obat, tensi, gejala) | Kualitas data untuk Puskesmas |
| Latensi suara p50/p95 | Kenyamanan bicara lansia |
| Kepatuhan disclosure "asisten AI" | Etika |
| **North-star (pilot nanti): frekuensi telepon keluarga tidak turun** | Menjawab kritik "AI menggantikan anak" |

## 5. Scope

### 5.1 Dalam scope MVP (18 Okt)
Ringkasnya, detail ada di [02_PRD.md](02_PRD.md):
- Panggilan keluar harian real-time (Twilio, atau fallback panggilan browser)
- Skrip harian: disclosure AI + kata sandi keluarga → titip pesan → obat → tensi → gejala → penutup + edukasi SeGeRa Ke RS
- Pemicu tanda bahaya 2 jalur (aturan + LLM) + eskalasi 3 warna
- Skrining stroke verbal + catat *last known well*
- Eskalasi 🔴: konferensi telepon (Sahabat Kring + anak), alert di aplikasi + RS ber-CT, pre-alert ke board IGD
- Rapor di aplikasi keluarga dengan "Bahan Obrolan"
- Aplikasi: Daftar Kring Hari Ini, Board IGD (sebelumnya direncanakan web + WA; diganti 16 Okt)
- Memori sederhana per pasien
- Harness evaluasi tingkat teks (30 skenario)

### 5.2 Di luar scope MVP (masuk Stage 2/roadmap)
Panel tanda vital suara *live*, endpointing personal, backchannel, deteksi krama/ngoko otomatis, mode DTMF, berbagi bertingkat penuh, Telepon Bareng, jam kronis (gagal jantung/kognitif), mode sovereign (Sahabat-AI), integrasi SATUSEHAT/PSC 119, uji lansia sungguhan (Stage 2).

### 5.3 Non-goals (tidak akan pernah dilakukan KRING)
- Mendiagnosis penyakit atau mengubah dosis obat
- Meniru suara anggota keluarga (voice cloning)
- Mengaku sebagai manusia
- Meminta uang, OTP, NIK, atau data rekening
- **Di demo/uji: menelepon 119 atau RS sungguhan** (semua tujuan eskalasi di demo adalah nomor tim)

## 6. Batasan (constraints)

| Batasan | Detail | Sumber keputusan |
|---|---|---|
| Waktu | MVP selesai 18 Okt 2026. Grand Final 1 Nov 2026 | Tim |
| Biaya | **Paling hemat.** ElevenLabs Starter (±$6/bulan, ±30.000 kredit, tanpa overage). Twilio tetap trial. Hosting gratis. OpenAI dari billing yang sudah ada, pakai model termurah yang lolos uji | Tim |
| Vendor suara | ElevenLabs untuk TTS dan STT (Scribe) | Tim |
| LLM | OpenAI | Tim |
| Orkestrasi suara | Pipecat (open-source, Python) | Tim |
| Telepon | Twilio, akun trial (maksimal 5 nomor terverifikasi, ada pesan trial di awal panggilan) | Tim (akun sudah ada) |
| Orisinalitas | Source code harus karya asli tim (aturan lomba) | Panitia |
| Bahasa dokumen | Bahasa Indonesia | Tim |
| Pembagian kerja | Per **workstream/job**, tidak per orang | Tim |

## 7. Stakeholder & mitra potensial (belum dihubungi)

| Pihak | Peran potensial | Status |
|---|---|---|
| RS Akademik UGM (Code Stroke Lintas Sektor) | Mitra klinis, validasi, pilot | Belum dihubungi |
| Puskesmas di Gunungkidul / Sleman | Pengguna B2G | Belum dihubungi |
| Nakes (dokter/perawat) | Review skrip klinis & aturan tanda bahaya | **Belum ada, lihat pertanyaan terbuka** |
| Lansia & keluarga | Uji pengguna (Stage 2) | Belum ada |

## 8. Struktur dokumen Stage 0

| No | Dokumen | Isi |
|---|---|---|
| 01 | Project Charter | Dokumen ini |
| 02 | [PRD](02_PRD.md) | Persona, user story, fitur + acceptance criteria |
| 03 | [Arsitektur Teknis](03_ARSITEKTUR_TEKNIS.md) | Stack, komponen, alur data, latensi |
| 04 | [Data Model](04_DATA_MODEL.md) | Skema database, pemetaan FHIR, retensi |
| 05 | [Desain Percakapan & Keselamatan Klinis](05_DESAIN_PERCAKAPAN.md) | State machine, skrip, aturan tanda bahaya, eskalasi |
| 06 | [Etika, Privasi & Regulasi](06_ETIKA_PRIVASI_REGULASI.md) | Requirement etika, UU PDP, KMK 951/2026 |
| 07 | [Rencana Evaluasi](07_EVALUASI.md) | Harness, persona, metrik, target |
| 08 | [Roadmap & Job Breakdown](08_ROADMAP.md) | Stage 0–3, workstream, gate |
| 09 | [Checklist Stage 0](09_STAGE0_CHECKLIST.md) | Semua persiapan sebelum coding |
| 10 | [Anggaran & Kuota](10_ANGGARAN_KUOTA.md) | Kredit ElevenLabs, OpenAI, Twilio, free tier |
| 11 | [Register Risiko](11_RISIKO.md) | Risiko + mitigasi |
| 12 | [Keputusan & Pertanyaan Terbuka](12_KEPUTUSAN_DAN_PERTANYAAN.md) | Decision log + hal yang belum diketahui |
| 13 | [Konvensi Repo](13_KONVENSI_REPO.md) | Struktur folder, branch, commit, secrets |
| 14 | [Rencana Deliverable](14_DELIVERABLE.md) | Video, proposal, pitch deck, README, demo |
| 15 | [Defense Bank](15_DEFENSE_BANK.md) | Pertanyaan sulit juri, lapisan perlindungan, jawaban 15 detik |
