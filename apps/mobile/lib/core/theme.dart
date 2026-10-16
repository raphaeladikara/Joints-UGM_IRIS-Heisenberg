import 'package:flutter/material.dart';

/// Token warna TILIK. Hijau daun (tenang, "dijaga") + krem hangat. Warna level selalu ditemani ikon dan teks,
/// tidak pernah jadi satu-satunya pembawa makna.
abstract final class TColors {
  static const bg = Color(0xFFF7F3EA);
  static const panel = Color(0xFFFFFFFF);
  static const line = Color(0xFFE6DFD0);
  static const ink = Color(0xFF1E2A24);
  static const muted = Color(0xFF5F6B63);

  static const leaf = Color(0xFF1F6B4F);
  static const leafDeep = Color(0xFF154D39);
  static const leafTint = Color(0xFFE2F0E8);
  static const clay = Color(0xFFC0623B);

  static const green = Color(0xFF237A4B);
  static const greenTint = Color(0xFFDDF1E4);
  static const yellow = Color(0xFF8A6100);
  static const yellowTint = Color(0xFFFFF0C7);
  static const red = Color(0xFFC0272D);
  static const redTint = Color(0xFFFDE2E1);
  static const grey = Color(0xFF5F6B63);
  static const greyTint = Color(0xFFEDEAE3);

  // Board IGD (gelap, dibaca dari jauh).
  static const night = Color(0xFF111816);
  static const nightPanel = Color(0xFF1B2521);
  static const nightLine = Color(0xFF2C3833);
}

abstract final class TText {
  static const display = TextStyle(fontFamily: 'Fredoka', fontSize: 34, height: 1.1, fontWeight: FontWeight.w600, color: TColors.ink);
  static const h1 = TextStyle(fontFamily: 'Fredoka', fontSize: 26, height: 1.2, fontWeight: FontWeight.w600, color: TColors.ink);
  static const h2 = TextStyle(fontFamily: 'Fredoka', fontSize: 20, height: 1.25, fontWeight: FontWeight.w600, color: TColors.ink);
  static const h3 = TextStyle(fontFamily: 'Fredoka', fontSize: 17, height: 1.3, fontWeight: FontWeight.w600, color: TColors.ink);
  static const body = TextStyle(fontFamily: 'Nunito', fontSize: 15.5, height: 1.45, fontWeight: FontWeight.w600, color: TColors.ink);
  static const small = TextStyle(fontFamily: 'Nunito', fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: TColors.muted);
  static const label = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.4,
    color: TColors.muted,
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: TColors.leaf, primary: TColors.leaf, surface: TColors.panel, error: TColors.red);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: TColors.bg,
    fontFamily: 'Nunito',
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
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: TColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TColors.leaf,
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(fontFamily: 'Fredoka', fontSize: 16.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TColors.leafDeep,
        minimumSize: const Size(48, 48),
        side: const BorderSide(color: TColors.line, width: 1.5),
        textStyle: const TextStyle(fontFamily: 'Fredoka', fontSize: 15.5, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: const ChipThemeData(
      labelStyle: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 13.5, color: TColors.ink),
      side: BorderSide(color: TColors.line),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: TColors.panel,
      indicatorColor: TColors.leafTint,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700, fontSize: 12.5)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TColors.panel,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: TColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: TColors.line),
      ),
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
    'in_progress' => const LevelStyle('Sedang ditelepon', TColors.leaf, TColors.leafTint, Icons.phone_in_talk_rounded),
    _ => const LevelStyle('Dijadwalkan', TColors.grey, TColors.greyTint, Icons.schedule_rounded),
  };
}
