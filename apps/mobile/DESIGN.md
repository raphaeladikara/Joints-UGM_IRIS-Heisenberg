# KRING: sistem desain aplikasi

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
- `Human3D` di `lib/core/human3d.dart`: model GLB lansia realistis (MakeHuman CC0, dibangun `tool/build_elder_glb.py`,
  titik organ dari `tool/glb_anchors.py` → `assets/models/anchors.json`) di `<model-viewer>` (WebView, offline). Titik
  status = hotspot berdenyut; ketuk → panel detail, kamera menghadap titik. Desktop jatuh ke `Body3D` prosedural.
- Maskot **Kiki** (burung kutilang biru, `lib/core/mascot.dart`): ekspresi mengikuti status (senang/cemas/siaga/ngantuk),
  dipakai di hero, kartu pasien, jadwal obat, layar kosong, dan rapor (`TiliSays`).
- Fitur keluarga di `lib/features/contact/care_views.dart`: `StreakBar` (🔥 obat rutin, 💙 telepon/minggu), `SummaryCard`
  (kartu gelap + cincin skor sehat, ala kartu "Summary"), `IntakeCard` (gelas air + takaran garam), `MedsView` (jam
  obat ala fasting tracker, stok, kalender 30 hari), `MonthlyReportPage` (tren tensi 30 hari, salin ringkasan dokter).
- Menu rendah garam di `lib/features/contact/recipes.dart` (filter ala aplikasi resep, kirim resep lewat titip pesan).
- `DoctorCard` / `DoctorCallScreen` (`lib/features/contact/doctor.dart`) dan `DoctorInbox` (Puskesmas).
- Layar kesehatan keluarga di `lib/features/contact/health_views.dart`.

## Gerak
Satu bahasa gerak: masuk dengan `easeOutExpo` (cincin, gauge), pindah tab 280 ms `easeOutCubic`. Tubuh 3D punya
inersia geser dan berputar menghadapkan titik yang diketuk.
