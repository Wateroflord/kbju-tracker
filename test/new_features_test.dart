import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/arc/arc_service.dart';
import 'package:kbju_tracker/food/food_models.dart';
import 'package:kbju_tracker/food/meal_plan.dart';
import 'package:kbju_tracker/screens/interval_timer_screen.dart';

RecipeIngredient ing(String name, double g) => RecipeIngredient(name: name, grams: g, kcal: g, protein: 0, fat: 0, carbs: 0);

void main() {
  group('план питания → список покупок', () {
    final plov = Recipe(id: 'plov', name: 'Плов', portions: 4, items: [ing('Рис', 400), ing('Курица', 600), ing('Морковь', 200)]);
    final grecha = Recipe(id: 'gr', name: 'Гречка с курицей', items: [ing('гречка', 100), ing('курица ', 150)]);

    test('порции и одинаковые продукты складываются', () {
      final plan = {
        1: [const PlanMeal('plov', 2)], // половина плова
        2: [const PlanMeal('gr', 1), const PlanMeal('gr', 1)],
        3: [const PlanMeal('deleted', 1)], // рецепт удалён — пропускаем
      };
      final list = planShopping([plov, grecha], plan);
      final m = {for (final p in list) p.name.toLowerCase(): p.grams};
      expect(m['рис'], 200);
      expect(m['курица'], 300 + 300); // «Курица» и «курица » — один продукт
      expect(m['морковь'], 100);
      expect(m['гречка'], 200);
      expect(list.length, 4);
    });

    test('сохранение плана', () {
      expect(PlanMeal.fromJson(const PlanMeal('x', 1.5).toJson())!.portions, 1.5);
      expect(PlanMeal.fromJson({'r': '', 'p': 1}), isNull);
      expect(PlanMeal.fromJson('мусор'), isNull);
    });

    test('граммы текстом', () {
      expect(gramsText(600), '600 г');
      expect(gramsText(1250), '1,3 кг');
      expect(gramsText(2000), '2 кг');
      expect(gramsText(3), '3 г');
      expect(planShopId('Курица '), planShopId('курица'));
    });
  });

  group('Winter Arc', () {
    test('кто обогнал', () {
      expect(ArcService.overtakers(['a', 'me', 'b', 'c'], ['a', 'c', 'me', 'b'], 'me'), ['c']);
      expect(ArcService.overtakers(['me', 'b'], ['me', 'b'], 'me'), isEmpty);
      expect(ArcService.overtakers([], ['b', 'me'], 'me'), isEmpty); // первая синхронизация — молчим
      expect(ArcService.overtakers(['me'], ['new', 'me'], 'me'), isEmpty); // новенький — не «обогнал»
    });

    test('челлендж недели одинаковый всю неделю и меняется в понедельник', () {
      final mon = DateTime(2026, 11, 23), sun = DateTime(2026, 11, 29), nextMon = DateTime(2026, 11, 30);
      expect(weekStart(sun), mon);
      expect(challengeFor(mon).cat, challengeFor(sun).cat);
      expect(challengeFor(nextMon).cat, isNot(challengeFor(sun).cat));
    });

    test('рейтинг категории за неделю', () {
      final recs = [
        {'day': '2026-11-23', 'user': 'a', 'name': 'Аня', 'steps': 20, 'total': 50},
        {'day': '2026-11-24', 'user': 'a', 'name': 'Аня', 'steps': 10, 'total': 60},
        {'day': '2026-11-24', 'user': 'b', 'name': 'Боря', 'steps': 20, 'total': 90},
        {'day': '2026-11-16', 'user': 'b', 'name': 'Боря', 'steps': 20, 'total': 90}, // прошлая неделя
      ];
      final rows = ArcService.categoryBoard(recs, 'steps', '2026-11-23', '2026-11-29');
      expect(rows.first.userId, 'a');
      expect(rows.first.points, 30);
      expect(rows[1].points, 20);
    });
  });

  test('таймер круговой: табата, EMOM, свой', () {
    final t = buildIntervals(IntervalMode.tabata);
    expect(t.first.kind, 'prep');
    expect(t.where((s) => s.kind == 'work').length, 8);
    expect(t.where((s) => s.kind == 'rest').length, 7); // после последнего раунда отдыха нет
    expect(t.fold<int>(0, (s, x) => s + x.seconds), 10 + 8 * 20 + 7 * 10);
    final e = buildIntervals(IntervalMode.emom, rounds: 12);
    expect(e.where((s) => s.kind == 'work').every((s) => s.seconds == 60), isTrue);
    expect(e.where((s) => s.kind == 'work').length, 12);
    final c = buildIntervals(IntervalMode.custom, work: 40, rest: 0, rounds: 3);
    expect(c.where((s) => s.kind == 'rest'), isEmpty);
  });
}
