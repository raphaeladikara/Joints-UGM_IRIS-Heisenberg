import 'package:flutter/material.dart';

/// Token warna KRING: putih bersih + biru langit, dengan aksen aprikot dari gradien "Pipo" (lihat [PipoBackground]).
/// Semua teks di atas latar mana pun ≥ 4,5:1. Warna level selalu ditemani ikon dan teks, tidak pernah jadi
/// satu-satunya pembawa makna (buta warna merah-hijau umum pada lansia pria).
abstract final class TColors {
  static const bg = Color(0xFFF5F8FC); // putih kebiruan, tidak silau
  static const panel = Color(0xFFFFFFFF);
  static const sunk = Color(0xFFEDF2F8); // isian tombol & track
  static const line = Color(0xFFE1E8F1);
  static const ink = Color(0xFF0E1A2B); // hampir hitam, 16:1
  static const muted = Color(0xFF536179); // teks kedua, 6:1 di atas bg

  static const brand = Color(0xFF1A6CE0); // biru bersih, 5:1 di atas putih
  static const brandDeep = Color(0xFF0B4DB0);
  static const brandTint = Color(0xFFE6F0FF);
  static const skyBright = Color(0xFF5BB4FF); // isi gauge & grafik
  static const clay = Color(0xFFC0623A); // sistolik, aksen hangat

  // Gradien Pipo (21st.dev): aprikot, biru langit, kertas.
  static const apricot = Color(0xFFE6B093);
  static const skyBlue = Color(0xFFA3CEFF);
  static const paper = Color(0xFFFAF9EF);

  // Ubin pastel. Teks di atasnya selalu `ink`; ikon memakai pasangan `*Ink`.
  static const sky = Color(0xFFE6F0FF);
  static const skyInk = Color(0xFF0B4DB0);
  static const sage = Color(0xFFE3F4EA);
  static const sageInk = Color(0xFF1F6A3E);
  static const peach = Color(0xFFFBEDE4);
  static const peachInk = Color(0xFF8E3F1C);
  static const lavender = Color(0xFFECEBFB);
  static const lavenderInk = Color(0xFF4B3C8C);
  static const butter = Color(0xFFFFF5D6);
  static const butterInk = Color(0xFF6E5300);

  static const green = Color(0xFF1F7A47);
  static const greenTint = Color(0xFFDFF3E7);
  static const yellow = Color(0xFF8A5A00);
  static const yellowTint = Color(0xFFFFF1CC);
  static const red = Color(0xFFC4261D);
  static const redTint = Color(0xFFFDE5E2);
  static const grey = Color(0xFF536179);
  static const greyTint = Color(0xFFEBEFF5);

  // Pil navigasi & board IGD (gelap, dibaca dari jauh).
  static const night = Color(0xFF0E1A2B);
  static const nightPanel = Color(0xFF1A2638);
  static const nightLine = Color(0xFF2C3A50);
}

abstract final class TShadow {
  /// Bayangan biru yang sangat tipis: kartu putih terangkat di atas latar putih tanpa terlihat kotor.
  static const soft = [BoxShadow(color: Color(0x120E3A7A), blurRadius: 28, offset: Offset(0, 10)), BoxShadow(color: Color(0x0A0E3A7A), blurRadius: 3, offset: Offset(0, 1))];
  static const lift = [BoxShadow(color: Color(0x220E2A5A), blurRadius: 32, offset: Offset(0, 16))];
}

/// Plus Jakarta Sans: grotesk tegas buatan desainer Indonesia. Judul & angka tebal (800), isi 500.
abstract final class TText {
  static const _f = 'Jakarta';
  static const display = TextStyle(fontFamily: _f, fontSize: 34, height: 1.08, fontWeight: FontWeight.w800, color: TColors.ink, letterSpacing: -1.1);
  static const h1 = TextStyle(fontFamily: _f, fontSize: 27, height: 1.15, fontWeight: FontWeight.w800, color: TColors.ink, letterSpacing: -0.7);
  static const h2 = TextStyle(fontFamily: _f, fontSize: 21, height: 1.2, fontWeight: FontWeight.w700, color: TColors.ink, letterSpacing: -0.4);
  static const h3 = TextStyle(fontFamily: _f, fontSize: 18, height: 1.25, fontWeight: FontWeight.w700, color: TColors.ink, letterSpacing: -0.2);
  static const body = TextStyle(fontFamily: _f, fontSize: 16.5, height: 1.45, fontWeight: FontWeight.w500, color: TColors.ink);
  static const small = TextStyle(fontFamily: _f, fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w500, color: TColors.muted);
  static const label = TextStyle(fontFamily: _f, fontSize: 13, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: 0.2, color: TColors.muted);

  /// Angka besar di ubin metrik (angka tabular supaya tidak "menari" saat berubah).
  static const metric = TextStyle(
    fontFamily: _f,
    fontSize: 40,
    height: 1.0,
    fontWeight: FontWeight.w800,
    color: TColors.ink,
    letterSpacing: -1.6,
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
    fontFamily: 'Jakarta',
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
        textStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TColors.brandDeep,
        minimumSize: const Size(56, 52),
        side: const BorderSide(color: TColors.line, width: 1.5),
        textStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: 16.5, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TColors.brandDeep,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
    chipTheme: const ChipThemeData(
      labelStyle: TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w700, fontSize: 14.5, color: TColors.ink),
      side: BorderSide(color: TColors.line),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: TColors.panel,
      indicatorColor: TColors.brandTint,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Jakarta', fontWeight: FontWeight.w800, fontSize: 13.5)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: TColors.night,
      contentTextStyle: const TextStyle(fontFamily: 'Jakarta', fontSize: 15.5, fontWeight: FontWeight.w700, color: Colors.white),
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
