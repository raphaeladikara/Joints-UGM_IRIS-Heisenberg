# Ideas Breakdown: JOINTS x INSPIRE 2026 Hackathon

Dibuat 13 Oktober 2026. Deadline submission 15–16 Oktober, jadi sisa waktu efektif sekitar **2–3 hari**. Semua rekomendasi di bawah dibuat dengan batasan waktu ini.

---

## 1. Ringkasan lomba (yang relevan untuk ide)

| Hal | Detail | Implikasi untuk ide |
|---|---|---|
| Tema | Pilih 1 dari Education / Healthcare / Sustainability, tidak bisa diganti | Ide ini masuk **Healthcare** |
| Subtema Healthcare | Kepulauan/pedalaman · penyakit kronis · stres/burnout · **Puskesmas & klinik kewalahan antrean dan administrasi manual** · keluarga perawat lansia · polusi udara | Tidak ada subtema "disabilitas" atau "UGD" di Healthcare. Yang paling dekat: **Puskesmas/klinik, antrean, dan administrasi**. |
| Penilaian | Inovasi 25% · **Implementasi Teknis 30%** · Fungsionalitas & Desain 20% · Dampak & Kelayakan 15% · Presentasi 10% | 50% nilai ada di teknis plus fungsionalitas. Demo harus benar-benar jalan. |
| Deliverables | Video ≤ 2 menit, proposal ≤ 10 hlm, pitch deck (wajib ada bagian penggunaan AI), repo GitHub + README, prototype | Prototype harus bisa direkam untuk video dalam 2 hari |
| Final | 1 Nov, pitch 10–12 menit + QnA 5–8 menit | Ada ±2 minggu setelah submission untuk memoles demo sebelum final |

> Catatan: pemetaan bobot penilaian di PPT tidak sejajar rapi (sudah dicatat di `penjelasan_lomba.md`). Cek ulang ke slide aslinya.

---

## 2. Ide yang dinilai

**EmergencyTurjuman 2.0**: aplikasi kios/tablet di loket pendaftaran UGD. Pasien Tuli atau korban stroke berinteraksi lewat kamera. MediaPipe membaca gerakan tangan dan ekspresi wajah secara real-time, menerjemahkannya jadi teks/audio medis, dan memandu pasien memahami prosedur secara visual. Diposisikan sebagai alat bantu komunikasi aktif, bukan dasbor.

---

## 3. Temuan riset

### 3.1 Masalahnya nyata
- Dalam satu survei, **64,7% dari 405 responden disabilitas rungu** menilai akses layanan kesehatan di Indonesia masih sulit. Hambatan utamanya komunikasi dengan nakes, yang bisa berujung salah paham dan salah diagnosis. ([Sewagati ITS](https://journal.its.ac.id/index.php/sewagati/article/download/10541/9061/31209))
- Nakes yang bisa bahasa isyarat masih sangat sedikit, dan perbedaan struktur BISINDO dengan Bahasa Indonesia ikut menjadi hambatan. ([UIN Malang](https://urj.uin-malang.ac.id/index.php/mij/article/download/8913/2509))
- Penyandang disabilitas di Indonesia berjumlah sekitar 22,5–28 juta jiwa, tergantung sumbernya (BPS/Susenas 2020). Saya tidak menemukan angka resmi khusus Tuli. Untuk proposal, cari publikasi BPS per ragam disabilitas atau data GERKATIN. ([Untar](https://journal.untar.ac.id/index.php/jstupa/article/view/27502/17972), [detik](https://inet.detik.com/telecommunication/d-6946615/telkomsel-hadirkan-layanan-khusus-teman-tuli-di-19-grapari-se-indonesia))
- Ada dua sistem isyarat: **SIBI** (dipakai di SLB/pendidikan formal) dan **BISINDO** (dipakai komunitas Tuli sehari-hari). Untuk komunikasi pasien, yang tepat BISINDO. ([UPN Jatim](https://repository.upnjatim.ac.id/39556/2/21082010197-bab1.pdf))

### 3.2 Kompetitor dan prior art: "penerjemah BISINDO" sudah sangat ramai
- Puluhan skripsi/jurnal sudah membangun penerjemah BISINDO berbasis MediaPipe/CNN/LSTM/YOLO: Gunadarma, ITS, UPN Jatim, Narotama, Pamulang, Widya Cipta Dharma, Mercu Buana, dan lain-lain. ([ITS](https://repository.its.ac.id/100015), [Wicida](https://repository.wicida.ac.id/6370/), [Mercu Buana](https://repository.mercubuana.ac.id/69873))
- **Gesti Talk** (Binus) juara 3 Samsung Solve for Tomorrow 2025 dengan ide yang hampir sama: BISINDO ke teks/suara lewat kamera HP. ([Samsung](https://www.samsung.com/id/solvefortomorrow/alumni/kygb))
- Hampir semuanya **berhenti di alfabet atau kosakata kecil**, dan belum ada yang fokus ke **alur klinis**.
- **Kesimpulan:** juri hampir pasti sudah pernah melihat "penerjemah bahasa isyarat". Penerjemahnya sendiri tidak cukup untuk nilai inovasi. Pembedanya harus ada di **konteks klinis plus alur kerjanya**.

### 3.3 Batas teknologi
- Akurasi BISINDO di riset: **87–97%**, tetapi untuk **alfabet atau 10–76 kata isolated** dengan dataset kecil, dan diukur di kondisi lab. ([JUTIF](https://jutif.if.unsoed.ac.id/index.php/jurnal/article/view/1492), [Polibatam](https://jurnal.polibatam.ac.id/index.php/JAIC/article/download/11878/3402/38766))
- Studi untuk ASL mencatat akurasi turun dari 97% saat pelatihan menjadi 73% saat deploy. Penyebab yang sering disebut: pencahayaan, latar belakang, dan gestur yang mirip.
- **Penerjemahan kalimat kontinu** (continuous sign language translation) masih jadi masalah riset terbuka. Tidak realistis dikerjakan dalam 3 hari, bahkan untuk tim riset.
- Komunitas Tuli internasional sudah lama mengkritik "sarung tangan/aplikasi penerjemah". Alasannya: alat seperti ini mengabaikan grammar non-manual (alis, mulut, badan), dibangun tanpa melibatkan Tuli, dan **memindahkan beban komunikasi ke orang Tuli**. Banyak Tuli justru lebih nyaman memakai teks atau tulisan. ([CACM](https://cacm.acm.org/magazines/2018/12/232889-technology-for-the-deaf/fulltext), [Android Headlines](https://www.androidheadlines.com/2020/07/ucla-sign-language-translating-translator-glove-app-prototype-accurate-critics.html))

### 3.4 Konteks lapangan
- Antrean pendaftaran manual di Puskesmas melebihi standar (±8,8 menit per pasien vs standar 5–7 menit). Pendaftaran daring lewat Mobile JKN kurang dipakai karena lansia kesulitan memakai aplikasinya. ([Polije](https://jurkes.polije.ac.id/index.php/journal/article/download/634/206/4457), [Poltekkes Jogja](https://eprints.poltekkesjogja.ac.id/21512/4/Chapter%201.pdf))
- Banyak RS sudah memakai **APM (Anjungan Pendaftaran Mandiri)**, yaitu kios pendaftaran. Artinya bentuk "kios" sudah diterima di faskes, dan ide ini bisa diposisikan sebagai **lapisan aksesibilitas untuk APM**.
- Untuk stroke dengan afasia, alat yang dipakai adalah **papan komunikasi bergambar** (contoh: SmallTalk Intensive Care, AphasiaTalk), bukan bahasa isyarat. ([SmallTalk](https://apps.apple.com/us/app/-/id403057381), [AphasiaTalk](https://www.ict.mahidol.ac.th/sdg/aphasiatalk-application/))

---

## 4. Review board

Saya mensimulasikan 5 penilai dengan sudut pandang berbeda, sesuai siapa saja yang kemungkinan menjadi juri atau penanya saat QnA.

### 🩺 dr. A: Dokter IGD (sudut pandang klinis)
**Skor: 4/10.** "Konsepnya punya niat baik, tapi alurnya tidak cocok dengan cara IGD bekerja."
- Pasien gawat darurat **tidak antre di kios**. Di IGD, triase dilakukan perawat dalam hitungan menit (ESI/ATS), dan pendaftaran biasanya diurus keluarga belakangan. Kios di "loket pendaftaran UGD" akan dipertanyakan.
- **Stroke adalah kesalahan konsep paling fatal.** Pasien stroke tidak bisa bahasa isyarat. Sering satu sisi tubuhnya lumpuh (hemiparesis), jadi isyarat dua tangan pun tidak mungkin. Mereka butuh penanganan dalam *golden period* ±4,5 jam, bukan berinteraksi dengan kios. Kalau juri berlatar medis, poin ini bisa menjatuhkan seluruh pitch.
- Yang realistis: pasien Tuli dengan kondisi **non-kritis hingga semi-urgent** di **rawat jalan / Puskesmas / IGD level triase hijau-kuning**.

### 🤟 Mbak B: Aktivis komunitas Tuli
**Skor: 5/10.** "Jangan bikin alat yang memaksa kami ber-isyarat ke mesin."
- Istilah: komunitas lebih suka **"Tuli"** (huruf T kapital) daripada "tuna rungu". Ganti di semua materi. Aturan lomba juga melarang konten diskriminatif.
- Isyarat seharusnya **salah satu opsi input**, bukan satu-satunya. Banyak Tuli lebih cepat mengetik atau menunjuk gambar.
- Arah sebaliknya (nakes ke pasien) justru lebih sering gagal: perawat bicara, pasien Tuli tidak paham. Ide ini baru mengurus satu arah.
- Libatkan minimal 1 orang Tuli (Pusbisindo/GERKATIN DIY) sebagai validator. Ini juga bahan cerita yang kuat untuk pitch.
- BISINDO punya variasi daerah. Pilih satu (misal BISINDO Yogyakarta, karena final di UGM) dan nyatakan dengan jelas.

### 🤖 Mas C: AI/CV engineer (juri teknis, 30% bobot)
**Skor: 5/10 untuk klaim saat ini, 8/10 kalau scope-nya diperketat.**
- Klaim "menerjemahkan gerakan tangan dan ekspresi wajah secara real-time menjadi teks medis" terlalu lebar. Kalau di demo modelnya salah tebak, kepercayaan juri langsung hilang.
- Yang realistis dalam 2–3 hari: **isolated sign recognition 20–30 isyarat medis** pakai MediaPipe Holistic/Hand landmarks + model kecil (GRU/LSTM atau 1D-CNN) di browser. Dataset dibuat sendiri: ±30–40 sampel per isyarat × 3–4 orang.
- Wajib ada **confidence gating**: kalau confidence < threshold, tampilkan 3 kandidat teratas dan biarkan pasien memilih dengan tap. Ini menutupi kelemahan akurasi dan sekaligus menjadi fitur UX.
- "Ekspresi wajah" lebih baik dipakai untuk hal yang jelas, misalnya skala nyeri (Wong-Baker) yang dipilih dengan tap. Mengklaim membaca grammar non-manual dari wajah tidak realistis.
- Bonus teknis yang terlihat oleh juri: inferensi **on-device** (MediaPipe Tasks Vision + TF.js/ONNX Web), tanpa video yang dikirim ke server.

### 🏥 Bu D: Kepala Puskesmas / pengambil kebijakan (Dampak & Kelayakan)
**Skor: 5/10.** "Siapa yang beli, siapa yang pakai, dan masuk ke sistem apa?"
- Kalau output-nya cuma teks di layar, perawat tetap harus menulis ulang. Jadikan output **ringkasan anamnesis terstruktur** (keluhan utama, lokasi, durasi, skala nyeri, alergi, red flag) yang bisa dibaca perawat atau di-scan lewat QR, idealnya dalam format yang kompatibel dengan **SATUSEHAT (FHIR)**. Mock pun cukup.
- Posisikan sebagai **add-on untuk APM/kios pendaftaran yang sudah ada**, bukan hardware baru. Biaya cukup tablet + browser.
- Subtema: kalau dibingkai sebagai "**Puskesmas/klinik: pendaftaran inklusif yang memangkas waktu anamnesis**", ide ini menempel ke subtema resmi. Kalau dibingkai sebagai "UGD", ide ini terasa di luar daftar.
- Privasi: data kesehatan termasuk data pribadi spesifik menurut **UU PDP No. 27/2022**. Nyatakan bahwa video tidak disimpan dan semua pemrosesan terjadi di perangkat.

### 😈 Devil's advocate (pertanyaan QnA terburuk)
- "Kenapa tidak pakai tulisan atau ketik saja? Orang Tuli kan bisa membaca." → Jawaban: literasi Bahasa Indonesia tertulis di sebagian Tuli rendah karena BISINDO adalah bahasa pertama mereka dengan grammar berbeda. Isyarat + piktogram lebih inklusif. **Siapkan data atau kutipan pendukung.**
- "Akurasi model berapa? Kalau salah terjemahan medis, siapa yang bertanggung jawab?" → Jawaban: confidence gating + konfirmasi pasien + perawat tetap memverifikasi. Alat ini **asistif, bukan diagnostik**.
- "Apa bedanya dengan Gesti Talk dan puluhan skripsi BISINDO lainnya?" → Jawaban: mereka penerjemah umum level alfabet. Kita **alur anamnesis klinis dua arah** yang menghasilkan data terstruktur untuk faskes.
- "Versi 1.0-nya mana?" → Nama "2.0" akan memancing pertanyaan ini. Kalau tidak ada v1, **hapus "2.0"**.

---

## 5. Skor rubrik: ide sekarang vs alternatif

Ini estimasi subjektif dari board (skala 0–10 per aspek, dikali bobot):

| Ide | Inovasi 25% | Teknis 30% | Fungsi & Desain 20% | Dampak 15% | Presentasi 10% | **Total /100** | Risiko 3 hari |
|---|---|---|---|---|---|---|---|
| **A0. EmergencyTurjuman (versi sekarang)** | 6 | 5 | 6 | 4 | 7 | **~55** | Tinggi (klaim terlalu besar, stroke salah konsep) |
| **A1. Turjuman versi tweak (lihat §6)** | 7,5 | 7,5 | 8 | 7,5 | 8 | **~76** | Sedang-rendah |
| B. StrokeGuard: deteksi dini stroke (FAST) via kamera untuk keluarga lansia (asimetri wajah via Face Mesh, arm drift via Pose, bicara pelo via audio) | 8,5 | 6,5 | 7 | 7 | 9 | **~74** | Tinggi (validitas medis, ganti ide total, tanpa dataset pasien) |
| C. Monitor lansia: deteksi jatuh (Pose) + kepatuhan obat | 6,5 | 7 | 7 | 7 | 7,5 | **~69** | Sedang (deteksi jatuh sudah umum) |
| D. Antrean + pra-triase Puskesmas berbasis LLM (generik) | 5 | 7 | 7 | 7,5 | 7 | **~66** | Rendah, tapi inovasinya pas-pasan |
| E. Chatbot/konseling burnout mahasiswa | 4 | 6 | 7 | 6 | 7 | **~58** | Rendah, tapi sangat pasaran |

**Verdict board:** tidak ada alternatif yang **jauh** lebih bagus. Satu-satunya pesaing serius adalah B (StrokeGuard): wow factor-nya tinggi, tetapi harus mulai dari nol 2 hari sebelum deadline, dan juri medis akan menyerang validitasnya. **Pertahankan ide Turjuman, tetapi lakukan tweak besar.** Versi sekarang (~55) punya beberapa lubang yang bisa menjatuhkan nilai. Versi tweak (~76) adalah taruhan dengan risiko paling rendah dan potensi paling tinggi.

> Ide stroke jangan dibuang: simpan sebagai **roadmap / future work** di proposal ("modul skrining FAST"). Itu menunjukkan visi tanpa menambah scope.

---

## 6. Rekomendasi tweak (versi A1)

### 6.1 Reframing
| Sebelum | Sesudah |
|---|---|
| Kios di **loket UGD** | Kios/tablet di **pendaftaran Puskesmas & klinik/RS (APM)**, untuk triase non-kritis. Langsung menempel ke subtema "Puskesmas kewalahan antrean & administrasi manual". |
| Untuk pasien Tuli **dan korban stroke** | Fokus **Teman Tuli** (pengguna utama). Mode piktogram + teks besar otomatis membantu lansia dan pasien afasia (pengguna sekunder). Stroke dihapus dari klaim utama. |
| "Menerjemahkan gerakan + ekspresi jadi teks medis" (satu arah) | **Komunikasi dua arah**: pasien → nakes (isyarat/piktogram/ketik) dan nakes → pasien (suara → teks + piktogram + klip video BISINDO). |
| Output teks/audio | Output **ringkasan anamnesis terstruktur** + nomor antrean + QR untuk perawat. |
| "tuna rungu" | **"Tuli" / "Teman Tuli"** |
| "2.0" | Hapus, kecuali memang ada v1 |

Usulan nama: **Turjuman**, **Isyarat Sehat**, atau **TemanSehat**. Hindari kata "Emergency" karena memancing kritik soal alur IGD.

### 6.2 Alur pengguna (yang didemokan)
1. **Pilih mode**: 🤟 Isyarat · 👆 Gambar · ⌨️ Ketik. Kios mendeteksi tangan di depan kamera lalu menyarankan mode isyarat.
2. **Keluhan utama**: pasien berisyarat, misalnya "SAKIT" + "PERUT". Kalau model ragu, muncul 3 kandidat untuk ditap.
3. **Lokasi**: tap pada **body map**.
4. **Skala nyeri**: tap wajah Wong-Baker 0–10.
5. **Durasi & gejala penyerta**: isyarat/tap (hari, demam, mual, muntah, sesak, darah).
6. **Red-flag check** berbasis aturan sederhana (nyeri dada, sesak berat, perdarahan, hamil + nyeri perut). Kalau terpenuhi, layar menampilkan "PANGGIL PERAWAT SEKARANG" dan muncul alert.
7. **Ringkasan**: LLM menyusun gloss isyarat menjadi kalimat Bahasa Indonesia baku + JSON terstruktur. Pasien mengonfirmasi ✔️.
8. **Tiket + QR**: perawat scan dan langsung membaca ringkasan di HP (cukup satu halaman, bukan dasbor).
9. **Mode Nakes → Pasien**: perawat bicara, lalu teks besar + piktogram muncul, ditambah klip BISINDO pra-rekam untuk 10–15 kalimat prosedur umum ("Silakan tunggu dipanggil", "Kami akan ambil darah", "Buka baju bagian atas").

### 6.3 Kosakata isyarat MVP (±20–25, isolated)
SAKIT, KEPALA, PERUT, DADA, DEMAM, PUSING, MUAL, MUNTAH, SESAK, BATUK, DIARE, DARAH/BERDARAH, HAMIL, ALERGI, OBAT, HARI, MINGGU, YA, TIDAK, TOLONG, TERIMA KASIH, SELESAI.
> Validasi bentuk isyarat ke Teman Tuli atau video Pusbisindo. Nyatakan varian BISINDO yang dipakai.

### 6.4 Tech stack (bisa jadi dalam 2–3 hari)
| Lapisan | Pilihan |
|---|---|
| Frontend kios | React + Vite (atau Next.js), layout tablet landscape, PWA |
| Landmark | **MediaPipe Tasks Vision** (HandLandmarker + PoseLandmarker; Holistic kalau sempat) di browser |
| Model isyarat | Python: rekam landmark → GRU/LSTM kecil atau 1D-CNN (Keras/PyTorch) → export **TF.js / ONNX Web**. Inferensi on-device. |
| Nakes → pasien | Web Speech API (`id-ID`) untuk STT + piktogram (ARASAAC, lisensi CC) + video BISINDO pra-rekam |
| Ringkasan | LLM (Claude API): gloss → kalimat + JSON anamnesis; red-flag tetap **rule-based**, bukan LLM |
| Data/QR | Supabase/Firebase atau JSON lokal + QR, dengan mock resource FHIR `Observation`/`Condition` (sebut "SATUSEHAT-ready") |
| Privasi | Video tidak pernah keluar dari browser; yang dikirim hanya teks ringkasan |

### 6.5 Rencana kerja sampai deadline
| Kapan | Target |
|---|---|
| **13 Okt (hari ini)** | Kunci scope & kosakata. Rekam dataset (20–25 isyarat × 30–40 sampel × 3–4 orang, variasi cahaya/latar). Skeleton UI kios. |
| **14 Okt** | Training + konversi model ke web. Integrasi kamera → prediksi → kandidat top-3. Body map, skala nyeri, red-flag, ringkasan LLM, QR. Mode nakes → pasien (STT + piktogram). |
| **15 Okt pagi–siang** | Bug fix, rekam demo, edit **video ≤ 2 menit**. README + repo rapi. |
| **15–16 Okt** | Proposal ≤ 10 hlm, pitch deck (+ slide **penggunaan AI**: Claude/ChatGPT untuk coding & copy, MediaPipe, LLM di produk). Submit, dan **cek jam tutup**. |
| **16 Okt–1 Nov** (kalau lolos) | Uji dengan 2–3 Teman Tuli, tambah kosakata, ukur akurasi & waktu anamnesis (sebelum vs sesudah), poles demo live. |

### 6.6 Angka yang perlu ada di pitch
- Akurasi model per kelas (confusion matrix) dan latensi inferensi (ms/frame) di tablet.
- Estimasi waktu anamnesis: tanpa alat (tulis-tulisan bolak-balik) vs dengan alat. Uji sendiri walau sampelnya kecil.
- Biaya: tablet ±Rp3–5 jt + browser, tanpa server GPU.
- Statistik 64,7% Tuli kesulitan akses kesehatan sebagai hook masalah.

---

## 7. Hal yang perlu dicek

1. **Apakah tema Healthcare sudah dikonfirmasi ke panitia?** Kalau belum, ini tetap pilihan yang tepat.
2. **Apakah subtema wajib dipilih persis dari daftar**, atau hanya contoh? Tanya CP/Discord. Kalau wajib, framing "Puskesmas/klinik" (§6.1) jadi keharusan.
3. **Ada kenalan Teman Tuli / juru bahasa isyarat?** Satu orang validator saja sudah mengangkat nilai dampak dan kredibilitas di QnA.
4. **Ada v1-nya?** Kalau tidak ada, hapus "2.0".
5. Jam tutup submission (belum tertulis di PPT).

---

## 8. Kesimpulan singkat

- **Ide dasarnya layak dipertahankan.** Masalahnya nyata, emosional, dan cocok dengan kekuatan demo computer vision.
- **Versi sekarang punya 3 lubang besar:** (1) stroke salah konsep, (2) alur kios di IGD tidak realistis, (3) klaim penerjemahan real-time terlalu besar dan rawan gagal saat demo. Ditambah subtema yang kurang menempel dan pesaing "penerjemah BISINDO" yang sangat banyak.
- **Tweak yang mengubah hasil:** pindah ke pendaftaran Puskesmas/APM, fokus Teman Tuli, komunikasi dua arah, input multimodal dengan confidence gating, dan output anamnesis terstruktur + QR. Estimasi skor naik dari ~55 ke ~76.
- Tidak perlu ganti ide. Ide alternatif terbaik (StrokeGuard) masuk ke roadmap.

---

### Sumber
- [Sewagati ITS: akses kesehatan disabilitas rungu](https://journal.its.ac.id/index.php/sewagati/article/download/10541/9061/31209)
- [UIN Malang: kesehatan mental pasien tunarungu](https://urj.uin-malang.ac.id/index.php/mij/article/download/8913/2509)
- [Untar: data disabilitas BPS/Susenas](https://journal.untar.ac.id/index.php/jstupa/article/view/27502/17972)
- [detik: Kemenko PMK data disabilitas](https://inet.detik.com/telecommunication/d-6946615/telkomsel-hadirkan-layanan-khusus-teman-tuli-di-19-grapari-se-indonesia)
- [UPN Jatim: SIBI vs BISINDO](https://repository.upnjatim.ac.id/39556/2/21082010197-bab1.pdf)
- [Samsung Solve for Tomorrow: Gesti Talk](https://www.samsung.com/id/solvefortomorrow/alumni/kygb)
- [ITS: penerjemah BISINDO web](https://repository.its.ac.id/100015)
- [Wicida: BISINDO Translator mobile](https://repository.wicida.ac.id/6370/)
- [Mercu Buana: MediaPipe Holistic + LSTM BISINDO](https://repository.mercubuana.ac.id/69873)
- [JUTIF Unsoed: pengenalan BISINDO](https://jutif.if.unsoed.ac.id/index.php/jurnal/article/view/1492)
- [Polibatam JAIC: CNN BISINDO](https://jurnal.polibatam.ac.id/index.php/JAIC/article/download/11878/3402/38766)
- [CACM: Technology for the Deaf](https://cacm.acm.org/magazines/2018/12/232889-technology-for-the-deaf/fulltext)
- [Android Headlines: kritik glove penerjemah](https://www.androidheadlines.com/2020/07/ucla-sign-language-translating-translator-glove-app-prototype-accurate-critics.html)
- [Polije: antrean pendaftaran Puskesmas](https://jurkes.polije.ac.id/index.php/journal/article/download/634/206/4457)
- [Poltekkes Jogja: beban Puskesmas Gamping](https://eprints.poltekkesjogja.ac.id/21512/4/Chapter%201.pdf)
- [SmallTalk Intensive Care](https://apps.apple.com/us/app/-/id403057381)
- [AphasiaTalk (Mahidol)](https://www.ict.mahidol.ac.th/sdg/aphasiatalk-application/)
