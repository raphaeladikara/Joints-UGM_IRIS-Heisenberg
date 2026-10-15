# TILIK

> **Jalur cepat stroke dimulai dari rumah Mbah, bukan dari pintu IGD.**

TILIK adalah agen suara AI yang setiap pagi menelepon lansia penderita hipertensi lewat **telepon biasa** (tanpa aplikasi, tanpa internet). TILIK mengecek obat, tensi, dan gejala, lalu menyaring tanda stroke saat itu juga. Kalau ada tanda bahaya, TILIK menggerakkan tetangga, anak, dan IGD dengan informasi jam onset. Di hari-hari biasa, TILIK memberi anak bahan obrolan supaya mereka lebih sering menelepon orang tuanya.

**Tim IRIS-Heisenberg** · Hackathon JOINTS x INSPIRE 2026 · Tema **Healthcare**

---

## Status: Stage 0 (persiapan)

Repo ini **belum berisi kode produk**. Saat ini isinya dokumen persiapan: blueprint, roadmap, keputusan, dan checklist yang harus selesai sebelum kode ditulis.

| Stage | Periode | Status |
|---|---|---|
| Stage 0: Persiapan | 15 Okt 2026 | 🟡 Berjalan |
| Stage 1: MVP | 16–18 Okt 2026 | ⏳ |
| Stage 2: Menuju Grand Final | 19–31 Okt 2026 | ⏳ |
| Grand Final | 1 Nov 2026 | ⏳ |

## Cara membaca repo ini

Kalau baru bergabung, baca dengan urutan ini:
1. [Project Charter](docs/stage-0/01_PROJECT_CHARTER.md): masalah, solusi, scope, batasan
2. [Checklist Stage 0](docs/stage-0/09_STAGE0_CHECKLIST.md): yang harus dikerjakan **sekarang**
3. [Keputusan & Pertanyaan Terbuka](docs/stage-0/12_KEPUTUSAN_DAN_PERTANYAAN.md): yang sudah diputuskan & yang belum
4. [Roadmap & Job Breakdown](docs/stage-0/08_ROADMAP.md): rencana harian per workstream

### Dokumen Stage 0 lengkap
| No | Dokumen |
|---|---|
| 01 | [Project Charter](docs/stage-0/01_PROJECT_CHARTER.md) |
| 02 | [PRD: fitur & acceptance criteria](docs/stage-0/02_PRD.md) |
| 03 | [Arsitektur Teknis](docs/stage-0/03_ARSITEKTUR_TEKNIS.md) |
| 04 | [Data Model](docs/stage-0/04_DATA_MODEL.md) |
| 05 | [Desain Percakapan & Keselamatan Klinis](docs/stage-0/05_DESAIN_PERCAKAPAN.md) |
| 06 | [Etika, Privasi & Regulasi](docs/stage-0/06_ETIKA_PRIVASI_REGULASI.md) |
| 07 | [Rencana Evaluasi](docs/stage-0/07_EVALUASI.md) |
| 08 | [Roadmap & Job Breakdown](docs/stage-0/08_ROADMAP.md) |
| 09 | [Checklist Stage 0](docs/stage-0/09_STAGE0_CHECKLIST.md) |
| 10 | [Anggaran & Kuota](docs/stage-0/10_ANGGARAN_KUOTA.md) |
| 11 | [Register Risiko](docs/stage-0/11_RISIKO.md) |
| 12 | [Keputusan & Pertanyaan Terbuka](docs/stage-0/12_KEPUTUSAN_DAN_PERTANYAAN.md) |
| 13 | [Konvensi Repo](docs/stage-0/13_KONVENSI_REPO.md) |
| 14 | [Rencana Deliverable](docs/stage-0/14_DELIVERABLE.md) |
| 15 | [Defense Bank: pertanyaan sulit juri & jawabannya](docs/stage-0/15_DEFENSE_BANK.md) |

### Riset
| Dokumen | Isi |
|---|---|
| [Ideas Breakdown v1](docs/research/Ideas_Breakdown.md) | Penilaian ide awal (penerjemah BISINDO) |
| [Ideas Breakdown v2](docs/research/Ideas_Breakdown_v2.md) | Pencarian ide 95+ dan lahirnya TILIK |
| [Ideas Breakdown v3](docs/research/Ideas_Breakdown_v3.md) | Cek kebaruan global + optimasi rubrik |
| [Ideas Breakdown v4 (FINAL)](docs/research/Ideas_Breakdown_v4_FINAL.md) | ATM, momen WOW, plafon teknis |
| [Audit Celah Etika & Defense](docs/research/TILIK_Celah_Etika_dan_Defense.md) | 22 celah + pembelaannya |
| [Ringkasan ketentuan lomba](penjelasan_lomba.md) | Timeline, deliverable, rubrik |

## Stack (rencana)
Pipecat (Python) · ElevenLabs (Scribe STT + TTS) · OpenAI · Twilio · WhatsApp Cloud API · Supabase · Next.js. Detail dan alasannya ada di [03_ARSITEKTUR_TEKNIS.md](docs/stage-0/03_ARSITEKTUR_TEKNIS.md).

## Cara menjalankan
*Akan diisi di Stage 1.* Ringkasan rencananya ada di [14_DELIVERABLE.md §6](docs/stage-0/14_DELIVERABLE.md).

## Catatan penting
- Semua data di prototype adalah **data fiktif**.
- Aturan klinis masih **draf** dan belum direview tenaga kesehatan.
- Mode demo **tidak pernah** menelepon 119 atau nomor RS sungguhan.
