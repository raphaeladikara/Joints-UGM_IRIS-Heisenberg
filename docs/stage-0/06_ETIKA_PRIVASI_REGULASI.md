# 06 · Etika, Privasi & Regulasi (Requirement)

Dokumen ini mengubah hasil audit di [`docs/research/TILIK_Celah_Etika_dan_Defense.md`](../research/TILIK_Celah_Etika_dan_Defense.md) menjadi **requirement yang bisa dicek**. Argumen dan sumbernya ada di dokumen riset tersebut.

---

## 1. Requirement etika

| ID | Requirement | Menjawab celah | MVP? |
|---|---|---|---|
| ETH-01 | Setiap panggilan diawali disclosure "asisten AI" | Deception | ✅ MUST |
| ETH-02 | **Kata sandi keluarga** disebut di awal setiap panggilan | Penipuan yang menyamar jadi TILIK | ✅ MUST |
| ETH-03 | Tidak ada voice cloning. Pesan anak diputar dengan **suara asli** | Deception, AI menggantikan keluarga | ✅ MUST |
| ETH-04 | TILIK tidak pernah mengaku punya perasaan atau memposisikan diri sebagai keluarga | Ketergantungan emosional | ✅ MUST (prompt + eval) |
| ETH-05 | Rapor WA memuat **Bahan Obrolan** + tautan "Telepon Ibu sekarang" | "AI menggantikan telepon anak" | ✅ MUST |
| ETH-06 | Eskalasi 3 warna. 🔴 hanya untuk kriteria mayor | Alarm palsu | ✅ MUST |
| ETH-07 | Responder lokal (**Sahabat Tilik**) dihubungi pertama saat 🔴 | Anak jauh tidak bisa menolong | ✅ MUST |
| ETH-08 | Edukasi SeGeRa Ke RS + informasi "boleh menelepon balik" di setiap penutup | Rasa aman palsu | ✅ MUST (telepon balik = SHOULD) |
| ETH-09 | Tidak pernah meminta uang/OTP/NIK/rekening | Penipuan | ✅ MUST |
| ETH-10 | Mode `WRONG_PERSON`: tanpa data medis | Privasi | ✅ MUST |
| ETH-11 | Hak pasien menolak dihormati: tidak memaksa minum obat, boleh menolak panggilan, boleh berhenti layanan | Otonomi, paternalisme | ✅ MUST (perilaku) |
| ETH-12 | Consent dari **pasien sendiri** (bukan hanya keluarga). Berbagi bertingkat | Pengawasan berlebihan | ⚪ MVP: data seed. UI = LATER |
| ETH-13 | Mode rahasia (curhat tidak diteruskan, kecuali keselamatan) | Otonomi | LATER |
| ETH-14 | Nudge Kangen + family-first | AI menggantikan keluarga | SHOULD |
| ETH-15 | Mode DTMF + TTS pelan/rendah untuk gangguan pendengaran | Akses | LATER |
| ETH-16 | Bahasa hormat (krama), tidak menggurui. Framing martabat & kemandirian di semua materi | Ageism, aturan lomba anti-diskriminasi | ✅ MUST |
| ETH-17 | Sinyal penelantaran/kekerasan diteruskan ke nakes, **bukan** ke keluarga | Konflik keluarga | LATER |
| ETH-18 | North-star pilot: frekuensi telepon keluarga **tidak boleh turun** | Pembuktian | Stage 2+ |

## 2. Privasi (acuan: UU No. 27/2022 tentang Pelindungan Data Pribadi)

| ID | Requirement | MVP? |
|---|---|---|
| PRV-01 | **Minimisasi data**: audio mentah tidak disimpan secara default | ✅ |
| PRV-02 | Fitur suara disimpan sebagai angka agregat, bukan sidik suara (voiceprint) | SHOULD |
| PRV-03 | Secrets & kredensial tidak pernah di-commit (`.env` di `.gitignore`) | ✅ |
| PRV-04 | MVP **hanya memakai data fiktif**. Uji dengan orang sungguhan (Stage 2) memakai lembar persetujuan | ✅ |
| PRV-05 | `family_codeword` tidak pernah tampil di UI web | ✅ |
| PRV-06 | Web Board IGD/Puskesmas tidak dipublikasikan tanpa proteksi (minimal kata sandi demo / link rahasia) | ✅ |
| PRV-07 | Kebijakan retensi tertulis (lihat [04](04_DATA_MODEL.md) §4) | ✅ (dokumen) |
| PRV-08 | Rencana produksi: DPIA, enkripsi, data di region Indonesia, data tidak dijual, asuransi hanya menerima agregat/atas consent | Roadmap (disebut di proposal) |

> **Catatan vendor:** ElevenLabs, OpenAI, Twilio, Meta, dan Supabase memproses data di luar Indonesia. Untuk MVP dengan data fiktif hal ini bisa diterima. Untuk produksi, ini menjadi alasan **mode sovereign** (roadmap).

## 3. Regulasi alat kesehatan berbasis software

**KMK No. HK.01.07/MENKES/951/2026** (ditetapkan 7 September 2026) tentang Pedoman Izin Edar Alat Kesehatan Berbasis Perangkat Lunak:
- AI (termasuk LLM) masuk kategori alat kesehatan **jika memiliki tujuan medis**. AI untuk administrasi dikecualikan.
- Ada mekanisme **regulatory sandbox** untuk produk yang bukti klinisnya untuk populasi Indonesia belum memadai.
- Sumber: ringkasan firma hukum/konsultan regulasi. **Teks resmi belum dibaca tim**, jadi verifikasi di JDIH Kemenkes (pertanyaan terbuka Q-12).

**Pemetaan modul TILIK:**
| Modul | Sifat | Jalur |
|---|---|---|
| Pendamping, pengingat obat, rapor keluarga, titip pesan, Daftar Tilik (administratif) | Non-medis / administratif | Tidak memerlukan izin edar alkes (dugaan, perlu konfirmasi) |
| Pemicu tanda bahaya, skrining stroke, analisis suara, pre-alert IGD | Berpotensi SaMD (tujuan medis: skrining/triase) | Regulatory sandbox bersama mitra RS + validasi klinis lokal |

**Prinsip produk:** TILIK adalah *decision support*. Keputusan klinis selalu di tangan tenaga kesehatan.

## 4. Etika lomba & produksi materi

| ID | Requirement |
|---|---|
| CMP-01 | Tidak memakai cuplikan, poster, atau tokoh film *Tilik* (hak cipta). Kata "tilik" boleh dipakai sebagai kata umum |
| CMP-02 | Nama Puskesmas/RS di demo: gunakan label "(simulasi)". Jangan mengesankan endorsement institusi yang belum menjadi mitra (pertanyaan terbuka Q-11) |
| CMP-03 | Semua angka statistik di proposal/deck diverifikasi ke sumber asli. Angka sekunder ditandai |
| CMP-04 | Slide **penggunaan AI** wajib (aturan lomba): AI di dalam produk + AI untuk pengembangan, riset, dan dokumentasi, masing-masing dengan perannya |
| CMP-05 | Tidak ada konten SARA, diskriminasi, atau framing lansia sebagai "beban" |
| CMP-06 | Source code karya asli tim. Library open-source dicantumkan dengan lisensinya |
| CMP-07 | **Demo tidak pernah memanggil 119 atau nomor RS sungguhan** (`DEMO_MODE` allowlist) |

## 5. Slide "Etika by Design" (untuk pitch deck)
Lihat draf di dokumen riset §8.3. Masukkan ke deck sebagai satu slide.
