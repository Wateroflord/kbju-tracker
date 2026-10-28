import 'package:flutter/services.dart';

import '../i18n/i18n.dart';

class SpeechException implements Exception {
  final String message;
  SpeechException(this.message);
  @override
  String toString() => message;
}

/// Голосовой ввод через встроенное распознавание речи Android (окно Google).
class Speech {
  static const _ch = MethodChannel('kbju/speech');

  static String get _tag => switch (appLang) {
        AppLang.ru => 'ru-RU',
        AppLang.uk => 'uk-UA',
        AppLang.en => 'en-US',
        AppLang.pl => 'pl-PL',
      };

  /// Распознанный текст или null, если пользователь отменил.
  static Future<String?> listen({String? lang, String? prompt}) async {
    try {
      final r = await _ch.invokeMethod<String>('listen', {
        'lang': lang ?? _tag,
        'prompt': prompt ?? tr('Скажи, что ты съел'),
      });
      final t = r?.trim() ?? '';
      return t.isEmpty ? null : t;
    } on PlatformException catch (e) {
      if (e.code == 'unavailable') {
        throw SpeechException(tr('На телефоне нет распознавания речи. Установи приложение Google или используй микрофон на клавиатуре.'));
      }
      throw SpeechException(trf('Ошибка голосового ввода: {0}', [e.message ?? e.code]));
    } on MissingPluginException {
      throw SpeechException(tr('Голосовой ввод недоступен на этом устройстве'));
    }
  }
}
