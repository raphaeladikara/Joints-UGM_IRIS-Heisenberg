# Ideas Breakdown v3 (FINAL): TILIK

Dibuat 13 Oktober 2026. Versi ini menggantikan [v2](Ideas_Breakdown_v2.md). Isinya: cek kebaruan ulang (termasuk pesaing global), penguatan konsep, optimasi per aspek rubrik resmi, dan daftar resource siap pakai.

**Rubrik resmi (sudah dikonfirmasi dari slide):** Inovasi Solusi 25% · Implementasi Teknis 30% · Fungsionalitas & Desain 20% · Dampak & Kelayakan Implementasi 15% · Presentasi & Demonstrasi 10%.

> **Jujur soal 95+:** skor di sini adalah proyeksi. Prototype yang disubmit 16 Okt realistisnya di **~88–90**. Untuk tembus **95+ di Grand Final 1 Nov**, semua item di §6 harus ada. Ini ide dengan plafon tertinggi yang bisa saya temukan, dan alasannya ada di §1.

---

## 0. TL;DR

**TILIK: sistem "Cegah, Deteksi, Arahkan" untuk lansia hipertensi yang tinggal jauh dari anaknya, lewat telepon biasa.**

1. **Cegah**: setiap pagi AI menelepon Mbah (HP jadul pun bisa), ngobrol hangat dalam bahasa Indonesia dengan sapaan Jawa, mengecek obat, tensi, dan gejala. Anak di perantauan bisa **"titip pesan"** lewat WA untuk disampaikan di telepon besok paginya.
2. **Deteksi**: kalau ada tanda bahaya, TILIK menjalankan **skrining stroke verbal** (adaptasi Cincinnati Prehospital Stroke Scale, CPSS, ala dispatcher 119) dan membandingkan **suara Mbah hari ini dengan baseline suaranya sendiri** (bicara pelo/lambat).
3. **Arahkan**: TILIK mencatat **jam terakhir Mbah terlihat normal** (*last known well*), menelepon dan WA anak serta kader, lalu menunjukkan **RS terdekat yang siap stroke (ada CT-scan)**, bukan sekadar faskes terdekat.

Hasilnya: rapor WA untuk keluarga dan **daftar prioritas untuk Puskesmas** yang langsung menaikkan indikator kinerja Prolanis BPJS (RPPT).

---

## 1. Kenapa TILIK, dan bukan ide lain

Saya menguji 9 ide (detail di v2 §2). Hasil akhirnya:

| Ide | Ceiling | Feasibility 3 hari | Impact | Pitch | Proyeksi | Pembunuhnya |
|---|---|---|---|---|---|---|
| **TILIK (v3)** | **9,5** | **8,5** | **9,5** | **10** | **88 → 95+** | Tidak ada yang fatal. Risikonya teknis dan bisa dimitigasi (§8) |
| Turjuman tweak | 7,5 | 8 | 7 | 8 | ~76 | Puluhan pesaing BISINDO, pasar sempit |
| StrokeGuard kamera | 8,5 | 6 | 8 | 9 | ~74 | Butuh pasien stroke untuk data & validasi |
| Posbindu Copilot | 7 | 8,5 | 7,5 | 6,5 | ~72 | Kurang "wow" |
| AI scribe Puskesmas | 7 | 9 | 8 | 7 | ~70 | Sudah ada Nexmedis, PaperlessHospital, paper ePuskesmas |
| Skrining TBC batuk | 8 | 5 | 9 | 8 | ~68 | AUROC model terbaik (HeAR) hanya 0,739 |

**Kenapa skor pitch TILIK paling tinggi:** ini satu-satunya ide yang demonya bisa dirasakan langsung oleh juri. HP di panggung berdering, lalu HP di meja juri ikut bergetar.

---

## 2. Cek kebaruan (global + Indonesia)

### 2.1 Siapa yang sudah melakukan sesuatu yang mirip
| Pemain | Apa yang dilakukan | Bukti | Yang **tidak** mereka lakukan |
|---|---|---|---|
| **Naver CLOVA CareCall** (Korea, Jepang) | AI menelepon lansia yang tinggal sendiri, fokus kesepian dan kesejahteraan. Dipakai pemda Seoul, Busan, Izumo | Best paper CHI 2023, laporan Boston Globe 2026 | Tidak klinis (obat/tensi), tidak ada skrining stroke, tidak ada routing RS |
| **Hippocratic AI** (AS) | Agen suara untuk chronic care management, kontrak dengan payer dan RS AS | Studi JMIR 2026: 4.415 panggilan; klaim kapasitas tim naik 360% (dari vendor) | Pasar AS dan berbahasa Inggris/Spanyol, tanpa elemen keluarga, tanpa stroke routing |
| **Emory, AHA Hypertension 2025** | AI voice agent menelepon ±2.000 pasien (mayoritas > 65 th) untuk mengambil tensi rumah, eskalasi ke perawat | **85% pasien terjangkau, biaya per bacaan 88,7% lebih murah** dari perawat | Riset AS, tanpa skrining stroke, tanpa loop keluarga |
| **Penn State / Houston Methodist** | Deteksi stroke dari wajah + ucapan via iPhone di RS | 80+ pasien | Dilakukan di RS dan pakai kamera, bukan telepon harian di rumah |
| **BPJS Prolanis** | "Reminder via SMS/telepon" manual oleh faskes untuk jadwal kunjungan | Pedoman Prolanis | Manual, satu arah, tidak mengecek obat/gejala, data kontak sering salah |
| **Indosat-Huawei "AI New Calling"** | Demo AI menelepon untuk ucapan ulang tahun | Bisnis.com, Agustus 2026 | Bukan kesehatan |
| Nanachat, chatbot lansia | Chat berbasis aplikasi | Google AI competition | Butuh smartphone + internet |

### 2.2 Matriks pembeda
| Kemampuan | CareCall | Hippocratic | Emory | Prolanis SMS | **TILIK** |
|---|:-:|:-:|:-:|:-:|:-:|
| Telepon biasa, tanpa smartphone | ✅ | ✅ | ✅ | ✅ | ✅ |
| Bahasa Indonesia + sapaan/bahasa daerah | ❌ | ❌ | ❌ | – | ✅ |
| Kepatuhan obat + tensi terstruktur | ❌ | ✅ | ✅ (tensi) | ❌ | ✅ |
| **Skrining stroke verbal + jam onset** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Baseline suara personal (tren bicara)** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Routing ke RS siap stroke** | ❌ | ❌ | ❌ | ❌ | ✅ |
| **Loop keluarga perantau (rapor + titip pesan)** | ❌ | ❌ | ❌ | ❌ | ✅ |
| Terhubung ke indikator BPJS (RPPT/KBK) | – | – | – | ✅ manual | ✅ |

**Kesimpulan kebaruan:**
- Konsep "AI menelepon pasien" **sudah tervalidasi** di luar negeri. Ini nilai plus, karena menjawab pertanyaan "feasible tidak?".
- **Di Indonesia belum ada sama sekali.** Saya tidak menemukan layanan sejenis.
- **Kombinasi skrining stroke + jam onset + baseline suara + routing RS siap stroke + loop keluarga belum dilakukan siapa pun**, termasuk pemain global.
- Kalimat untuk pitch: *"Korea dan Amerika sudah membuktikan lansia mau ditelepon AI. Kami yang pertama memakainya untuk mengejar golden period stroke di Indonesia."*

---

## 3. Masalah dan angka (versi final, untuk slide)

| # | Fakta | Angka | Sumber |
|---|---|---|---|
| 1 | Stroke penyebab kematian #1 | **18,5%** dari total kematian (SKI 2023) | [Kemenkes](https://sehatnegeriku.kemkes.go.id/baca/umum/20241025/4046682/cegah-stroke-dengan-aktivitas-fisik) |
| 2 | Pasien stroke yang terlambat ke RS | Median kedatangan **16,5 jam**, 65,9% tiba > 8 jam (RSHS Bandung). **Hanya 10,1%** tiba dalam golden period (RSOMH Bukittinggi 2024) | [CNBC](https://www.cnbcindonesia.com/lifestyle/20251201141131-33-690015/stroke-jadi-pembunuh-nomor-satu-di-ri-gejalanya-sering-diabaikan), [UMY](https://etd.umy.ac.id/46447/4/Bab%20I.pdf), [Unmuh Jember](https://repository.unmuhjember.ac.id/32417/2/C.%20BAB%20I.pdf) |
| 3 | Faktor keterlambatan | Rendahnya pengetahuan keluarga, **pasien yang tinggal sendiri**, jarak ke RS | sda |
| 4 | Hipertensi tidak rutin minum obat | **32,3%** + 13,3% tidak minum sama sekali. **59,8%** berhenti karena "merasa sudah sehat" | Riskesdas 2018 via [Undip](https://ejournal2.undip.ac.id/index.php/jekk/article/download/26705/12595) |
| 5 | Peserta JKN hipertensi / DM | 20,5 jt / 7,4 jt. Prolanis hanya 4,8 jt | [Investortrust](https://investortrust.id/lifestyle/82798/bpjs-kesehatan-tekan-kasus-kronis-dengan-prolanis) |
| 6 | RPPT (indikator kapitasi BPJS) | Target > 5%. Cilegon 2023: 0,68%. Kupang 2019–21: 0 Puskesmas yang mencapai | [Banten](https://ejournal.bantenprov.go.id/index.php/jkpd/article/download/336/202), [Undana](https://ejurnal.undana.ac.id/index.php/CMJ/article/download/24288/9881/) |
| 7 | Lansia tanpa generasi muda di rumah | 5,5% tinggal sendiri + 21,7% hanya dengan pasangan ≈ **27% (±7,9 jt)** | BPS via [Undip](https://eprints2.undip.ac.id/id/eprint/52172/3/HANA%20MARYAM%20ROHMAH_13040222140094%20Bab%20I.pdf) *(verifikasi ke PDF BPS)* |
| 8 | Lansia dan teknologi | 49% memakai HP, **hanya 26% memakai internet** | BPS via [GoodStats](https://data.goodstats.id/statistic/52-lansia-indonesia-menggunakan-hp-pada-2025-mPzl6) |
| 9 | Bukti AI voice agent untuk lansia | Emory: **85% terjangkau, biaya 88,7% lebih murah** | [UPI](https://www.upi.com/Health_News/2025/09/08/AI-voice-agent-seniors-high-blood-pressure/4551757339502/), [HomeCare](https://www.homecaremag.com/news/ai-voice-agents-help-seniors-accurately-report-blood-pressure-research-says) |
| 10 | Skrining stroke lewat telepon | Dispatcher yang memakai CPSS lewat telepon: sensitivitas ±68%. Tanpa skala bisa serendah 40% | [PMC 2013](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3867422/), [PMC pilot](https://pmc.ncbi.nlm.nih.gov/articles/PMC4315162) |

**Narasi satu baris:** *"Stroke membunuh paling banyak orang Indonesia. Hanya 1 dari 10 pasien sampai di RS tepat waktu, dan yang paling sering terlambat adalah lansia yang tinggal sendiri. Padahal 2 dari 3 lansia tidak bisa memakai aplikasi, tapi semuanya bisa mengangkat telepon."*

---

## 4. Desain produk

### 4.1 Tiga pengguna, tiga antarmuka
| Pengguna | Antarmuka | Nilai |
|---|---|---|
| **Mbah** | Telepon biasa, tanpa layar | Ditemani, diingatkan, ditolong cepat |
| **Anak perantau** | WhatsApp | Rapor harian, **titip pesan**, alert darurat + arah ke RS |
| **Puskesmas / kader** | 1 halaman "Daftar Tilik Hari Ini" | Siapa yang perlu dikunjungi, data tensi dan kepatuhan untuk RPPT |

### 4.2 Alur panggilan harian
```
07.00  📞 TILIK menelepon
  │   [Panggilan pertama: rekaman suara asli anak → "Bu, mulai besok ditelepon Tilik ya"]
  ▼
Sapa ("Sugeng enjing, Bu Sri. Niki Tilik saking Puskesmas Gamping…")
  ▼
Titip pesan dari anak ("Mas Dika titip pesen: sampun kontrol dereng?")
  ▼
Obat sudah diminum? ─ belum → gali alasannya (lupa / habis / merasa sehat) → edukasi singkat
  ▼
Tensi (kalau ada alat) → angka dibacakan → TILIK mengulang untuk konfirmasi
  ▼
Gejala: pusing, nyeri dada, sesak, kesemutan/lemah sesisi, bicara susah?
  ▼
Mesin red flag (aturan deterministik ∥ klasifikasi LLM ∥ deviasi suara dari baseline)
  │
  ├─ aman ─▶ penutup hangat + pengingat jadwal Prolanis ─▶ log ─▶ rapor WA + daftar Puskesmas
  │
  └─ 🚨 curiga stroke ─▶ skrining verbal (adaptasi CPSS):
          • "Coba Ibu ulangi: 'Langit biru di atas desa'" → analisis kejelasan bicara
          • "Coba angkat kedua tangan 10 detik, ada yang turun?" (dijawab Mbah/orang di dekatnya)
          • "Ada orang di dekat Ibu? Minta lihat senyumnya, mencong tidak?"
          • "Jam berapa terakhir Ibu merasa normal?" → last known well
        ▼
     Eskalasi paralel: telepon + WA anak · WA kader/Puskesmas · instruksi 119/ambulans desa
     + kartu WA: "RS siap stroke terdekat: RSUP Dr. Sardjito (CT 24 jam), ±23 menit"
     + "Onset ±06.40, sisa golden period ±3 jam 50 menit"
```

### 4.3 Fitur MVP (16 Okt) vs Final (1 Nov)
| Fitur | MVP submit | Final |
|---|:-:|:-:|
| Telepon keluar real-time (Twilio ↔ Pipecat) + barge-in | ✅ | ✅ |
| State machine dialog + function calling (log obat, tensi, gejala, eskalasi) | ✅ | ✅ |
| Red flag ganda (aturan + LLM) | ✅ | ✅ |
| Skrining stroke verbal + jam onset | ✅ | ✅ |
| Eskalasi WA ke anak + kartu RS siap stroke (data RS DIY dikurasi manual) | ✅ | ✅ |
| Rapor WA harian | ✅ | ✅ |
| Titip pesan dari anak (WA → agenda telepon besok) | ✅ (sederhana) | ✅ |
| Daftar Tilik Hari Ini (Puskesmas) | ✅ | ✅ + proyeksi RPPT |
| Harness evaluasi (pasien sintetis LLM-vs-LLM) | ✅ 30 skenario | ✅ 100+ skenario + angka final |
| Baseline suara (kecepatan bicara, rasio jeda, latensi menjawab, artikulasi) | ⚪ prototype offline | ✅ live + visual tren |
| Uji ke lansia sungguhan | ⚪ 1–2 orang | ✅ 5–10 orang + wawancara 1 Puskesmas |
| Ekspor FHIR `Observation` (SATUSEHAT-ready) | ⚪ JSON mock | ✅ |
| Bahasa Jawa lebih penuh / opsi Sahabat-AI | ❌ | ⚪ eksperimen |

---

## 5. Arsitektur teknis

```
 ┌──────────┐   PSTN   ┌─────────┐  WebSocket  ┌──────────────── TILIK Core (Python) ───────────────┐
 │ HP Mbah  │◀────────▶│ Twilio  │◀───────────▶│ Pipecat pipeline                                    │
 └──────────┘          └─────────┘   (audio)   │  VAD (end-of-turn diperpanjang untuk lansia)        │
                                               │   → STT (id-ID / jv-ID)                             │
                                               │   → Dialog Manager (state machine + LLM + tools)    │
                                               │   → TTS (lambat, hangat, kalimat pendek)            │
                                               │  ∥ Voice Feature Tap → parselmouth/librosa          │
                                               │  ∥ Red-Flag Engine (rules ∥ LLM ∥ voice z-score)    │
                                               └───────┬───────────────────────┬─────────────────────┘
                                                       ▼                       ▼
                                              Supabase (Postgres)      Escalation Service
                                              calls · observations     · WA Cloud API (anak, kader)
                                              voice_baseline · tasks   · Twilio call ke anak
                                                       ▼               · Stroke-ready RS lookup
                                     ┌─────────────────┴───────────────┐
                                     ▼                                 ▼
                         Web "Daftar Tilik Hari Ini"        WA Rapor + Titip Pesan (webhook)
                         (Next.js, 1 halaman)               → agenda panggilan berikutnya
```

**Detail yang perlu disebut di pitch karena juri teknis menilainya:**
- **Latensi:** target p50 ≤ 900 ms per giliran. Opsi speech-to-speech (Gemini Live) vs cascaded (STT → LLM → TTS). Pilih cascaded kalau butuh kontrol bahasa dan logging, lalu ukur keduanya.
- **VAD khusus lansia:** jeda akhir giliran lebih panjang (±1,2 s, bukan 0,5 s) supaya Mbah tidak dipotong. Detail kecil yang menunjukkan empati desain.
- **Guardrail:** LLM tidak boleh mendiagnosis atau mengubah dosis. Semua output medis lewat tool call yang tervalidasi skema (Pydantic).
- **Red flag "fail-safe":** cukup salah satu dari tiga detektor terpicu untuk eskalasi. Dioptimalkan untuk recall.
- **Voice baseline:** fitur per panggilan disimpan, lalu z-score terhadap 7 panggilan terakhir. Anomali dipakai sebagai **sinyal**, bukan diagnosis.
- **Evaluasi otomatis:** LLM berperan sebagai "pasien sintetis" dengan persona (Mbah sehat, lupa obat, pura-pura sehat, pendengaran kurang, stroke onset, salah sambung, cucu yang mengangkat). Hitung **recall red flag, F1 ekstraksi obat/tensi, latensi p50/p95, rata-rata durasi panggilan, tingkat panggilan selesai**.
- **Privasi (UU PDP 27/2022):** audio mentah tidak disimpan secara default. Yang disimpan hanya transkrip ringkas, fitur numerik, dan log terstruktur. Ada opt-in dan opt-out.

---

## 6. Optimasi per aspek rubrik

| Aspek | Bobot | Juri mencari | Yang harus TILIK tunjukkan | Target |
|---|---|---|---|---|
| **Inovasi Solusi** | 25% | Kebaruan, bukan sekadar meniru | Matriks pembeda §2.2. Tiga hal yang belum ada di dunia: **skrining stroke + jam onset + routing RS siap stroke** dalam panggilan harian, **baseline suara personal**, dan **loop keluarga perantau**. Sebut juga sudut BPJS/RPPT | 9,5 |
| **Implementasi Teknis** | 30% | Benar-benar jalan, arsitektur jelas, kualitas kode, tidak cuma memanggil API | Telepon real-time sungguhan; state machine + tool calling; 3 detektor red flag; **harness evaluasi dengan angka**; repo rapi (README, diagram, `.env.example`, `docker compose up`, test); log latensi | 9,5 |
| **Fungsionalitas & Desain** | 20% | Alur lengkap, UX tepat untuk penggunanya | Voice UX lansia (lambat, satu pertanyaan per giliran, konfirmasi angka, sabar, krama); rapor WA yang jelas; halaman Puskesmas yang bisa dipahami dalam 5 detik; skenario gagal (tidak diangkat, salah sambung, cucu yang menjawab) | 9,5 |
| **Dampak & Kelayakan** | 15% | Skala masalah, bukti, jalur adopsi, biaya, regulasi | Angka §3; bukti Emory (85% terjangkau, 88,7% lebih murah); unit economics dari pricing nyata; jalur B2G via kapitasi/RPPT, B2C via anak perantau; mitra alami Indosat (telco + Sahabat-AI); UU PDP; **validasi: uji ke lansia + kutipan nakes** | 9,5 |
| **Presentasi & Demo** | 10% | Cerita, kejelasan, demo live | Hook film *Tilik* + "kapan terakhir kamu telepon ibumu?"; **telepon live di panggung**, HP juri bergetar; angka evaluasi; video cadangan | 10 |
| **Total** | | | | **≈ 95,5** |

### Pemotong nilai yang harus ditutup
| Risiko | Efek | Mitigasi |
|---|---|---|
| Demo telepon gagal (sinyal gedung, latensi) | Presentasi + Teknis jatuh | Cadangan 1: panggilan via browser (Pipecat SmallWebRTC) di HP dengan UI telepon. Cadangan 2: video rekaman. Uji di lokasi saat warm-up 08.00 |
| "Ini cuma wrapper API" | Teknis turun | Tonjolkan state machine, red-flag engine, voice features, harness eval, dan data model. Itu semua kode tim |
| Overclaim medis | Dampak & kredibilitas turun | Bahasa yang dipakai: "skrining dan percepatan rujukan", bukan "deteksi stroke". Sebut sensitivitas CPSS lewat telepon (±68%) secara jujur, dibandingkan baseline nol untuk lansia tinggal sendiri |
| Nomor penelepon asing (Twilio US) dianggap penipuan | Kelayakan | Produksi: SIP trunk lokal atau mitra telco (Indosat). Protokol anti-penipuan + perkenalan dengan suara anak |
| Bahasa Jawa TTS kurang bagus | Desain | MVP pakai TTS Indonesia + frasa Jawa. Uji provider besok pagi |
| Etika: AI menyamar jadi manusia/anak | Etika (aturan lomba) | TILIK **selalu memperkenalkan diri sebagai asisten AI Puskesmas**, **tanpa voice cloning** suara anak. Yang diputar hanya rekaman asli anak |

---

## 7. Resource siap pakai

### 7.1 Framework & infrastruktur
| Kebutuhan | Resource | Catatan |
|---|---|---|
| Pipeline agen suara | **Pipecat** (open-source, Python): [docs Gemini Live + Twilio](https://docs.pipecat.ai/guides/features/gemini-live), contoh `phone-bot-twilio` di repo `pipecat-ai/pipecat`, [pipecat-examples (twilio-chatbot)](https://github.com/Vonage/pipecat-examples) | Scaffold cepat: `uv tool install pipecat-ai-cli` → `pipecat init` (pilih Twilio) |
| Alternatif | LiveKit Agents (open-source) | Kalau tim lebih nyaman dengan WebRTC |
| Telepon | Twilio Programmable Voice + Media Streams | Akun trial hanya bisa menelepon nomor terverifikasi. Cukup untuk demo |
| WhatsApp | WhatsApp Cloud API (nomor tes Meta) | Untuk rapor, alert, dan webhook titip pesan |
| Database | Supabase | Postgres + auth + realtime untuk halaman Puskesmas |

### 7.2 Speech & bahasa
| Kebutuhan | Opsi | Status |
|---|---|---|
| STT Indonesia | Google Cloud STT `id-ID`, Whisper large-v3, Gemini Live | Tersedia |
| STT Jawa | Google Cloud STT **`jv-ID` terkonfirmasi ada** ([docs](https://cloud.google.com/dotnet/docs/reference/Google.Cloud.Speech.V1/latest/Google.Cloud.Speech.V1.LanguageCodes.Javanese)); Whisper mendukung Jawa | Uji kualitas dengan suara lansia |
| TTS Indonesia | Google Cloud TTS `id-ID`, ElevenLabs multilingual, Prosa.ai (lokal, ±40 suara) ([Gizmologi](https://gizmologi.id/apps/prosa-ai-hadirkan-pembaruan-text-to-speech/)) | Tersedia |
| TTS Jawa | **Belum terkonfirmasi** di Google Cloud TTS. Cek dengan `listVoices(languageCode="jv-ID")`; alternatif ElevenLabs/Gemini TTS | ⚠️ Verifikasi besok pagi |
| LLM bahasa daerah | **Sahabat-AI** (GoTo × Indosat, open-source di Hugging Face; Indonesia, Jawa, Sunda, Bali, Batak) ([GoTo](https://www.gotocompany.com/en/news/press/sahabat-ai-gets-smarter-indosat-and-goto-launch-new-70-billion-parameter-model-with-multilingual-chat-service), [CNBC](https://www.cnbcindonesia.com/tech/20241114125849-37-588208/goto-dan-indosat-bikin-ai-bahasa-jawa-dan-sunda/amp)) | Untuk final/roadmap: menerjemahkan ke krama, atau sebagai narasi "sovereign AI" |
| LLM dialog | Claude / Gemini (tool calling stabil) | Untuk MVP |

### 7.3 Analisis suara & stroke
| Kebutuhan | Resource |
|---|---|
| Ekstraksi fitur suara | `praat-parselmouth`, `librosa`, openSMILE (eGeMAPS) |
| Referensi deteksi stroke dari ucapan | [StrokeSense (GitHub)](https://github.com/avellal14/StrokeSense), Penn State/Houston Methodist ([ScienceDaily](https://www.sciencedaily.com/releases/2020/10/201022123120.htm)) |
| Referensi skrining stroke lewat telepon | CPSS untuk dispatcher ([PMC3867422](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3867422/)) |
| Dataset ucapan dysarthric (kalau mau melatih pembanding) | TORGO, UASpeech (bahasa Inggris, akses perlu didaftar). **Tidak wajib untuk MVP**, karena baseline personal (z-score) tidak butuh dataset |
| Bukti biomarker ucapan | Meta-analisis MCI: ±80% akurasi ([PMC](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12560767/)) |

### 7.4 Domain kesehatan
- Pedoman Prolanis & KBK BPJS (Peraturan BPJS 7/2019): definisi RPPT.
- SATUSEHAT (FHIR R4): resource `Patient`, `Observation` (tensi: LOINC 85354-9), `Condition`.
- Daftar RS siap stroke DIY untuk demo: kurasi manual (RSUP Dr. Sardjito, RS Bethesda, RS PKU Muhammadiyah, dll.). **Cek ketersediaan CT 24 jam sebelum dicantumkan.**

---

## 8. Rencana kerja

Asumsi 3–4 orang.

| Waktu | Backend/AI (A) | Backend/AI (B) | Frontend/WA (C) | Riset/Konten (D) |
|---|---|---|---|---|
| **13 Okt malam** | Pipecat + Twilio "hello call" jalan | Uji STT/TTS (id/jv) dengan 5 rekaman suara lansia | Skema Supabase + WA Cloud API | Kunci skrip dialog + daftar red flag + data RS DIY |
| **14 Okt** | State machine + tool calling + eskalasi | Red-flag engine + skrining stroke + voice features | Daftar Tilik Hari Ini + rapor WA + titip pesan | Proposal draft, storyboard video |
| **15 Okt pagi** | Integrasi end-to-end, ukur latensi | Harness eval 30 skenario, ambil angka | Polish UI, cadangan WebRTC | Uji ke 1–2 lansia, wawancara singkat nakes |
| **15 Okt siang–malam** | README + diagram + docker | Bug fix | Rekam & edit video ≤ 2 menit | Pitch deck (+ slide penggunaan AI) |
| **16 Okt** | Final check repo | | | Proposal final, **submit** (cek jam tutup) |
| **17 Okt–1 Nov** | Voice baseline live, 100+ skenario eval, opsi Sahabat-AI | Uji 5–10 lansia, surat/kutipan Puskesmas | Polish demo panggung | Latihan pitch 3×, simulasi QnA |

### Struktur video ≤ 2 menit
| Detik | Isi |
|---|---|
| 0–12 | Cuplikan nuansa *Tilik*: ibu di desa, anak di kota. Teks: "Kapan terakhir kamu telepon ibumu?" |
| 12–30 | Angka: stroke #1, 10% tepat waktu, 74% lansia tanpa internet |
| 30–80 | Demo: HP jadul berdering → ngobrol → Mbah bicara pelo → skrining → HP anak menerima alert + RS siap stroke |
| 80–100 | Rapor WA, titip pesan, halaman Puskesmas, angka evaluasi |
| 100–120 | Dampak + model bisnis + "TILIK: karena tidak semua anak bisa pulang setiap hari." |

---

## 9. QnA terberat

| Pertanyaan | Jawaban |
|---|---|
| "Apa bedanya dengan Hippocratic AI / CareCall?" | Matriks §2.2. Mereka untuk AS/Korea dan tidak ada stroke routing maupun loop keluarga. Kami yang pertama di Indonesia, berbahasa lokal, dan terhubung ke Prolanis. |
| "Sensitivitas skrining stroke lewat telepon cuma ±68%, kan?" | Benar, dan kami tidak menyembunyikannya. Pembandingnya: lansia yang tinggal sendiri saat ini **0%** terskrining dan median baru tiba di RS setelah 16,5 jam. Tambahan baseline suara personal dirancang untuk menaikkan recall. |
| "Lansia mau ngobrol dengan AI?" | Bukti CareCall dan Emory (85% terjangkau) + hasil uji kami ke N lansia. |
| "Kenapa tidak WhatsApp saja?" | 74% lansia tidak memakai internet. Telepon menjangkau semuanya. WA dipakai untuk keluarga. |
| "Biayanya?" | Unit economics dari pricing nyata vs biaya rawat stroke. Emory: 88,7% lebih murah dari perawat. |
| "Siapa yang bayar?" | Puskesmas (kapitasi KBK/RPPT), keluarga (langganan), asuransi/BPJS (klaim stroke turun). Mitra telco alami: Indosat (AI New Calling + Sahabat-AI). |
| "Bagaimana kalau AI salah dan ada yang celaka?" | TILIK tidak mendiagnosis. Semua red flag diteruskan ke manusia, desainnya mengutamakan recall, dan setiap keputusan tercatat untuk audit. |
| "Penipuan dan etika?" | AI selalu mengaku AI, tanpa voice cloning, tidak pernah meminta uang/OTP/NIK, opt-in, dan UU PDP dipatuhi. |

---

## 10. Hal yang perlu dicek sebelum mulai

1. Pastikan **tema Healthcare** dan apakah subtema wajib dipilih persis dari daftar. TILIK cocok dengan subtema "keluarga merawat lansia".
2. Uji kualitas **TTS/STT Indonesia & Jawa** dengan suara lansia sungguhan.
3. Batasan **Twilio trial** untuk nomor Indonesia + biaya per menit.
4. Verifikasi angka sekunder (BPS lansia tinggal sendiri, Riskesdas 59,8%) ke dokumen asli sebelum masuk proposal.
5. Siapa lansia dan nakes yang bisa diajak uji/wawancara minggu ini?

---

### Sumber tambahan v3 (sumber lain ada di v1 & v2)
- [Hippocratic AI: agen yang menelepon pasien](https://hippocraticai.com/ai-agents-that-call-your-patients/) · [AI Chronic Care Management](https://hippocraticai.com/ai-chronic-care-management-payor/) · [JMIR Formative 2026](https://formative.jmir.org/2026/1/e87704) · [arXiv 2603.29893](https://arxiv.org/pdf/2603.29893) · [MobiHealthNews](https://www.mobihealthnews.com/news/university-hospitals-hippocratic-ai-team-patient-engagement)
- [UPI: AI voice agent seniors BP (Emory/AHA 2025)](https://www.upi.com/Health_News/2025/09/08/AI-voice-agent-seniors-high-blood-pressure/4551757339502/) · [HomeCare Magazine](https://www.homecaremag.com/news/ai-voice-agents-help-seniors-accurately-report-blood-pressure-research-says)
- [ClinicalTrials NCT02454660](https://clinicaltrials.gov/study/NCT02454660)
- [Pedoman Prolanis: reminder SMS/telepon](https://pkmpaduraksa.pemalangkab.go.id/wp-content/uploads/2022/04/19_STANDAR-PELAYANAN-PROLANIS.pdf) · [Unimus: Prolanis](https://jurnal.unimus.ac.id/index.php/jkmi/article/download/17635/pdf)
- [PMC3867422: CPSS saat wawancara dispatch](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3867422/) · [PMC4315162: pilot dispatcher](https://pmc.ncbi.nlm.nih.gov/articles/PMC4315162) · [PubMed: San Diego dispatcher](https://pubmed.ncbi.nlm.nih.gov/18584497/)
- [StrokeSense](https://github.com/avellal14/StrokeSense) · [ScienceDaily: stroke via smartphone](https://www.sciencedaily.com/releases/2020/10/201022123120.htm) · [SciTePress: mobile stroke speech](https://scitepress.org/Papers/2019/75869/pdf/index.html)
- [CNBC: stroke pembunuh nomor satu](https://www.cnbcindonesia.com/lifestyle/20251201141131-33-690015/stroke-jadi-pembunuh-nomor-satu-di-ri-gejalanya-sering-diabaikan) · [UMY Bab I](https://etd.umy.ac.id/46447/4/Bab%20I.pdf) · [Unmuh Jember Bab I](https://repository.unmuhjember.ac.id/32417/2/C.%20BAB%20I.pdf)
- [Pipecat Gemini Live](https://docs.pipecat.ai/guides/features/gemini-live) · [pipecat-examples](https://github.com/Vonage/pipecat-examples)
- [Google Cloud STT Javanese](https://cloud.google.com/dotnet/docs/reference/Google.Cloud.Speech.V1/latest/Google.Cloud.Speech.V1.LanguageCodes.Javanese)
- [GoTo: Sahabat-AI 70B](https://www.gotocompany.com/en/news/press/sahabat-ai-gets-smarter-indosat-and-goto-launch-new-70-billion-parameter-model-with-multilingual-chat-service) · [CNBC: AI Jawa & Sunda](https://www.cnbcindonesia.com/tech/20241114125849-37-588208/goto-dan-indosat-bikin-ai-bahasa-jawa-dan-sunda/amp)
- [Prosa.ai TTS](https://gizmologi.id/apps/prosa-ai-hadirkan-pembaruan-text-to-speech/)
