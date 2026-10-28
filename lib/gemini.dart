import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'util.dart';
import 'i18n/i18n.dart';

class AiFoodItem {
  final String name;
  final double grams, kcal, protein, fat, carbs;
  const AiFoodItem({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });
}

class AiResult {
  final List<AiFoodItem> items;
  final String note;
  const AiResult(this.items, this.note);
}

class GeminiException implements Exception {
  final String message;
  GeminiException(this.message);
  @override
  String toString() => message;
}

class _TryNextModel implements Exception {
  final String message;
  _TryNextModel(this.message);
}

/// Распознавание еды через Google Gemini API.
class GeminiService {
  static const _base = 'https://generativelanguage.googleapis.com/v1beta';

  /// Если выбранная модель недоступна, пробуем следующие.
  static const fallbackModels = [
    'gemini-flash-latest',
    'gemini-3.8-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
  ];

  static Future<AiResult> analyze({
    required String apiKey,
    required String model,
    Uint8List? image,
    String hint = '',
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw GeminiException(tr('Добавь API-ключ Gemini во вкладке «Профиль».'));
    }
    final first = model.trim().isEmpty ? fallbackModels.first : model.trim();
    final models = <String>[first, ...fallbackModels.where((m) => m != first)];

    String lastError = tr('Не удалось получить ответ от ИИ');
    for (final m in models) {
      try {
        return await _call(key, m, image, hint.trim());
      } on _TryNextModel catch (e) {
        lastError = e.message;
      }
    }
    throw GeminiException(lastError);
  }

  /// Проверка ключа: запрашиваем список моделей.
  static Future<String?> testKey(String apiKey) async {
    try {
      final res = await http.get(
        Uri.parse('$_base/models?pageSize=50'),
        headers: {'x-goog-api-key': apiKey.trim()},
      ).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) return null;
      if (res.statusCode == 400 || res.statusCode == 401 || res.statusCode == 403) {
        return trf('Ключ не принят: {0}', [_errMsg(res.bodyBytes)]);
      }
      return trf('Ошибка {0}: {1}', [res.statusCode, _errMsg(res.bodyBytes)]);
    } on TimeoutException {
      return tr('Сервер не ответил. Проверь интернет.');
    } catch (e) {
      return trf('Нет соединения: {0}', [e]);
    }
  }

  /// Язык, на котором ИИ пишет названия блюд и комментарий.
  static String get _outLang => switch (appLang) {
        AppLang.ru => 'Russian',
        AppLang.uk => 'Ukrainian',
        AppLang.en => 'English',
        AppLang.pl => 'Polish',
      };

  static String _prompt(String hint, bool hasImage) {
    final b = StringBuffer()
      ..writeln('You are an experienced nutritionist.')
      ..writeln(hasImage
          ? 'Look at the food photo. Identify every dish or product in it.'
          : 'The user described the food they ate in text. Identify every dish or product.')
      ..writeln('Estimate the portion weight in grams and calculate calories, protein, fat and carbs '
          'for the whole portion (NOT per 100 g).')
      ..writeln('If a package label is visible, use its data.')
      ..writeln('Take oil, sauces and the cooking method into account.');
    if (hint.isNotEmpty) {
      b.writeln('Clarification from the user (trust it more than your own estimate): $hint');
    }
    b
      ..writeln('Write dish names and the note in $_outLang.')
      ..writeln('Answer with exactly one JSON object, no markdown, no explanations:')
      ..writeln('{"items":[{"name":"Dish name","grams":150,"kcal":250,'
          '"protein":20,"fat":10,"carbs":15}],"note":"short comment"}')
      ..writeln('If there is no food, return an empty items list and explain why in note.');
    return b.toString();
  }

  static String _mime(Uint8List b) {
    if (b.length > 4 && b[0] == 0x89 && b[1] == 0x50) return 'image/png';
    if (b.length > 12 && b[0] == 0x52 && b[1] == 0x49 && b[8] == 0x57 && b[9] == 0x45) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  static Future<AiResult> _call(String key, String model, Uint8List? image, String hint) async {
    final parts = <Map<String, dynamic>>[
      {'text': _prompt(hint, image != null)},
    ];
    if (image != null) {
      parts.add({
        'inlineData': {'mimeType': _mime(image), 'data': base64Encode(image)},
      });
    }
    final body = jsonEncode({
      'contents': [
        {'role': 'user', 'parts': parts},
      ],
      'generationConfig': {'responseMimeType': 'application/json'},
    });

    final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('$_base/models/$model:generateContent'),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': key,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 90));
    } on TimeoutException {
      throw GeminiException(tr('ИИ слишком долго отвечает. Попробуй ещё раз.'));
    } catch (e) {
      throw GeminiException(tr('Нет соединения с интернетом.'));
    }

    final code = res.statusCode;
    if (code == 404 || code >= 500) {
      throw _TryNextModel(trf('Модель {0} недоступна ({1}). Попробуй позже.', [model, code]));
    }
    if (code == 429) {
      throw GeminiException(tr('Превышен лимит запросов Gemini. Подожди минуту и попробуй снова.'));
    }
    if (code != 200) {
      final msg = _errMsg(res.bodyBytes);
      final low = msg.toLowerCase();
      if (low.contains('api key') || low.contains('api_key')) {
        throw GeminiException(tr('Неверный API-ключ. Проверь его во вкладке «Профиль».'));
      }
      if (code == 400 && low.contains('model')) {
        throw _TryNextModel(trf('Модель {0} не подходит: {1}', [model, msg]));
      }
      throw GeminiException(trf('Ошибка запроса ({0}): {1}', [code, msg]));
    }

    final Map<String, dynamic> j;
    try {
      j = Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
    } catch (_) {
      throw GeminiException(tr('Сервер вернул непонятный ответ.'));
    }
    final cands = j['candidates'];
    if (cands is! List || cands.isEmpty) {
      final fb = j['promptFeedback'];
      final reason = fb is Map ? fb['blockReason'] : null;
      throw GeminiException(trf('ИИ не вернул ответ{0}.', [reason != null ? ' ($reason)' : '']));
    }
    final content = (cands.first as Map)['content'];
    final rawParts = content is Map ? content['parts'] : null;
    final text = (rawParts is List ? rawParts : const [])
        .whereType<Map>()
        .where((p) => p['thought'] != true && p['text'] is String)
        .map((p) => p['text'] as String)
        .join();
    return _parse(text);
  }

  static AiResult _parse(String text) {
    final s = text.indexOf('{');
    final e = text.lastIndexOf('}');
    if (s < 0 || e <= s) throw GeminiException(tr('Не удалось разобрать ответ ИИ.'));
    final dynamic data;
    try {
      data = jsonDecode(text.substring(s, e + 1));
    } catch (_) {
      throw GeminiException(tr('Не удалось разобрать ответ ИИ.'));
    }
    if (data is! Map) throw GeminiException(tr('Не удалось разобрать ответ ИИ.'));
    final raw = data['items'];
    final items = <AiFoodItem>[];
    if (raw is List) {
      for (final it in raw.whereType<Map>()) {
        final name = (it['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        items.add(AiFoodItem(
          name: name,
          grams: _r(asDouble(it['grams'])),
          kcal: _r(asDouble(it['kcal'])),
          protein: _r(asDouble(it['protein'])),
          fat: _r(asDouble(it['fat'])),
          carbs: _r(asDouble(it['carbs'])),
        ));
      }
    }
    return AiResult(items, (data['note'] ?? '').toString().trim());
  }

  static double _r(double v) => v < 0 ? 0 : (v * 10).round() / 10;

  static String _errMsg(List<int> bytes) {
    try {
      final j = jsonDecode(utf8.decode(bytes));
      if (j is Map && j['error'] is Map) {
        return (j['error'] as Map)['message']?.toString() ?? tr('неизвестная ошибка');
      }
    } catch (_) {}
    return tr('неизвестная ошибка');
  }
}
