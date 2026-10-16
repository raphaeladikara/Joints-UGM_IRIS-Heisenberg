# TILIK: sistem desain aplikasi

Pengguna: anak (sering di atas 40 tahun), kader/tetangga lansia, perawat Puskesmas. Dibaca di HP, sering di luar
ruangan atau di bawah lampu redup. Prinsipnya: teks besar, kontras tinggi, satu aksi utama per layar, warna tidak
pernah jadi satu-satunya pembawa makna.

## Warna (`lib/core/theme.dart` → `TColors`)
| Peran | Token | Nilai |
|---|---|---|
| Latar | `bg` | `#F4F1EA` krem kertas (tidak silau) |
| Teks | `ink` / `muted` | `#1B2330` / `#4D5868` (14:1 dan 6,6:1 di atas krem) |
| Merek & aksi | `brand` | `#2F5DA8` biru teduh, `brandDeep` `#1E3F7A` |
| Ubin pastel | `sky` `sage` `peach` `lavender` `butter` | teks di atasnya selalu `ink`, ikon memakai pasangan `*Ink` |
| Status | `green` `yellow` `red` | `#1F7A47` `#8A5A00` `#B3261E`, selalu dengan ikon + label |
| Pil navigasi, kartu sinkron, board IGD | `night` | `#141A24` |

Pemetaan ubin tetap: langkah = peach, tidur = lavender, detak jantung = sky, oksigen = sage (kuning bila rendah),
bahan obrolan = butter.

## Tipografi
Fredoka (judul, angka metrik dengan angka tabular) + Nunito (isi). Isi 17, kecil 14,5, label 13,5, metrik 40.
Tidak ada teks di bawah 12.

## Bentuk & kedalaman
Sudut 26 untuk panel/ubin, 30 untuk kartu utama, 18 untuk tombol dan input. Bayangan `TShadow.soft` (offset 8, blur
24) untuk panel di atas krem; ubin pastel tanpa bayangan. Tombol minimal 56 px tinggi, sentuhan minimal 48 px.

## Komponen
- `MetricTile`, `MiniBars`, `HeartLine`, `ActivityRings`, `BpGauge`, `PillNav` di `lib/core/health_widgets.dart`.
- `Body3D` di `lib/core/body3d.dart`: mesh prosedural (elipsoid, kapsul, loft badan), Lambert + cahaya tepi, titik
  status berdenyut (merah lebih cepat). Putaran otomatis berhenti bila pengguna mematikan animasi.
- Layar kesehatan keluarga di `lib/features/contact/health_views.dart`.

## Gerak
Satu bahasa gerak: masuk dengan `easeOutExpo` (cincin, gauge), pindah tab 280 ms `easeOutCubic`. Tubuh 3D punya
inersia geser dan berputar menghadapkan titik yang diketuk.
