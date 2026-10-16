import 'package:flutter/material.dart';

/// Token warna TILIK: krem kertas yang tidak silau + biru teduh berkontras tinggi, untuk mata lansia dan keluarganya.
/// Semua teks di atas latar mana pun ≥ 4,5:1. Warna level selalu ditemani ikon dan teks, tidak pernah jadi
/// satu-satunya pembawa makna (buta warna merah-hijau umum pada lansia pria).
abstract final class TColors {
  static const bg = Color(0xFFF4F1EA); // krem kertas
  static const panel = Color(0xFFFFFFFF);
  static const sunk = Color(0xFFECE8DF); // isian tombol & track
  static const line = Color(0xFFE3DDD1);
  static const ink = Color(0xFF1B2330); // hampir hitam, 14:1 di atas krem
  static const muted = Color(0xFF4D5868); // teks kedua, 6,6:1 di atas krem

  static const brand = Color(0xFF2F5DA8); // biru teduh, 6,2:1 di atas putih
  static const brandDeep = Color(0xFF1E3F7A);
  static const brandTint = Color(0xFFE3ECFA);
  static const clay = Color(0xFFB4532F); // sistolik, aksen hangat

  // Ubin pastel. Teks di atasnya selalu `ink`; ikon memakai pasangan `*Ink`.
  static const sky = Color(0xFFDCE9F7);
  static const skyInk = Color(0xFF1E4C86);
  static const sage = Color(0xFFDDEFD9);
  static const sageInk = Color(0xFF2B6136);
  static const peach = Color(0xFFFBE4D5);
  static const peachInk = Color(0xFF8E3F1C);
  static const lavender = Color(0xFFE8E3F5);
  static const lavenderInk = Color(0xFF4B3C8C);
  static const butter = Color(0xFFFFF2C2);
  static const butterInk = Color(0xFF6E5300);

  static const green = Color(0xFF1F7A47);
  static const greenTint = Color(0xFFDDF1E4);
  static const yellow = Color(0xFF8A5A00);
  static const yellowTint = Color(0xFFFFF0C7);
  static const red = Color(0xFFB3261E);
  static const redTint = Color(0xFFFCE3E0);
  static const grey = Color(0xFF4D5868);
  static const greyTint = Color(0xFFEAE6DE);

  // Pil navigasi & board IGD (gelap, dibaca dari jauh).
  static const night = Color(0xFF141A24);
  static const nightPanel = Color(0xFF1E2633);
  static const nightLine = Color(0xFF303A4A);
}

abstract final class TShadow {
  /// Bayangan lembut dengan offset: kartu terasa diletakkan di atas kertas, bukan bercahaya.
  static const soft = [BoxShadow(color: Color(0x14243048), blurRadius: 24, offset: Offset(0, 8)), BoxShadow(color: Color(0x0A243048), blurRadius: 4, offset: Offset(0, 1))];
  static const lift = [BoxShadow(color: Color(0x26141A24), blurRadius: 30, offset: Offset(0, 14))];
}

abstract final class TText {
  static const display = TextStyle(fontFamily: 'Fredoka', fontSize: 36, height: 1.08, fontWeight: FontWeight.w600, color: TColors.ink, letterSpacing: -0.5);
  static const h1 = TextStyle(fontFamily: 'Fredoka', fontSize: 28, height: 1.15, fontWeight: FontWeight.w600, color: TColors.ink, letterSpacing: -0.3);
  static const h2 = TextStyle(fontFamily: 'Fredoka', fontSize: 22, height: 1.2, fontWeight: FontWeight.w600, color: TColors.ink);
  static const h3 = TextStyle(fontFamily: 'Fredoka', fontSize: 18.5, height: 1.25, fontWeight: FontWeight.w600, color: TColors.ink);
  static const body = TextStyle(fontFamily: 'Nunito', fontSize: 17, height: 1.45, fontWeight: FontWeight.w600, color: TColors.ink);
  static const small = TextStyle(fontFamily: 'Nunito', fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w600, color: TColors.muted);
  static const label = TextStyle(fontFamily: 'Nunito', fontSize: 13.5, height: 1.2, fontWeight: FontWeight.w800, letterSpacing: 0.2, color: TColors.muted);

  /// Angka besar di ubin metrik (Fredoka, angka tabular supaya tidak "menari" saat berubah).
  static const metric = TextStyle(
    fontFamily: 'Fredoka',
    fontSize: 40,
    height: 1.0,
    fontWeight: FontWeight.w600,
    color: TColors.ink,
    letterSpacing: -1,
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
        textStyle: const TextStyle(fontFamily: 'Fredoka', fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TColors.brandDeep,
        minimumSize: const Size(56, 52),
        side: const BorderSide(color: TColors.line, width: 1.5),
        textStyle: const TextStyle(fontFamily: 'Fredoka', fontSize: 16.5, fontWeight: FontWeight.w600),
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
