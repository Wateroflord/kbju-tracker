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
  final double fiber;
  final double salt;

  const FavFood({
    required this.id,
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.fiber = 0,
    this.salt = 0,
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
        if (fiber > 0) 'fiber': fiber,
        if (salt > 0) 'salt': salt,
      };

  factory FavFood.fromJson(Map<String, dynamic> j) => FavFood(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        grams: asDouble(j['grams']),
        kcal: asDouble(j['kcal']),
        protein: asDouble(j['protein']),
        fat: asDouble(j['fat']),
        carbs: asDouble(j['carbs']),
        fiber: asDouble(j['fiber']),
        salt: asDouble(j['salt']),
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

/// Ингредиент рецепта: КБЖУ на указанный вес.
class RecipeIngredient {
  final String name;
  final double grams, kcal, protein, fat, carbs, fiber, salt;

  const RecipeIngredient({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.fiber = 0,
    this.salt = 0,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'grams': grams,
        'kcal': kcal,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        if (fiber > 0) 'fiber': fiber,
        if (salt > 0) 'salt': salt,
      };

  factory RecipeIngredient.fromJson(Map<String, dynamic> j) => RecipeIngredient(
        name: j['name']?.toString() ?? '',
        grams: asDouble(j['grams']),
        kcal: asDouble(j['kcal']),
        protein: asDouble(j['protein']),
        fat: asDouble(j['fat']),
        carbs: asDouble(j['carbs']),
        fiber: asDouble(j['fiber']),
        salt: asDouble(j['salt']),
      );
}

/// Своё блюдо из ингредиентов. КБЖУ считается на 100 г готового блюда.
class Recipe {
  final String id;
  final String name;
  final List<RecipeIngredient> items;

  /// Вес готового блюда (после варки/жарки), г. 0 — сумма весов ингредиентов.
  final double cookedGrams;

  /// На сколько порций рассчитан рецепт.
  final int portions;

  const Recipe({
    required this.id,
    required this.name,
    required this.items,
    this.cookedGrams = 0,
    this.portions = 1,
  });

  double get rawGrams => items.fold(0.0, (s, i) => s + i.grams);
  double get weight => cookedGrams > 0 ? cookedGrams : rawGrams;
  double get kcal => items.fold(0.0, (s, i) => s + i.kcal);
  double get protein => items.fold(0.0, (s, i) => s + i.protein);
  double get fat => items.fold(0.0, (s, i) => s + i.fat);
  double get carbs => items.fold(0.0, (s, i) => s + i.carbs);
  double get fiber => items.fold(0.0, (s, i) => s + i.fiber);
  double get salt => items.fold(0.0, (s, i) => s + i.salt);

  /// Вес одной порции, г.
  double get portionGrams => portions > 0 ? weight / portions : weight;

  /// Множитель для [g] граммов готового блюда.
  double factor(double g) => weight > 0 ? g / weight : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items.map((i) => i.toJson()).toList(),
        'cookedGrams': cookedGrams,
        'portions': portions,
      };

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        items: ((j['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => RecipeIngredient.fromJson(Map<String, dynamic>.from(m)))
            .where((i) => i.name.isNotEmpty)
            .toList(),
        cookedGrams: asDouble(j['cookedGrams']),
        portions: asInt(j['portions'], 1).clamp(1, 50).toInt(),
      );
}
