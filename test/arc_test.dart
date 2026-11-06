import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/arc/arc_score.dart';
import 'package:kbju_tracker/arc/arc_service.dart';
import 'package:kbju_tracker/life/models.dart';
import 'package:kbju_tracker/models.dart';
import 'package:kbju_tracker/store.dart';
import 'package:kbju_tracker/util.dart';

void main() {
  group('Очки за день', () {
    test('правила', () {
      expect(ArcRules.food(DayStatus.good), 30);
      expect(ArcRules.food(DayStatus.over), 10);
      expect(ArcRules.food(DayStatus.none), 0);
      expect(ArcRules.water(2000, 2000), 10);
      expect(ArcRules.water(1999, 2000), 0);
      expect(ArcRules.water(500, 0), 0);
      expect(ArcRules.sleep(7.5), 20);
      expect(ArcRules.sleep(6.2), 10);
      expect(ArcRules.sleep(4), 0);
      expect(ArcRules.steps(10500, 10000), 20);
      expect(ArcRules.steps(7000, 10000), 10);
      expect(ArcRules.steps(6999, 10000), 0);
      expect(ArcRules.max.values.reduce((a, b) => a + b), 100);
    });

    test('тренировки: в неделю не больше, чем в плане', () {
      final days = ['2026-11-02', '2026-11-03', '2026-11-04', '2026-11-05', '2026-11-09', '2026-11-09'];
      final c = ArcRules.countedWorkoutDays(days, 3);
      expect(c, {'2026-11-02', '2026-11-03', '2026-11-04', '2026-11-09'});
    });

    test('очки считаются из данных приложения', () {
      final s = AppStore();
      final k = todayKey();
      s.life.stepGoal = 10000;
      s.life.steps[k] = 12000;
      final wake = DateTime.now();
      s.life.sleep[k] = SleepEntry(wake.subtract(const Duration(hours: 8)).millisecondsSinceEpoch, wake.millisecondsSinceEpoch);
      final d = arcScores(s, k, k).single;
      expect(d.day, k);
      expect(d.steps, 20);
      expect(d.sleep, 20);
      expect(d.workout, 0);
      expect(d.total, d.food + d.water + 40);
      final week = arcScores(s, dkey(addDays(today(), -6)), k);
      expect(week.length, 7);
      expect(week.first.total, 0);
    });

    test('сравнение с записью сервера', () {
      const d = ArcDay('2026-11-06', food: 30, sleep: 20);
      expect(d.sameAs({'food': 30, 'water': 0, 'sleep': 20, 'steps': 0, 'workout': 0}), isTrue);
      expect(d.sameAs({'food': 10, 'water': 0, 'sleep': 20, 'steps': 0, 'workout': 0}), isFalse);
    });
  });

  group('Рейтинг', () {
    final recs = <Map<String, dynamic>>[
      {'user': 'a', 'name': 'Стас', 'day': '2026-11-06', 'total': 80},
      {'user': 'a', 'name': 'Стас', 'day': '2026-11-05', 'total': 60},
      {'user': 'a', 'name': 'Стас', 'day': '2026-11-04', 'total': 40},
      {'user': 'b', 'name': 'Вова', 'day': '2026-11-06', 'total': 20},
      {'user': 'b', 'name': 'Вова', 'day': '2026-11-05', 'total': 100},
      {'user': 'b', 'name': 'Вова', 'day': '2026-11-04', 'total': 100},
      {'user': 'b', 'name': 'Вова', 'day': '2026-10-20', 'total': 100},
    ];

    test('весь Arc и серия дней', () {
      final rows = ArcService.leaderboard(recs, ArcPeriod.arc, '2026-11-06', '2026-11-01');
      expect(rows.map((r) => r.name), ['Вова', 'Стас']);
      expect(rows[0].points, 220, reason: 'день до старта не считается');
      expect(rows[0].streak, 2, reason: 'сегодня меньше 50 — серия до вчера');
      expect(rows[1].points, 180);
      expect(rows[1].streak, 2);
      expect(rows[1].today, 80);
    });

    test('сегодня', () {
      final rows = ArcService.leaderboard(recs, ArcPeriod.today, '2026-11-06', '2026-11-01');
      expect(rows.map((r) => r.points), [80, 20]);
      expect(rows.first.name, 'Стас');
    });

    test('7 дней', () {
      final rows = ArcService.leaderboard(recs, ArcPeriod.week, '2026-11-06', '2026-10-01');
      expect(rows.first.points, 220);
      expect(rows.first.days, 3);
    });
  });

  test('адрес сервера', () {
    expect(ArcService.normalizeUrl('192.168.1.5'), 'http://192.168.1.5:8090');
    expect(ArcService.normalizeUrl('http://10.0.0.2:9000/'), 'http://10.0.0.2:9000');
    expect(ArcService.normalizeUrl(''), '');
  });
}
