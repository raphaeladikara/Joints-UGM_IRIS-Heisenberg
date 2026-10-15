# Ideas Breakdown v2: mencari ide 95+/100 (Healthcare)

Dibuat 13 Oktober 2026, lanjutan dari [Ideas_Breakdown.md](Ideas_Breakdown.md). Deadline submission 15–16 Oktober, final 1 November.

> **Soal angka 95+:** skor di dokumen ini adalah **proyeksi plafon** (ceiling) kalau eksekusinya penuh. Tidak ada ide yang dijamin 95. Yang bisa dilakukan: pilih ide dengan plafon paling tinggi, lalu tutup semua celah yang bisa memotong nilai. Bagian §5 berisi daftar yang harus ada supaya plafon itu tercapai.

---

## 1. Cara menilai

Empat metrik yang diminta, masing-masing 0–10:

| Metrik | Pertanyaannya |
|---|---|
| **Ceiling** | Kalau dieksekusi sempurna, seberapa tinggi ide ini bisa dinilai (inovasi + kedalaman teknis)? |
| **Feasibility** | Bisa jadi prototype yang **jalan beneran** dalam 2–3 hari, lalu dipoles sampai final? |
| **Impact** | Seberapa besar masalahnya, bisa diukur atau tidak, dan ada pembeli/jalur adopsinya atau tidak? |
| **Pitch & Storytelling** | Ada momen "wow" saat demo? Ceritanya bikin juri ingat? |

Lalu dikonversi ke rubrik resmi: Inovasi 25 · Teknis 30 · Fungsi & Desain 20 · Dampak 15 · Presentasi 10.

---

## 2. Kandidat yang diuji

| # | Ide | Subtema | Ceiling | Feasibility | Impact | Pitch | **Proyeksi rubrik** | Kenapa tidak/ya |
|---|---|---|---|---|---|---|---|---|
| **1** | **TILIK**: AI yang menelepon lansia/pasien Prolanis tiap hari (telepon biasa, bahasa daerah), cek obat & gejala, deteksi tanda stroke, lapor ke anak & Puskesmas | Lansia + penyakit kronis + Puskesmas | **9,5** | **8,5** | **9,5** | **10** | **~90 saat submit → 95+ di final** | Lihat §3 |
| 2 | Turjuman versi tweak (kios BISINDO untuk Puskesmas) | Puskesmas | 7,5 | 8 | 7 | 8 | ~76 | Pesaingnya padat (puluhan skripsi, Gesti Talk), dan pasarnya sempit |
| 3 | StrokeGuard: skrining FAST lewat kamera HP | Lansia | 8,5 | 6 | 8 | 9 | ~74 | Validitas medis gampang diserang, dan tidak ada dataset pasien stroke |
| 4 | Posbindu Copilot: kader memotret tensimeter (OCR) → skor risiko PTM | Penyakit kronis | 7 | 8,5 | 7,5 | 6,5 | ~72 | Solid tapi kurang "wow" |
| 5 | AI scribe Puskesmas: percakapan → SOAP → ePuskesmas | Puskesmas | 7 | 9 | 8 | 7 | ~70 | **Sudah ramai**: paper arXiv 2024 untuk ePuskesmas, Nexmedis MaleoScribe, PaperlessHospital |
| 6 | Skrining TBC dari suara batuk (Google HeAR) | Kepulauan/pedalaman | 8 | 5 | 9 | 8 | ~68 | AUROC HeAR untuk TBC hanya **0,739**. Juri teknis akan bertanya soal validitas |
| 7 | Paparan polusi personal per rute komuter | Polusi | 6,5 | 7,5 | 6,5 | 6,5 | ~65 | Datanya ada, tapi dampak kesehatannya sulit dibuktikan |
| 8 | Deteksi burnout pasif (pola ketik/suara) | Stres/burnout | 7 | 6 | 6,5 | 6,5 | ~62 | Isu privasi dan stigma, dan validitasnya lemah |

**Pemenangnya jelas: TILIK.** Ini satu-satunya ide yang skornya tinggi di keempat metrik sekaligus. Ide lain selalu punya satu metrik yang jeblok.

---

## 3. TILIK: AI yang *nilik* Mbah setiap hari

> *Tilik* (Jawa) = menjenguk. Juga judul film pendek viral 2018 yang hampir semua juri kenal, jadi hook pembuka gratis.

### 3.1 Satu kalimat
**Agen suara AI yang menelepon lansia penderita hipertensi/diabetes lewat telepon biasa (tanpa aplikasi, tanpa smartphone), mengobrol dalam bahasa mereka, mengecek obat, tensi, dan gejala, menyaring tanda bahaya stroke saat itu juga, lalu mengirim laporan ke anak yang merantau dan daftar prioritas ke Puskesmas.**

### 3.2 Kenapa ini kena di semua subtema sekaligus
| Subtema resmi | Bagaimana TILIK menjawabnya |
|---|---|
| **Keluarga merawat lansia, sulit memantau kondisi & kepatuhan obat** | Inti produk: telepon harian + laporan WA ke keluarga |
| **Usia produktif/kronis jarang periksa** | Pasien Prolanis hipertensi/DM dipantau tanpa harus datang |
| **Puskesmas kewalahan administrasi** | Puskesmas tidak perlu menelepon satu per satu. Yang datang ke mereka adalah daftar prioritas pasien yang perlu ditindaklanjuti |

### 3.3 Masalah dan angka
| Fakta | Angka | Sumber |
|---|---|---|
| Stroke = penyebab kematian #1 di Indonesia | **18,5%** dari total kematian (SKI 2023) | [Kemenkes](https://sehatnegeriku.kemkes.go.id/baca/umum/20241025/4046682/cegah-stroke-dengan-aktivitas-fisik) |
| Penderita hipertensi yang **tidak rutin** minum obat | **32,3%**, plus **13,3%** tidak minum sama sekali | Riskesdas 2018 via [Undip](https://ejournal2.undip.ac.id/index.php/jekk/article/download/26705/12595) |
| Alasan terbanyak berhenti minum obat | **59,8%: "merasa sudah sehat"**. Ini masalah komunikasi, bukan akses | sda |
| Peserta JKN dengan hipertensi / DM (2024) | **20,5 juta / 7,4 juta** | BPJS via [Investortrust](https://investortrust.id/lifestyle/82798/bpjs-kesehatan-tekan-kasus-kronis-dengan-prolanis) |
| Yang ikut Prolanis (Agt 2025) | 4,8 juta (±16% penderita hipertensi JKN) | sda |
| **Rasio Peserta Prolanis Terkendali (RPPT)** | Target BPJS > 5%. Puskesmas se-Cilegon 2023: **0,68%**. Kota Kupang 2019–2021: **0 Puskesmas** yang mencapai target | [Banten](https://ejournal.bantenprov.go.id/index.php/jkpd/article/download/336/202), [Undana](https://ejurnal.undana.ac.id/index.php/CMJ/article/download/24288/9881/) |
| Lansia Indonesia | ±12% penduduk ≈ **29 juta** | [BPS 2024](https://www.bps.go.id/id/publication/2024/12/31/a00d4477490caaf0716b711d) |
| Lansia tinggal sendiri / hanya dengan pasangan | **5,5% + 21,7% ≈ 27%** ≈ ±7,9 juta orang tanpa generasi muda di rumah | BPS via [Undip](https://eprints2.undip.ac.id/id/eprint/52172/3/HANA%20MARYAM%20ROHMAH_13040222140094%20Bab%20I.pdf) *(verifikasi ke PDF BPS)* |
| Lansia yang memakai HP | **49,27%** (2024), dan hanya **26,42%** yang akses internet | BPS via [GoodStats](https://data.goodstats.id/statistic/52-lansia-indonesia-menggunakan-hp-pada-2025-mPzl6) |

**Kenapa telepon, bukan aplikasi:** hanya ±1 dari 4 lansia yang memakai internet. Aplikasi kesehatan (termasuk Mobile JKN) gagal di lansia karena antarmukanya. **Telepon biasa bisa dipakai siapa saja, bahkan HP jadul.**

**Kenapa Puskesmas mau bayar:** RPPT adalah indikator **Kapitasi Berbasis Kinerja** BPJS (Peraturan BPJS 7/2019). Kalau RPPT rendah, kapitasi Puskesmas terpotong. Jadi TILIK bukan sekadar "fitur sosial", tapi alat yang langsung menyentuh pendapatan faskes.

### 3.4 Kebaruan
- **Konsepnya sudah terbukti di luar negeri:** Naver **CLOVA CareCall** (Korea) menelepon lansia yang tinggal sendiri, dipakai pemda Seoul dan Busan, lalu Izumo (Jepang), dan papernya dapat best paper di CHI 2023. ([Naver](https://www.navercorp.com/en/media/pressReleasesDetail?seq=31080), [Boston Globe 2026](https://www.bostonglobe.com/2026/04/28/world/they-said-ai-saved-me-how-south-korea-is-checking-its-seniors/), [EU Futurium](https://futurium.ec.europa.eu/da/node/12561))
- **Di Indonesia belum ada:** saya tidak menemukan layanan yang menggabungkan telepon AI, pendamping lansia, dan cek kesehatan. Yang ada baru demo "AI New Calling" Indosat-Huawei (ucapan ulang tahun) dan chatbot berbasis aplikasi. ([Bisnis](https://teknologi.bisnis.com/read/20260826/101/1999119/indosat-huawei-perkenalkan-ai-new-calling-ini-contoh-4-kasus-pemanfaatannya))
- **Pembeda dari CareCall:** CareCall fokus kesepian dan kesejahteraan umum. TILIK fokus **klinis**: kepatuhan obat Prolanis, tensi, **skrining stroke verbal + eskalasi**, dan **data terstruktur untuk Puskesmas**. Ditambah bahasa daerah dan konteks keluarga perantau.
- Kalimat untuk pitch: *"Korea sudah membuktikan lansia mau ngobrol dengan AI. Kami membawanya ke Indonesia dan menjadikannya alat klinis."*

### 3.5 Pengguna dan alurnya
```
               ┌────────────── 07.00 TILIK menelepon ──────────────┐
               │  "Sugeng enjing, Mbah Sri. Niki Tilik saking      │
               │   Puskesmas Gamping. Sampun sarapan?"             │
               └───────────────────────┬───────────────────────────┘
                                       ▼
   1. Sapa & kabar ─► 2. Obat sudah diminum? ─► 3. Tensi (kalau punya alat, dibacakan)
                                       ▼
   4. Gejala: pusing, nyeri dada, sesak, kesemutan, bicara pelo?
                                       ▼
             ┌──────── Ada red flag? ────────┐
           TIDAK                            YA
             ▼                               ▼
   5. Penutup + pengingat           🚨 Skrining verbal stroke (adaptasi CPSS
      jadwal Prolanis                  versi telepon ala dispatcher):
             ▼                         ulangi kalimat · angkat kedua tangan ·
   Log terstruktur                     senyum (dicek orang terdekat)
             ▼                               ▼
   📱 WA "Rapor Mbah" ke anak       📞 Telepon + WA ke anak, kader/Puskesmas,
   🏥 Daftar prioritas Puskesmas       arahkan ke IGD/119, catat jam onset
```

| Pengguna | Antarmuka | Yang mereka dapat |
|---|---|---|
| **Mbah (pengguna utama)** | **Telepon biasa, tanpa layar** | Teman ngobrol, pengingat obat, pertolongan cepat |
| **Anak perantau (pembayar B2C)** | WhatsApp | Rapor harian/mingguan + alert darurat |
| **Puskesmas/Prolanis (pembayar B2G)** | 1 halaman daftar prioritas | Siapa yang harus dikunjungi atau ditelepon hari ini, dan data tensi/kepatuhan untuk RPPT |

### 3.6 Fitur dan kedalaman teknis
| Fitur | Implementasi | Kenapa juri teknis suka |
|---|---|---|
| **Agen suara real-time via telepon** | Twilio Voice (Media Streams) → server **Pipecat**/LiveKit Agents → STT → LLM → TTS | Latensi ≤ 1 detik per giliran, ada barge-in (Mbah bisa memotong) |
| **Dialog terkendali (guardrail)** | State machine (sapa → obat → tensi → gejala → penutup), LLM hanya mengisi tiap state, dengan **function calling** `log_obat`, `log_tensi`, `log_gejala`, `eskalasi` | AI tidak "ngelantur": tidak mendiagnosis, tidak mengubah dosis |
| **Red-flag ganda** | Aturan deterministik (kata kunci + ambang tensi ≥180/120) **dan** klasifikasi LLM. Salah satu terpicu → eskalasi | Recall tinggi untuk kasus kritis, bisa diaudit |
| **Skrining stroke verbal** | Skrip adaptasi CPSS versi telepon + catat **jam onset** (penting untuk golden period ±4,5 jam) | Klinis masuk akal, bukan gimmick |
| **Tren suara (voice biomarker)** | `parselmouth`/`librosa`: kecepatan bicara, rasio jeda, latensi menjawab, variasi pitch → **dibandingkan dengan baseline Mbah sendiri** (z-score) | Pembeda teknis. Meta-analisis: fitur ucapan ±80% akurat membedakan MCI ([PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12560767/)). Diposisikan sebagai **sinyal tren, bukan diagnosis** |
| **Bahasa daerah** | Bahasa Indonesia sebagai default + sapaan/ungkapan Jawa (ngoko/krama). Jawa penuh dan Sunda masuk roadmap | Inklusif, dan juri di Jogja pasti tersenyum |
| **Rapor WA keluarga** | WhatsApp Cloud API (nomor tes gratis) atau Fonnte | Pembayar B2C melihat nilai setiap hari |
| **Daftar prioritas Puskesmas** | Supabase + 1 halaman web, skor risiko (tensi, kepatuhan, red flag, tidak mengangkat 2× berturut-turut) | Data dipetakan ke resource FHIR `Observation` → "SATUSEHAT-ready" |
| **Evaluasi** | **Harness 30–50 percakapan sintetis** (Mbah normal, lupa obat, pelo, pura-pura sehat, salah sambung, pendengaran kurang) → ukur akurasi ekstraksi, recall red flag, latensi | Ini yang membedakan tim juara dari tim demo: **ada angka** |

### 3.7 Keamanan dan etika (siapkan untuk QnA)
- **Anti-penipuan:** lansia sering jadi korban penipuan telepon. TILIK **tidak pernah** meminta uang, OTP, NIK, atau data rekening. Panggilan pertama didahului rekaman suara anak/kader ("Bu, nanti ada telepon dari Tilik ya"). Nomor resmi Puskesmas bisa diverifikasi.
- **Persetujuan:** opt-in oleh pasien atau keluarga saat pendaftaran Prolanis/Posyandu Lansia.
- **UU PDP 27/2022:** data kesehatan termasuk data spesifik. Rekaman audio tidak disimpan secara default; yang disimpan hanya log terstruktur dan fitur suara numerik.
- **Batas peran:** asistif, bukan diagnosis. Semua red flag diteruskan ke manusia.
- **Gagal aman:** kalau STT tidak yakin atau Mbah tidak paham, ulangi dengan kalimat lebih sederhana. Kalau masih gagal, tandai "perlu ditelepon manusia".

### 3.8 Model bisnis (singkat)
| Segmen | Siapa bayar | Nilai |
|---|---|---|
| B2G | Puskesmas / Dinkes (dana kapitasi, BOK) | RPPT naik → kapitasi KBK aman, beban telepon kader berkurang |
| B2C | Anak perantau (langganan bulanan) | Tenang, ada rapor & alert |
| B2B | BPJS / asuransi swasta | Komplikasi (stroke, gagal ginjal) turun, sehingga klaim turun |

Biaya per panggilan = (menit × tarif telepon) + (token STT/LLM/TTS). Hitung dari pricing API yang benar-benar dipakai dan tampilkan di proposal. Jangan pakai angka tebakan.

---

## 4. Proyeksi skor rubrik TILIK

| Aspek (bobot) | Saat submit 16 Okt | Di final 1 Nov | Yang menaikkan dari kiri ke kanan |
|---|---|---|---|
| Inovasi (25) | 9 | 9,5 | Tambah tren suara + sudut RPPT/KBK |
| Implementasi Teknis (30) | 8,5 | 9,5 | Harness evaluasi + angka latensi/recall; eskalasi end-to-end |
| Fungsionalitas & Desain (20) | 8,5 | 9,5 | Suara TTS yang hangat, alur tanpa macet, rapor WA rapi |
| Dampak & Kelayakan (15) | 9 | 9,5 | Surat dukungan/wawancara 1 Puskesmas atau kader + uji 3–5 lansia sungguhan |
| Presentasi (10) | 9 | 10 | **Demo telepon live di panggung** |
| **Total** | **~88** | **~95–96** | |

---

## 5. Syarat wajib supaya tembus 95

1. **Demo telepon live.** Di panggung, HP anggota tim (berperan sebagai Mbah) berdering, di-loudspeaker, dan ngobrol dengan TILIK. Mbah bilang "tangan kiri kok kesemutan, ngomongnya agak susah". TILIK menjalankan skrining stroke, lalu **HP "anak" di meja juri bergetar** menerima alert WA. Ini momen yang membuat juri ingat. Siapkan **video cadangan** kalau sinyal gedung jelek.
2. **Ada angka evaluasi**, bukan cuma "berhasil". Contoh: *"Recall red flag 100% pada 20 skenario kritis, akurasi ekstraksi obat/tensi 9x%, latensi median 0,8 s."*
3. **Validasi manusia:** wawancara 1 nakes Puskesmas/pengelola Prolanis + uji coba ke 3–5 lansia (kakek-nenek anggota tim pun sah). Kutip pendapat mereka di pitch.
4. **Jangan overclaim.** Tren suara = "sinyal untuk ditindaklanjuti", bukan "mendeteksi demensia/stroke".
5. **Jawaban QnA siap** (lihat §7).
6. **Slide penggunaan AI** (wajib dari panitia): AI di dalam produk (STT/LLM/TTS) + AI untuk development (coding assistant, desain, copywriting), masing-masing dengan perannya.

---

## 6. Rencana kerja 13–16 Oktober

| Kapan | Target | PIC saran |
|---|---|---|
| **13 Okt malam** | Pilih stack, akun Twilio (trial bisa menelepon nomor yang sudah diverifikasi), WA Cloud API test number, Supabase. Tulis skrip dialog + daftar red flag dengan acuan sumber klinis | Semua |
| **14 Okt** | **Pipeline suara jalan**: telepon masuk/keluar → Pipecat → STT/LLM/TTS. State machine + function calling. Alert WA. *Fallback kalau telepon bermasalah: panggilan via browser (WebRTC) dengan UI "HP jadul"* | 2 orang backend/AI |
| **14 Okt** | Halaman daftar prioritas Puskesmas + rapor WA + slot data tren suara | 1 orang FE |
| **15 Okt pagi** | Harness evaluasi 30 skenario sintetis + ambil angka. Uji ke 1–2 lansia sungguhan | 1 orang |
| **15 Okt siang** | Rekam demo dan edit **video ≤ 2 menit** (hook film Tilik → masalah → telepon live → alert → angka) | 1 orang |
| **15–16 Okt** | Proposal ≤ 10 hlm, pitch deck, README (arsitektur + cara menjalankan + `.env.example`). Submit | Semua |
| **17 Okt–1 Nov** | Tren suara, bahasa Jawa yang lebih lengkap, wawancara Puskesmas, uji 5 lansia, poles demo panggung | Semua |

**Yang perlu diverifikasi besok pagi (sebelum kode ditulis):**
- Kualitas STT/TTS untuk Bahasa Indonesia dan Jawa dari provider yang dipilih (Google Cloud `id-ID`/`jv-ID`, Gemini Live, OpenAI Realtime, ElevenLabs). Rekam 5 contoh suara lansia dan bandingkan.
- Batasan akun trial Twilio untuk panggilan ke nomor Indonesia.
- Klaim "source code karya asli tim": pakai framework open-source (Pipecat/LiveKit) + API boleh, tetapi **jangan** pakai platform agen no-code (Vapi/Retell) sebagai inti produk.

---

## 7. QnA terberat

| Pertanyaan juri | Jawaban |
|---|---|
| "Lansia mau ngobrol sama robot?" | Bukti dari CareCall: dipakai pemda Seoul, Busan, dan Izumo (Jepang), dan pengguna lansia melaporkan puas. Kami juga sudah uji ke N lansia: (hasil). |
| "Kalau AI salah dan Mbah stroke, siapa tanggung jawab?" | TILIK tidak mendiagnosis. Red flag memakai aturan deterministik + LLM dengan bias **lebih baik salah alarm daripada terlewat**, dan semua diteruskan ke manusia (keluarga/kader/119). |
| "Bedanya dengan reminder obat biasa (alarm/SMS)?" | Reminder satu arah tidak bisa tahu Mbah **kenapa** berhenti minum obat (59,8% merasa sudah sehat). Percakapan bisa menggali alasannya, mengedukasi, dan mencatat data untuk dokter. |
| "Biaya per panggilan?" | Rumus + angka dari pricing nyata (§3.8), dibandingkan dengan biaya 1 rawat inap stroke. |
| "Kenapa tidak WhatsApp call?" | 74% lansia tidak memakai internet. Telepon seluler biasa menjangkau semuanya. WA tetap dipakai untuk keluarga. |
| "Penipuan telepon?" | Lihat §3.7: protokol anti-penipuan, perkenalan oleh suara anak/kader, tidak pernah meminta data sensitif. |
| "Bahasa daerah?" | MVP: Indonesia + sapaan Jawa. Roadmap: Jawa penuh, Sunda, Minang, dan seterusnya, divalidasi penutur asli. |

---

## 8. Kalau tetap mau jalur Turjuman

Versi tweak di [Ideas_Breakdown.md](Ideas_Breakdown.md) §6 masih layak (~76). Tapi plafonnya terbatas oleh pesaing yang padat dan pasar yang sempit. Untuk mengejar 95+, TILIK punya peluang jauh lebih besar dengan risiko eksekusi yang mirip: keduanya butuh ±2 hari kerja untuk MVP.

---

### Sumber
- [Kemenkes: stroke 18,5% kematian (SKI 2023)](https://sehatnegeriku.kemkes.go.id/baca/umum/20241025/4046682/cegah-stroke-dengan-aktivitas-fisik)
- [Undip JEKK: kepatuhan obat hipertensi (Riskesdas 2018)](https://ejournal2.undip.ac.id/index.php/jekk/article/download/26705/12595)
- [Investortrust: data Prolanis BPJS](https://investortrust.id/lifestyle/82798/bpjs-kesehatan-tekan-kasus-kronis-dengan-prolanis)
- [Jurnal Kebijakan Pembangunan Daerah Banten: RPPT Cilegon](https://ejournal.bantenprov.go.id/index.php/jkpd/article/download/336/202)
- [Cendana Medical Journal Undana: RPPT Kupang](https://ejurnal.undana.ac.id/index.php/CMJ/article/download/24288/9881/)
- [BPS: Statistik Penduduk Lanjut Usia 2024](https://www.bps.go.id/id/publication/2024/12/31/a00d4477490caaf0716b711d)
- [Undip: pola tinggal lansia (kutipan BPS)](https://eprints2.undip.ac.id/id/eprint/52172/3/HANA%20MARYAM%20ROHMAH_13040222140094%20Bab%20I.pdf)
- [GoodStats: lansia pengguna HP & internet](https://data.goodstats.id/statistic/52-lansia-indonesia-menggunakan-hp-pada-2025-mPzl6)
- [Naver: CLOVA CareCall](https://www.navercorp.com/en/media/pressReleasesDetail?seq=31080)
- [Boston Globe 2026: AI checking on South Korea's seniors](https://www.bostonglobe.com/2026/04/28/world/they-said-ai-saved-me-how-south-korea-is-checking-its-seniors/)
- [EU Futurium: CLOVA CareCall](https://futurium.ec.europa.eu/da/node/12561)
- [Korea JoongAng Daily: CareCall di Jepang](https://www.koreajoongangdaily.com/business/ever-wanted-to-chat-with-lee-byung-hun-with-navers-ai-service-for-older-people-in-japan-you-could/10412900)
- [Bisnis: Indosat-Huawei AI New Calling](https://teknologi.bisnis.com/read/20260826/101/1999119/indosat-huawei-perkenalkan-ai-new-calling-ini-contoh-4-kasus-pemanfaatannya)
- [PMC: meta-analisis biomarker ucapan untuk MCI](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12560767/)
- [arXiv 2409.17054: LLM untuk transkripsi ke ePuskesmas](https://arxiv.org/abs/2409.17054v1)
- [Dealroom: Nexmedis](https://app.dealroom.co/companies/nexmedis)
- [Tenity: PaperlessHospital](https://www.tenity.com/?p=1974)
- [The Decoder: Google HeAR](https://the-decoder.com/google-releases-code-for-hear-an-ai-that-analyzes-audio-to-assess-health/)
- [Gigazine: HeAR AUROC TBC 0,739](https://gigazine.net/gsc_news/en/20240902-google-hear-cough-ai)
