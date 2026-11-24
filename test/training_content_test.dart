import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/i18n/strings_en.dart';
import 'package:kbju_tracker/i18n/strings_pl.dart';
import 'package:kbju_tracker/i18n/strings_uk.dart';
import 'package:kbju_tracker/life/content.dart';

void main() {
  test('встроенные программы ссылаются на существующие упражнения', () {
    final ids = builtinExercises.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'повторяются id упражнений');
    final pids = builtinPrograms.map((p) => p.id).toList();
    expect(pids.toSet().length, pids.length, reason: 'повторяются id программ');
    for (final p in builtinPrograms) {
      expect(p.days, isNotEmpty, reason: p.id);
      expect(p.days.map((d) => d.id).toSet().length, p.days.length, reason: p.id);
      for (final w in p.weekdays) {
        expect(w, inInclusiveRange(1, 7), reason: p.id);
      }
      for (final d in p.days) {
        expect(d.exercises, isNotEmpty, reason: '${p.id}/${d.id}');
        for (final pe in d.exercises) {
          expect(ids, contains(pe.exId), reason: '${p.id}/${d.id}');
          expect(pe.sets, inInclusiveRange(1, 6), reason: '${p.id}/${pe.exId}');
          if (!pe.toFailure) {
            expect(pe.repMin, lessThanOrEqualTo(pe.repMax), reason: '${p.id}/${pe.exId}');
          }
        }
      }
    }
    for (final id in ['gym_ab', 'fullbody_abc', 'machines', 'upper_lower', 'ppl', 'db_home', 'bodyweight', 'hiit_home']) {
      expect(pids, contains(id));
    }
  });

  test('программы и упражнения переведены на английский, польский и украинский', () {
    final texts = <String>[
      for (final e in builtinExercises) ...[e.name, e.technique, e.easier],
      for (final p in builtinPrograms) ...[p.title, p.desc, for (final d in p.days) d.title],
    ].where((t) => t.isNotEmpty).toList();
    for (final dict in [stringsEn, stringsPl, stringsUk]) {
      expect(texts.where((t) => !dict.containsKey(t)).toList(), isEmpty);
    }
  });
}
