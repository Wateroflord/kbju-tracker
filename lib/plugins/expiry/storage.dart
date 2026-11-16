import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backup.dart';
import 'models.dart';
import 'notifications.dart';

/// Все данные приложения. Хранятся на телефоне.
class AppStore extends ChangeNotifier {
  AppStore._();
  static final AppStore instance = AppStore._();

  SharedPreferences? _prefs;
  final List<Item> items = [];

  /// Справочник «штрихкод → товар»: второй раз тот же товар заполнится мгновенно и без интернета.
  final Map<String, ProductInfo> products = {};

  int warnDays = 2;
  int notifyHour = 9;
  int notifyMinute = 0;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _prefs = p;
    try {
      final raw = p.getString('items_v1');
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        items
          ..clear()
          ..addAll(list.map(
              (e) => Item.fromJson(Map<String, dynamic>.from(e as Map))));
      }
    } catch (e) {
      debugPrint('Ошибка загрузки товаров: $e');
    }
    try {
      final raw = p.getString('products_v1');
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        products.clear();
        map.forEach((k, v) {
          products[k] = ProductInfo.fromJson(Map<String, dynamic>.from(v as Map));
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки справочника: $e');
    }
    warnDays = p.getInt('warnDays') ?? 2;
    notifyHour = p.getInt('notifyHour') ?? 9;
    notifyMinute = p.getInt('notifyMinute') ?? 0;
  }

  Future<void> _persist() async {
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    await p.setString(
        'items_v1', jsonEncode(items.map((e) => e.toJson()).toList()));
    await p.setString('products_v1',
        jsonEncode(products.map((k, v) => MapEntry(k, v.toJson()))));
    await p.setInt('warnDays', warnDays);
    await p.setInt('notifyHour', notifyHour);
    await p.setInt('notifyMinute', notifyMinute);
    await Notifier.reschedule(this);
  }

  List<Item> activeFor(Shelf s) {
    final list = items.where((i) => !i.removed && i.shelf == s).toList();
    list.sort((a, b) {
      final c = a.expiry.compareTo(b.expiry);
      return c != 0 ? c : a.name.compareTo(b.name);
    });
    return list;
  }

  List<Item> get history {
    final list = items.where((i) => i.removed).toList();
    list.sort((a, b) =>
        (b.removedAt ?? b.createdAt).compareTo(a.removedAt ?? a.createdAt));
    return list;
  }

  int alertCount(Shelf s) =>
      activeFor(s).where((i) => i.status(warnDays) != ExpiryStatus.ok).length;

  ProductInfo? known(String barcode) => products[barcode.trim()];

  Future<void> save(Item item) async {
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.add(item);
    }
    if (item.barcode.isNotEmpty && item.name.isNotEmpty) {
      products[item.barcode] =
          ProductInfo(name: item.name, imageUrl: item.imageUrl, shelf: item.shelf);
    }
    await _persist();
  }

  Future<void> markRemoved(Item item) async {
    item.removed = true;
    item.removedAt = DateTime.now();
    await _persist();
  }

  Future<void> restore(Item item) async {
    item.removed = false;
    item.removedAt = null;
    await _persist();
  }

  Future<void> delete(Item item) async {
    items.removeWhere((i) => i.id == item.id);
    await _persist();
  }

  Future<void> clearHistory() async {
    items.removeWhere((i) => i.removed);
    await _persist();
  }

  /// Всё содержимое приложения одним JSON (для резервной копии).
  String exportBackup() => Backup(
        items: items,
        products: products,
        warnDays: warnDays,
        notifyHour: notifyHour,
        notifyMinute: notifyMinute,
      ).encode();

  /// Восстановить из копии. Возвращает число товаров в копии.
  Future<int> importBackup(String raw) async {
    final b = Backup.parse(raw);
    final merged = Backup.merge(items, b.items);
    items
      ..clear()
      ..addAll(merged);
    products.addAll(b.products);
    warnDays = b.warnDays;
    notifyHour = b.notifyHour;
    notifyMinute = b.notifyMinute;
    await _persist();
    return b.items.length;
  }

  Future<void> updateSettings({int? warn, int? hour, int? minute}) async {
    if (warn != null) warnDays = warn;
    if (hour != null) notifyHour = hour;
    if (minute != null) notifyMinute = minute;
    await _persist();
  }
}
