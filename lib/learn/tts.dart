import 'package:flutter/services.dart';

/// Озвучка слов встроенным синтезатором речи Android.
class Tts {
  static const _ch = MethodChannel('kbju/tts');

  /// false — на телефоне нет голоса для этого языка.
  static Future<bool> speak(String text, String lang) async {
    final tag = switch (lang) {
      'pl' => 'pl-PL',
      'uk' => 'uk-UA',
      'ru' => 'ru-RU',
      'de' => 'de-DE',
      _ => 'en-US',
    };
    // Подсказки в скобках не озвучиваем: «to go (on foot)» → «to go».
    final clean = text.replaceAll(RegExp(r'\s*\([^)]*\)'), '').replaceAll('…', '');
    try {
      return await _ch.invokeMethod<bool>('speak', {'text': clean, 'lang': tag}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> stop() async {
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }
}
