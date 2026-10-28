import '../util.dart';
import 'life_store.dart';
import 'models.dart';

class ExerciseRecord {
  final double value; // кг, повторы или секунды
  final int reps;
  final String date;
  const ExerciseRecord(this.value, this.reps, this.date);
}

/// Расчёты по тренировкам: прогрессия, рекорды, история веса.
extension TrainingCalc on LifeStore {
  /// Подсказка, что делать сегодня, по прошлой тренировке.
  String? progressionHint(PlanExercise pe, {String? exceptSessionId}) {
    final last = lastSetsOf(pe.exId, exceptSessionId: exceptSessionId);
    if (last == null || last.isEmpty) return null;
    final ex = exerciseById(pe.exId);
    final unit = ex.timed ? 'с' : '';
    final prev = last.map((s) => '${s.reps}$unit').join(', ');
    final w = last.first.weight;
    final head = (w > 0 && !ex.bodyweight)
        ? 'Прошлый раз: ${fmt1(w)} кг × $prev'
        : 'Прошлый раз: $prev';

    final allSets = last.length >= pe.sets;
    if (pe.toFailure) {
      return '$head. Попробуй +1 повтор в каждом подходе.';
    }
    final top = allSets && last.take(pe.sets).every((s) => s.reps >= pe.repMax);
    if (!top) return '$head. Цель — дойти до ${pe.repMax}$unit во всех подходах.';
    if (ex.timed) return '$head. Все подходы по верхней границе — добавь 10 секунд.';
    if (ex.bodyweight || w <= 0) return '$head. Все подходы по верхней границе — добавь +1 повтор или усложни вариант.';
    return '$head. Все подходы по верхней границе — сегодня ставь ${fmt1(w + 2.5)} кг.';
  }

  /// Лучший результат: для упражнений с весом — максимальный вес, иначе — повторы/секунды.
  ExerciseRecord? recordOf(String exId) {
    final ex = exerciseById(exId);
    ExerciseRecord? best;
    for (final s in sessions) {
      if (!s.finished) continue;
      for (final e in s.exercises) {
        if (e.exId != exId) continue;
        for (final set in e.sets) {
          if (!set.done) continue;
          final useWeight = !ex.bodyweight && !ex.timed && set.weight > 0;
          final v = useWeight ? set.weight : set.reps.toDouble();
          if (best == null || v > best.value || (v == best.value && set.reps > best.reps)) {
            best = ExerciseRecord(v, set.reps, s.date);
          }
        }
      }
    }
    return best;
  }

  /// Рабочий вес (или повторы) по датам: максимум за тренировку.
  List<MapEntry<String, double>> historyOf(String exId) {
    final ex = exerciseById(exId);
    final out = <String, double>{};
    for (final s in sessions) {
      if (!s.finished) continue;
      for (final e in s.exercises) {
        if (e.exId != exId) continue;
        for (final set in e.sets) {
          if (!set.done) continue;
          final useWeight = !ex.bodyweight && !ex.timed && set.weight > 0;
          final v = useWeight ? set.weight : set.reps.toDouble();
          if (v > (out[s.date] ?? -1)) out[s.date] = v;
        }
      }
    }
    final list = out.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return list;
  }

  /// Упражнения, которые хотя бы раз выполнялись.
  List<String> trainedExerciseIds() {
    final ids = <String>{};
    for (final s in sessions) {
      if (!s.finished) continue;
      for (final e in s.exercises) {
        if (e.sets.any((x) => x.done)) ids.add(e.exId);
      }
    }
    return ids.toList();
  }

  /// План упражнения для сессии (из программы), если найден.
  PlanExercise planFor(Session s, String exId) {
    final p = programById(s.programId);
    if (p != null) {
      for (final d in p.days) {
        if (d.id != s.dayId) continue;
        for (final pe in d.exercises) {
          if (pe.exId == exId) return pe;
        }
      }
    }
    return PlanExercise(exId, 3, 8, 12);
  }

  /// Тренировок за последние 7 дней.
  int sessionsLast7() => finishedSessionsBetween(addDays(today(), -6), addDays(today(), 1));
}
