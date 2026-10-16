# KRING: sistem desain aplikasi

Pengguna: anak (sering di atas 40 tahun), kader/tetangga lansia, perawat Puskesmas. Dibaca di HP, sering di luar
ruangan atau di bawah lampu redup. Prinsipnya: teks besar, kontras tinggi, satu aksi utama per layar, warna tidak
pernah jadi satu-satunya pembawa makna.

## Logo
Piringan telepon putar (rotary dial) timbul di kotak hijau bergradien: piringan krem, sembilan lubang jari hijau dan
satu lubang terakota, poros terakota, penahan jari terakota. Dibangun `tool/make_icon.py` → ikon Android/web,
`assets/kring_icon_512.png` (dipakai di layar awal), dan `docs/brand/` (ikon 1024, piringan saja, lockup + "KRING").

## Warna: palet "Daun & Tanah" (`lib/core/theme.dart` → `TColors`)
Proporsi 60/30/10: krem & putih, hijau, terakota (hemat, hanya aksen).
| Peran | Token | Nilai |
|---|---|---|
| Latar | `bg` / `panel` / `sunk` / `line` | krem kertas `#F7F3EA`, putih `#FFFFFF`, pasir `#EFE8DA`, garis `#E6DFD0` |
| Teks | `ink` / `muted` | hijau-hitam `#1E2A24` / abu hijau `#5F6B63` |
| Merek & aksi | `brand` / `brandDeep` / `brandTint` | hijau daun `#1F6B4F`, hijau tua `#154D39`, hijau muda `#E2F0E8` |
| Aksen | `clay` / `apricot` | terakota `#C0623B`, terakota muda `#E9A27E` (angka & cincin di kartu gelap) |
| Gradien hero | `apricot` `skyBlue` `paper` | `#E9A27E` `#9CC5B0` `#F7F3EA`, hanya di hero (`PipoBackground`) |
| Ubin lembut | `sky` `sage` `peach` `lavender` `butter` | hijau muda, hijau tint, terakota tint `#F7E4DA`, abu hangat `#EDEAE3`, kuning tint |
| Status (hanya makna level) | `green` `yellow` `red` | `#237A4B` / `#DDF1E4`, isi `#D99A12` teks `#8A6100` / `#FFF0C7`, `#C0272D` / `#FDE2E1`; selalu dengan ikon + label |
| Pil navigasi, kartu gelap, HP Mbah, board IGD | `night` | hijau malam `#0F2E24`, panel `#173B2F` |

Pemetaan ubin tetap: langkah = peach, tidur = lavender, detak jantung = sky, oksigen = sage (kuning bila rendah),
bahan obrolan = butter.

## Tipografi
Nunito (OFL) untuk semuanya: judul & angka Black/ExtraBold (900/800), isi Medium/SemiBold (500/600). Bobot statis
dibuat dari font variabel Google Fonts. Isi 16,5, kecil 14,5, label 13, metrik 40 (angka tabular).
Tidak ada teks di bawah 12.

## Bentuk & kedalaman
Sudut 26 untuk panel/ubin, 30 untuk kartu utama, 18 untuk tombol dan input. Bayangan `TShadow.soft` (offset 8, blur
28) bernuansa hijau untuk panel di atas latar krem; ubin pastel tanpa bayangan. Tombol minimal 56 px tinggi, sentuhan minimal 48 px.

## Komponen
- `MetricTile`, `MiniBars`, `HeartLine`, `ActivityRings`, `BpGauge`, `PillNav` di `lib/core/health_widgets.dart`.
- `Human3D` di `lib/core/human3d.dart`: model GLB lansia bergaya kartun senada Kiki (nenek: kebaya
  kutubaru hijau muda, jarik kawung, sanggul uban, kacamata; kakek: peci, kemeja batik parang hijau tua, sarung terakota), dibangun
  `tool/build_toon_elder_glb.py` tanpa aset pihak ketiga; titik organ ikut dihitung ke `assets/models/anchors.json`) di `<model-viewer>` (WebView, offline). Titik
  status = hotspot berdenyut; ketuk → panel detail, kamera menghadap titik. Desktop jatuh ke `Body3D` prosedural.
- Maskot **Kiki** (burung kutilang hijau daun berpipi terakota, `lib/core/mascot.dart`): ekspresi mengikuti status (senang/cemas/siaga/ngantuk),
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
