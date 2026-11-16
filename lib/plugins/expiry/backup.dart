import 'dart:convert';

import 'models.dart';

/// Резервная копия всех данных «Просрочки» в одном JSON-файле.
class Backup {
  Backup({
    required this.items,
    required this.products,
    required this.warnDays,
    required this.notifyHour,
    required this.notifyMinute,
  });

  final List<Item> items;
  final Map<String, ProductInfo> products;
  final int warnDays, notifyHour, notifyMinute;

  static const marker = 'winter-expiry';

  String encode() => const JsonEncoder.withIndent(' ').convert({
        'app': marker,
        'version': 1,
        'exported': DateTime.now().toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'products': products.map((k, v) => MapEntry(k, v.toJson())),
        'settings': {
          'warnDays': warnDays,
          'notifyHour': notifyHour,
          'notifyMinute': notifyMinute,
        },
      });

  /// Разбирает файл копии. Бросает [FormatException] с понятным текстом.
  static Backup parse(String raw) {
    final dynamic j;
    try {
      j = jsonDecode(raw.trim());
    } catch (_) {
      throw const FormatException('Это не файл резервной копии');
    }
    if (j is! Map || j['app'] != marker) {
      throw const FormatException('Это не резервная копия «Просрочки»');
    }
    final items = <Item>[];
    for (final e in (j['items'] as List? ?? const [])) {
      if (e is! Map) continue;
      try {
        items.add(Item.fromJson(Map<String, dynamic>.from(e)));
      } catch (_) {
        // битую запись пропускаем, остальные восстанавливаем
      }
    }
    final products = <String, ProductInfo>{};
    final p = j['products'];
    if (p is Map) {
      p.forEach((k, v) {
        if (v is Map) products['$k'] = ProductInfo.fromJson(Map<String, dynamic>.from(v));
      });
    }
    final s = j['settings'] is Map ? j['settings'] as Map : const {};
    int pick(Object? v, int def, int min, int max) {
      final n = v is int ? v : int.tryParse('$v');
      return n == null || n < min || n > max ? def : n;
    }

    return Backup(
      items: items,
      products: products,
      warnDays: pick(s['warnDays'], 2, 1, 7),
      notifyHour: pick(s['notifyHour'], 9, 0, 23),
      notifyMinute: pick(s['notifyMinute'], 0, 0, 59),
    );
  }

  /// Сливает копию с текущими данными: записи с тем же id заменяются, новые добавляются.
  static List<Item> merge(List<Item> current, List<Item> incoming) {
    final byId = {for (final i in current) i.id: i};
    for (final i in incoming) {
      byId[i.id] = i;
    }
    return byId.values.toList();
  }
}
