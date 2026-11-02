// Проверки расчётов. Запускаются на GitHub перед каждой сборкой:
// если что-то сломалось, сборка остановится и покажет, какая проверка не прошла.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/calc.dart';
import 'package:kbju_tracker/data_export.dart';
import 'package:kbju_tracker/extra_store.dart';
import 'package:kbju_tracker/food/fill_advisor.dart';
import 'package:kbju_tracker/food/food_models.dart';
import 'package:kbju_tracker/gemini.dart';
import 'package:kbju_tracker/models.dart';
import 'package:kbju_tracker/store.dart';
import 'package:kbju_tracker/sync/merge.dart';

FoodEntry entry(String id, String date, double kcal, {double protein = 10, double fiber = 0, double salt = 0}) => FoodEntry(
      id: id,
      date: date,
      time: DateTime.parse('${date}T12:00:00').millisecondsSinceEpoch,
      meal: Meal.lunch,
      name: 'Еда $id',
      grams: 100,
      kcal: kcal,
      protein: protein,
      fat: 5,
      carbs: 20,
      fiber: fiber,
      salt: salt,
    );

const profile = Profile(sex: Sex.male, age: 25, heightCm: 180, weightKg: 80, activity: 2, goal: Goal.maintain);

void main() {
  group('Нормы', () {
    test('калории и БЖУ в разумных пределах', () {
      final t = computeTargets(profile);
      expect(t.kcal, inInclusiveRange(2200, 3200));
      expect(t.protein, greaterThan(80));
      expect(t.waterMl, greaterThan(1500));
    });

    test('ориентир клетчатки', () {
      expect(fiberTarget(2000), 28);
      expect(fiberTarget(1000), 20); // не меньше 20
      expect(fiberTarget(0), 25);
    });
  });

  group('Записи о еде', () {
    test('клетчатка и соль сохраняются и читаются', () {
      final e = entry('1', '2026-11-02', 300, fiber: 4.5, salt: 1.2);
      final back = FoodEntry.fromJson(jsonDecode(jsonEncode(e.toJson())) as Map<String, dynamic>);
      expect(back.fiber, 4.5);
      expect(back.salt, 1.2);
    });

    test('старые записи без клетчатки не меняются при сохранении', () {
      final e = entry('1', '2026-11-02', 300);
      expect(e.toJson().containsKey('fiber'), isFalse);
      expect(e.toJson().containsKey('salt'), isFalse);
    });

    test('итоги дня считают клетчатку и соль', () {
      final t = Totals()
        ..add(entry('1', '2026-11-02', 300, fiber: 3, salt: 1))
        ..add(entry('2', '2026-11-02', 200));
      expect(t.kcal, 500);
      expect(t.fiber, 3);
      expect(t.salt, 1);
      expect(t.microCount, 1);
    });

    test('удаление и возврат записи', () {
      final s = AppStore();
      s.addEntries([entry('a', '2026-11-02', 300)]);
      final removed = s.deleteEntry('a');
      expect(s.entries, isEmpty);
      s.restoreEntry(removed!);
      expect(s.entries.single.id, 'a');
      s.restoreEntry(removed); // повторно не дублируется
      expect(s.entries.length, 1);
    });
  });

  group('Рецепты', () {
    const r = Recipe(
      id: 'r1',
      name: 'Плов',
      portions: 4,
      cookedGrams: 1000,
      items: [
        RecipeIngredient(name: 'Рис', grams: 300, kcal: 1050, protein: 21, fat: 3, carbs: 230),
        RecipeIngredient(name: 'Курица', grams: 500, kcal: 550, protein: 105, fat: 12, carbs: 0),
      ],
    );

    test('КБЖУ на 100 г считается от веса готового блюда', () {
      final k = r.factor(100);
      expect(r.kcal * k, closeTo(160, 0.01));
      expect(r.protein * k, closeTo(12.6, 0.01));
      expect(r.portionGrams, 250);
    });

    test('без веса готового блюда берётся сумма ингредиентов', () {
      final raw = Recipe(id: 'r2', name: 'Салат', items: r.items);
      expect(raw.weight, 800);
    });

    test('рецепт сохраняется и читается', () {
      final back = Recipe.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
      expect(back.items.length, 2);
      expect(back.portions, 4);
      expect(back.kcal, 1600);
    });

    test('порция пересчитывается по весу', () {
      const it = AiFoodItem(name: 'x', grams: 200, kcal: 400, protein: 20, fat: 10, carbs: 50, fiber: 4, salt: 1);
      final half = it.scaled(100);
      expect(half.kcal, 200);
      expect(half.protein, 10);
      expect(half.fiber, 2);
      expect(half.salt, 0.5);
    });
  });

  group('Чем добрать норму', () {
    test('подбирает свои продукты, которые влезают в остаток', () {
      final s = AppStore();
      s.saveProfile(profile);
      final key = DateTime.now().toIso8601String().substring(0, 10);
      s.addEntries([entry('a', key, 1200, protein: 40)]);
      s.food.toggleFavorite(const FavFood(id: 'f1', name: 'Творог', grams: 200, kcal: 220, protein: 36, fat: 4, carbs: 8));
      s.food.toggleFavorite(const FavFood(id: 'f2', name: 'Торт', grams: 100, kcal: 450, protein: 4, fat: 25, carbs: 50));
      final ideas = FillAdvisor.local(s, key);
      final names = ideas.map((i) => i.item.name).toList();
      expect(names, contains('Творог'));
      if (names.contains('Торт')) expect(names.indexOf('Творог'), lessThan(names.indexOf('Торт')));
      for (final i in ideas) {
        expect(i.item.kcal, lessThanOrEqualTo(Remaining.of(s, key).kcal * 1.15));
      }
    });
  });

  group('Настройки', () {
    test('скрытые вкладки и тренировки с часов сохраняются', () {
      final a = ExtraStore(() {});
      a.setTabVisible('care', false);
      a.setHc(workouts: true);
      a.setHcDay('2026-11-01', [const HcWorkout(start: 1000, end: 1801000, type: 'RUNNING', kcal: 300)]);
      final b = ExtraStore(() {})..load(jsonDecode(jsonEncode(a.toJson())));
      expect(b.tabVisible('care'), isFalse);
      expect(b.tabVisible('learn'), isTrue);
      expect(b.hcWorkouts, isTrue);
      expect(b.hcLog['2026-11-01']!.single.minutes, 30);
    });
  });

  group('Синхронизация', () {
    test('записи, добавленные на обоих устройствах, объединяются', () {
      final base = {'entries': []};
      final a = {
        'entries': [
          {'id': '1', 'kcal': 100}
        ]
      };
      final b = {
        'entries': [
          {'id': '2', 'kcal': 200}
        ]
      };
      final m = merge3(base, a, b, aNewer: true) as Map;
      expect((m['entries'] as List).length, 2);
    });
  });

  group('Выгрузка CSV', () {
    test('название с запятой берётся в кавычки', () {
      final s = AppStore();
      s.addEntries([
        FoodEntry(
            id: 'x', date: '2026-11-02', time: 0, meal: Meal.dinner, name: 'Суп, хлеб', grams: 300, kcal: 250, protein: 10, fat: 8, carbs: 30),
      ]);
      final csv = DataExport.foodCsv(s);
      expect(csv.split('\n').first, startsWith('date,time,meal,name'));
      expect(csv, contains('"Суп, хлеб"'));
    });
  });
}
