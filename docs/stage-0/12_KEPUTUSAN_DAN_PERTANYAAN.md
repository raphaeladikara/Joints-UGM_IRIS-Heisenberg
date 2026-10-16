# 12 · Log Keputusan & Pertanyaan Terbuka

Aturan dokumen ini: **tidak ada keputusan berdasarkan asumsi.** Hal yang belum diketahui dicatat sebagai pertanyaan terbuka. Kolom "Sumber" menunjukkan siapa yang memutuskan:
- **Tim**: diputuskan langsung oleh tim.
- **Delegasi**: tim meminta dipilihkan yang terbaik/terhemat. Pilihan beserta alasannya dicatat dan boleh diubah tim kapan saja.
- **Spike**: ditentukan oleh hasil uji di Stage 0.

---

## 1. Log keputusan

| ID | Tanggal | Keputusan | Sumber | Alasan / catatan |
|---|---|---|---|---|
| D-01 | 13 Okt | Ide final: **KRING** (v4 + audit etika) | Tim | Lihat `docs/research/` |
| D-02 | 15 Okt | Nama produk **KRING**, nama tim **IRIS-Heisenberg** | Tim | |
| D-03 | 15 Okt | Orkestrasi suara: **Pipecat** (pipeline sendiri), bukan ElevenLabs Agents Platform | Tim | Kode inti karya tim (aturan orisinalitas), skor teknis |
| D-04 | 15 Okt | **ElevenLabs** untuk TTS **dan** STT (Scribe) | Tim | Satu vendor suara |
| D-05 | 15 Okt | LLM: **OpenAI**. Model spesifik ditentukan di S-04 (termurah yang lolos) | Tim + Spike | |
| D-06 | 15 Okt | Telepon: **Twilio** (akun trial yang sudah ada) | Tim | |
| D-07 | 15 Okt | Commit & push atas nama **Mikael Adikara**. Tanpa co-author/kontributor AI di riwayat git | Tim | Penggunaan AI tetap diungkapkan di pitch deck sesuai aturan lomba (CMP-04) |
| D-08 | 15 Okt | Semua dokumen dalam **Bahasa Indonesia** | Tim | |
| D-09 | 15 Okt | Dokumen riset (v1–v4, audit etika) **dimasukkan ke repo** (`docs/research/`) | Tim | Jejak proses berpikir |
| D-10 | 15 Okt | Pembagian kerja **per job/workstream**, tidak per orang | Tim | |
| D-11 | 15 Okt | Biaya: **paling hemat**. ElevenLabs Starter. Twilio tetap trial. Hosting gratis | Tim | |
| D-12 | 15 Okt | **MVP selesai 18 Okt** = deadline efektif | Tim | Deadline resmi panitia = Q-01 |
| D-13 | 15 Okt | Wilayah demo: **DIY/Gunungkidul**, jejaring Code Stroke RSA UGM | Tim | |
| D-14 | 15 Okt | Scope MVP = daftar MUST di [02_PRD](02_PRD.md) (disesuaikan dengan waktu 3 hari) | Delegasi | Tim meminta scope ditentukan sesuai kelayakan waktu |
| D-15 | 15 Okt | WhatsApp: **WhatsApp Cloud API (Meta)** | Delegasi | Resmi (tidak berisiko blokir), nomor tes gratis, webhook tersedia. Alternatif: Twilio WhatsApp Sandbox (peserta harus "join" dulu) |
| D-16 | 15 Okt | Database: **Supabase free** | Delegasi | Realtime untuk Board IGD, Storage untuk pesan suara, gratis |
| D-17 | 15 Okt | Web: **Next.js + Tailwind + shadcn/ui** di **Vercel Hobby** | Delegasi | UI rapi, API route gratis untuk webhook WA |
| D-18 | 15 Okt | Server suara: **laptop + Cloudflare Quick Tunnel** | Delegasi | Gratis. URL dinamis bisa ditangani karena URL dikirim saat membuat panggilan |
| D-19 | 15 Okt | Rute RS: **tabel waktu tempuh statis** | Delegasi | Tanpa API berbayar |
| D-20 | 15 Okt | Memori MVP: daftar fakta JSON, **tanpa embedding** | Delegasi | Hemat & cukup |
| D-21 | 15 Okt | Evaluasi utama mode **teks** (0 kredit ElevenLabs) | Delegasi | Hemat kredit |
| D-22 | 15 Okt | Fallback panggilan: **WebRTC (Pipecat SmallWebRTC)** | Delegasi | Gratis. Dipakai kalau S-01 gagal |
| D-28 | 15 Okt | Sisa kredit ElevenLabs ±15.000. Prioritas: **video demo benar-benar berjalan**. Alokasi baru + credit guard ([10](10_ANGGARAN_KUOTA.md)) | Tim (prioritas) + Delegasi (alokasi) | |
| D-29 | 15 Okt | Pakai **2 nomor tim** dulu untuk demo. Nomor **tidak ditulis di repo publik**, hanya di `.env` | Tim (nomor) + Delegasi (privasi) | Data pribadi tidak masuk repo publik |
| D-30 | 15 Okt | Laptop server suara: **laptop Raphael** | Tim | Spesifikasi dicatat di S-08 |
| D-31 | 15 Okt | Akun Meta (WhatsApp Cloud API): **akun Raphael** | Tim | |
| D-32 | 15 Okt | Kode: **nama variabel/fungsi/kelas bahasa Inggris**. **Komentar & docstring bahasa Indonesia**. Konten percakapan Indonesia/Jawa | Delegasi | Inggris konsisten dengan API library (Pipecat, OpenAI, Twilio). Komentar Indonesia konsisten dengan dokumen (D-08) dan mudah dibaca juri |
| D-33 | 15 Okt | Arsitektur eskalasi **event-driven & agnostik perangkat**: sinyal apa pun (panggilan, telepon balik, tombol SOS, jam tangan, sensor) masuk ke mesin eskalasi yang sama. MVP: hanya sinyal dari panggilan. Stage 2: endpoint event + simulasi "jam tangan mendeteksi jatuh" | Delegasi | Menjawab pertanyaan "kalau krisis mendadak di luar jam telepon?" (lihat [15](15_DEFENSE_BANK.md)) |
| D-34 | 16 Okt | Prototype aplikasi: **Flutter** (Android + web, 5 peran) + **FastAPI + SQLite di Docker** (`apps/mobile`, `apps/api`). Logika dialog, Safety Agent, dan eskalasi ditulis sebagai API yang nanti dipanggil pipeline Pipecat. Supabase/Next.js (D-16, D-17) belum dipakai; realtime diganti polling | Tim (minta prototype HP seperti Nyambung) + Delegasi (stack) | Bisa didemokan tanpa kunci API apa pun; jalur LLM opsional. Tidak menggantikan D-03–D-06 untuk pipeline telepon |
| D-35 | 16 Okt | Nama produk **KRING** (dulu TILIK): bunyi dering telepon, satu-satunya yang perlu dilakukan Mbah adalah mengangkat | Tim | Hindari kebingungan dengan film *Tilik* (CMP-01); mudah diingat |
| D-36 | 16 Okt | Kanal: **lansia lewat telepon biasa**, semua pihak lain lewat **satu aplikasi KRING** (Flutter, 5 peran). WhatsApp Cloud API (D-15, D-31) dan web Next.js (D-17) tidak dipakai | Tim | Sesuai prototipe; satu aplikasi lebih kaya (3D, jam tangan, dokter, jadwal obat) daripada WA + web |
| D-37 | 16 Okt | Framing utama: **companion + jembatan keluarga dua arah**; kesehatan dan jalur cepat stroke sebagai lapis kedua dan ketiga | Tim | Ide awal tim; lebih empatik. Stroke tetap pembeda dan sumber angka dampak |
| D-39 | 16 Okt | Model OpenAI diganti `gpt-5.4-mini` → **`gpt-6-luna`** (menggantikan D-26) | Tim | Lebih murah (US$0,10/0,50 vs 0,75/4,50 per juta token) dan recall 🔴 naik 34/35 → 35/35. Konsekuensi: giliran gejala dengan LLM lebih lambat (p50 2,3 s vs 1,4 s) |
| D-38 | 16 Okt | Harness evaluasi `eval/` (E1 teks, E2 audio) dan hasil baseline commit 167fc90 dipakai di paper; temuan **tidak** di-*tune* ke set uji yang sama | Tim + Delegasi | Angka jujur; perbaikan diuji dengan set skenario baru |
| D-23 | 16 Okt | Transport utama (PSTN vs WebRTC) | Tim | **WebRTC** untuk demo (diuji end-to-end); kode Twilio siap tapi kredensial belum ada |
| D-24 | 16 Okt | Model TTS & voice ID ElevenLabs | Tim | `eleven_flash_v2_5`, suara Selina (KRING) dan Bambang (simulator Mbah) |
| D-25 | 16 Okt | Kode bahasa STT & dukungan Jawa | Tim | `scribe_v2_realtime`, bahasa `id` untuk semua; WER Jawa 11,8% (sintetis) |
| D-26 | 16 Okt | Model OpenAI (dialog & classifier) | Tim | `gpt-5.4-mini` untuk klasifikasi + ekstraksi memori; kalimat dialog dari skrip JSON, bukan LLM |
| D-27 | – | Desain eskalasi konferensi final | **Spike S-05** | |

## 2. Pertanyaan terbuka

| ID | Pertanyaan | Memblokir? | Ditanyakan ke | Status |
|---|---|---|---|---|
| Q-01 | **Jam/tanggal resmi tutup submission** dan cara submit? Tim belum tahu, dan deadline efektif internal 18 Okt | ⭐ Ya (deliverable) | CP / Discord JOINTS | Terbuka |
| Q-02 | Tema Healthcare sudah dikonfirmasi ke panitia? | Ya | Tim / panitia | Terbuka |
| Q-03 | Subtema wajib dipilih persis dari daftar? | Tidak | CP | Terbuka |
| Q-04 | Saldo trial Twilio tersisa berapa? | Tidak | Pemilik akun Twilio | Terbuka |
| Q-05 | Tanggal **reset kredit** ElevenLabs & sisa kredit saat ini? Tarif kredit per model? | Tidak lagi memblokir | Dashboard ElevenLabs | **Sebagian terjawab:** sisa ±15.000 (D-28). Tanggal reset & tarif per model belum diketahui |
| Q-06 | Nomor HP siapa yang dipakai untuk peran Bu Sri, Mas Dika, Bu Tini (maks. 5 terverifikasi)? | ⭐ Ya | Tim | **Sebagian terjawab:** 2 nomor tim (D-29). **Pembagian peran (nomor mana = Bu Sri, mana = Mas Dika) belum ditentukan** |
| Q-07 | Siapa penutur asli bahasa Jawa yang bisa memvalidasi frasa krama? | Tidak (MVP bisa minimal) | Tim | Terbuka |
| Q-08 | Ada **nakes** (dokter/perawat) yang bisa mereview aturan tanda bahaya & skrip skrining? | Tidak untuk MVP (label "draf"), **Ya untuk final** | Tim | Terbuka |
| Q-09 | Akun Meta (WhatsApp Cloud API) milik siapa/dibuat siapa? | Ya (WA) | Tim | **Terjawab:** akun Raphael (D-31) |
| Q-10 | Laptop mana yang menjadi server suara (OS, versi Python/Node)? | ⭐ Ya | Tim | **Sebagian terjawab:** laptop Raphael (D-30). OS & versi Python/Node dicatat di S-08 |
| Q-11 | Boleh memakai nama institusi nyata (Puskesmas/RSUD) di demo dengan label "(simulasi)", atau pakai nama fiktif? | Tidak | Tim | Terbuka (rekomendasi: label "(simulasi)", tanpa logo) |
| Q-12 | Teks resmi KMK 951/2026 sudah dibaca (bukan hanya ringkasan)? | Tidak | Tim | Terbuka |
| Q-13 | RS mana yang benar-benar punya **CT 24 jam** (RSUD Wonosari, RS Saptosari, RS Panti Rahayu, RSA UGM, Sardjito)? | Tidak untuk MVP (label "simulasi") | Tim (web resmi RS / telepon informasi) | Terbuka |
| Q-14 | Siapa yang menyediakan HP jadul untuk properti demo final? | Tidak (final) | Tim | Terbuka |
| Q-15 | Bersedia upgrade Twilio (berbayar) kalau ternyata dibutuhkan untuk demo final? Saat ini keputusannya: tidak (hemat) | Tidak | Tim | Terjawab sementara: tidak |
| Q-16 | Apakah ada lansia (keluarga anggota tim) yang bersedia ikut uji di Stage 2, dengan persetujuan? | Tidak (Stage 2) | Tim | Terbuka |
| Q-17 | Bahasa untuk nama variabel/fungsi & komentar kode (Indonesia atau Inggris)? | Ya (sebelum kode ditulis) | Tim | **Terjawab:** didelegasikan → D-32 |
| Q-19 | Ada nomor ketiga (peran Bu Tini / Sahabat Kring) untuk demo? Tanpa itu, konferensi darurat hanya pasien + anak | Tidak (ada alternatif WA) | Tim | Terbuka |
| Q-18 | Lisensi repo (misal MIT, Apache-2.0, atau tanpa lisensi)? | Tidak | Tim | Terbuka |

## 3. Cara memperbarui
- Keputusan baru → tambah baris D-xx (tanggal, sumber, alasan).
- Keputusan yang diubah → jangan dihapus, tambahkan baris baru yang menyebut "menggantikan D-xx".
- Pertanyaan terjawab → ubah status menjadi "Terjawab: …" dan, kalau menghasilkan keputusan, buat D-xx.
