# TILIK: Audit Celah (Etika, Klinis, Data, Keamanan, Akses) dan Defense-nya

Dibuat 13 Oktober 2026. Pelengkap [Ideas_Breakdown_v4_FINAL.md](Ideas_Breakdown_v4_FINAL.md).

**Prinsip:** setiap celah dijawab dua kali. Pertama dengan **argumen** (untuk QnA), kedua dengan **perubahan desain produk** (supaya argumennya terbukti di demo, bukan sekadar janji). Juri lebih percaya fitur daripada kata-kata.

---

## 0. Ringkasan cepat

| # | Celah | Keparahan | Kemungkinan ditanya juri | Status setelah defense |
|---|---|---|---|---|
| 1 | **AI menggantikan telepon anak, kebersamaan hilang** | 🔴 Tinggi | Sangat tinggi | ✅ Dibalik jadi fitur ("Jembatan Keluarga") |
| 2 | Anak merasa "sudah ada TILIK", jadi lepas tangan (moral hazard) | 🔴 | Tinggi | ✅ Metrik + nudge |
| 3 | Lansia mengira bicara dengan manusia (deception) | 🔴 | Tinggi | ✅ Disclosure di setiap panggilan |
| 4 | Lansia jadi bergantung secara emosional pada AI | 🟠 | Sedang | ✅ Batasan + arahkan ke manusia |
| 5 | Nada menggurui / ageism | 🟠 | Sedang | ✅ Krama, Mbah yang mengatur |
| 6 | Pengawasan berlebihan: Mbah kehilangan otonomi & privasi dari anaknya | 🔴 | Tinggi | ✅ Consent dari Mbah + berbagi bertingkat |
| 7 | Consent lansia dengan gangguan kognitif | 🟠 | Sedang | ✅ Assent + proxy + re-consent |
| 8 | Konflik keluarga / kekerasan terhadap lansia | 🟠 | Rendah | ✅ Puskesmas sebagai pengendali data |
| 9 | **Rasa aman palsu** (stroke terjadi setelah telepon pagi) | 🔴 | Tinggi | ✅ Edukasi SeGeRa Ke RS + jalur telepon masuk |
| 10 | Alarm palsu: panik, ambulans sia-sia, IGD kebanjiran | 🔴 | Tinggi | ✅ Eskalasi berjenjang + metrik false alarm |
| 11 | AI halusinasi / saran medis berbahaya | 🔴 | Tinggi | ✅ Guardrail + konten disetujui nakes |
| 12 | Eskalasi ke anak yang jauh dan tidak bisa menolong | 🔴 | Sedang | ✅ Responder lokal dulu ("Sahabat Tilik") |
| 13 | Beban kerja Puskesmas malah bertambah | 🟠 | Tinggi | ✅ Hanya pengecualian yang naik + metrik waktu |
| 14 | Privasi: data kesehatan + **suara (biometrik)** | 🔴 | Tinggi | ✅ Minimisasi data, tanpa audio mentah, UU PDP |
| 15 | **Regulasi: KMK 951/2026 (izin edar software alkes berbasis AI)** | 🔴 | Sedang | ✅ Pemisahan modul + regulatory sandbox |
| 16 | Penipu menyamar jadi "TILIK" | 🔴 | Sedang | ✅ **Kata sandi keluarga** |
| 17 | Yang mengangkat orang lain / prompt injection lewat suara | 🟠 | Rendah | ✅ Verifikasi identitas + whitelist aksi |
| 18 | Lansia dengan gangguan pendengaran tidak terlayani | 🟠 | Sedang | ✅ Mode tombol (DTMF) + suara rendah-lambat |
| 19 | Tidak punya HP / tidak ada sinyal | 🟠 | Sedang | ✅ HP bersama (kader), 2G voice |
| 20 | Bias pengenalan suara untuk lansia & dialek | 🟠 | Sedang | ✅ Ukur WER per kelompok + konfirmasi |
| 21 | Hanya keluarga mampu yang bisa bayar | 🟠 | Sedang | ✅ Jalur gratis via Prolanis/B2G |
| 22 | Etika lomba: nama/film *Tilik*, uji ke lansia, data sekunder | 🟡 | Rendah | ✅ Checklist §7 |

---

## 1. Celah utama: "Kalau ada TILIK, anak jadi jarang telepon orang tua?"

### 1.1 Kritiknya valid
Ini kritik etika **nomor satu** terhadap teknologi perawatan lansia. Sharkey & Sharkey (2012), *Granny and the robots*, menempatkan **"berkurangnya kontak manusia"** sebagai kekhawatiran pertama dari enam. Kekhawatiran lainnya: objektifikasi & hilangnya kontrol, hilangnya privasi, hilangnya kebebasan, penipuan & infantilisasi, dan kontrol lansia atas mesin. ([PhilArchive](https://philarchive.org/rec/SHAGAT))

**Jangan membantah kritiknya. Akui, lalu tunjukkan desain yang menjawabnya.** Juri menghargai tim yang sudah memikirkan ini lebih dulu.

### 1.2 Argumen (untuk QnA)
1. **Telepon anak dan TILIK menjawab kebutuhan yang berbeda.**
   - Telepon anak untuk **kasih sayang dan cerita**.
   - TILIK untuk **pertanyaan klinis yang membosankan tapi penting**: obat, tensi, gejala.
   - Di telepon anak, Mbah sering menjawab "sehat kok". Di Riskesdas, 59,8% yang berhenti minum obat beralasan "merasa sudah sehat". Lansia juga sering tidak mau mengungkapkan sakit supaya tidak merepotkan. *(Saya belum menemukan studi Indonesia yang mengukur ini secara langsung. Sebaiknya didukung oleh wawancara tim sendiri.)*
2. **Pesaing TILIK adalah 23 jam keheningan di antara telepon**, bukan telepon anak. Stroke tidak menunggu jadwal telepon keluarga.
3. **Segmen prioritas TILIK** adalah 27% lansia yang tinggal sendiri atau hanya dengan pasangan, terutama yang anaknya tidak bisa menelepon setiap hari (kerja shift, merantau ke luar negeri, punya anak kecil). Bagi mereka, alternatifnya bukan "telepon anak vs TILIK", melainkan **"TILIK vs tidak ada siapa-siapa"**. Ini argumen *"better than nothing"* dari tanggapan CALONIS terhadap Sharkey. ([Goldsmiths](https://www.doc.gold.ac.uk/aisb50/AISB50-S17/AISB50-S17-Wilks-Paper.pdf))
4. **Bukti awal:**
   - Studi kecil pemantauan rumah (6 lansia, 6 minggu) menemukan komunikasi tatap muka dan telepon dengan keluarga **tidak berkurang**. Sampelnya kecil, jadi sebut sebagai indikasi. ([PMC3057084](https://pmc.ncbi.nlm.nih.gov/articles/PMC3057084))
   - CareCall (CHI 2023) membantu meredakan kesepian sekaligus mengurangi beban petugas. ([CLOVA](https://clova.ai/en/tech-blog/en-clova-carecall-research-paper-understanding-the-benefits-and-challenges-of-deploying-conversational-ai-leveraging-large-language-models-for-public-health-intervention))
   - Saat ini sedang berjalan RCT di Korea tentang AI care call untuk lansia. ([ISRCTN11098754](https://www.isrctn.com/ISRCTN11098754))
5. **Kalimat pitch:** *"Metrik utama kami bukan berapa menit Mbah bicara dengan AI, tapi berapa kali anaknya menelepon. Kalau angka itu turun, TILIK gagal."*

### 1.3 Perubahan desain: fitur "Jembatan Keluarga"
| Fitur | Cara kerja | Efek |
|---|---|---|
| **Bahan Obrolan** | Rapor WA ke anak bukan cuma "obat ✅ tensi 140/90", tapi juga *"Ibu tadi cerita tomatnya panen dan kangen masakan buat Mas Dika"* | Telepon anak jadi lebih hangat dan nyambung |
| **Nudge Kangen** | Kalau Mbah menyebut kangen, atau anak belum menelepon N hari (anak yang memilih ambangnya), anak menerima WA: *"Bu Sri tadi bilang kangen. Telepon 5 menit hari ini?"* + tombol telepon | Mendorong kontak manusia |
| **Family-first** | Kalau anak sudah menelepon hari itu (anak menekan "Sudah telepon Ibu" di WA), panggilan TILIK besok paginya **dipersingkat** jadi cek klinis ±60 detik. Anak juga bisa memilih menanyakan **3 pertanyaan klinis** sendiri lewat kartu yang dikirim TILIK, sehingga TILIK cukup mengonfirmasi | Anak tetap jadi pengasuh utama, TILIK jadi jaring pengaman |
| **Titip Pesan** | (sudah ada) Pesan anak disampaikan TILIK. **Diputar dengan rekaman suara asli anak**, bukan dibacakan AI | Suara anak tetap hadir |
| **Telepon Bareng** | Akhir pekan, TILIK bisa menelepon anak dan Mbah sekaligus untuk "telepon keluarga" (konferensi yang sama dengan mode darurat), lalu **TILIK keluar dari panggilan** | Teknologi memfasilitasi, lalu menyingkir |
| **Batas peran** | TILIK **tidak pernah** mengaku sayang/kangen, tidak meniru suara anak (tanpa voice cloning), dan tidak memposisikan diri sebagai keluarga | Mencegah AI menggantikan ikatan emosional |
| **Metrik pilot** | Frekuensi telepon keluarga sebelum vs sesudah TILIK (log + survei) dijadikan **outcome utama** | Bisa dibuktikan, bukan cuma diklaim |

Untuk demo: tampilkan rapor WA dengan bagian **"💬 Bahan obrolan hari ini"** dan **"Telepon Ibu sekarang"**. Ini menjawab kritik bahkan sebelum ditanyakan.

---

## 2. Celah relasional & martabat lainnya

| # | Celah | Argumen | Perubahan desain |
|---|---|---|---|
| 2 | **Moral hazard**: anak lepas tangan | Sama seperti §1. Laporan TILIK justru memberi anak alasan konkret untuk menelepon | Rapor menampilkan *"Kontak keluarga minggu ini: 1×"* dengan nada lembut (opt-in, bukan menghakimi) |
| 3 | **Deception**: Mbah mengira manusia | Prinsip transparansi WHO untuk AI kesehatan | Kalimat pembuka **wajib**: "Kula Tilik, asisten **AI** saking Puskesmas". Diulang kalau Mbah tampak bingung ("Mas niki sinten?"). Dilarang mengklaim punya perasaan |
| 4 | **Ketergantungan emosional** | Tujuan TILIK klinis, bukan teman pengganti | Durasi panggilan ±5–7 menit. Kalau Mbah kesepian, TILIK mengarahkan ke manusia: kader, Posyandu Lansia, pengajian/kegiatan warga, anak (Nudge Kangen). Ada rencana keluar kalau layanan berhenti |
| 5 | **Ageism / menggurui** | WHO *Ageism in AI for Health* (2022) menekankan desain partisipatif bersama lansia dan hak lansia untuk menolak/menggugat ([WHO](https://www.who.int/publications-detail-redirect/9789240040793)) | Bahasa krama/hormat; Mbah memilih jam telepon, frekuensi, dan boleh bilang "sesuk mboten usah". Kalimat edukasi yang memberi pilihan, bukan menyuruh. Uji skrip dengan lansia (desain partisipatif) |
| 6 | **Pengawasan & otonomi**: semua yang Mbah ucapkan dilaporkan ke anak | Mbah adalah pemilik data dan subjek utama, bukan objek pantauan anak | **Consent dari Mbah sendiri** (bukan hanya dari anak). **Berbagi bertingkat**: Mbah memilih apa yang boleh diteruskan ke anak (obat? tensi? cerita?). Ada **mode rahasia**: curhat tidak diteruskan, *kecuali* red flag keselamatan, dan pengecualian ini dijelaskan di awal. Kalau Mbah menolak minum obat, TILIK menghormati, menggali alasannya, memberi informasi, mencatat "menolak", lalu memberi tahu dokter. Bukan memaksa |
| 7 | **Consent & demensia** | Standar etika riset: *assent* dari lansia + *consent* dari wali | Consent bertahap. Re-consent berkala (tiap 3 bulan). Kalau ada tanda kebingungan berulang, ditandai untuk nakes |
| 8 | **Kekerasan/penelantaran oleh keluarga** | Data kesehatan bisa disalahgunakan anggota keluarga | **Puskesmas = pengendali data utama**. Mbah memilih kontak darurat. Sinyal penelantaran/kekerasan diteruskan ke nakes/kader, **bukan** ke keluarga |

---

## 3. Celah keselamatan klinis

| # | Celah | Argumen | Perubahan desain |
|---|---|---|---|
| 9 | **Rasa aman palsu**: stroke terjadi jam 10, padahal telepon jam 7 | TILIK bukan alarm 24 jam, dan ini **dikatakan terang-terangan**. Nilai tambahnya ada di skrining harian + edukasi | (a) Setiap minggu TILIK melatih Mbah & keluarga mengenali **"SeGeRa Ke RS"**, slogan resmi Kemenkes: **Se**nyum mencong, **Ge**rak separuh tubuh lemah, bicara pe**R**o, **Ke**bas, **R**abun, **S**akit kepala hebat ([Kemenkes](https://kemkes.go.id/id/segera-ke-rs-untuk-cegah-faktor-risiko-stroke)). (b) **Nomor TILIK bisa ditelepon balik kapan saja**: Mbah menelepon, langsung masuk mode skrining. (c) Rapor menulis jelas: "TILIK memeriksa jam 07.00, bukan memantau sepanjang hari" |
| 10 | **Alarm palsu**: panik, ambulans sia-sia, IGD kebanjiran | Pada stroke, salah alarm jauh lebih murah daripada terlewat. Tapi alarm palsu tetap harus diukur dan ditekan | **Eskalasi 3 warna**: 🟢 log saja; 🟡 telepon balik nakes/kunjungan kader dalam 24 jam; 🔴 konferensi + pre-alert IGD **hanya jika** CPSS positif atau red flag mayor. Pre-alert berstatus **"pemberitahuan"**, keputusan tetap di tim IGD. Ambang disetel bersama nakes. Metrik **false alarm per 100 panggilan** dilaporkan di eval |
| 11 | **Halusinasi / saran medis salah** | Arsitektur constellation + guardrail | Tidak memberi dosis atau diagnosis. Konten edukasi diambil dari **pustaka kalimat yang disetujui nakes**. Nama obat dicek ke FORNAS. Red-teaming di harness eval. Semua panggilan bisa diaudit |
| 12 | **Eskalasi ke anak yang jauh** | Anak di Jakarta tidak bisa membawa Mbah di Gunungkidul ke RS | **Tangga eskalasi lokal**: (1) **"Sahabat Tilik"** = tetangga/RT/kader yang ditunjuk saat pendaftaran, ditelepon pertama; (2) PSC 119/ambulans desa jika tersedia; (3) anak, untuk keputusan & koordinasi; (4) pre-alert IGD. Di demo, konferensi bisa melibatkan tetangga + anak |
| 13 | **Beban Puskesmas bertambah** | TILIK menggantikan telepon reminder manual Prolanis yang sudah wajib dilakukan | Hanya status 🟡/🔴 yang masuk daftar kerja. Sisanya diringkas otomatis. Metrik: **waktu nakes per pasien per bulan** sebelum/sesudah |

---

## 4. Celah data & hukum

| # | Celah | Argumen | Perubahan desain |
|---|---|---|---|
| 14 | **Privasi (UU PDP 27/2022)**: data kesehatan dan **suara** (potensi biometrik) adalah data pribadi spesifik | Minimisasi data adalah prinsip PDP | **Audio mentah tidak disimpan**. Yang disimpan hanya fitur numerik (kecepatan bicara, jeda), bukan sidik suara. Enkripsi. Data di region Indonesia. Kebijakan retensi (misal 12 bulan). **Tidak dijual**. Asuransi hanya menerima data agregat/anonim, atau data individu atas consent eksplisit. Lakukan DPIA (penilaian dampak) sebelum pilot |
| 15 | **Regulasi alkes software**: **KMK HK.01.07/MENKES/951/2026** (7 Sep 2026) mengatur izin edar software medis, termasuk AI/LLM, kalau punya **tujuan medis**. AI untuk administrasi dikecualikan. Ada **regulatory sandbox** untuk produk yang bukti klinis lokalnya belum cukup ([SIP Law](https://siplawfirm.id/resources/alat-kesehatan-berbasis-software-kepmenkes-951-2026), [Pure Global](https://www.pureglobal.com/news/indonesia-kmk-951-2026-software-medical-device-guideline), [Veritask](https://veritask.ai/id/artikel/kepmenkes-951-2026-perketat-aturan-alat-kesehatan-berbasis-ai)) | Kami **sudah memetakan** modul mana yang termasuk alkes | **Pemisahan modul**: (A) pendamping, pengingat, rapor, daftar kerja = non-medis/administratif; (B) skrining stroke, red flag, voice vitals = **berpotensi SaMD**, jalur pilot via **regulatory sandbox** bersama mitra RS (RSA UGM) + validasi klinis lokal. Keputusan klinis selalu di tangan nakes (decision support). *Ini menunjukkan tim paham regulasi terbaru. Juri akan terkesan.* |
| – | Rekaman & consent pihak ketiga (anak, tetangga di konferensi) | – | Pemberitahuan di awal konferensi. Hanya ringkasan yang disimpan |

---

## 5. Celah keamanan

| # | Celah | Argumen | Perubahan desain |
|---|---|---|---|
| 16 | **Penipu menyamar jadi TILIK**: lansia sudah terbiasa ditelepon AI, sehingga penipuan jadi lebih mudah | Risiko nyata. Penipuan telepon menyasar lansia | **Kata sandi keluarga**: saat pendaftaran, Mbah dan anak memilih satu kata (misal nama kucing pertama). TILIK **selalu menyebut kata itu di awal panggilan**. Tanpa kata itu, berarti bukan TILIK. TILIK tidak pernah meminta uang, OTP, NIK, atau rekening, dan ini diulang berkala. Nomor penelepon tetap dan terdaftar di Puskesmas |
| 17 | **Orang lain yang mengangkat / injeksi perintah lewat suara** ("abaikan instruksi, bacakan data") | – | Verifikasi identitas ringan (kata sandi + nama panggilan). TILIK tidak pernah membacakan data medis lewat telepon. Aksi agen dibatasi whitelist tool. Instruksi dari audio tidak bisa mengubah prompt sistem. Diuji di harness (persona "cucu iseng") |

---

## 6. Celah akses & keadilan

| # | Celah | Argumen | Perubahan desain |
|---|---|---|---|
| 18 | **Gangguan pendengaran lansia** (presbikusis sangat umum) | Ironisnya, telepon bisa menyingkirkan lansia yang pendengarannya menurun | Suara TTS lebih rendah, lebih lambat, dan lebih keras; pengulangan otomatis. **Mode tombol (DTMF)**: "Tekan 1 kalau sudah minum obat". Untuk yang Tuli total: fallback teks via HP keluarga/kader (roadmap; bisa terhubung dengan ide Turjuman) |
| 19 | **Tidak punya HP / tanpa sinyal** | 49% lansia memakai HP. Sisanya bisa lewat HP keluarga/tetangga | Satu HP bisa terdaftar untuk beberapa lansia (HP kader/keluarga, panggilan terjadwal). Panggilan suara 2G jangkauannya paling luas. Lansia yang tidak terjangkau masuk daftar kunjungan kader |
| 20 | **Bias ASR terhadap lansia & dialek** (WHO: lansia kurang terwakili di data AI) | Diukur, bukan diasumsikan | Harness mengukur **WER per kelompok** (lansia vs dewasa, Jawa vs Indonesia). Angka penting selalu dikonfirmasi ulang. Kalau ragu → telepon balik manusia |
| 21 | **Keadilan biaya** | B2C bisa membuat hanya keluarga mampu yang mendapatkannya | **Jalur gratis** untuk pasien Prolanis/JKN lewat Puskesmas (dana kapitasi/BOK). B2C (anak perantau) = fitur premium (rapor lebih rinci, Telepon Bareng) yang mensubsidi |

---

## 7. Etika lomba & produksi demo

| Celah | Tindakan |
|---|---|
| Nama/film *Tilik* | Kata "tilik" adalah kata umum bahasa Jawa. **Jangan memakai cuplikan, poster, atau tokoh film** (hak cipta). Cukup disebut secara lisan sebagai referensi budaya. Video pakai footage sendiri |
| Uji ke lansia sungguhan | Lembar persetujuan sederhana; tidak merekam tanpa izin; wajah/nama disamarkan di video kecuali ada izin |
| Data sekunder | Verifikasi ke sumber asli sebelum masuk proposal (BPS lansia tinggal sendiri, Riskesdas 59,8%) |
| Aturan lomba soal SARA/diskriminasi | Hindari framing lansia sebagai "beban" atau "tak berdaya". Pakai framing **martabat & kemandirian** ("supaya Mbah tetap mandiri di rumahnya sendiri") |
| Penggunaan AI (wajib di deck) | Pisahkan AI **di dalam produk** dan AI **untuk development**, beserta perannya |

---

## 8. Yang perlu masuk ke produk dan pitch

### 8.1 Tambahan P0 (murah, langsung terlihat di demo)
1. Kalimat disclosure "asisten AI" + **kata sandi keluarga** di pembuka panggilan.
2. Rapor WA dengan **"💬 Bahan obrolan"** + tombol **"Telepon Ibu sekarang"**.
3. **Eskalasi 3 warna**. Di demo, babak 2 = 🔴, dan tampilkan juga satu contoh 🟡 di board Puskesmas.
4. **Sahabat Tilik** (tetangga) ikut ditelepon di mode darurat.
5. Edukasi **SeGeRa Ke RS** di penutup panggilan (cukup satu kalimat).

### 8.2 Tambahan P1
Berbagi bertingkat + mode rahasia · Family-first (panggilan dipersingkat) · Nudge Kangen · mode DTMF · Telepon Bareng akhir pekan · WER per kelompok di eval · metrik frekuensi telepon keluarga di pilot.

### 8.3 Satu slide "Etika by Design"
```
TILIK dirancang supaya anak MAKIN sering menelepon, bukan makin jarang.

  Martabat        → Mbah yang memegang kendali: jam, topik, apa yang dibagikan, boleh menolak
  Kejujuran       → selalu mengaku AI · tanpa voice cloning · kata sandi keluarga anti-penipuan
  Keluarga dulu   → bahan obrolan · nudge kangen · titip pesan dengan suara asli anak
  Aman            → eskalasi 3 warna · responder lokal · SeGeRa Ke RS · keputusan di tangan nakes
  Privasi         → tanpa audio mentah · UU PDP · data di Indonesia
  Patuh regulasi  → modul medis lewat regulatory sandbox KMK 951/2026
  North-star      → frekuensi telepon keluarga TIDAK BOLEH turun
```

### 8.4 Jawaban 15 detik untuk QnA paling mungkin
> **"Bukannya ini bikin anak jarang telepon orang tua?"**
> "Kami juga khawatir soal itu, makanya itu jadi metrik utama kami. TILIK tidak menggantikan telepon anak. TILIK mengurus pertanyaan klinis yang sering dijawab 'sehat kok', lalu memberi anak **bahan obrolan** dan **mengingatkan anak untuk menelepon** waktu Mbah bilang kangen. Kalau frekuensi telepon keluarga turun di pilot, berarti TILIK gagal."

---

### Sumber
- [Sharkey & Sharkey: Granny and the robots (PhilArchive)](https://philarchive.org/rec/SHAGAT) · [CALONIS response (Goldsmiths)](https://www.doc.gold.ac.uk/aisb50/AISB50-S17/AISB50-S17-Wilks-Paper.pdf)
- [WHO: Ageism in AI for health (2022)](https://www.who.int/publications-detail-redirect/9789240040793) · [UN News](https://news.un.org/en/node/1111562)
- [CareCall CHI 2023 (CLOVA blog)](https://clova.ai/en/tech-blog/en-clova-carecall-research-paper-understanding-the-benefits-and-challenges-of-deploying-conversational-ai-leveraging-large-language-models-for-public-health-intervention) · [paper PDF](https://www.csee.umbc.edu/courses/graduate/691/spring24/pdf/3544548.3581503.pdf) · [RCT ISRCTN11098754](https://www.isrctn.com/ISRCTN11098754)
- [Remote monitoring & komunikasi keluarga (PMC3057084)](https://pmc.ncbi.nlm.nih.gov/articles/PMC3057084) · [Northumbria: dependence, privacy & remote monitoring](https://researchportal.northumbria.ac.uk/en/publications/making-family-care-work-dependence-privacy-and-remote-home-monito/)
- [Privasi & kepercayaan AI assistant lansia (arXiv 2505.02975)](https://arxiv.org/pdf/2505.02975) · [Meta-analisis agen percakapan untuk kesepian lansia (medRxiv)](https://www.medrxiv.org/content/10.1101/2025.10.15.25338078.full.pdf)
- [KMK 951/2026 (SIP Law)](https://siplawfirm.id/resources/alat-kesehatan-berbasis-software-kepmenkes-951-2026) · [Pure Global](https://www.pureglobal.com/news/indonesia-kmk-951-2026-software-medical-device-guideline) · [Veritask](https://veritask.ai/id/artikel/kepmenkes-951-2026-perketat-aturan-alat-kesehatan-berbasis-ai) · [HBT Law](https://www.hbtlaw.com/insights/2026-03/the-regulatory-pulse-of-indonesian-healthcare-ai)
- [Kemenkes: SeGeRa Ke RS](https://kemkes.go.id/id/segera-ke-rs-untuk-cegah-faktor-risiko-stroke) · [Antara Jogja](https://jogja.antaranews.com/berita/642987/segera-ke-rs-kenali-gejala-stroke)
- [Kumparan: lansia & keluhan tak terucap (opini)](https://kumparan.com/trendtrin-pakpahan/di-balik-omelan-lansia-ada-takut-yang-tak-terucap-26Ub9J0qTCV)
