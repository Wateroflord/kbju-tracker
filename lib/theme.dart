import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';

/// Палитра: тёмный плоский интерфейс (как игровое меню настроек) —
/// почти чёрный фон, графитовые панели и один красный акцент.
class AppColors {
  static const bg = Color(0xFF0B0B0D);
  static const surface = Color(0xFF131416);
  static const surface2 = Color(0xFF1A1A1E);
  static const border = Color(0xFF26272B);
  static const text = Color(0xFFEDEDEF);
  static const muted = Color(0xFF7A7D82);

  static const accent = Color(0xFFCE3535); // красный акцент (как у uc.zone)
  static const accent2 = Color(0xFFAFB3BA); // светло-серый для второстепенного

  static const protein = Color(0xFF5B9DFF);
  static const fat = Color(0xFFF2B14C);
  static const carbs = Color(0xFFA78BFA);
  static const water = Color(0xFF4CC9F0);

  static const good = Color(0xFF3DD68C);
  static const under = Color(0xFFF2B14C);
  static const over = Color(0xFFFF5C7A);

  static Color status(DayStatus s) => switch (s) {
        DayStatus.good => good,
        DayStatus.under => under,
        DayStatus.over => over,
        DayStatus.none => border,
      };
}

class Txt {
  static const tab = [FontFeature.tabularFigures()];

  static TextStyle num(double size, {Color color = AppColors.text, FontWeight weight = FontWeight.w700}) =>
      TextStyle(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFeatures: tab,
        letterSpacing: -0.5,
        height: 1.05,
      );

  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: AppColors.muted,
  );

  /// Заголовок блока, как «Auto Ursa Settings» в референсе.
  static const section = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.text,
  );

  static const h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    color: AppColors.text,
  );

  static const h2 = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.text,
  );

  static const body = TextStyle(fontSize: 14, color: AppColors.text, height: 1.35);
  static const small = TextStyle(fontSize: 12, color: AppColors.muted, height: 1.3);
}

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accent2,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.over,
    ),
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    primaryTextTheme: GoogleFonts.interTextTheme(base.primaryTextTheme),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionHandleColor: AppColors.accent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.surface2),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.border),
    ),
    dividerColor: AppColors.border,
  );
}

InputDecoration fieldDeco(String label, {String? suffix, String? hint}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: c, width: w),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    isDense: true,
    filled: true,
    fillColor: AppColors.surface2,
    labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
    floatingLabelStyle: const TextStyle(color: AppColors.accent, fontSize: 13),
    suffixStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
    hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.6), fontSize: 13),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    border: b(AppColors.border),
    enabledBorder: b(AppColors.border),
    focusedBorder: b(AppColors.accent, 1.4),
  );
}
