import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/budget/models.dart';

void main() {
  group('Бюджет', () {
    const txs = [
      Tx(id: '1', day: '2026-11-02', amount: 120.5, cat: 'food'),
      Tx(id: '2', day: '2026-11-05', amount: 40, cat: 'transport'),
      Tx(id: '3', day: '2026-11-05', amount: 2400, cat: 'salary', income: true),
      Tx(id: '4', day: '2026-11-20', amount: 30, cat: 'food'),
      Tx(id: '5', day: '2026-10-30', amount: 999, cat: 'games'),
    ];

    test('итог месяца по категориям', () {
      final m = summarizeMonth(txs, 2026, 11);
      expect(m.income, 2400);
      expect(m.expense, closeTo(190.5, 0.001));
      expect(m.balance, closeTo(2209.5, 0.001));
      expect(m.byCat['food'], closeTo(150.5, 0.001));
      expect(m.topCats.first.key, 'food');
    });

    test('еда из КБЖУ добавляется к тратам', () {
      final m = summarizeMonth(txs, 2026, 11, extraExpense: {kbjuFoodCat.id: 300, 'zero': 0});
      expect(m.expense, closeTo(490.5, 0.001));
      expect(m.byCat[kbjuFoodCat.id], 300);
      expect(m.byCat.containsKey('zero'), isFalse);
      expect(catById(kbjuFoodCat.id).name, contains('КБЖУ'));
      expect(catById('нет такой').id, 'other');
    });

    test('сколько можно тратить в день', () {
      // Ноябрь — 30 дней, сегодня 21-е: осталось 10 дней включая сегодня.
      expect(perDayLeft(1500, 500, 2026, 11, DateTime(2026, 11, 21)), 100);
      expect(perDayLeft(1500, 1600, 2026, 11, DateTime(2026, 11, 21)), 0);
      expect(perDayLeft(0, 100, 2026, 11, DateTime(2026, 11, 21)), isNull);
      expect(perDayLeft(1500, 0, 2026, 10, DateTime(2026, 11, 21)), isNull); // прошлый месяц
      expect(perDayLeft(3100, 0, 2026, 12, DateTime(2026, 11, 21)), 100); // будущий — весь месяц
    });

    test('копилки', () {
      const g = Goal(id: 'g', name: 'Телефон маме', target: 2500, saved: 1000);
      expect(g.progress, closeTo(0.4, 0.001));
      expect(g.left, 1500);
      expect(monthsToGoal(g, 400), 4);
      expect(monthsToGoal(g, 0), isNull);
      expect(monthsToGoal(g.copyWith(saved: 2600), 100), 0);
      expect(Goal.fromJson(g.toJson())!.name, 'Телефон маме');
    });

    test('записи по дням, история и сохранение', () {
      final days = byDay(txs, 2026, 11);
      expect(days.map((e) => e.key), ['2026-11-20', '2026-11-05', '2026-11-02']);
      expect(days[1].value.length, 2);
      expect(expenseHistory(txs, 2026, 11, 2), [999, closeTo(190.5, 0.001)]);
      final back = Tx.fromJson(txs[2].toJson())!;
      expect(back.income, isTrue);
      expect(back.amount, 2400);
      expect(Tx.fromJson({'d': 'плохо', 'a': 1}), isNull);
      expect(Tx.fromJson({'d': '2026-11-01', 'a': 0}), isNull);
    });

    test('сумма из текста', () {
      expect(parseAmount('12,50'), 12.5);
      expect(parseAmount('1 200'), 1200);
      expect(parseAmount('0'), isNull);
      expect(parseAmount('abc'), isNull);
    });
  });
}
