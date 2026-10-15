# TILIK: Ideas Breakdown v4 (FINAL)

> **"Jalur cepat stroke dimulai dari rumah Mbah, bukan dari pintu IGD."**

Dibuat 13 Oktober 2026. Dokumen ini menggantikan v1–v3 sebagai acuan utama ([v1](Ideas_Breakdown.md) · [v2](Ideas_Breakdown_v2.md) · [v3](Ideas_Breakdown_v3.md)). Fokus v4: **WOW factor dan plafon teknis setinggi mungkin**, memakai metode **ATM (Amati, Tiru, Modifikasi)** dari pemain global, dan memastikan tiap aspek rubrik sudah mentok.

**Rubrik resmi:** Inovasi Solusi 25 · Implementasi Teknis 30 · Fungsionalitas & Desain 20 · Dampak & Kelayakan 15 · Presentasi & Demonstrasi 10.

---

## 0. Verdict

1. **Ide ini adalah plafon tertinggi yang bisa saya temukan.** Saya sudah menguji 12 kandidat (§1). Yang punya WOW tinggi selalu jatuh di validitas atau feasibility. Yang aman selalu kurang WOW. TILIK satu-satunya yang tinggi di semua metrik.
2. **v4 menambah 6 momen WOW dan 7 lapisan teknis** yang semuanya meniru (ATM) sistem yang sudah terbukti: Hippocratic AI Polaris, Naver CareCall, Emory AHA 2025, Cordio HearO, Penn State stroke speech, dan Code Stroke RSA UGM.
3. **Kartu as untuk juri UGM:**
   - DIY adalah **provinsi dengan proporsi lansia tertinggi di Indonesia (17,83%, SUPAS 2025)**.
   - **RS Akademik UGM sudah menjalankan "Code Stroke Lintas Sektor"** di Gunungkidul. Program itu menyebut "keterlambatan identifikasi gejala" sebagai hambatan dan memantau *onset-to-arrival time*.
   - Program itu juga selaras dengan tema prioritas **"Menua Sehat" dalam Academic Health System UGM 2025–2029**.
   - Posisi TILIK: **jalur pertama dari rumah ke IGD** yang melengkapi Code Stroke milik UGM sendiri.
4. **Proyeksi jujur:** ~89–90 saat submit 16 Okt, **~96–97 di Grand Final** kalau P0 + P1 (§5) selesai dan demo live berjalan.

---

## 1. Stress test terakhir: apakah ada ide yang lebih tinggi?

Skor WOW dan plafon teknis dinilai 0–10.

| # | Ide | WOW | Plafon teknis | Validitas/klaim | Feasibility 3 hari | Verdict |
|---|---|---|---|---|---|---|
| **1** | **TILIK v4** | **10** | **9,5** | Aman kalau framing-nya "skrining + percepatan rujukan" | **8** | ✅ **Pilih** |
| 2 | Kios cek tensi dari video wajah (rPPG) | 9 | 8 | ❌ Error tensi SD ±13–16 mmHg ([PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9706384/)), jauh di atas batas standar validasi ±8 mmHg. Juri teknis yang paham akan menyerang | 7 | Jebakan validitas |
| 3 | StrokeGuard kamera (FAST wajah + lengan) | 9 | 8 | ⚠️ Butuh data pasien stroke | 6 | Masuk TILIK sebagai roadmap |
| 4 | Skrining TBC dari batuk (HeAR) | 8 | 8 | ❌ AUROC 0,739 | 5 | Validitas |
| 5 | Full-duplex speech AI (Moshi) untuk lansia | 9 | 10 | – | 3 | Moshi berbahasa Inggris dan lisensi bobotnya non-komersial ([arXiv](https://arxiv.org/html/2410.00037v1)). Tidak realistis |
| 6 | Deteksi gagal jantung dari suara (ATM Cordio) sebagai produk utama | 8 | 9 | ⚠️ Data masih interim dan dari vendor | 5 | Masuk TILIK sebagai "jam kronis" (§4.3) |
| 7 | Deteksi depresi lansia dari suara (ATM Kintsugi) | 6 | 8 | ⚠️ Sens 71% / spes 74% | 6 | Isu stigma. Roadmap saja |
| 8 | AI scribe Puskesmas | 5 | 7 | ✅ | 9 | Sudah ramai (Nexmedis, PaperlessHospital) |
| 9 | Turjuman BISINDO | 6 | 7 | ✅ | 8 | Pasar sempit, pesaing padat |
| 10 | Radar mmWave deteksi jatuh lansia | 8 | 9 | ✅ | 2 | Hardware tidak sempat |
| 11 | Antrean + pra-triase LLM | 4 | 6 | ✅ | 9 | Generik |
| 12 | Polusi / burnout | 5 | 6 | ⚠️ | 7 | Dampak sulit dibuktikan |

**Kesimpulan:** ide-ide yang tampak lebih "wah" (rPPG, full-duplex, kamera stroke) gagal di validitas atau feasibility. Ide terbaik untuk dua di antaranya (gagal jantung dari suara, stroke dari wajah/suara) **diserap ke dalam TILIK** sebagai lapisan biomarker suara, sehingga plafonnya ikut naik tanpa ikut menanggung risikonya.

---

## 2. Peta ATM (Amati → Tiru → Modifikasi)

| Amati (sumber) | Bukti | Tiru | Modifikasi khas TILIK |
|---|---|---|---|
| **Naver CLOVA CareCall** | Pemda Seoul, Busan, Izumo. Best paper CHI 2023 ([Naver](https://www.navercorp.com/en/media/pressReleasesDetail?seq=31080), [Boston Globe](https://www.bostonglobe.com/2026/04/28/world/they-said-ai-saved-me-how-south-korea-is-checking-its-seniors/)) | Telepon rutin ke lansia + dasbor pemda + flag "tidak mengangkat 2×" | Fokus klinis (obat, tensi, stroke), bahasa Indonesia/Jawa, loop anak perantau |
| **Hippocratic AI Polaris** | Arsitektur *constellation*: 1 agen percakapan + agen spesialis paralel untuk keselamatan ([arXiv 2403.13313](https://arxiv.org/html/2403.13313v1)). Klaim 10 jt+ panggilan ([arXiv 2603.29893](https://arxiv.org/pdf/2603.29893)) | Pola multi-agen: percakapan + spesialis | Versi ringan memakai LLM API + aturan deterministik. Spesialis lokal: obat FORNAS, stroke, suara |
| **Hippocratic AI, studi memori (JMIR 2026)** | Setiap memori dari panggilan lalu yang dipakai agen menambah ±2,47 menit durasi panggilan ([JMIR](https://formative.jmir.org/2026/1/e87704)) | Memori jangka panjang per pasien | Memori keluarga & budaya: nama cucu, arisan, sawah, pengajian |
| **Emory, AHA Hypertension 2025** | 85% pasien terjangkau, biaya per bacaan 88,7% lebih murah ([UPI](https://www.upi.com/Health_News/2025/09/08/AI-voice-agent-seniors-high-blood-pressure/4551757339502/)) | Pengambilan tensi via telepon + eskalasi ambang | Konfirmasi angka yang dibacakan + tren + data RPPT untuk Puskesmas |
| **Cordio HearO** | Suara harian memprediksi dekompensasi gagal jantung ±3 minggu lebih awal, sensitivitas 82%, FP 18% (interim) ([The Hospitalist](https://blogs.the-hospitalist.org/content/voice-analysis-app-promising-early-warning-system-heart-failure-decompensation)) | **Kalimat baku harian** + perbandingan dengan baseline diri sendiri | Disisipkan ke obrolan (bukan rekam terpisah), dan dua jam: akut (stroke) + kronis (tren) |
| **Penn State / Houston Methodist** | Model wajah + ucapan menyamai dokter IGD dalam skrining stroke ([ScienceDaily](https://www.sciencedaily.com/releases/2020/10/201022123120.htm)) | Analisis ucapan untuk dysarthria | Lewat telepon 8 kHz, dibandingkan baseline personal |
| **Dispatcher CPSS (119/911)** | CPSS via telepon meningkatkan pengenalan stroke ([PMC3867422](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3867422/)) | Skrip CPSS versi telepon | Dijalankan proaktif oleh AI, bukan menunggu ditelepon |
| **Prehospital pre-notification** | Busan: DTN 29,7 vs 42,1 menit dengan pre-notifikasi ([SJTREM](https://sjtrem.biomedcentral.com/articles/10.1186/s13049-016-0251-2/tables/2)). Meta-analisis: efek tunggal belum signifikan (p = 0,085) ([PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC7401993/table/T3)) | Pre-alert ke tim stroke RS | **Pre-alert dari rumah**, dengan jam onset + CPSS + obat (antikoagulan?) |
| **Code Stroke Lintas Sektor RSA UGM** | Jejaring 3 RS ber-CT di Gunungkidul (RSUD Wonosari, RS Saptosari, RS Panti Rahayu), indikator onset-to-arrival ([PERSI 2025](https://www.persi.or.id/wp-content/uploads/2025/10/RS-Akademik-UGM-Code-Stroke-Lintas-Sektor.pdf)) | Jejaring dan alur rujukan | TILIK = **sensor komunitas** yang memicu Code Stroke lebih awal |

**Kalimat ATM untuk pitch:** *"Korea membuktikan lansia mau ditelepon AI. Amerika membuktikan AI bisa mengambil tensi 88% lebih murah. Israel membuktikan suara bisa memprediksi gagal jantung. UGM sudah membangun Code Stroke di IGD. Kami menyatukan semuanya menjadi jalur cepat dari rumah Mbah."*

---

## 3. Enam momen WOW (koreografi demo)

Pitch 10–12 menit, demo live ±4 menit dalam 3 babak. Properti: **1 HP jadul (Nokia)**, 1 HP "anak" di meja juri, layar presentasi dibagi dua (slide + panel live).

| # | Momen | Apa yang dilihat juri | Teknologi di baliknya |
|---|---|---|---|
| **W1** | **HP jadul berdering di panggung** | Nokia bunyi. "Tanpa aplikasi, tanpa internet." | PSTN outbound (Twilio) |
| **W2** | **TILIK ingat dan sopan** | "Sugeng enjing, Bu Sri. Wingi panjenengan cerios putu badhe wisuda, sampun?" Mbah menjawab ngoko, TILIK ikut menyesuaikan tingkat bahasanya | Memori jangka panjang + deteksi register bahasa (krama/ngoko) |
| **W3** | **Panel "Tanda Vital Suara" live** | Saat Mbah bicara, grafik kecepatan bicara / jeda / kejernihan artikulasi bergerak di samping garis baseline 14 hari. Babak 2: "Mbah" mulai pelo, **grafik menyala merah** | Streaming feature extraction (parselmouth) + robust z-score + CUSUM |
| **W4** | **Skrining stroke + jam onset** | TILIK dengan tenang menjalankan CPSS verbal, menanyakan "jam pinten terakhir sehat?", lalu menampilkan **countdown golden period** di layar | Agen spesialis stroke + state machine darurat |
| **W5** | **HP juri berdering: konferensi 3 arah** | HP "anak" di meja juri berdering. TILIK membriefing dalam 10 detik ("Ibu Anda menunjukkan tanda stroke sejak ±06.40…") lalu **menyambungkan anak dengan Mbah** dalam satu panggilan | Twilio Conference + ringkasan LLM |
| **W6** | **IGD sudah tahu sebelum pasien tiba** | Layar "IGD RSUD Wonosari" menerima **Pre-alert Code Stroke**: onset, CPSS 2/3, obat (amlodipin; antikoagulan: tidak), ETA 23 menit. WA anak menerima peta ke RS ber-CT terdekat | Supabase realtime + data jejaring Code Stroke + routing |

Babak 1 (normal) dipakai untuk W1–W3. Babak 2 (stroke) untuk W3–W6. **Selalu siapkan video cadangan per babak.**

---

## 4. Plafon teknis: arsitektur v4

### 4.1 Diagram
```
                         ┌──────────────────────── TILIK Constellation (Python, asyncio) ─────────────────────┐
 HP Mbah ◀─PSTN─▶ Twilio │                                                                                     │
           (8 kHz μ-law) │  Audio in ─┬─▶ Personalized VAD/Endpointing ─▶ STT (id/jv) ─▶ ┌──────────────────┐  │
                         │            │                                                  │ PRIMARY AGENT    │  │
                         │            │                                                  │ (percakapan,     │  │
                         │            │                                                  │  state machine,  │  │
                         │            │                                                  │  memori, krama)  │  │
                         │            │                                                  └──┬────────▲──────┘  │
                         │            │                          transcript/event bus ◀────┘        │ guidance│
                         │            ▼                                   │                         │         │
                         │   VOICE VITALS agent ──────┐       ┌───────────┼──────────┬──────────────┤         │
                         │   (DSP streaming:          │       ▼           ▼          ▼              │         │
                         │    artic. rate, pause,     │   SAFETY      MEDICATION   MEMORY      ESCALATION     │
                         │    HNR, F0, jitter)        │   agent       agent        agent       orchestrator   │
                         │   → baseline z / CUSUM ────┴─▶ (rules ∥    (FORNAS,     (fakta      (conference,   │
                         │                                LLM ∥ voice) alasan putus  pasien,     WA, pre-alert, │
                         │                                             obat)        keluarga)   routing)      │
                         │  TTS (lambat, hangat) ◀──────────────────────────── Primary agent                  │
                         └────────────────┬───────────────────────────────────────────────┬──────────────────┘
                                          ▼                                               ▼
                        Supabase: patients · calls · observations(FHIR) ·      Twilio Conference (Mbah+anak)
                        voice_features · baselines · memories · alerts         WA Cloud API (rapor/titip pesan)
                                          ▼                                     IGD Pre-alert board (realtime)
                     Web: Daftar Tilik Hari Ini (Puskesmas) · Panel Tanda Vital Suara · Board IGD
```

### 4.2 Tujuh lapisan teknis (yang menaikkan skor 30%)
| # | Lapisan | Detail implementasi | Kenapa bernilai tinggi |
|---|---|---|---|
| T1 | **Constellation multi-agen** (ATM Polaris) | Primary agent mengobrol. Agen Safety, Medication, Memory, dan Voice Vitals berjalan paralel di event bus (asyncio) dan menyuntikkan *guidance* ke primary. Keputusan medis hanya lewat tool call yang tervalidasi skema | Arsitektur, bukan sekadar wrapper API. Mudah dijelaskan dengan diagram |
| T2 | **Red flag 3 jalur, fail-safe** | (a) aturan deterministik (kata kunci + ambang tensi ≥180/120, nyeri dada, lemah sesisi), (b) klasifikasi LLM, (c) anomali suara. **OR-gate**, dioptimalkan untuk recall | Auditabel, aman, terukur |
| T3 | **Personalized endpointing** | Ambang jeda akhir giliran dipelajari dari distribusi jeda Mbah sendiri (persentil-95, dibatasi 0,7–2,0 s). Ditambah *backchannel* ("nggih…", "oh ngaten") saat Mbah bicara panjang | Detail teknis yang jarang dipakai, langsung terasa di UX lansia |
| T4 | **Voice Vitals: dua jam** | Per ucapan: articulation rate, pause ratio, HNR, F0 range, jitter/shimmer (parselmouth, ekstraksi di audio 8 kHz). **Jam akut**: robust z (median/MAD) vs 14 panggilan terakhir → stroke. **Jam kronis**: CUSUM untuk tren beberapa minggu → sinyal gagal jantung/kognitif (ATM Cordio, framing riset). Kalimat baku harian disisipkan secara natural ("Coba Ibu ucapkan: *Sugeng enjing, kula sampun ngunjuk obat*") | Plafon riset tinggi, tetapi klaimnya tetap "sinyal", bukan diagnosis |
| T5 | **Memori jangka panjang + register bahasa** | Ekstraksi fakta tiap panggilan → tabel `memories` (+ embedding). Retrieval dilakukan di awal panggilan. Deteksi krama/ngoko dari jawaban Mbah | Didukung bukti engagement (JMIR 2026), dan sangat menyentuh secara budaya |
| T6 | **Escalation orchestrator** | Twilio Conference (Mbah + anak, opsional kader), WA alert + peta, **pre-alert IGD** ke board realtime, perhitungan sisa golden period dari *last known well*, routing ke RS ber-CT (jejaring Code Stroke) | End-to-end dari rumah sampai IGD |
| T7 | **Harness evaluasi tingkat audio** | Pasien sintetis: LLM persona → TTS → **disimulasikan lewat codec telepon 8 kHz μ-law + noise** → pipeline TILIK. Persona: sehat, lupa obat, pura-pura sehat, pendengaran kurang, cucu yang mengangkat, salah sambung, **stroke (ucapan diperlambat + diperhalus secara sinyal)**. Metrik: recall red flag, F1 ekstraksi, latensi p50/p95, WER di audio telepon, false alarm per 100 panggilan | **Pembeda terbesar** dari tim lain: ada angka, ada metodologi |

Opsional untuk final: **mode "sovereign"**, yaitu Whisper + Sahabat-AI 8B self-hosted (vLLM) dengan tabel benchmark vs API. Data tidak keluar Indonesia, dan ini narasi yang kuat untuk B2G.

### 4.3 Batas klaim
| Lapisan | Boleh diklaim | Jangan diklaim |
|---|---|---|
| Skrining stroke verbal | "Mempercepat pengenalan & rujukan. CPSS via telepon terbukti meningkatkan akurasi dispatcher" | "Mendeteksi stroke dengan akurasi X%" |
| Jam akut suara | "Menangkap perubahan bicara mendadak dibanding baseline pribadi, sebagai pemicu skrining" | "Mendiagnosis dysarthria" |
| Jam kronis suara | "Sinyal tren untuk ditindaklanjuti nakes. Riset serupa (Cordio) menunjukkan sinyal ±3 minggu lebih awal" | "Memprediksi gagal jantung" |
| Pre-alert IGD | "Memberi IGD info onset & riwayat sebelum pasien tiba" | "Memangkas door-to-needle X menit" (bukti meta-analisis belum signifikan) |

---

## 5. Prioritas fitur

| Prioritas | Fitur | Target |
|---|---|---|
| **P0 (wajib sebelum submit 16 Okt)** | Telepon outbound real-time + barge-in · state machine + tool calling · red flag 3 jalur (versi suara: offline/semi-live) · skrining stroke + jam onset · **Twilio Conference ke anak** · WA alert + peta RS ber-CT · **board pre-alert IGD** · memori sederhana (3–5 fakta) · Daftar Tilik Hari Ini · harness eval 30 skenario teks + 10 skenario audio · README + diagram + docker | Video demo menampilkan W1, W2 (memori), W4, W5, W6 |
| **P0 tambahan etika** ([detail](TILIK_Celah_Etika_dan_Defense.md) §8) | Disclosure "asisten AI" + **kata sandi keluarga** · rapor WA dengan **Bahan Obrolan** + tombol "Telepon Ibu sekarang" · **eskalasi 3 warna** · **Sahabat Tilik** (tetangga/kader) di mode darurat · edukasi SeGeRa Ke RS | Menjawab kritik etika sebelum ditanyakan |
| **P1 (sebelum final 1 Nov)** | Panel Tanda Vital Suara **live** (W3) · personalized endpointing + backchannel · register krama/ngoko · eval 100+ skenario audio · uji 5–10 lansia sungguhan · wawancara nakes/tim Code Stroke · unit economics nyata | Semua 6 momen WOW live |
| **P2 (roadmap di slide)** | Jam kronis (gagal jantung/kognitif) · mode sovereign Sahabat-AI · integrasi SATUSEHAT & PSC 119 · bahasa Sunda/Madura · skrining kamera via HP keluarga (StrokeGuard) | Visi |

---

## 6. Optimasi rubrik final

| Aspek | Bobot | Bukti yang ditunjukkan | Proyeksi submit | Proyeksi final |
|---|---|---|---|---|
| **Inovasi Solusi** | 25 | Matriks pembeda; peta ATM (§2); 3 hal yang belum ada di dunia (stroke screening + onset + pre-alert IGD dalam check-in harian; voice vitals dua jam; loop anak perantau); first mile untuk Code Stroke RSA UGM | 9 | **9,7** |
| **Implementasi Teknis** | 30 | Constellation T1–T7; telepon real-time sungguhan; **tabel hasil eval** (recall, F1, p50/p95, WER, false alarm); repo dengan test & docker | 8,7 | **9,6** |
| **Fungsionalitas & Desain** | 20 | Voice UX lansia (endpointing personal, backchannel, krama, satu pertanyaan per giliran, konfirmasi angka); 4 permukaan yang konsisten (telepon, WA, Puskesmas, IGD); skenario gagal tertangani | 8,8 | **9,6** |
| **Dampak & Kelayakan** | 15 | DIY 17,83% lansia; stroke 18,5% kematian; hanya 10,1% tepat waktu; Emory 85% / −88,7% biaya; jalur pembayar (kapitasi RPPT, keluarga, asuransi); mitra jaringan Code Stroke UGM; UU PDP; hasil uji lansia + kutipan nakes | 9 | **9,6** |
| **Presentasi & Demonstrasi** | 10 | Koreografi 6 WOW, HP juri berdering, cerita DIY & Code Stroke UGM, video cadangan | 9 | **10** |
| **Total tertimbang** | | | **~89,6** | **~96,6** |

---

## 7. Bank data untuk slide dan proposal

| Kategori | Angka | Sumber |
|---|---|---|
| Lansia DIY | **17,83%** (tertinggi nasional), nasional 11,97% (SUPAS 2025) | [CNBC](https://www.cnbcindonesia.com/news/20260505124043-4-732367/indonesia-masuk-fase-aging-population-yogyakarta-yang-tertinggi), [Katadata](https://katadata.co.id/finansial/makro/69f98f9b16452/bps-indonesia-resmi-masuki-fase-penuaan-penduduk-lansia-hampir-12) |
| Stroke | 18,5% kematian (SKI 2023); prevalensi 8,3‰ | [Kemenkes](https://sehatnegeriku.kemkes.go.id/baca/umum/20241025/4046682/cegah-stroke-dengan-aktivitas-fisik), [PERSI/RSA UGM](https://www.persi.or.id/wp-content/uploads/2025/10/RS-Akademik-UGM-Code-Stroke-Lintas-Sektor.pdf) |
| Keterlambatan | Median 16,5 jam; 65,9% > 8 jam (RSHS); 10,1% tepat waktu (RSOMH 2024); tinggal sendiri = faktor risiko | [UMY](https://etd.umy.ac.id/46447/4/Bab%20I.pdf), [Unmuh Jember](https://repository.unmuhjember.ac.id/32417/2/C.%20BAB%20I.pdf), [CNBC](https://www.cnbcindonesia.com/lifestyle/20251201141131-33-690015/stroke-jadi-pembunuh-nomor-satu-di-ri-gejalanya-sering-diabaikan) |
| Hambatan sistem (Gunungkidul) | Keterlambatan identifikasi gejala, CT 24 jam terbatas, koordinasi rujukan | [PERSI/RSA UGM](https://www.persi.or.id/wp-content/uploads/2025/10/RS-Akademik-UGM-Code-Stroke-Lintas-Sektor.pdf) |
| Kepatuhan obat | 32,3% tidak rutin + 13,3% tidak minum; 59,8% "merasa sehat" | [Undip](https://ejournal2.undip.ac.id/index.php/jekk/article/download/26705/12595) |
| Prolanis/RPPT | 20,5 jt JKN hipertensi; 4,8 jt Prolanis; RPPT Cilegon 0,68% vs target > 5% | [Investortrust](https://investortrust.id/lifestyle/82798/bpjs-kesehatan-tekan-kasus-kronis-dengan-prolanis), [Banten](https://ejournal.bantenprov.go.id/index.php/jkpd/article/download/336/202) |
| Teknologi lansia | 49% memakai HP, 26% memakai internet | [GoodStats](https://data.goodstats.id/statistic/52-lansia-indonesia-menggunakan-hp-pada-2025-mPzl6) |
| Bukti AI voice | Emory 85% / −88,7%; Polaris 10 jt+ panggilan (klaim vendor); memori +2,47 menit/memori | [UPI](https://www.upi.com/Health_News/2025/09/08/AI-voice-agent-seniors-high-blood-pressure/4551757339502/), [arXiv](https://arxiv.org/pdf/2603.29893), [JMIR](https://formative.jmir.org/2026/1/e87704) |
| Bukti suara | Cordio sens 82% ±3 minggu lebih awal (interim); MCI ±80% (meta-analisis); depresi lansia 82%/81% | [Hospitalist](https://blogs.the-hospitalist.org/content/voice-analysis-app-promising-early-warning-system-heart-failure-decompensation), [PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12560767/), [Frontiers](https://www.frontiersin.org/journals/psychiatry/articles/10.3389/fpsyt.2022.1016676/pdf) |

---

## 8. Resource teknis

| Kebutuhan | Resource | Catatan praktis |
|---|---|---|
| Pipeline suara | **Pipecat** ([Gemini Live + Twilio](https://docs.pipecat.ai/guides/features/gemini-live), contoh `phone-bot-twilio`, [pipecat-examples](https://github.com/Vonage/pipecat-examples)) | `uv tool install pipecat-ai-cli` → `pipecat init` |
| Telepon & konferensi | Twilio Programmable Voice + Media Streams + **Conference** | ⚠️ **Akun trial memutar pesan "trial account" di awal panggilan dan hanya bisa menelepon nomor terverifikasi. Upgrade (top-up kecil) sebelum rekam demo.** Server harus publik (Cloud Run/Fly/VPS; ngrok untuk dev) |
| STT | Google STT `id-ID` & **`jv-ID`** ([docs](https://cloud.google.com/dotnet/docs/reference/Google.Cloud.Speech.V1/latest/Google.Cloud.Speech.V1.LanguageCodes.Javanese)), Whisper large-v3 | Uji di audio 8 kHz |
| TTS | Google `id-ID`, ElevenLabs multilingual, Prosa.ai (lokal) | TTS Jawa belum terkonfirmasi. Frasa Jawa diucapkan suara Indonesia |
| LLM | Claude/Gemini (tool calling); **Sahabat-AI** (open, Jawa/Sunda) untuk mode sovereign ([GoTo](https://www.gotocompany.com/en/news/press/sahabat-ai-gets-smarter-indosat-and-goto-launch-new-70-billion-parameter-model-with-multilingual-chat-service)) | |
| Fitur suara | `praat-parselmouth`, `librosa`, openSMILE eGeMAPS | Referensi: [StrokeSense](https://github.com/avellal14/StrokeSense) |
| Data & realtime | Supabase (Postgres + realtime + pgvector) | Satu backend untuk board Puskesmas, panel suara, dan IGD |
| WA | WhatsApp Cloud API (nomor tes) | Rapor, titip pesan, alert |
| Peta/ETA | Google Directions / OSRM | Data RS ber-CT: RSUD Wonosari, RS Saptosari, RS Panti Rahayu (Gunungkidul) + RSA UGM, RSUP Sardjito (Sleman). **Verifikasi layanan CT 24 jam** |
| Interop | FHIR R4 (`Observation` tensi LOINC 85354-9, `Communication` untuk pre-alert) | Label "SATUSEHAT-ready" |

---

## 9. Rencana kerja

| Waktu | A: Voice/Telephony | B: Agents & Safety | C: Web/WA/Data | D: Eval/Riset/Konten |
|---|---|---|---|---|
| **13 Okt malam** | Pipecat + Twilio hello-call (akun di-upgrade) | Skrip state machine + daftar red flag + skrip CPSS | Skema Supabase, WA Cloud API | Uji STT/TTS id/jv di audio 8 kHz; data RS ber-CT |
| **14 Okt** | Barge-in, latensi, Conference | Safety/Medication/Memory agent + tool calling | Board IGD + Daftar Tilik + rapor WA + peta | Persona & skenario eval; storyboard video |
| **15 Okt** | Integrasi end-to-end, deploy publik | Voice features offline + baseline z | Polish UI, panel suara statis | Jalankan eval → tabel angka; rekam video ≤ 2 menit |
| **16 Okt** | README, diagram, docker | Bug fix | – | Proposal ≤ 10 hlm + pitch deck (slide penggunaan AI) → **submit** |
| **17 Okt–1 Nov** | Endpointing personal, backchannel | Voice vitals live, krama/ngoko | Panel suara live, polish | Uji 5–10 lansia, wawancara nakes/tim stroke, eval 100+, latihan pitch 3× + gladi demo di jaringan seluler |

---

## 10. Risiko dan mitigasi

| Risiko | Mitigasi |
|---|---|
| Sinyal di gedung final | Gladi saat warm-up 08.00; hotspot cadangan; fallback panggilan browser (WebRTC) dengan UI telepon; video per babak |
| Latensi > 1,5 s | Ukur sejak hari 1. Opsi Gemini Live (speech-to-speech) vs cascaded. Kalimat pembuka cepat |
| Scope terlalu besar | Disiplin P0/P1/P2. P0 saja sudah ±89 |
| Overclaim medis | Patuhi tabel §4.3 |
| Etika | AI selalu mengaku AI; tanpa voice cloning; tidak pernah meminta uang/OTP/NIK; opt-in; UU PDP; audio mentah tidak disimpan |
| "Wrapper API" | Tunjukkan T1–T7 + angka eval, yang semuanya kode tim |
| Demo konferensi gagal | Pre-test nomor juri/tim; cadangan WA call; video |

---

## 11. QnA tambahan (lanjutan dari v3 §9)

| Pertanyaan | Jawaban |
|---|---|
| "Apa hubungannya dengan RS/UGM?" | Code Stroke RSA UGM membereskan jalur di dalam RS. TILIK menutup jalur dari rumah, yang di dokumen mereka sendiri disebut sebagai hambatan ("keterlambatan identifikasi gejala"). Kami ingin pilot di jejaring Gunungkidul. |
| "Constellation itu overkill?" | Setiap agen punya satu tanggung jawab yang bisa diuji terpisah. Itu juga pola yang dipakai sistem dengan 10 juta+ panggilan (Polaris). |
| "Biomarker suara lewat telepon 8 kHz valid?" | Kami tidak mengklaim diagnosis. Fitur prosodi (kecepatan, jeda) tetap ada di 8 kHz, dan kami membandingkan Mbah dengan dirinya sendiri, bukan dengan populasi. Hasil eval audio kami: (angka). |
| "Kenapa tidak pakai Moshi/full-duplex?" | Belum mendukung bahasa Indonesia dan lisensi bobotnya non-komersial. Endpointing personal + backchannel memberi 80% manfaatnya hari ini. |

---

### Sumber baru v4
- [Polaris arXiv 2403.13313](https://arxiv.org/html/2403.13313v1) · [Polaris arXiv 2603.29893](https://arxiv.org/pdf/2603.29893) · [Hippocratic research](https://www.hippocraticai.com/research)
- [Cordio HearO (The Hospitalist)](https://blogs.the-hospitalist.org/content/voice-analysis-app-promising-early-warning-system-heart-failure-decompensation) · [HFSA ePoster](https://hfsa.multilearning.com/hfsa/2021/eposters/343569/antoinette.birs.refractory.coronary.vasospasm.and.sudden.cardiac.death.in.a.html)
- [Sonde JMIR 2025](https://www.jmir.org/2025/1/e68741) · [Sonde respiratory](https://www.speechtechmag.com/Articles/News/Speech-Technology-News/Sonde-Healths-Respiratory-Responsive-Vocal-Biomarker-Tool-Identifies-Patients-with-Respiratory-Conditions-158804.aspx)
- [Kintsugi, Annals of Family Medicine 2025](https://www.annfammed.org/content/23/1/60/tab-figures-data) · [Frontiers Psychiatry 2022](https://www.frontiersin.org/journals/psychiatry/articles/10.3389/fpsyt.2022.1016676/pdf)
- [Prehospital notification Busan (SJTREM)](https://sjtrem.biomedcentral.com/articles/10.1186/s13049-016-0251-2/tables/2) · [Meta-regresi DTN (PMC)](https://pmc.ncbi.nlm.nih.gov/articles/PMC7401993/table/T3) · [AAN 2025 pre-notification](https://index.mirasmart.com/AAN2025/PDFfiles/AAN2025-003215.html)
- [rPPG Lifelight VISION (PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9706384/)
- [Moshi arXiv 2410.00037](https://arxiv.org/html/2410.00037v1)
- [RSA UGM: Code Stroke Lintas Sektor (PERSI Awards 2025)](https://www.persi.or.id/wp-content/uploads/2025/10/RS-Akademik-UGM-Code-Stroke-Lintas-Sektor.pdf)
- [CNBC: DIY lansia tertinggi (SUPAS 2025)](https://www.cnbcindonesia.com/news/20260505124043-4-732367/indonesia-masuk-fase-aging-population-yogyakarta-yang-tertinggi) · [Katadata](https://katadata.co.id/finansial/makro/69f98f9b16452/bps-indonesia-resmi-masuki-fase-penuaan-penduduk-lansia-hampir-12)
- Sumber lain: lihat v1–v3.
