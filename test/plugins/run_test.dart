import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/walks/run_model.dart';

/// Точки на север: ~[stepM] метров за [stepSec] секунд.
List<RunPoint> line(int n, {double stepM = 10, int stepSec = 3, int t0 = 0, double lat0 = 50.0}) {
  const mPerDeg = 111195.0; // метров в градусе широты
  return [for (var i = 0; i < n; i++) RunPoint(lat0 + i * stepM / mPerDeg, 19.9, t0 + i * stepSec * 1000)];
}

void main() {
  group('Пробежки', () {
    test('фильтр GPS', () {
      const a = RunPoint(50, 19.9, 0);
      expect(acceptPoint(null, a, 10), isTrue);
      expect(acceptPoint(null, a, 60), isFalse); // неточная
      expect(acceptPoint(a, RunPoint(50.00001, 19.9, 1000), 5), isFalse); // ~1 м — дрожание
      expect(acceptPoint(a, RunPoint(50.0001, 19.9, 3000), 5), isTrue); // ~11 м за 3 с
      expect(acceptPoint(a, RunPoint(50.001, 19.9, 1000), 5), isFalse); // 111 м за 1 с — телепорт
    });

    test('дистанция, отрезки по километрам и темп', () {
      // 251 точка по 10 м каждые 3 с → 2,5 км, 5:00 на километр.
      final seg = line(251);
      expect(totalM([seg]), closeTo(2500, 5));
      final sp = splits([seg]);
      expect(sp.length, 2);
      expect(sp.first, closeTo(300, 2));
      expect(paceText(paceOf(2500, 750)), '5:00');
      expect(paceText(recentPace(seg)), '5:00');
      expect(paceText(double.nan), isNull);
    });

    test('пауза не ломает отрезки', () {
      final a = line(51); // 500 м
      final b = line(52, t0: 10 * 60 * 1000, lat0: 50.01); // после паузы 10 минут, ещё 510 м
      final sp = splits([a, b]);
      expect(sp.length, 1);
      expect(sp.single, closeTo(300, 2)); // пауза в километр не попала
    });

    test('форматирование', () {
      expect(durText(65), '01:05');
      expect(durText(3725), '1:02:05');
      expect(kmText(5234), '5,23');
    });

    test('прореживание и сохранение', () {
      final seg = line(100, stepM: 4);
      final t = thin(seg);
      expect(t.length, lessThan(seg.length));
      expect(t.first.t, seg.first.t);
      expect(t.last.t, seg.last.t);
      final r = Run(id: '1', start: 0, seconds: 750, meters: 2500, segments: [t], splitSec: const [300, 301]);
      final back = Run.fromJson(r.toJson())!;
      expect(back.meters, 2500);
      expect(back.segments.single.length, t.length);
      expect(back.splitSec, [300, 301]);
    });

    test('рекорды и неделя', () {
      final now = DateTime(2026, 11, 28);
      final runs = [
        Run(id: 'a', start: DateTime(2026, 11, 27).millisecondsSinceEpoch, seconds: 1500, meters: 5000, splitSec: const [310, 290]),
        Run(id: 'b', start: DateTime(2026, 11, 1).millisecondsSinceEpoch, seconds: 1000, meters: 3000, splitSec: const [330]),
      ];
      final rec = records(runs);
      expect(rec.longest!.id, 'a');
      expect(rec.fastestKmSec, 290);
      expect(rec.best5k!.id, 'a');
      expect(kmLastDays(runs, now), 5);
    });
  });
  test('какие пробежки идут в Winter Arc', () {
    final d = DateTime(2026, 11, 28, 9);
    final runs = [
      Run(id: 'a', start: d.millisecondsSinceEpoch, seconds: 600, meters: 2100),
      Run(id: 'b', start: d.add(const Duration(days: 1)).millisecondsSinceEpoch, seconds: 16 * 60, meters: 1500),
      Run(id: 'c', start: d.add(const Duration(days: 2)).millisecondsSinceEpoch, seconds: 300, meters: 900),
    ];
    expect(arcRunDays(runs), {'2026-11-28', '2026-11-29'});
  });
}
