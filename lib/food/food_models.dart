// Модели раздела «Питание»: избранные продукты, товары по штрихкоду.

import '../util.dart';

/// Продукт с готовым КБЖУ на порцию (избранное и «недавние»).
class FavFood {
  final String id;
  final String name;
  final double grams;
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;

  const FavFood({
    required this.id,
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  String get norm => name.trim().toLowerCase();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'grams': grams,
        'kcal': kcal,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
      };

  factory FavFood.fromJson(Map<String, dynamic> j) => FavFood(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        grams: asDouble(j['grams']),
        kcal: asDouble(j['kcal']),
        protein: asDouble(j['protein']),
        fat: asDouble(j['fat']),
        carbs: asDouble(j['carbs']),
      );
}

/// Товар по штрихкоду. КБЖУ на 100 г.
class BarcodeProduct {
  final String code;
  final String name;
  final String brand;
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;
  final double serving; // граммов в порции, 0 — не указано
  final double package; // граммов в упаковке, 0 — не указано
  final bool user; // введён вручную

  const BarcodeProduct({
    required this.code,
    required this.name,
    this.brand = '',
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.serving = 0,
    this.package = 0,
    this.user = false,
  });

  String get title => brand.isEmpty || name.toLowerCase().contains(brand.toLowerCase()) ? name : '$name ($brand)';

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'brand': brand,
        'kcal': kcal,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        'serving': serving,
        'package': package,
        'user': user,
      };

  factory BarcodeProduct.fromJson(Map<String, dynamic> j) => BarcodeProduct(
        code: j['code']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        brand: j['brand']?.toString() ?? '',
        kcal: asDouble(j['kcal']),
        protein: asDouble(j['protein']),
        fat: asDouble(j['fat']),
        carbs: asDouble(j['carbs']),
        serving: asDouble(j['serving']),
        package: asDouble(j['package']),
        user: j['user'] == true,
      );
}
