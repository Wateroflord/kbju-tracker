import 'package:flutter/services.dart';

/// Не давать экрану гаснуть (таймеры разминки и дыхания).
class ScreenOn {
  static const _ch = MethodChannel('kbju/screen');

  static Future<void> set(bool on) async {
    try {
      await _ch.invokeMethod('keepOn', {'on': on});
    } catch (_) {}
  }
}
