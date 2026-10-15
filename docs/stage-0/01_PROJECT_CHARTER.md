# 01 · Project Charter: TILIK

| | |
|---|---|
| **Produk** | TILIK |
| **Tim** | IRIS-Heisenberg |
| **Lomba** | Hackathon JOINTS x INSPIRE 2026 (HIMAKOM & HMEI UGM) |
| **Tema** | Healthcare |
| **Subtema utama** | Keluarga yang merawat lansia dan sulit memantau kondisi, kepatuhan obat, dan bantuan sehari-hari |
| **Subtema pendukung** | Usia produktif/kronis yang jarang periksa · Puskesmas kewalahan administrasi |
| **Status dokumen** | Stage 0 (persiapan sebelum menulis kode) |
| **Dibuat** | 15 Oktober 2026 |

---

## 1. Masalah

Stroke adalah penyebab kematian nomor satu di Indonesia (18,5% dari total kematian, SKI 2023). Peluang pasien selamat ditentukan oleh *golden period* ±4,5 jam, tetapi:

- Median kedatangan pasien stroke ke RS adalah **16,5 jam** (RSHS Bandung), dan hanya **10,1%** yang tiba dalam golden period (RSOMH Bukittinggi, 2024).
- Salah satu faktor keterlambatan adalah **pasien yang tinggal sendiri** dan keluarga yang tidak mengenali gejalanya.
- **32,3%** penderita hipertensi tidak rutin minum obat, dan **59,8%** di antaranya beralasan "merasa sudah sehat" (Riskesdas 2018).
- DIY adalah provinsi dengan proporsi lansia tertinggi di Indonesia (**17,83%**, SUPAS 2025).
- Hanya ±26% lansia yang memakai internet, sehingga aplikasi kesehatan sulit menjangkau mereka. Telepon biasa bisa dipakai hampir semua lansia.

Program **Code Stroke Lintas Sektor RS Akademik UGM** di Gunungkidul memperbaiki alur *di dalam* RS. Dokumen program itu sendiri menyebut "keterlambatan identifikasi gejala" sebagai hambatan. **Jalur dari rumah ke IGD masih kosong.**

Sumber lengkap ada di [`docs/research/Ideas_Breakdown_v4_FINAL.md`](../research/Ideas_Breakdown_v4_FINAL.md) §7.

## 2. Solusi (satu kalimat)

**TILIK adalah agen suara AI yang setiap pagi menelepon lansia penderita hipertensi lewat telepon biasa. TILIK mengecek obat, tensi, dan gejala, menyaring tanda stroke saat itu juga, lalu menggerakkan tetangga, anak, dan IGD dengan informasi jam onset, sambil membuat anak lebih sering menelepon orang tuanya.**

Kerangka produk: **Cegah, Deteksi, Arahkan.**
1. **Cegah**: telepon harian (obat, tensi, gejala) + rapor dan "bahan obrolan" untuk keluarga.
2. **Deteksi**: pemicu tanda bahaya (aturan + LLM, ditambah analisis suara di tahap berikutnya) + skrining stroke verbal.
3. **Arahkan**: eskalasi 3 warna, konferensi telepon dengan tetangga dan anak, pre-alert ke IGD, dan arahan ke RS ber-CT terdekat.

## 3. Pengguna

| Pengguna | Antarmuka | Nilai yang didapat |
|---|---|---|
| Lansia ("Mbah") | Telepon biasa, tanpa layar | Ditemani, diingatkan, ditolong cepat |
| Anak/keluarga | WhatsApp | Rapor, bahan obrolan, titip pesan, alert darurat |
| Tetangga/kader ("Sahabat Tilik") | Telepon + WhatsApp | Dipanggil pertama saat darurat (paling dekat secara fisik) |
| Puskesmas | Web: "Daftar Tilik Hari Ini" | Daftar prioritas tindak lanjut, data tensi & kepatuhan |
| IGD RS | Web: "Board Pre-alert" | Info onset, hasil skrining, dan obat sebelum pasien tiba |

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
- Eskalasi 🔴: konferensi telepon (Sahabat Tilik + anak), WA alert + RS ber-CT, pre-alert ke board IGD
- Rapor WA dengan "Bahan Obrolan"
- Web: Daftar Tilik Hari Ini, Board IGD
- Memori sederhana per pasien
- Harness evaluasi tingkat teks (30 skenario)

### 5.2 Di luar scope MVP (masuk Stage 2/roadmap)
Panel tanda vital suara *live*, endpointing personal, backchannel, deteksi krama/ngoko otomatis, mode DTMF, berbagi bertingkat penuh, Telepon Bareng, jam kronis (gagal jantung/kognitif), mode sovereign (Sahabat-AI), integrasi SATUSEHAT/PSC 119, uji lansia sungguhan (Stage 2).

### 5.3 Non-goals (tidak akan pernah dilakukan TILIK)
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
