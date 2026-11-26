import 'food_models.dart';

/// Блюдо в плане питания: рецепт и сколько порций.
class PlanMeal {
  final String recipeId;
  final double portions;
  const PlanMeal(this.recipeId, this.portions);

  Map<String, dynamic> toJson() => {'r': recipeId, 'p': portions};

  static PlanMeal? fromJson(dynamic j) {
    if (j is! Map) return null;
    final id = j['r']?.toString() ?? '';
    final p = j['p'];
    final portions = p is num ? p.toDouble() : double.tryParse('$p') ?? 1;
    if (id.isEmpty || portions <= 0) return null;
    return PlanMeal(id, portions);
  }
}

/// Продукт для списка покупок: сколько граммов нужно на всю неделю.
class PlanProduct {
  final String name; // как в рецепте (первое написание)
  final double grams;
  const PlanProduct(this.name, this.grams);
}

String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ').replaceAll('ё', 'е');

/// Что купить на неделю: ингредиенты всех блюд плана, одинаковые продукты сложены.
/// Порции считаются от порций рецепта: 2 порции рецепта «на 4 порции» = половина ингредиентов.
List<PlanProduct> planShopping(List<Recipe> recipes, Map<int, List<PlanMeal>> plan) {
  final byId = {for (final r in recipes) r.id: r};
  final grams = <String, double>{};
  final names = <String, String>{};
  for (final day in plan.values) {
    for (final m in day) {
      final r = byId[m.recipeId];
      if (r == null || r.portions <= 0) continue;
      final k = m.portions / r.portions;
      for (final i in r.items) {
        final key = _norm(i.name);
        if (key.isEmpty) continue;
        names.putIfAbsent(key, () => i.name.trim());
        grams[key] = (grams[key] ?? 0) + i.grams * k;
      }
    }
  }
  final out = [for (final e in grams.entries) PlanProduct(names[e.key]!, e.value)];
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

/// Ключ товара в списке покупок — чтобы повторное «добавить» обновляло, а не дублировало.
String planShopId(String name) => 'plan_${_norm(name).replaceAll(RegExp(r'[^a-zа-яіїєґ0-9]+'), '_')}';

/// «600 г», «1,2 кг».
String gramsText(double g, {String gUnit = 'г', String kgUnit = 'кг'}) {
  if (g >= 1000) {
    final kg = (g / 100).round() / 10;
    final s = kg == kg.roundToDouble() ? kg.toStringAsFixed(0) : kg.toStringAsFixed(1).replaceAll('.', ',');
    return '$s $kgUnit';
  }
  return '${(g / 10).round() * 10 == 0 ? g.round() : (g / 10).round() * 10} $gUnit';
}
