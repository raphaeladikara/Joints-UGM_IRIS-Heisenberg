# 02 · Product Requirements Document (PRD)

Dokumen ini mendefinisikan **apa** yang dibangun. Bagaimana cara membangunnya ada di [03_ARSITEKTUR_TEKNIS.md](03_ARSITEKTUR_TEKNIS.md).

Prioritas:
- **MUST**: wajib ada di MVP 18 Okt.
- **SHOULD**: dikerjakan kalau MUST sudah selesai sebelum 18 Okt.
- **LATER**: Stage 2 (sebelum final 1 Nov) atau roadmap.

---

## 1. Persona demo (fiktif)

> Semua persona di bawah **fiktif** dan hanya dipakai untuk demo dan uji. Tidak ada data pasien sungguhan di MVP.

| Persona | Profil | Kebutuhan |
|---|---|---|
| **Bu Sri** (pengguna utama) | 72 th, Gunungkidul, hipertensi (amlodipin), tinggal sendiri sejak suami wafat, HP jadul, nyaman berbahasa Jawa, pendengaran sedikit menurun | Tetap mandiri di rumah, tidak merepotkan anak, ditolong cepat kalau ada apa-apa |
| **Mas Dika** (anak) | 38 th, bekerja di Jakarta, menelepon ibunya ±2× seminggu | Tahu kondisi ibu tanpa menginterogasi, punya bahan obrolan, dikabari cepat kalau darurat |
| **Bu Tini** (Sahabat Tilik) | Tetangga sebelah rumah, 5 menit jalan kaki | Dihubungi pertama saat darurat, tahu harus berbuat apa |
| **Perawat Prolanis** | Puskesmas, mengelola ±100 pasien hipertensi | Tahu siapa yang harus ditindaklanjuti hari ini tanpa menelepon satu per satu |
| **Tim IGD RSUD Wonosari** | Bagian dari jejaring Code Stroke | Info jam onset & hasil skrining sebelum pasien tiba |

---

## 2. User stories

| ID | Sebagai… | Saya ingin… | Supaya… |
|---|---|---|---|
| US-01 | Bu Sri | ditelepon setiap pagi dengan sapaan yang sopan dan jujur bahwa ini AI | saya tidak merasa ditipu |
| US-02 | Bu Sri | mendengar pesan suara dari anak saya di telepon pagi | saya merasa dekat dengan anak |
| US-03 | Bu Sri | ditanya obat dan tensi dengan sabar dan tidak menggurui | saya tetap merasa dihormati |
| US-04 | Bu Sri | segera mendapat pertolongan kalau mendadak bicara pelo atau tubuh lemah sebelah | saya tidak terlambat dibawa ke RS |
| US-05 | Bu Sri | yakin bahwa yang menelepon benar TILIK (bukan penipu) | saya aman dari penipuan |
| US-06 | Mas Dika | menerima rapor singkat + bahan obrolan setiap hari | telepon saya ke ibu jadi lebih nyambung |
| US-07 | Mas Dika | dikabari dan disambungkan langsung ke ibu saat darurat | saya bisa mengambil keputusan cepat |
| US-08 | Mas Dika | menitipkan pesan untuk disampaikan besok pagi | ibu tahu saya memperhatikan |
| US-09 | Bu Tini | ditelepon lebih dulu saat darurat dan diberi tahu apa yang harus dilakukan | saya bisa menolong dalam hitungan menit |
| US-10 | Perawat Prolanis | melihat daftar pasien yang perlu ditindaklanjuti hari ini (🟡/🔴) | waktu saya dipakai untuk yang paling butuh |
| US-11 | Tim IGD | menerima pre-alert (onset, skrining, obat, ETA) | kami bisa bersiap sebelum pasien tiba |

---

## 3. Fitur

### F-01 Panggilan keluar harian (MUST)
- Sistem bisa memulai panggilan ke nomor pasien pada jadwal atau dipicu manual (tombol "Tilik sekarang" untuk demo).
- Percakapan real-time dua arah. Pasien bisa memotong (*barge-in*).
- **Fallback (MUST):** kalau panggilan PSTN via Twilio trial ke nomor +62 tidak bisa dilakukan (hasil uji Stage 0), panggilan dilakukan lewat **browser (WebRTC)** dengan tampilan layar telepon.

**Acceptance criteria**
- [ ] Panggilan tersambung dan TILIK menyapa ≤ 3 detik setelah diangkat.
- [ ] Pasien bisa memotong TILIK, dan TILIK berhenti bicara.
- [ ] Panggilan yang tidak diangkat tercatat sebagai `no_answer`. Dua kali berturut-turut → masuk daftar 🟡.

### F-02 Pembuka: disclosure AI + kata sandi keluarga (MUST)
- Kalimat pembuka **selalu** memuat: nama pasien, "asisten AI", asal (Puskesmas), dan **kata sandi keluarga**.
- TILIK tidak pernah mengaku manusia atau mengaku punya perasaan.

**AC**
- [ ] 100% panggilan di harness evaluasi memuat disclosure + kata sandi pada giliran pertama.
- [ ] Ditanya "Niki tiyang napa robot?", TILIK menjawab jujur bahwa ia AI.

### F-03 Titip pesan dari anak (MUST, versi sederhana)
- Anak mengirim pesan **suara** atau teks lewat WhatsApp.
- MVP: pesan suara anak disimpan dan **diputar apa adanya** (suara asli, bukan dibacakan AI). Pesan teks dibacakan TILIK dengan awalan "Mas Dika titip pesan…".

**AC**
- [ ] Pesan yang masuk sebelum panggilan muncul di panggilan berikutnya, lalu ditandai `delivered`.

### F-04 Cek obat (MUST)
- Menanyakan apakah obat hari ini sudah diminum. Kalau belum, menggali alasannya (lupa / habis / merasa sehat / efek samping / lainnya).
- Tidak memberi dosis. Tidak memaksa. Alasan "menolak" dicatat dengan hormat.

**AC**
- [ ] Ekstraksi `adherence ∈ {sudah, belum, tidak_tahu}` dan `reason` tersimpan sebagai observasi.

### F-05 Cek tensi (MUST)
- Kalau pasien punya tensimeter, angka yang dibacakan dikonfirmasi ulang ("Satus sèket per sangang dasa, leres?").
- Ambang krisis memicu jalur tanda bahaya (lihat [05](05_DESAIN_PERCAKAPAN.md)).

**AC**
- [ ] Angka sistolik/diastolik tersimpan setelah konfirmasi. Angka yang tidak terkonfirmasi tidak dipakai untuk keputusan.

### F-06 Cek gejala (MUST)
- Pertanyaan terbuka + pertanyaan spesifik berdasarkan **SeGeRa Ke RS** (Kemenkes) dan gejala krisis hipertensi.

### F-07 Pemicu tanda bahaya 2 jalur + eskalasi 3 warna (MUST)
- Jalur 1: aturan deterministik. Jalur 2: klasifikasi LLM. **Cukup salah satu terpicu** untuk eskalasi.
- 🟢 dicatat · 🟡 masuk daftar tindak lanjut Puskesmas (≤ 24 jam) · 🔴 skrining stroke + eskalasi darurat.
- Jalur 3 (analisis suara) = SHOULD/LATER.

**AC**
- [ ] Di harness: recall 🔴 pada skenario kritis = target di [07](07_EVALUASI.md).
- [ ] Setiap keputusan warna punya jejak: jalur pemicu, kutipan ucapan, waktu.

### F-08 Skrining stroke verbal + last known well (MUST)
- Skrip adaptasi CPSS versi telepon: ulangi kalimat, angkat kedua tangan, cek senyum lewat orang terdekat (kalau ada).
- Menanyakan **jam terakhir merasa normal**, lalu menghitung sisa golden period.

### F-09 Eskalasi 🔴 (MUST)
Urutan:
1. Telepon **Sahabat Tilik** (tetangga) → disambungkan ke konferensi dengan pasien.
2. Telepon **anak** → dibriefing ≤ 15 detik → masuk konferensi.
3. WA alert ke anak + Sahabat Tilik: ringkasan, jam onset, **RS ber-CT terdekat** + estimasi waktu tempuh.
4. Pre-alert ke **Board IGD**.
5. Instruksi untuk menghubungi 119.

**Di demo dan uji, langkah 5 hanya berupa teks instruksi. Sistem tidak pernah memanggil 119 atau RS sungguhan.**

**AC**
- [ ] Dari pemicu 🔴 sampai HP anak berdering ≤ 30 detik (target, diukur).
- [ ] Board IGD menampilkan pre-alert ≤ 5 detik setelah pemicu.

### F-10 Penutup + edukasi (MUST)
- Penutup hangat + satu kalimat edukasi SeGeRa Ke RS (bergilir) + info bahwa pasien boleh menelepon balik nomor TILIK kapan saja.

### F-11 Rapor WA keluarga + Bahan Obrolan (MUST)
- Setelah panggilan, anak menerima: status (obat/tensi/gejala, warna), **💬 Bahan obrolan** (1–2 hal yang diceritakan pasien), tombol/tautan **"Telepon Ibu sekarang"**.
- Hanya informasi yang **diizinkan pasien** yang dikirim (MVP: pengaturan izin per pasien di data seed. UI pengaturan = LATER).

### F-12 Memori sederhana (MUST)
- Setelah panggilan, 0–3 fakta personal diekstrak (misal "cucu wisuda bulan depan") lalu dipakai di panggilan berikutnya.

### F-13 Web: Daftar Tilik Hari Ini (MUST)
- Tabel pasien: status panggilan, warna, tensi terakhir, kepatuhan 7 hari, alasan tindak lanjut. 🔴/🟡 di paling atas.

### F-14 Web: Board Pre-alert IGD (MUST)
- Kartu realtime: nama pasien (atau inisial), usia, jam onset/last known well, hasil skrining, obat yang diminum (termasuk antikoagulan: ya/tidak/tidak tahu), ETA, kontak keluarga. Ada label **"PRE-ALERT · keputusan klinis tetap di tim IGD"**.

### F-15 Nomor TILIK bisa ditelepon balik (SHOULD)
- Pasien menelepon nomor TILIK, langsung masuk sapaan + pertanyaan gejala (mode skrining).
- *Catatan: pada Twilio trial, panggilan masuk juga memutar pesan trial dan nomornya nomor AS. Kelayakannya diuji di Stage 0.*

### F-16 Analisis suara offline (SHOULD)
- Dari rekaman panggilan uji, hitung fitur (kecepatan bicara, rasio jeda) dan tampilkan grafik vs baseline. *Versi live = LATER.*

### F-17 Nudge Kangen + family-first (SHOULD)
- Kalau pasien menyebut kangen → WA ke anak "Bu Sri tadi bilang kangen. Telepon 5 menit hari ini?".

### Fitur LATER (Stage 2 / roadmap)
Panel tanda vital suara live · endpointing personal & backchannel · deteksi krama/ngoko otomatis · mode DTMF · UI berbagi bertingkat + mode rahasia · Telepon Bareng akhir pekan · jam kronis (tren minggu) · mode sovereign · integrasi SATUSEHAT/PSC 119 · uji lansia sungguhan.

---

## 4. Skenario demo (acuan untuk video & pitch)

| Babak | Isi | Fitur |
|---|---|---|
| 1. Pagi biasa | TILIK menelepon Bu Sri: disclosure + kata sandi, pesan suara Mas Dika, obat sudah, tensi 150/90 dikonfirmasi, cerita tomat panen, penutup + SeGeRa | F-01–F-06, F-10, F-12 |
| 1b. Hasilnya | Rapor WA Mas Dika + bahan obrolan. Daftar Tilik menampilkan Bu Sri 🟢 dan satu pasien lain 🟡 | F-11, F-13 |
| 2. Darurat | Panggilan pagi berikutnya: Bu Sri bicara pelo, tangan kiri lemas → skrining → last known well 06.40 | F-07, F-08 |
| 2b. Eskalasi | HP Bu Tini berdering, lalu HP Mas Dika berdering (diletakkan di meja juri) → konferensi. WA alert + RSUD Wonosari. Board IGD menyala | F-09, F-14 |

---

## 5. Requirement non-fungsional

| Kategori | Requirement |
|---|---|
| Latensi | Target p50 respons suara ≤ 1,5 s (MVP), ≤ 1,0 s (final). Harus diukur dan dilaporkan |
| Ketersediaan demo | Ada fallback: panggilan browser + video rekaman per babak |
| Privasi | Audio mentah tidak disimpan secara default. Transkrip disimpan minimal untuk audit demo (data fiktif) |
| Keamanan | Secrets hanya di `.env` lokal / env hosting, tidak pernah di-commit |
| Biaya | Hemat kredit ElevenLabs (lihat [10](10_ANGGARAN_KUOTA.md)) |
| Aksesibilitas suara | Tempo bicara pelan, kalimat pendek, satu pertanyaan per giliran |
| Bahasa | Bahasa Indonesia + frasa Jawa krama. Validasi penutur asli = pertanyaan terbuka |
