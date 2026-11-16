import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF0E0B14);
  static const surface = Color(0xFF17131F);
  static const surface2 = Color(0xFF211B2B);
  static const border = Color(0xFF2E2639);
  static const text = Color(0xFFF2EEF7);
  static const muted = Color(0xFF9C93AB);
  static const gold = Color(0xFFF5B942);
  static const a = Color(0xFF4FA8FF); // ты
  static const b = Color(0xFFFF5468); // соперник
  static const good = Color(0xFF3DDC97);
  static const mid = Color(0xFFFFC94D);
  static const warn = Color(0xFFFF9F43);
  static const bad = Color(0xFFFF5468);
}

Color scoreColor(double? s) {
  if (s == null) return C.muted;
  if (s >= 8.5) return C.gold;
  if (s >= 7) return C.good;
  if (s >= 5.5) return C.mid;
  if (s >= 4) return C.warn;
  return C.bad;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: C.gold,
    brightness: Brightness.dark,
  ).copyWith(
    primary: C.gold,
    onPrimary: const Color(0xFF1A1206),
    secondary: C.a,
    surface: C.surface,
    onSurface: C.text,
    error: C.bad,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: C.bg,
      foregroundColor: C.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.text, letterSpacing: 0.2),
    ),
    cardTheme: CardThemeData(
      color: C.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: C.border),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: C.surface,
      indicatorColor: C.gold.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? C.gold : C.muted),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.gold,
        foregroundColor: const Color(0xFF1A1206),
        disabledBackgroundColor: C.surface2,
        disabledForegroundColor: C.muted,
        minimumSize: const Size(0, 54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? C.gold.withValues(alpha: 0.18) : C.surface,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? C.gold : C.muted,
        ),
        side: WidgetStateProperty.all(const BorderSide(color: C.border)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: C.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.border)),
      focusedBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.gold)),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
