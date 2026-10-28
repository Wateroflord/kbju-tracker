import '../util.dart';
import 'life_store.dart';
import 'models.dart';
import '../i18n/i18n.dart';

class ExerciseRecord {
  final double value; // кг, повторы или секунды
  final int reps;
  final String date;
  const ExerciseRecord(this.value, this.reps, this.date);
}

/// Расчётный максимум на 1 повтор (формула Эпли). Для 1 повтора — сам вес.
double e1rm(double weight, int reps) {
  if (weight <= 0 || reps <= 0) return 0;
  if (reps == 1) return weight;
  return weight * (1 + reps / 30);
}

/// Процент от 1ПМ для заданного числа повторов (обратная формула Эпли).
double pctForReps(int reps) => reps <= 1 ? 1.0 : 1 / (1 + reps / 30);

/// Расчёты по тренировкам: прогрессия, рекорды, история веса.
extension TrainingCalc on LifeStore {
  /// Подсказка, что делать сегодня, по прошлой тренировке.
  String? progressionHint(PlanExercise pe, {String? exceptSessionId}) {
    final last = lastSetsOf(pe.exId, exceptSessionId: exceptSessionId);
    if (last == null || last.isEmpty) return null;
    final ex = exerciseById(pe.exId);
    final unit = ex.timed ? tr('с') : '';
    final prev = last.map((s) => '${s.reps}$unit').join(', ');
    final w = last.first.weight;
    final head = (w > 0 && !ex.bodyweight)
        ? trf('Прошлый раз: {0} кг × {1}', [fmt1(w), prev])
        : trf('Прошлый раз: {0}', [prev]);

    final allSets = last.length >= pe.sets;
    if (pe.toFailure) {
      return trf('{0}. Попробуй +1 повтор в каждом подходе.', [head]);
    }
    final top = allSets && last.take(pe.sets).every((s) => s.reps >= pe.repMax);
    if (!top) return trf('{0}. Цель — дойти до {1}{2} во всех подходах.', [head, pe.repMax, unit]);
    if (ex.timed) return trf('{0}. Все подходы по верхней границе — добавь 10 секунд.', [head]);
    if (ex.bodyweight || w <= 0) return trf('{0}. Все подходы по верхней границе — добавь +1 повтор или усложни вариант.', [head]);
    return trf('{0}. Все подходы по верхней границе — сегодня ставь {1} кг.', [head, fmt1(w + 2.5)]);
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

  /// Расчётный 1ПМ по датам (лучший подход за тренировку). Только для упражнений с весом.
  List<MapEntry<String, double>> e1rmHistory(String exId) {
    final ex = exerciseById(exId);
    if (ex.bodyweight || ex.timed) return const [];
    final out = <String, double>{};
    for (final s in sessions) {
      if (!s.finished) continue;
      for (final e in s.exercises) {
        if (e.exId != exId) continue;
        for (final set in e.sets) {
          if (!set.done || set.weight <= 0 || set.reps <= 0 || set.reps > 20) continue;
          final v = e1rm(set.weight, set.reps);
          if (v > (out[s.date] ?? 0)) out[s.date] = v;
        }
      }
    }
    return out.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  /// Лучший расчётный 1ПМ за всё время.
  double bestE1rm(String exId) {
    var best = 0.0;
    for (final e in e1rmHistory(exId)) {
      if (e.value > best) best = e.value;
    }
    return best;
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
