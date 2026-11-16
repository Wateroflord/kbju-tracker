import 'dart:convert';
import 'dart:typed_data';

import 'package:winter_core/winter_core.dart';

import 'util.dart';
import 'i18n/i18n.dart';

class AiFoodItem {
  final String name;
  final double grams, kcal, protein, fat, carbs;
  final double fiber, salt; // г, 0 — неизвестно
  const AiFoodItem({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.fiber = 0,
    this.salt = 0,
  });

  /// Та же еда, пересчитанная на другой вес.
  AiFoodItem scaled(double newGrams) {
    final k = grams > 0 ? newGrams / grams : 1.0;
    double r(double v) => (v * k * 10).round() / 10;
    return AiFoodItem(
      name: name,
      grams: newGrams,
      kcal: r(kcal),
      protein: r(protein),
      fat: r(fat),
      carbs: r(carbs),
      fiber: r(fiber),
      salt: (salt * k * 100).round() / 100,
    );
  }
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
  /// Если выбранная модель недоступна, пробуем следующие.
  static const fallbackModels = WinterGemini.models;

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

  /// Произвольный запрос к ИИ: текст (или JSON при [json] = true). Используется для
  /// недельного отчёта и генератора программ.
  static Future<String> generate({
    required String apiKey,
    required String model,
    required String prompt,
    bool json = false,
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
        return await _post(key, m, [
          {'text': prompt}
        ], json);
      } on _TryNextModel catch (e) {
        lastError = e.message;
      }
    }
    throw GeminiException(lastError);
  }

  /// Язык ответа ИИ (язык интерфейса), по-английски — для промпта.
  static String get outLang => _outLang;

  /// Достать JSON-объект из ответа ИИ.
  static Map<String, dynamic> parseJsonObject(String text) {
    final s = text.indexOf('{');
    final e = text.lastIndexOf('}');
    if (s < 0 || e <= s) throw GeminiException(tr('Не удалось разобрать ответ ИИ.'));
    try {
      final d = jsonDecode(text.substring(s, e + 1));
      if (d is Map) return Map<String, dynamic>.from(d);
    } catch (_) {}
    throw GeminiException(tr('Не удалось разобрать ответ ИИ.'));
  }

  /// Проверка ключа: запрашиваем список моделей.
  static Future<String?> testKey(String apiKey) async {
    final e = await WinterGemini.testKey(apiKey);
    if (e == null) return null;
    return switch (e.kind) {
      GeminiFail.badKey => trf('Ключ не принят: {0}', [_detail(e)]),
      GeminiFail.timeout => tr('Сервер не ответил. Проверь интернет.'),
      GeminiFail.offline => trf('Нет соединения: {0}', [e.detail]),
      _ => trf('Ошибка {0}: {1}', [e.code, _detail(e)]),
    };
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
      ..writeln('Estimate the portion weight in grams and calculate calories, protein, fat, carbs, '
          'dietary fiber and salt (grams of salt, not sodium) for the whole portion (NOT per 100 g).')
      ..writeln('If a package label is visible, use its data.')
      ..writeln('Take oil, sauces and the cooking method into account.');
    if (hint.isNotEmpty) {
      b.writeln('Clarification from the user (trust it more than your own estimate): $hint');
    }
    b
      ..writeln('Write dish names and the note in $_outLang.')
      ..writeln('Answer with exactly one JSON object, no markdown, no explanations:')
      ..writeln('{"items":[{"name":"Dish name","grams":150,"kcal":250,'
          '"protein":20,"fat":10,"carbs":15,"fiber":3,"salt":1.2}],"note":"short comment"}')
      ..writeln('If there is no food, return an empty items list and explain why in note.');
    return b.toString();
  }

  static Future<AiResult> _call(String key, String model, Uint8List? image, String hint) async {
    final parts = <Map<String, dynamic>>[
      WinterGemini.text(_prompt(hint, image != null)),
      if (image != null) WinterGemini.image(image),
    ];
    return _parse(await _post(key, model, parts, true));
  }

  /// Один запрос к одной модели (общий клиент winter_core). Недоступная модель → [_TryNextModel].
  static Future<String> _post(String key, String model, List<Map<String, dynamic>> parts, bool json) async {
    try {
      // Модели перебирает сам analyze()/generate(), поэтому здесь — только [model].
      return await WinterGemini.generate(key: key, model: model, parts: parts, json: json, onlyModel: true);
    } on GeminiError catch (e) {
      if (e.kind == GeminiFail.unavailable) {
        throw _TryNextModel(e.detail.isEmpty
            ? trf('Модель {0} недоступна ({1}). Попробуй позже.', [model, e.code])
            : trf('Модель {0} не подходит: {1}', [model, e.detail]));
      }
      throw GeminiException(_message(e));
    }
  }

  static String _detail(GeminiError e) => e.detail.isEmpty ? tr('неизвестная ошибка') : e.detail;

  static String _message(GeminiError e) => switch (e.kind) {
        GeminiFail.noKey => tr('Добавь API-ключ Gemini во вкладке «Профиль».'),
        GeminiFail.badKey => tr('Неверный API-ключ. Проверь его во вкладке «Профиль».'),
        GeminiFail.timeout => tr('ИИ слишком долго отвечает. Попробуй ещё раз.'),
        GeminiFail.offline => tr('Нет соединения с интернетом.'),
        GeminiFail.rateLimit => tr('Превышен лимит запросов Gemini. Подожди минуту и попробуй снова.'),
        GeminiFail.blocked => trf('ИИ не вернул ответ{0}.', [e.detail.isEmpty ? '' : ' (${e.detail})']),
        GeminiFail.empty => tr('ИИ вернул пустой ответ.'),
        GeminiFail.badResponse => tr('Сервер вернул непонятный ответ.'),
        GeminiFail.unavailable || GeminiFail.http => trf('Ошибка запроса ({0}): {1}', [e.code, _detail(e)]),
      };

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
          fiber: _r(asDouble(it['fiber'])),
          salt: _r2(asDouble(it['salt'])),
        ));
      }
    }
    return AiResult(items, (data['note'] ?? '').toString().trim());
  }

  static double _r(double v) => v < 0 ? 0 : (v * 10).round() / 10;
  static double _r2(double v) => v < 0 ? 0 : (v * 100).round() / 100;


}
