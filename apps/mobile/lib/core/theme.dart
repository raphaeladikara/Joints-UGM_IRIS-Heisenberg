import 'package:flutter/material.dart';

/// Token warna KRING, palet "Daun & Tanah": krem kertas + hijau daun, terakota sebagai aksen hemat (60/30/10).
/// Semua teks di atas latar mana pun ≥ 4,5:1. Warna level (hijau/kuning/merah) hanya untuk makna level dan selalu
/// ditemani ikon dan teks (buta warna merah-hijau umum pada lansia pria).
abstract final class TColors {
  static const bg = Color(0xFFF7F3EA); // krem kertas
  static const panel = Color(0xFFFFFFFF);
  static const sunk = Color(0xFFEFE8DA); // pasir: isian tombol & track
  static const line = Color(0xFFE6DFD0); // garis / border kartu
  static const ink = Color(0xFF1E2A24); // hijau-hitam
  static const muted = Color(0xFF5F6B63); // abu hijau, teks kedua

  static const brand = Color(0xFF1F6B4F); // hijau daun
  static const brandDeep = Color(0xFF154D39); // hijau tua
  static const brandTint = Color(0xFFE2F0E8); // hijau muda
  static const skyBright = Color(0xFF9CC5B0); // hijau sedang: isi gauge & grafik
  static const clay = Color(0xFFC0623B); // terakota: aksen, sistolik

  // Gradien hero: terakota muda, hijau sedang, krem.
  static const apricot = Color(0xFFE9A27E);
  static const skyBlue = Color(0xFF9CC5B0);
  static const paper = Color(0xFFF7F3EA);

  // Ubin lembut. Teks di atasnya selalu `ink`; ikon memakai pasangan `*Ink`.
  static const sky = Color(0xFFE2F0E8);
  static const skyInk = Color(0xFF154D39);
  static const sage = Color(0xFFDDF1E4);
  static const sageInk = Color(0xFF1F6B4F);
  static const peach = Color(0xFFF7E4DA); // terakota tint
  static const peachInk = Color(0xFF9A4626);
  static const lavender = Color(0xFFEDEAE3); // abu hangat
  static const lavenderInk = Color(0xFF4C5750);
  static const butter = Color(0xFFFFF0C7);
  static const butterInk = Color(0xFF8A6100);

  static const green = Color(0xFF237A4B);
  static const greenTint = Color(0xFFDDF1E4);
  static const yellow = Color(0xFF8A6100); // teks kuning (kontras); isian kuning #D99A12
  static const yellowTint = Color(0xFFFFF0C7);
  static const red = Color(0xFFC0272D);
  static const redTint = Color(0xFFFDE2E1);
  static const grey = Color(0xFF5F6B63);
  static const greyTint = Color(0xFFEDEAE3);

  // Pil navigasi, kartu gelap & board IGD: hijau malam.
  static const night = Color(0xFF0F2E24);
  static const nightPanel = Color(0xFF173B2F);
  static const nightLine = Color(0xFF2A4A3E);
}

/// Layar ringkas: HP 9:16 (≈ 360×640 dp) atau lebar ≤ 380 dp. Dipakai untuk merapatkan jarak & mengecilkan grafik,
/// bukan untuk mengecilkan teks.
extension CompactX on BuildContext {
  bool get compact {
    final s = MediaQuery.sizeOf(this);
    return s.height < 720 || s.width < 380;
  }
}

abstract final class TShadow {
  /// Bayangan hijau yang sangat tipis: kartu putih terangkat di atas latar krem tanpa terlihat kotor.
  static const soft = [BoxShadow(color: Color(0x14274A3A), blurRadius: 28, offset: Offset(0, 10)), BoxShadow(color: Color(0x0C274A3A), blurRadius: 3, offset: Offset(0, 1))];
  static const lift = [BoxShadow(color: Color(0x26153A2C), blurRadius: 32, offset: Offset(0, 16))];
}

/// Nunito: sans membulat yang ramah. Judul & angka ExtraBold/Black, isi Medium/SemiBold.
abstract final class TText {
  static const _f = 'Nunito';
  static const display = TextStyle(fontFamily: _f, fontSize: 34, height: 1.08, fontWeight: FontWeight.w900, color: TColors.ink, letterSpacing: -0.6);
  static const h1 = TextStyle(fontFamily: _f, fontSize: 27, height: 1.15, fontWeight: FontWeight.w900, color: TColors.ink, letterSpacing: -0.4);
  static const h2 = TextStyle(fontFamily: _f, fontSize: 21, height: 1.2, fontWeight: FontWeight.w800, color: TColors.ink, letterSpacing: -0.2);
  static const h3 = TextStyle(fontFamily: _f, fontSize: 18, height: 1.25, fontWeight: FontWeight.w800, color: TColors.ink, letterSpacing: -0.2);
  static const body = TextStyle(fontFamily: _f, fontSize: 16.5, height: 1.45, fontWeight: FontWeight.w500, color: TColors.ink);
  static const small = TextStyle(fontFamily: _f, fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w500, color: TColors.muted);
  static const label = TextStyle(fontFamily: _f, fontSize: 13, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: TColors.muted);

  /// Angka besar di ubin metrik (angka tabular supaya tidak "menari" saat berubah).
  static const metric = TextStyle(
    fontFamily: _f,
    fontSize: 40,
    height: 1.0,
    fontWeight: FontWeight.w900,
    color: TColors.ink,
    letterSpacing: -1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: TColors.brand, primary: TColors.brand, surface: TColors.panel, error: TColors.red);
  final radius = BorderRadius.circular(18);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TColors.bg,
    fontFamily: 'Nunito',
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: TColors.brand,
      selectionColor: TColors.brand.withValues(alpha: 0.22),
      selectionHandleColor: TColors.brand,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: TColors.bg,
      foregroundColor: TColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TText.h2,
    ),
    cardTheme: CardThemeData(
      color: TColors.panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: TColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TColors.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(56, 56),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TColors.brandDeep,
        minimumSize: const Size(56, 52),
        side: const BorderSide(color: TColors.line, width: 1.5),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 16.5, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TColors.brandDeep,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    chipTheme: const ChipThemeData(
      labelStyle: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 14.5, color: TColors.ink),
      side: BorderSide(color: TColors.line),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: TColors.panel,
      indicatorColor: TColors.brandTint,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, fontSize: 13.5)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: TColors.night,
      contentTextStyle: const TextStyle(fontFamily: 'Nunito', fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TColors.bg,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: TColors.bg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TColors.panel,
      hintStyle: TText.body.copyWith(color: TColors.muted, fontWeight: FontWeight.w500),
      border: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: TColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: TColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: const BorderSide(color: TColors.brand, width: 2)),
    ),
  );
}

/// Level 3 warna (🟢/🟡/🔴) + status non-level (tidak diangkat, dijadwalkan, sedang berjalan).
class LevelStyle {
  const LevelStyle(this.label, this.fg, this.bg, this.icon);
  final String label;
  final Color fg;
  final Color bg;
  final IconData icon;

  static LevelStyle of(String? level) => switch (level) {
    'red' => const LevelStyle('Darurat', TColors.red, TColors.redTint, Icons.emergency_rounded),
    'yellow' => const LevelStyle('Tindak lanjut', TColors.yellow, TColors.yellowTint, Icons.error_outline_rounded),
    'green' => const LevelStyle('Aman', TColors.green, TColors.greenTint, Icons.check_circle_outline_rounded),
    'no_answer' => const LevelStyle('Tidak diangkat', TColors.grey, TColors.greyTint, Icons.phone_missed_rounded),
    'in_progress' => const LevelStyle('Sedang ditelepon', TColors.brand, TColors.brandTint, Icons.phone_in_talk_rounded),
    _ => const LevelStyle('Dijadwalkan', TColors.grey, TColors.greyTint, Icons.schedule_rounded),
  };
}
