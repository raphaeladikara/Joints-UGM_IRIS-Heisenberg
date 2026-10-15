# 13 · Konvensi Repo

## 1. Struktur folder (rencana)

```
Joints-UGM_IRIS-Heisenberg/
├── README.md                  # Ringkasan, alur, cara menjalankan (wajib lomba)
├── penjelasan_lomba.md        # Ringkasan ketentuan lomba
├── .env.example               # Daftar variabel lingkungan (tanpa nilai)
├── .gitignore
├── docs/
│   ├── stage-0/               # Dokumen persiapan (charter, PRD, arsitektur, …)
│   └── research/              # Riset ide v1–v4 + audit etika
├── apps/
│   ├── voice/                 # Server suara Python (Pipecat, dialog manager, safety, eskalasi)
│   └── web/                   # Next.js: Daftar Tilik, Board IGD, konsol demo, webhook WA
├── supabase/
│   ├── migrations/            # Skema SQL
│   └── seed/                  # Data persona fiktif, RS, waktu tempuh
├── content/                   # Skrip percakapan, aturan tanda bahaya, template WA (sumber tunggal)
├── eval/                      # Harness evaluasi, persona, laporan
├── analysis/                  # Analisis suara offline (SHOULD)
└── spikes/                    # Catatan/arsip spike Stage 0 (bukan kode produk)
```

> Folder `apps/`, `supabase/`, `content/`, `eval/`, `analysis/`, dan `spikes/` dibuat di Stage 1, saat kodenya mulai ditulis.

## 2. Branch
| Branch | Fungsi |
|---|---|
| `main` | Selalu bisa dijalankan. Yang disubmit ke juri |
| `ws<N>/<deskripsi-singkat>` | Pekerjaan per workstream, misal `ws1/twilio-stream`, `ws2/safety-agent` |

- Merge ke `main` setelah jalan di lokal dan tidak merusak skenario harness yang relevan.
- **Freeze `main` 18 Okt siang** (lihat [08](08_ROADMAP.md)). Setelah itu hanya perbaikan bug.

## 3. Pesan commit
Format: `<tipe>(<area>): <ringkasan bahasa Indonesia>`

| Tipe | Kapan |
|---|---|
| `feat` | Fitur baru |
| `fix` | Perbaikan bug |
| `docs` | Dokumen |
| `content` | Skrip/aturan/template percakapan |
| `eval` | Harness/persona/laporan evaluasi |
| `chore` | Konfigurasi, dependensi |

Contoh: `feat(voice): sambungkan Twilio Media Streams ke pipeline Pipecat`

**Tidak memakai trailer co-author** apa pun selain anggota tim (D-07).

## 4. Secrets
- Nilai rahasia **hanya** di `.env` lokal / environment variable hosting. `.env` sudah ada di `.gitignore`.
- Sebelum push, cek `git diff --staged` untuk memastikan tidak ada kunci.
- Kalau kunci terlanjur ter-commit: **rotasi kunci segera** (menghapus commit tidak cukup karena repo publik).

## 5. Bahasa
- Dokumen: Bahasa Indonesia (D-08).
- Kode (D-32):
  - Nama variabel, fungsi, kelas, file, tabel/kolom database: **bahasa Inggris** (`log_blood_pressure`, `call_sessions`).
  - Komentar & docstring: **bahasa Indonesia**.
  - Konten percakapan (skrip, template WA): Indonesia/Jawa, disimpan di `content/`, bukan di-hardcode di kode.

## 6. Tooling (diputuskan saat S-08)
| Kebutuhan | Kandidat | Status |
|---|---|---|
| Manajer environment Python | `uv` (dipakai di dokumentasi Pipecat) atau `venv` + `pip` | Diputuskan di S-08 |
| Manajer paket web | `npm` / `pnpm` | Diputuskan di S-08 |
| Format/lint | `ruff` (Python), `eslint` + `prettier` (web) | Usulan |

## 7. Lisensi
- Lisensi repo: **belum diputuskan** (Q-18). Catatan: repo publik tanpa lisensi berarti hak cipta penuh tetap pada tim.
- Lisensi library pihak ketiga dicatat di README (CMP-06).
