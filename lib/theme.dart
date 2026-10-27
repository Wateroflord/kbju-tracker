import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

import 'models.dart';

/// Палитра: Dark Gaming SaaS — графит + неоновые акценты.
class AppColors {
  static const bg = Color(0xFF0A0C0F);
  static const surface = Color(0xFF12151A);
  static const surface2 = Color(0xFF1A1E25);
  static const border = Color(0xFF252B34);
  static const text = Color(0xFFE9EDF2);
  static const muted = Color(0xFF7D8794);

  static const accent = Color(0xFFC4FF3D); // неоновый лайм
  static const accent2 = Color(0xFF7C5CFF); // электрик-фиолетовый

  static const protein = Color(0xFF4DA3FF);
  static const fat = Color(0xFFFFB547);
  static const carbs = Color(0xFFB57BFF);
  static const water = Color(0xFF3DD9FF);

  static const good = Color(0xFF3DFFA2);
  static const under = Color(0xFFFFC14D);
  static const over = Color(0xFFFF4D6A);

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
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppColors.muted,
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
      onPrimary: Colors.black,
      secondary: AppColors.accent2,
      onSecondary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.over,
    ),
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionHandleColor: AppColors.accent,
    ),
  );
}

InputDecoration fieldDeco(String label, {String? suffix, String? hint}) {
  OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
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
