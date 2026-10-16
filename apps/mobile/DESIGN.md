# TILIK: sistem desain aplikasi

Pengguna: anak (sering di atas 40 tahun), kader/tetangga lansia, perawat Puskesmas. Dibaca di HP, sering di luar
ruangan atau di bawah lampu redup. Prinsipnya: teks besar, kontras tinggi, satu aksi utama per layar, warna tidak
pernah jadi satu-satunya pembawa makna.

## Warna (`lib/core/theme.dart` → `TColors`)
| Peran | Token | Nilai |
|---|---|---|
| Latar | `bg` | `#F5F8FC` putih kebiruan (tidak silau), panel `#FFFFFF` |
| Teks | `ink` / `muted` | `#0E1A2B` / `#536179` (16:1 dan 6:1) |
| Merek & aksi | `brand` | `#1A6CE0` biru bersih (5:1 di atas putih), `brandDeep` `#0B4DB0` |
| Gradien Pipo | `apricot` `skyBlue` `paper` | `#E6B093` `#A3CEFF` `#FAF9EF`, hanya di hero (`PipoBackground`, `lib/core/pipo.dart`) |
| Ubin pastel | `sky` `sage` `peach` `lavender` `butter` | teks di atasnya selalu `ink`, ikon memakai pasangan `*Ink` |
| Status | `green` `yellow` `red` | `#1F7A47` `#8A5A00` `#C4261D`, selalu dengan ikon + label |
| Pil navigasi, kartu sinkron, board IGD | `night` | `#0E1A2B` |

Pemetaan ubin tetap: langkah = peach, tidur = lavender, detak jantung = sky, oksigen = sage (kuning bila rendah),
bahan obrolan = butter.

## Tipografi
Plus Jakarta Sans (OFL, desainer Indonesia) untuk semuanya: judul & angka 800 dengan tracking rapat, isi 500.
Isi 16,5, kecil 14,5, label 13, metrik 40 (angka tabular).
Tidak ada teks di bawah 12.

## Bentuk & kedalaman
Sudut 26 untuk panel/ubin, 30 untuk kartu utama, 18 untuk tombol dan input. Bayangan `TShadow.soft` (offset 8, blur
28) bernuansa biru untuk panel di atas latar putih; ubin pastel tanpa bayangan. Tombol minimal 56 px tinggi, sentuhan minimal 48 px.

## Komponen
- `MetricTile`, `MiniBars`, `HeartLine`, `ActivityRings`, `BpGauge`, `PillNav` di `lib/core/health_widgets.dart`.
- `Body3D` di `lib/core/body3d.dart`: mesh prosedural lansia sesuai `sex` pasien. Pria: peci, kemeja batik biru,
  celana, tongkat. Wanita: sanggul uban, kebaya biru muda, kain jarik navy. Warna bahan per verteks × Lambert +
  cahaya tepi biru; titik status berdenyut (merah lebih cepat). Putaran otomatis berhenti bila pengguna mematikan animasi.
- `DoctorCard` / `DoctorCallScreen` (`lib/features/contact/doctor.dart`) dan `DoctorInbox` (Puskesmas).
- Layar kesehatan keluarga di `lib/features/contact/health_views.dart`.

## Gerak
Satu bahasa gerak: masuk dengan `easeOutExpo` (cincin, gauge), pindah tab 280 ms `easeOutCubic`. Tubuh 3D punya
inersia geser dan berputar menghadapkan titik yang diketuk.
