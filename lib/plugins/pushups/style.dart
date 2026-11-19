import 'package:flutter/material.dart';

/// «Боевые» цвета и шрифты Push-Up Arena поверх общего зимнего стиля.
class Arena {
  static const red = Color(0xFFFF4D5E); // акцент боя
  static const ice = Color(0xFF7FD8FF);

  /// Крупный жирный заголовок с ледяной тенью.
  static TextStyle title(double size) => TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        height: 1.05,
        letterSpacing: size > 60 ? -2 : 0.5,
        shadows: const [Shadow(color: Color(0xAA7FD8FF), blurRadius: 18)],
      );
}

/// 65400 мс → «1:05».
String fmtDuration(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
