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

/// Завершённое голодание.
class FastEntry {
  final int start; // ms
  final int end; // ms
  final int goalH;
  const FastEntry(this.start, this.end, this.goalH);

  double get hours => (end - start) / 3600000.0;
  bool get reached => hours >= goalH;

  Map<String, dynamic> toJson() => {'start': start, 'end': end, 'goalH': goalH};
  factory FastEntry.fromJson(Map<String, dynamic> j) =>
      FastEntry(asInt(j['start']), asInt(j['end']), asInt(j['goalH'], 16));
}

/// Категории расходов на еду.
const expenseCategories = ['groceries', 'eatout', 'sport', 'other'];

/// Расход на еду.
class Expense {
  final String id;
  final String date; // ключ дня
  final double amount;
  final String currency; // PLN | USD
  final String category;
  final String note;

  const Expense({
    required this.id,
    required this.date,
    required this.amount,
    this.currency = 'PLN',
    this.category = 'groceries',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'amount': amount,
        'currency': currency,
        'category': category,
        'note': note,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id']?.toString() ?? '',
        date: j['date']?.toString() ?? todayKey(),
        amount: asDouble(j['amount']),
        currency: j['currency']?.toString() == 'USD' ? 'USD' : 'PLN',
        category: expenseCategories.contains(j['category']) ? j['category'].toString() : 'other',
        note: j['note']?.toString() ?? '',
      );
}

/// Части тела для замеров (см).
const measureParts = ['waist', 'chest', 'hips', 'arm', 'thigh', 'neck'];
