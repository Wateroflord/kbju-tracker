import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/pushups/counter.dart';

/// Прогнать последовательность углов, шаг 100 мс.
RepCounter run(List<double> angles, {int stepMs = 100}) {
  final c = RepCounter();
  var t = 0;
  for (final a in angles) {
    c.update(a, t);
    t += stepMs;
  }
  return c;
}

void main() {
  test('правильные отжимания засчитываются', () {
    final c = run([170, 140, 110, 90, 85, 110, 140, 165, 170, 120, 88, 130, 168]);
    expect(c.reps, 2);
    expect(c.rejected, 0);
  });

  test('без упора лёжа (прямых рук) счёт не начинается', () {
    final c = run([90, 80, 120, 140]);
    expect(c.reps, 0);
    expect(c.ready, false);
  });

  test('неглубокое отжимание — «Ниже!»', () {
    final c = run([170, 130, 115, 130, 165]);
    expect(c.reps, 0);
    expect(c.rejected, 1);
    expect(c.hint, RepHint.lower);
  });

  test('не выпрямил руки — «Выпрями руки!»', () {
    final c = run([170, 90, 130, 90, 170]);
    expect(c.reps, 1); // в итоге выпрямил — одно отжимание
    expect(c.rejected, 1);
  });

  test('слишком быстрые повторы не засчитываются', () {
    final c = run([170, 90, 170, 90, 170], stepMs: 100);
    expect(c.reps, 1);
    expect(c.hint, RepHint.tooFast);
  });
}
