# 15 · Defense Bank: Pertanyaan Sulit Juri & Jawabannya

Tujuan: membuat KRING **"bulletproof"** saat QnA (5–8 menit di Grand Final). Setiap pertanyaan punya:
- **Jawaban 15 detik** (untuk diucapkan)
- **Bukti** (data/sumber)
- **Fitur/roadmap** yang membuktikannya (bukan sekadar janji)

> Aturan jawaban: **jujur soal batasan, lalu tunjukkan lapisan yang menutupnya.** Juri lebih percaya tim yang mengakui batas daripada tim yang mengklaim sempurna.
> Jawaban yang menyebut "(angka hasil uji)" harus diisi dengan hasil evaluasi nyata, jangan dikarang.

---

## 1. Pertanyaan paling berbahaya: "Bagaimana kalau Mbah tiba-tiba krisis/sekarat di luar jam telepon?"

### 1.1 Jawaban 15 detik
> "Betul, telepon harian bukan alarm 24 jam, dan kami tidak mengklaimnya. Karena itu KRING dirancang sebagai **otak eskalasi yang agnostik perangkat**. Telepon pagi adalah lapisan pertama. Sinyal lain, seperti tombol SOS, jam tangan yang mendeteksi jatuh atau ritme jantung tidak teratur, atau Mbah yang menelepon balik, masuk ke mesin eskalasi yang sama. Sinyal datang, KRING langsung menelepon Mbah. Kalau tidak ada jawaban, tetangga, anak, dan IGD bergerak. Ini bisa kami demokan sekarang."
> *(Lalu tekan tombol "Simulasikan: jam tangan mendeteksi jatuh" di konsol demo, kalau F-18 sudah jadi.)*

### 1.2 Lapisan perlindungan KRING
| Lapisan | Mekanisme | Siapa yang terjangkau | Biaya untuk keluarga | Status |
|---|---|---|---|---|
| **L0: Telepon harian** | Cek obat/tensi/gejala + skrining stroke + edukasi SeGeRa Ke RS | Semua yang punya akses telepon | 0 (B2G) | MVP |
| **L1: Telepon balik kapan saja** | Mbah/keluarga menelepon nomor KRING, langsung masuk mode skrining | Semua | Pulsa telepon | SHOULD (F-15) |
| **L2: Protokol tidak diangkat** | Pasien berisiko tinggi tidak mengangkat → ulang 15 menit → Sahabat Kring mengecek ke rumah | Semua | 0 | SHOULD (F-19) |
| **L3: Tombol SOS GSM (+ deteksi jatuh)** | Liontin/gelang ber-SIM: tekan tombol atau terdeteksi jatuh → panggilan ke nomor KRING → KRING skrining, kalau diam → 🔴 | Lansia **tanpa smartphone** | Perangkat sekali beli + pulsa (harga lokal belum dicek; harga internasional ±$25–90) | Roadmap (Stage 3) |
| **L4: Jam tangan pintar** | Deteksi jatuh, notifikasi ritme tidak teratur (AFib, faktor risiko stroke), tensi (model tertentu) → event ke KRING | Keluarga mampu | Mahal (misal Huawei Watch D ±Rp5,5 jt) | Stage 2: **simulasi**. Stage 3: integrasi |
| **L5: Komunitas** | Sahabat Kring, kader, Posyandu Lansia, PSC 119 | Semua | 0 | MVP (Sahabat Kring), roadmap (PSC 119) |

### 1.3 Kenapa TIDAK langsung "pakai smartwatch saja"? (antisipasi lanjutan)
| Kendala | Bukti |
|---|---|
| **Mahal** untuk lansia desa | Huawei Watch D (pengukur tensi di pergelangan) dijual ±Rp5,48 jt di Indonesia ([Gizmologi](https://gizmologi.id/gadget/wearable/spesifikasi-harga-huawei-watch-d2/amp/), [Soyacincau](https://soyacincau.com/?p=345745)) |
| **Kepatuhan pemakaian** rendah | Uji Pulsewatch (penyintas stroke ≥50 th): rata-rata jam dipakai **21,2 dari 30 hari**, skor usability 65/100 ([JMIR Cardio](https://cardio.jmir.org/2023/1/e45137/PDF)) |
| Perlu diisi daya setiap hari dan biasanya butuh smartphone pendamping | Hanya ±26% lansia memakai internet (BPS via GoodStats) |
| Deteksi jatuh di pergelangan **tidak sempurna** | Studi aplikasi smartwatch: sensitivitas jatuh ±77%, spesifisitas 99% (dewasa sehat, jatuh disimulasikan) ([PMC8981002](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8981002/)) |
| Fitur tensi jam tangan butuh kalibrasi dengan manset | Samsung Health Monitor: kalibrasi awal dengan manset, tersedia di Indonesia sejak 2021 untuk model tertentu ([Samsung](https://news.samsung.com/global/samsung-expands-vital-blood-pressure-and-electrocardiogram-tracking-to-galaxy-watch3-and-galaxy-watch-active2-in-31-more-countries)) |

**Kalimat kunci:** *"Jam tangan adalah sensor, KRING adalah otaknya. Sensor tanpa otak hanya bunyi alarm di HP anak yang sedang rapat di Jakarta. KRING mengubah sinyal menjadi tindakan: menelepon Mbah, menggerakkan tetangga, dan memberi tahu IGD."*

### 1.4 Kenapa tombol SOS saja tidak cukup?
- Lansia yang jatuh sering **tidak bisa bangun** dan bisa lama tergeletak. Studi BMJ pada lansia > 90 tahun: **80%** tidak bisa bangun sendiri setelah minimal satu kali jatuh, **30%** tergeletak ≥ 1 jam ([BMJ 2008](https://dx.doi.org/10.1136/bmj.a2227)).
- Tombol tidak berguna kalau tidak ditekan (pingsan, panik, tidak dipakai). Karena itu dibutuhkan **deteksi jatuh otomatis** dan **telepon proaktif** (L0/L2), bukan hanya tombol.
- *(Angka "hanya 20% menekan tombol" yang beredar di internet **belum terverifikasi** dari paper aslinya. Jangan dikutip.)*

### 1.5 Bukti nilai jam tangan untuk pencegahan stroke (kalau ditanya)
- Uji EQUAL (Belanda, ≥ 65 th, risiko stroke tinggi): AFib baru terdeteksi **9,6%** pada kelompok smartwatch vs **2,3%** perawatan biasa dalam 6 bulan; 57% di antaranya tanpa gejala. Dampaknya pada angka stroke **belum terbukti** ([HMP](https://www.hmpgloballearningnetwork.com/site/jic/news/smartwatch-screening-detects-more-atrial-fibrillation-high-risk-us-adults), [9to5Mac](https://9to5mac.com/2026/01/22/apple-watch-afib-study-effective-standard-care/)).
- Implikasi untuk KRING: notifikasi ritme tidak teratur → event `irregular_rhythm` → 🟡 ke Puskesmas untuk pemeriksaan EKG (bukan 🔴).

---

## 2. Validitas klinis

| Pertanyaan | Jawaban 15 detik | Bukti / fitur |
|---|---|---|
| "Skrining stroke lewat telepon akurat?" | "Tidak sempurna. Dispatcher yang memakai CPSS lewat telepon menangkap ±68%. Tapi pembandingnya adalah lansia yang tinggal sendiri, yang saat ini tidak diskrining sama sekali, dengan median kedatangan ke RS 16,5 jam. Desain kami mengutamakan recall: cukup satu jalur terpicu, eskalasi." | [PMC3867422](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3867422/), OR-gate (05 §4) |
| "Kalau AI salah, siapa yang bertanggung jawab?" | "KRING adalah decision support, bukan diagnosis. Semua 🔴 diteruskan ke manusia, setiap keputusan punya jejak audit, dan modul medisnya kami arahkan ke regulatory sandbox KMK 951/2026." | 06 §3 |
| "Sudah divalidasi dokter?" | "Belum, dan kami menandainya sebagai draf. Aturan kami turunkan dari SeGeRa Ke RS (Kemenkes) dan CPSS. Langkah berikutnya: review nakes dan pilot dengan jejaring Code Stroke." | Q-08 |
| "Alarm palsu membebani IGD?" | "🔴 hanya untuk kriteria mayor. Sisanya 🟡 ke Puskesmas. Pre-alert bersifat pemberitahuan, keputusan tetap di IGD. Alarm palsu kami ukur: (angka hasil uji) per 100 panggilan." | 07 §3 |
| "Kalau krisis hipertensi tanpa gejala?" | "Itu 🟡+, nakes menghubungi hari itu juga, bukan ambulans. Sesuai prinsip bahwa krisis tanpa kerusakan organ ditangani sebagai urgensi." | 05 §4 (draf, review nakes) |
| "Bagaimana kalau Mbah tidak punya tensimeter?" | "KRING tetap bekerja lewat gejala. Tensi diambil dari kader/Posyandu. Roadmap: tensimeter Bluetooth bersama di Posyandu." | L5, roadmap |
| "Bagaimana dengan TIA (gejala stroke yang hilang sendiri)?" | "Tetap diperlakukan serius dan dieskalasi, karena TIA bisa menjadi peringatan stroke. Ambang finalnya menunggu review nakes." | P-20 |

## 3. Teknis

| Pertanyaan | Jawaban 15 detik | Bukti / fitur |
|---|---|---|
| "Ini cuma wrapper API?" | "Vendor menyediakan telinga dan mulut. Otaknya kode kami: state machine, safety OR-gate, mesin eskalasi event-driven, memori, aplikasi lima peran, dan harness evaluasi dengan 143 skenario teks (100 non-kritis, 35 kritis, 8 guardrail)." | 03 |
| "Latensinya cukup untuk lansia?" | "p50 1,78 detik (WebRTC, 12 giliran). 0,7 detik di antaranya jeda hening yang sengaja dibuat panjang untuk lansia; STT 0,34 s, otak kami 8 ms, suara pertama 0,16 s. Ekor p95 5,1 s dari LLM dan pesan panjang, dan sudah kami tahu cara memangkasnya." | 07 |
| "Bahasa Jawa?" | "STT kami uji di audio 8 kHz kualitas telepon: WER 0% untuk bahasa Indonesia, 11,8% untuk bahasa Jawa. Itu suara sintetis, jadi angka lapangan lebih tinggi, dan itu yang kami uji berikutnya bersama lansia." | S-02/S-03 |
| "Kalau vendor (OpenAI/ElevenLabs/Twilio) down?" | "Panggilan gagal masuk daftar 'perlu ditelepon manusia' di Puskesmas, jadi tidak ada pasien yang hilang diam-diam. Roadmap: multi-vendor + mode sovereign." | Daftar Kring |
| "Kenapa tidak lewat aplikasi/WhatsApp call?" | "Hanya ±26% lansia memakai internet. Telepon biasa menjangkau semuanya, termasuk HP jadul. Aplikasinya kami taruh di tangan anak, tetangga, perawat, dan IGD yang sudah memakai ponsel pintar." | BPS |
| "Lho, katanya tanpa aplikasi, kok demonya aplikasi?" | "Mbah memang tanpa aplikasi; layar HP Mbah di demo hanya simulator telepon biasa (tertulis di layarnya). Aplikasi KRING untuk orang-orang di sekitar Mbah." | Prototipe |
| "Akurasinya berapa?" | "Recall merah 34/35 dengan dua jalur, 26/35 kalau hanya aturan. Alarm palsu 13 per 100, semuanya dari negasi seperti 'dada saya tidak sakit'. Kami laporkan juga satu kebocoran data yang ditemukan harness, karena evaluasi gunanya mencari kelemahan." | eval/ |
| "Skalanya ke jutaan pasien?" | "Arsitekturnya stateless per panggilan dan bisa diparalelkan. Biaya terukur ±US$0,27 per panggilan PSTN (100 panggilan ±US$27,2), lebih dari 80%-nya tarif telepon, jadi tuas penghematannya kerja sama operator." | [UPI](https://www.upi.com/Health_News/2025/09/08/AI-voice-agent-seniors-high-blood-pressure/4551757339502/) |
| "Kenapa ada pesan trial / nomor luar negeri di demo?" | "Ini prototype dengan akun uji coba. Produksi memakai nomor lokal lewat mitra operator." | R-02 |
| "Data pasiennya asli?" | "Tidak, semua data di prototype fiktif." | PRV-04 |

## 4. Pengguna & etika
Lihat jawaban lengkap di [`docs/research/TILIK_Celah_Etika_dan_Defense.md`](../research/TILIK_Celah_Etika_dan_Defense.md). Ringkasnya:

| Pertanyaan | Jawaban 15 detik |
|---|---|
| "AI menggantikan telepon anak?" | "Metrik utama kami adalah frekuensi telepon anak. KRING memberi bahan obrolan dan mengingatkan anak menelepon. Kalau angka itu turun, KRING gagal." |
| "Lansia mau ngobrol dengan AI?" | "CareCall di Korea dipakai pemda Seoul dan Busan. Emory menjangkau 85% pasien lansia. Hasil uji kami: (angka/kutipan)." |
| "Penipuan yang menyamar jadi KRING?" | "Setiap panggilan diawali kata sandi keluarga. KRING tidak pernah meminta uang, OTP, atau NIK." |
| "Mbah pikun/demensia?" | "Persetujuan bertahap (assent pasien + consent wali). Kebingungan berulang ditandai untuk nakes." |
| "Pendengaran kurang?" | "Tempo pelan, kalimat pendek, mode tombol angka (DTMF) di roadmap." |
| "Privasi?" | "Audio mentah tidak disimpan, ada minimisasi data, mengacu UU PDP. Rencana produksi: data di Indonesia (mode sovereign)." |
| "Mbah menolak minum obat?" | "Dihormati. KRING menggali alasannya, memberi informasi, dan mencatat untuk dokter. Tidak memaksa." |

## 5. Bisnis & adopsi

| Pertanyaan | Jawaban 15 detik | Bukti |
|---|---|---|
| "Siapa yang bayar?" | "Tiga jalur: Puskesmas (indikator kapitasi Prolanis/RPPT), keluarga (premium), dan asuransi (klaim stroke turun). Pasien JKN gratis." | v4 §3.8 |
| "Kenapa Puskesmas mau?" | "RPPT adalah indikator kapitasi berbasis kinerja BPJS, dan banyak Puskesmas jauh di bawah target 5% (Cilegon 0,68%). KRING menyediakan data tensi & kepatuhan yang dibutuhkan." | v3 §3 |
| "Bedanya dengan reminder SMS Prolanis?" | "SMS satu arah dan tidak tahu kenapa pasien berhenti minum obat (59,8% karena merasa sehat). KRING bercakap, menggali alasan, dan menyaring tanda bahaya." | Riskesdas 2018 |
| "Kompetitor (Hippocratic AI, CareCall)?" | "Mereka membuktikan konsepnya di AS dan Korea. Belum ada di Indonesia, dan belum ada yang menggabungkan skrining stroke, jam onset, pre-alert IGD, dan loop keluarga." | v4 §2 |
| "Kenapa harus kalian, bukan Halodoc/BPJS?" | "Kami fokus ke segmen yang tidak terjangkau aplikasi: lansia tanpa internet. Kami terbuka bermitra dengan BPJS/operator." | – |

## 6. Regulasi

| Pertanyaan | Jawaban 15 detik |
|---|---|
| "Butuh izin alat kesehatan?" | "Ya, untuk modul medisnya. KMK 951/2026 (September 2026) mengatur izin edar software medis termasuk AI/LLM, dan ada regulatory sandbox. Modul administratif (pengingat, rapor) kami pisahkan dari modul skrining." |
| "Telemedisin perlu izin?" | "KRING tidak memberikan konsultasi medis jarak jauh. Ia mengumpulkan data dan meneruskannya ke faskes. Detail regulasi telemedisin akan dikaji bersama mitra." *(jujur: belum dikaji mendalam)* |

## 7. Pertanyaan "jebakan" & cara menjawab

| Jebakan | Cara aman |
|---|---|
| Juri menyebut angka/studi yang tidak kita tahu | "Kami belum membaca studi itu. Boleh kami catat dan kaji?" Jangan mengarang |
| "Kalau begitu sistem kalian tidak berguna dong?" | Akui batasnya, lalu kembali ke pembanding: "dibanding tidak ada skrining sama sekali…" |
| Pertanyaan di luar scope (kanker, ibu hamil, dll.) | "Arsitekturnya bisa diperluas (protokol baru = konten baru), tapi fokus validasi kami saat ini hipertensi & stroke" |
| "Kenapa tidak pakai AI lokal?" | "Roadmap mode sovereign, misalnya Sahabat-AI yang mendukung bahasa Jawa dan Sunda. MVP memakai API karena keterbatasan waktu" |

## 8. Latihan
- [ ] Setiap anggota tim hafal jawaban 15 detik untuk §1 dan 5 pertanyaan teratas di §2–§5.
- [ ] Simulasi QnA 2× sebelum final: satu orang menjadi juri "galak" memakai dokumen ini.
- [ ] Isi semua "(angka hasil uji)" dari laporan evaluasi sebelum 31 Okt.

---

### Sumber tambahan
- [Huawei Watch D2 harga Indonesia (Gizmologi)](https://gizmologi.id/gadget/wearable/spesifikasi-harga-huawei-watch-d2/amp/) · [Watch D3 sertifikasi Indonesia](https://gadgetsandwearables.com/2026/08/19/huawei-watch-d3-certification-riv-b10-riv-b11/)
- [Deteksi jatuh smartwatch (PMC8981002)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8981002/) · [Review wearable jatuh (PMC8004721)](https://pmc.ncbi.nlm.nih.gov/articles/PMC8004721/)
- [Samsung Health Monitor Indonesia (2021)](https://news.samsung.com/global/samsung-expands-vital-blood-pressure-and-electrocardiogram-tracking-to-galaxy-watch3-and-galaxy-watch-active2-in-31-more-countries)
- [Pulsewatch RCT (JMIR Cardio)](https://cardio.jmir.org/2023/1/e45137/PDF) · [EQUAL trial (HMP)](https://www.hmpgloballearningnetwork.com/site/jic/news/smartwatch-screening-detects-more-atrial-fibrillation-high-risk-us-adults)
- [BMJ: lansia > 90 th tidak bisa bangun setelah jatuh](https://dx.doi.org/10.1136/bmj.a2227)
- [Contoh perangkat SOS GSM dengan deteksi jatuh (Beghelli)](https://beghelli.it/en/products/household-products/salvalavita/salvalavita-pocket-gsm) · [Newegg listing](https://www.newegg.com/p/3C6-02X3-01DN5)

## 9. Framing companion (pembaruan 16 Okt)

| Pertanyaan | Jawaban 15 detik |
|---|---|
| "Ini aplikasi kesehatan atau teman ngobrol?" | "Teman dulu. Mbah ditelepon karena ada yang ingin tahu kabarnya; karena tiap hari bicara, KRING juga yang paling cepat tahu kalau ada tanda stroke. Kesepian sendiri terkait risiko stroke 32% lebih tinggi." |
| "Apa bedanya dengan CareCall Korea?" | "CareCall berhenti di petugas. KRING menyambungkan dua arah ke anak (cerita ke aplikasi anak, suara anak kembali ke Mbah) dan punya jaring pengaman stroke: skrining, jam onset, tetangga dulu, pre-alert IGD." |
| "Anak jadi malas menelepon karena sudah ada AI?" | "Metrik utama kami justru frekuensi telepon anak (streak telepon keluarga di aplikasi). Bahan obrolan dan Nudge Kangen dibuat supaya anak menelepon, bukan diganti." |
