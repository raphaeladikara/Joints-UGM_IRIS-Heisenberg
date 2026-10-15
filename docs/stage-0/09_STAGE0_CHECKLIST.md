# 09 · Checklist Stage 0: Persiapan Sebelum Menulis Kode

Stage 0 dianggap selesai (**Gate G0**) kalau semua item bertanda ⭐ sudah dicentang dan keputusan dari setiap spike sudah dicatat di [12_KEPUTUSAN_DAN_PERTANYAAN.md](12_KEPUTUSAN_DAN_PERTANYAAN.md).

> Spike = percobaan kecil sekali pakai untuk menjawab satu pertanyaan teknis. Kode spike **tidak** masuk ke `main` sebagai kode produk. Simpan catatan hasilnya saja (atau taruh di `spikes/` kalau perlu diarsipkan).

---

## A. Administrasi lomba
- [ ] ⭐ Tanyakan ke CP/Discord: **jam & tanggal resmi tutup submission** dan **cara submit** (form/link/email) → Q-01
- [ ] ⭐ Pastikan tema **Healthcare** sudah dikonfirmasi ke panitia → Q-02
- [ ] Tanyakan apakah subtema harus dipilih persis dari daftar → Q-03
- [ ] Pastikan repo `raphaeladikara/Joints-UGM_IRIS-Heisenberg` adalah repo resmi submission. Semua anggota yang akan push punya akses write

## B. Akun & kredensial (WS-10)
| Akun | Status saat ini | Yang harus dilakukan | ⭐ |
|---|---|---|---|
| Twilio | Ada (trial, raphael.adikara@gmail.com) | Cek **saldo trial tersisa**. Catat Account SID. Buat **API Key** (lebih aman dari auth token). Catat nomor trial yang diberikan | ⭐ |
| ElevenLabs | Ada | Pastikan plan **Starter** aktif. Catat **tanggal reset kredit** & sisa kredit (Q-05). Buat API key | ⭐ |
| OpenAI | Ada | Buat API key project khusus TILIK. Set **batas pemakaian (usage limit)** di dashboard supaya tidak kebobolan biaya | ⭐ |
| Meta (WhatsApp Cloud API) | **Belum diketahui** | Buat/memakai Meta Developer App → produk WhatsApp → nomor tes. Daftarkan nomor penerima (maksimal sesuai batas nomor tes). Siapa pemilik akun Meta → Q-09 | ⭐ |
| Supabase | Belum diketahui | Buat project (free tier, region terdekat yang tersedia) | ⭐ |
| Vercel | Belum diketahui | Hubungkan ke repo (Hobby) | |
| Cloudflare | Tidak perlu akun untuk Quick Tunnel | Install `cloudflared` di laptop server | ⭐ |
| GitHub | Repo ada | Pastikan akun yang push (Mikael Adikara) punya akses write | ⭐ |

- [ ] ⭐ Semua kunci disimpan di **password manager / catatan privat tim**, bukan di chat grup terbuka dan **bukan di repo**
- [ ] ⭐ Salin [`.env.example`](../../.env.example) menjadi `.env` lokal di laptop server

## C. Nomor telepon untuk demo (Twilio trial: maksimal 5 nomor terverifikasi)
| Peran | Nomor milik | Status verifikasi |
|---|---|---|
| Bu Sri (pasien) | ? → Q-06 | [ ] |
| Mas Dika (anak, HP di meja juri) | ? | [ ] |
| Bu Tini (Sahabat Tilik) | ? | [ ] |
| Cadangan 1 | ? | [ ] |
| Cadangan 2 | ? | [ ] |

- [ ] ⭐ Verifikasi nomor di Twilio Console → Verified Caller IDs (via SMS)
- [ ] Siapkan HP jadul untuk peran Bu Sri (properti demo, opsional untuk MVP, wajib untuk final) → Q-14

## D. Spike teknis
Setiap spike: jalankan, catat hasil di tabel, ambil keputusan.

### S-01 ⭐ Twilio trial bisa menelepon nomor +62 terverifikasi?
- **Cara:** buat panggilan keluar dari nomor trial ke 1 nomor tim terverifikasi dengan TwiML sederhana (`<Say>`).
- **Catat:** tersambung? pesan trial terdengar? durasi maksimal? biaya per menit di log? kualitas suara?
- **Keputusan:** lolos → transport utama PSTN. Gagal → transport utama **WebRTC fallback** (PSTN hanya untuk final kalau ada perubahan budget, yang merupakan keputusan tim).

### S-02 ⭐ ElevenLabs TTS: model & suara
- **Cara:** generate 5 kalimat skrip (3 ID, 2 JV) dengan model kandidat: `eleven_v3` (mendukung Jawa) dan model latensi rendah yang tersedia di akun. Uji juga output format **μ-law 8000** untuk Twilio.
- **Catat:** kualitas (dengarkan bersama), waktu sampai byte pertama, **kredit yang terpakai per karakter** (cek dashboard usage), dukungan streaming.
- **Pilih suara:** 3–5 kandidat dari library, pilih yang hangat, jelas, tempo pelan. **Jangan memakai suara yang meniru orang sungguhan.**
- **Keputusan:** model untuk kalimat dinamis + model untuk frasa statis (boleh beda, asal suaranya konsisten) + voice ID.
- **Hemat:** total ≤ ±1.500 karakter untuk spike ini.

### S-03 ⭐ ElevenLabs Scribe (STT realtime)
- **Cara:** rekam 5 kalimat bahasa Indonesia + 3 kalimat bahasa Jawa (suara anggota tim, idealnya juga 1 suara orang tua dengan izin) → konversi ke 8 kHz μ-law → kirim ke Scribe realtime.
- **Catat:** apakah bahasa Indonesia & Jawa ada di daftar bahasa yang didukung (cek dokumentasi resmi), akurasi kasar (WER manual), latensi, kredit terpakai.
- **Keputusan:** kode bahasa yang dipakai (`id`, atau auto-detect), dan apakah Jawa realistis di MVP.

### S-04 ⭐ Pilih model OpenAI
- **Cara:** daftar model yang tersedia di akun (`GET /v1/models`). Uji 2–3 kandidat termurah yang mendukung tool calling + streaming pada 5 giliran persona (P-01, P-07, P-12, P-13, P-14).
- **Catat:** tool call benar? guardrail dipatuhi? TTFT p50? perkiraan biaya per panggilan (token masuk/keluar × harga di halaman pricing resmi)?
- **Keputusan:** `OPENAI_MODEL_DIALOG` (percakapan) dan `OPENAI_MODEL_CLASSIFIER` (klasifikasi/ekstraksi/pasien sintetis). Pilih **yang termurah yang lolos**.

### S-05 ⭐ Konferensi di Twilio trial
- **Cara:** panggilan A berjalan → alihkan ke `<Dial><Conference>` → panggil B dengan `<Play>` briefing lalu masuk konferensi yang sama.
- **Catat:** berhasil di trial? pesan trial muncul untuk tiap peserta? jeda?
- **Keputusan:** desain eskalasi tetap (lihat [03](03_ARSITEKTUR_TEKNIS.md) §2.4) atau disederhanakan.
- *Bergantung pada S-01.*

### S-06 WhatsApp Cloud API
- **Cara:** kirim teks dari nomor tes ke nomor tim. Terima webhook pesan teks & pesan suara (via tunnel/endpoint sementara). Unduh media pesan suara.
- **Catat:** aturan jendela 24 jam & kebutuhan template untuk pesan yang dimulai bisnis, batas nomor penerima nomor tes, biaya (harus 0 untuk skenario demo).
- **Keputusan:** alur rapor & alert (apakah anak perlu mengirim pesan dulu supaya jendela 24 jam terbuka).

### S-07 Tunnel + WebSocket
- **Cara:** jalankan contoh Pipecat Twilio di laptop + `cloudflared` Quick Tunnel → panggil.
- **Catat:** stabil? latensi tambahan?
- **Keputusan:** tunnel final (Cloudflare Quick Tunnel atau alternatif gratis lain).

### S-08 ⭐ Lingkungan pengembangan laptop server
- **Catat:** OS & versi, versi Python (Pipecat butuh Python modern; cek persyaratan versi di dokumentasi resmi), Node.js untuk web → Q-10
- **Keputusan:** laptop mana yang menjadi server suara saat demo.

### Tabel hasil spike
| Spike | Tanggal | Hasil | Keputusan | Kredit/biaya terpakai |
|---|---|---|---|---|
| S-01 | | | | |
| S-02 | | | | |
| S-03 | | | | |
| S-04 | | | | |
| S-05 | | | | |
| S-06 | | | | |
| S-07 | | | | |
| S-08 | | | | |

## E. Konten (WS-7)
- [ ] ⭐ Skrip state MVP final (ID + frasa JV) dari draf [05](05_DESAIN_PERCAKAPAN.md)
- [ ] ⭐ Daftar aturan tanda bahaya MVP (draf, diberi label "belum direview nakes" kalau reviewer belum ada → Q-08)
- [ ] Validasi frasa Jawa ke penutur asli → Q-07
- [ ] ⭐ Persona seed (Bu Sri dkk.) + kata sandi keluarga demo
- [ ] Teks briefing konferensi + template WA (rapor 🟢/🟡, alert 🔴)
- [ ] Pustaka edukasi SeGeRa Ke RS (min. 6 kalimat bergilir)

## F. Data RS & waktu tempuh
- [ ] ⭐ Verifikasi **CT-scan 24 jam** untuk: RSUD Wonosari, RS Saptosari, RS Panti Rahayu, RS Akademik UGM, RSUP Dr. Sardjito → Q-13
- [ ] Pilih 2–3 desa demo di Gunungkidul. Hitung waktu tempuh manual (peta) ke tiap RS, lalu catat sumber dan tanggalnya
- [ ] Putuskan label nama institusi di demo ("(simulasi)") → Q-11

## G. Repo (WS-10)
- [x] Struktur dokumen `docs/stage-0`, `docs/research`
- [x] `.gitignore` (secrets, venv, node_modules, rekaman)
- [x] `.env.example` (nama variabel saja, tanpa nilai)
- [ ] Sepakati konvensi branch & commit ([13](13_KONVENSI_REPO.md))

## H. Persiapan deliverable (WS-9)
- [ ] Mulai **log penggunaan AI** (tool apa, untuk apa) sejak hari ini. Ini wajib untuk deck → lihat [14](14_DELIVERABLE.md)
- [ ] Outline proposal (≤ 10 halaman) & outline deck disepakati
- [ ] Storyboard video ≤ 2 menit disepakati

## I. Gate G0
G0 lolos jika:
1. S-01, S-02, S-03, S-04, S-08 selesai dan keputusannya tercatat.
2. Semua akun ⭐ siap, `.env` lokal terisi.
3. Nomor demo terverifikasi.
4. Skrip & aturan MVP (draf) siap.
5. Pertanyaan terbuka yang memblokir (Q-01, Q-06) sudah terjawab atau ada keputusan sementara yang **disetujui tim**.
