import 'dart:ui';

import 'package:kbju_tracker/plugins/draw/course.dart';
import 'package:kbju_tracker/plugins/draw/shapes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lessons = [for (final m in course) ...m.lessons];

  test('курс не пустой, у уроков уникальные id', () {
    expect(course, isNotEmpty);
    final ids = <String>{};
    for (final l in lessons) {
      expect(ids.add(l.id), isTrue, reason: 'повтор id ${l.id}');
      expect(l.title.trim(), isNotEmpty, reason: l.id);
      expect(l.pages.isNotEmpty || l.exercises.isNotEmpty, isTrue, reason: l.id);
    }
  });

  test('подсказки для обводки рисуются внутри холста', () {
    const size = Size(400, 400);
    final area = const Rect.fromLTWH(0, 0, 400, 400).inflate(40);
    for (final l in lessons) {
      for (final e in l.exercises) {
        expect(e.task.trim(), isNotEmpty, reason: l.id);
        expect(e.seconds, greaterThanOrEqualTo(0), reason: l.id);
        if (!e.trace) continue;
        for (final g in e.guide.where((g) => g is! Special)) {
          final pts = g.samples(size);
          expect(pts, isNotEmpty, reason: '${l.id}: пустая подсказка');
          for (final p in pts) {
            expect(area.contains(p), isTrue, reason: '${l.id}: точка $p за краем холста');
          }
        }
      }
    }
  });

  test('ломаные и кривые описаны полными координатами', () {
    for (final l in lessons) {
      for (final g in [for (final p in l.pages) ...p.art, for (final e in l.exercises) ...e.guide]) {
        if (g is Poly) expect(g.xy.length.isEven && g.xy.length >= 4, isTrue, reason: l.id);
        if (g is Curve) expect(g.xy.length >= 8 && (g.xy.length - 2) % 6 == 0, isTrue, reason: l.id);
      }
    }
  });

  test('ежедневные задания: темы и условия без повторов', () {
    expect(challengeSubjects.toSet().length, challengeSubjects.length);
    expect(challengeConditions.toSet().length, challengeConditions.length);
  });
}
