import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/food/food_guide.dart';

void main() {
  test('тир-лист: от SSS до D, гречка и рис в SSS', () {
    expect(foodTiers.map((t) => t.tier), ['SSS', 'SS', 'S', 'A', 'B', 'C', 'D']);
    final sss = foodTiers.first.foods.map((f) => f.$1);
    expect(sss, containsAll(['Гречка', 'Рис']));
    final all = [for (final t in foodTiers) ...t.foods.map((f) => f.$1)];
    expect(all.toSet().length, all.length, reason: 'продукт в двух тирах');
  });

  test('блюда: все продукты известны, КБЖУ правдоподобные', () {
    final dishes = [...simpleDishes, ...tastyDishes];
    expect(simpleDishes.length, greaterThanOrEqualTo(6));
    expect(tastyDishes.length, greaterThanOrEqualTo(6));
    expect(dishes.map((d) => d.name).toSet().length, dishes.length);
    for (final d in dishes) {
      for (final (name, grams) in d.items) {
        expect(guideFoods.containsKey(name), isTrue, reason: '${d.name}: нет продукта «$name»');
        expect(grams, greaterThan(0));
      }
      final n = d.perPortion;
      expect(n.kcal, inInclusiveRange(250, 1000), reason: d.name);
      expect(n.p, greaterThan(10), reason: '${d.name}: мало белка');
      // калории сходятся с БЖУ (4/9/4 ккал на грамм) с допуском
      expect((n.p * 4 + n.f * 9 + n.c * 4 - n.kcal).abs() / n.kcal, lessThan(0.15), reason: d.name);
      expect(d.steps, isNotEmpty);
    }
  });

  test('блюдо сохраняется как рецепт с теми же КБЖУ', () {
    for (final d in [...simpleDishes, ...tastyDishes]) {
      final r = d.toRecipe('r1');
      expect(r.name, d.name);
      expect(r.portions, d.portions);
      expect((r.kcal / r.portions - d.perPortion.kcal).abs(), lessThan(0.01));
    }
  });
}
