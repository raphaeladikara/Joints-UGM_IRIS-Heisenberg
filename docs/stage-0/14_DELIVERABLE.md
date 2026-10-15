# 14 · Rencana Deliverable

Deliverable wajib dari panitia (lihat [`penjelasan_lomba.md`](../../penjelasan_lomba.md)): **video ≤ 2 menit, proposal A4 ≤ 10 halaman, pitch deck (wajib berisi penggunaan AI), repo GitHub + README, prototype.**
Tenggat internal: **18 Okt** (D-12). Tenggat resmi: Q-01.

---

## 1. Pemetaan ke rubrik

| Aspek (bobot) | Bukti di deliverable |
|---|---|
| Inovasi Solusi (25) | Deck: peta ATM + matriks pembeda + "first mile Code Stroke". Proposal §Inovasi |
| Implementasi Teknis (30) | Repo + README (arsitektur, cara menjalankan) + **tabel hasil evaluasi** + diagram |
| Fungsionalitas & Desain (20) | Video demo + screenshot Daftar Tilik/Board IGD/rapor WA + desain suara untuk lansia |
| Dampak & Kelayakan (15) | Data masalah, model biaya, jalur adopsi (Prolanis/RPPT, keluarga), regulasi (KMK 951/2026), etika |
| Presentasi & Demonstrasi (10) | Video + koreografi demo final |

## 2. Video ≤ 2 menit (storyboard)

| Detik | Visual | Audio/teks |
|---|---|---|
| 0–10 | Rumah di desa, HP di meja; lalu anak di kota sedang bekerja (footage sendiri) | "Kapan terakhir kamu menelepon ibumu?" |
| 10–25 | Kartu angka: stroke #1, hanya 1 dari 10 tiba tepat waktu, DIY provinsi paling tua | Narasi singkat |
| 25–55 | **Babak 1**: HP berdering → TILIK menyapa (disclosure + kata sandi) → pesan suara anak → obat/tensi → cerita | Audio panggilan asli |
| 55–65 | Rapor WA anak + "Bahan obrolan" + tombol telepon | "TILIK membuat anak lebih sering menelepon, bukan lebih jarang" |
| 65–100 | **Babak 2**: bicara pelo → skrining → HP Bu Tini & HP Mas Dika berdering → konferensi → Board IGD menyala → WA RS ber-CT | Audio panggilan asli + teks waktu |
| 100–112 | Tabel hasil evaluasi + diagram arsitektur singkat | |
| 112–120 | Logo TILIK + tagline | "Jalur cepat stroke dimulai dari rumah." |

- Tidak memakai cuplikan film *Tilik* (CMP-01).
- Kalau transport PSTN tidak tersedia (S-01), babak telepon direkam dengan **UI telepon WebRTC** dan disebut terang-terangan sebagai prototype.

## 3. Proposal A4 ≤ 10 halaman (outline)

| Hal | Isi |
|---|---|
| 1 | Cover: TILIK · tim IRIS-Heisenberg · tema Healthcare · subtema |
| 2 | Ringkasan eksekutif + latar belakang masalah (data) |
| 3 | Analisis masalah & pengguna (persona, jalur keterlambatan stroke, Prolanis/RPPT) |
| 4 | Solusi: Cegah–Deteksi–Arahkan + alur pengguna |
| 5 | Inovasi: peta ATM + matriks pembeda |
| 6 | Arsitektur teknis + teknologi (termasuk penggunaan AI) |
| 7 | Hasil prototype & evaluasi (tabel angka, screenshot) |
| 8 | Etika, privasi, regulasi (UU PDP, KMK 951/2026, Etika by Design) |
| 9 | Dampak, model bisnis, biaya, roadmap |
| 10 | Referensi |

## 4. Pitch deck (untuk submission + final 10–12 menit)

| # | Slide | Waktu (final) |
|---|---|---|
| 1 | Hook: "Kapan terakhir kamu telepon ibumu?" + DIY 17,83% lansia | 0:30 |
| 2 | Masalah: stroke #1, 16,5 jam vs 4,5 jam, lansia sendiri | 1:00 |
| 3 | Kenapa telepon (26% lansia internet) & kenapa sekarang | 0:30 |
| 4 | Solusi TILIK: Cegah–Deteksi–Arahkan | 0:45 |
| 5 | Peta ATM (CareCall, Emory, Polaris, Cordio, Code Stroke UGM) | 0:45 |
| 6 | **DEMO LIVE** (babak 1 & 2) | 4:00 |
| 7 | Arsitektur + constellation | 0:45 |
| 8 | Hasil evaluasi (angka) | 0:45 |
| 9 | **Etika by Design** | 0:45 |
| 10 | Dampak & model bisnis (Prolanis/RPPT, keluarga, asuransi) | 0:45 |
| 11 | Regulasi & jalur pilot (KMK 951/2026, sandbox, Code Stroke) | 0:30 |
| 12 | **Penggunaan AI** (wajib) | 0:30 |
| 13 | Roadmap + ajakan | 0:30 |

## 5. Slide penggunaan AI (wajib, CMP-04): isi dari log

Mulai catat **hari ini** di tabel ini, lalu salin ke deck:

| Tool AI | Dipakai untuk | Bagian proyek | Peran |
|---|---|---|---|
| OpenAI (model: S-04) | Agen percakapan, klasifikasi tanda bahaya, ekstraksi, pasien sintetis untuk evaluasi | Produk + evaluasi | Komponen produk |
| ElevenLabs Scribe | Speech-to-text | Produk | Komponen produk |
| ElevenLabs TTS | Text-to-speech | Produk | Komponen produk |
| *(isi oleh tim)* | Riset ide, analisis, dokumentasi | Pengembangan | Asisten |
| *(isi oleh tim)* | Coding assistant | Pengembangan | Asisten |
| *(isi oleh tim)* | Desain/visual | Pengembangan | Asisten |

## 6. README (wajib lomba: alur + cara menjalankan)

Isi akhir README (diperbarui di Stage 1):
1. Apa itu TILIK (1 paragraf) + demo video
2. Alur sistem (diagram)
3. Struktur repo
4. Prasyarat (akun, versi Python/Node)
5. Cara menjalankan: setup `.env` → database (migration + seed) → server suara + tunnel → web → memulai panggilan demo
6. Cara menjalankan evaluasi + hasil terakhir
7. Keterbatasan & etika (data fiktif, draf klinis, DEMO_MODE)
8. Lisensi & pihak ketiga

## 7. Koreografi demo Grand Final (Stage 2)
Mengacu pada 6 momen WOW di [`docs/research/Ideas_Breakdown_v4_FINAL.md`](../research/Ideas_Breakdown_v4_FINAL.md) §3, disesuaikan dengan fitur yang benar-benar jadi. Checklist H-1:
- [ ] Kredit ElevenLabs ≥ cadangan
- [ ] Supabase aktif
- [ ] Nomor demo terverifikasi & HP terisi baterai
- [ ] Laptop server + cadangan siap, tunnel diuji di jaringan lokasi
- [ ] Video cadangan per babak di laptop presentasi (offline)

## 8. Bank jawaban QnA
Lihat [`docs/research/Ideas_Breakdown_v3.md`](../research/Ideas_Breakdown_v3.md) §9, [`v4`](../research/Ideas_Breakdown_v4_FINAL.md) §11, dan [`audit etika`](../research/TILIK_Celah_Etika_dan_Defense.md) §8.4.
