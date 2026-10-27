import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'util.dart';

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
      throw GeminiException('Добавь API-ключ Gemini во вкладке «Профиль».');
    }
    final first = model.trim().isEmpty ? fallbackModels.first : model.trim();
    final models = <String>[first, ...fallbackModels.where((m) => m != first)];

    String lastError = 'Не удалось получить ответ от ИИ';
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
        return 'Ключ не принят: ${_errMsg(res.bodyBytes)}';
      }
      return 'Ошибка ${res.statusCode}: ${_errMsg(res.bodyBytes)}';
    } on TimeoutException {
      return 'Сервер не ответил. Проверь интернет.';
    } catch (e) {
      return 'Нет соединения: $e';
    }
  }

  static String _prompt(String hint, bool hasImage) {
    final b = StringBuffer()
      ..writeln('Ты — опытный нутрициолог.')
      ..writeln(hasImage
          ? 'Посмотри на фото еды. Определи каждое блюдо или продукт на фото.'
          : 'Пользователь описал съеденную еду текстом. Определи каждое блюдо или продукт.')
      ..writeln('Оцени вес порции в граммах и рассчитай калории, белки, жиры и углеводы '
          'для всей порции (НЕ на 100 г).')
      ..writeln('Если видна упаковка с этикеткой — используй данные с неё.')
      ..writeln('Учитывай масло, соусы и способ приготовления.');
    if (hint.isNotEmpty) {
      b.writeln('Уточнение от пользователя (доверяй ему больше, чем своей оценке): $hint');
    }
    b
      ..writeln('Ответь строго одним JSON-объектом без markdown и пояснений:')
      ..writeln('{"items":[{"name":"Название на русском","grams":150,"kcal":250,'
          '"protein":20,"fat":10,"carbs":15}],"note":"короткий комментарий на русском"}')
      ..writeln('Если еды нет — верни пустой список items и объясни причину в note.');
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
      throw GeminiException('ИИ слишком долго отвечает. Попробуй ещё раз.');
    } catch (e) {
      throw GeminiException('Нет соединения с интернетом.');
    }

    final code = res.statusCode;
    if (code == 404 || code >= 500) {
      throw _TryNextModel('Модель $model недоступна ($code). Попробуй позже.');
    }
    if (code == 429) {
      throw GeminiException('Превышен лимит запросов Gemini. Подожди минуту и попробуй снова.');
    }
    if (code != 200) {
      final msg = _errMsg(res.bodyBytes);
      final low = msg.toLowerCase();
      if (low.contains('api key') || low.contains('api_key')) {
        throw GeminiException('Неверный API-ключ. Проверь его во вкладке «Профиль».');
      }
      if (code == 400 && low.contains('model')) {
        throw _TryNextModel('Модель $model не подходит: $msg');
      }
      throw GeminiException('Ошибка запроса ($code): $msg');
    }

    final Map<String, dynamic> j;
    try {
      j = Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
    } catch (_) {
      throw GeminiException('Сервер вернул непонятный ответ.');
    }
    final cands = j['candidates'];
    if (cands is! List || cands.isEmpty) {
      final fb = j['promptFeedback'];
      final reason = fb is Map ? fb['blockReason'] : null;
      throw GeminiException('ИИ не вернул ответ${reason != null ? ' ($reason)' : ''}.');
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
    if (s < 0 || e <= s) throw GeminiException('Не удалось разобрать ответ ИИ.');
    final dynamic data;
    try {
      data = jsonDecode(text.substring(s, e + 1));
    } catch (_) {
      throw GeminiException('Не удалось разобрать ответ ИИ.');
    }
    if (data is! Map) throw GeminiException('Не удалось разобрать ответ ИИ.');
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
        return (j['error'] as Map)['message']?.toString() ?? 'неизвестная ошибка';
      }
    } catch (_) {}
    return 'неизвестная ошибка';
  }
}
