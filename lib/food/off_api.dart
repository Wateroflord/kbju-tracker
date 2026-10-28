import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../i18n/i18n.dart';
import '../util.dart';
import 'food_models.dart';

class OffException implements Exception {
  final String message;
  OffException(this.message);
  @override
  String toString() => message;
}

/// Бесплатная открытая база продуктов Open Food Facts (без ключа).
class OpenFoodFacts {
  static const _fields = 'product_name,product_name_ru,product_name_uk,product_name_pl,product_name_en,'
      'generic_name,brands,nutriments,serving_quantity,product_quantity';

  /// null — товара нет в базе.
  static Future<BarcodeProduct?> lookup(String code) async {
    final uri = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$code.json?fields=$_fields');
    final http.Response res;
    try {
      res = await http.get(uri, headers: {
        'User-Agent': 'KBJUTracker/1.0 (Android; personal app)',
        'Accept': 'application/json',
      }).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw OffException(tr('Сервер не ответил. Проверь интернет.'));
    } catch (_) {
      throw OffException(tr('Нет соединения с интернетом.'));
    }
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw OffException(trf('Ошибка базы продуктов ({0})', [res.statusCode]));
    }
    final dynamic j;
    try {
      j = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw OffException(tr('Сервер вернул непонятный ответ.'));
    }
    if (j is! Map || j['status'] != 1 || j['product'] is! Map) return null;
    final p = Map<String, dynamic>.from(j['product'] as Map);
    final n = p['nutriments'] is Map ? Map<String, dynamic>.from(p['nutriments'] as Map) : <String, dynamic>{};

    String name = '';
    for (final k in ['product_name_${appLang.code}', 'product_name', 'product_name_en', 'product_name_pl',
        'product_name_ru', 'product_name_uk', 'generic_name']) {
      final v = p[k]?.toString().trim() ?? '';
      if (v.isNotEmpty) {
        name = v;
        break;
      }
    }
    final brand = (p['brands']?.toString() ?? '').split(',').first.trim();
    if (name.isEmpty) name = brand.isNotEmpty ? brand : tr('Товар');

    var kcal = asDouble(n['energy-kcal_100g'], -1);
    if (kcal < 0) {
      final kj = asDouble(n['energy_100g'], -1);
      kcal = kj < 0 ? 0 : kj / 4.184;
    }
    final prot = asDouble(n['proteins_100g']);
    final fat = asDouble(n['fat_100g']);
    final carbs = asDouble(n['carbohydrates_100g']);
    if (kcal <= 0 && prot <= 0 && fat <= 0 && carbs <= 0) {
      // Товар есть, но без пищевой ценности — пусть пользователь введёт сам.
      return BarcodeProduct(code: code, name: name, brand: brand, kcal: 0, protein: 0, fat: 0, carbs: 0);
    }
    return BarcodeProduct(
      code: code,
      name: name,
      brand: brand,
      kcal: _r(kcal),
      protein: _r(prot),
      fat: _r(fat),
      carbs: _r(carbs),
      serving: asDouble(p['serving_quantity']),
      package: asDouble(p['product_quantity']),
    );
  }

  static double _r(double v) => (v * 10).round() / 10;
}
