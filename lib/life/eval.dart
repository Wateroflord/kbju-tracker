import 'dart:math' as math;

import '../models.dart';
import '../store.dart';
import '../util.dart';
import 'models.dart';

/// Расчёты по привычкам, которым нужны данные еды, воды и веса из AppStore.
extension LifeEval on AppStore {
  bool habitAutoDone(Habit h, DateTime d) {
    final k = dkey(d);
    switch (h.auto) {
      case HabitAuto.none:
        return false;
      case HabitAuto.steps:
        return life.stepsFor(k) >= life.stepGoal;
      case HabitAuto.food:
        return statusFor(k) == DayStatus.good;
      case HabitAuto.water:
        final t = targetsFor(k).waterMl;
        return t > 0 && waterFor(k) >= t;
      case HabitAuto.sleep:
        final s = life.sleepFor(k);
        return s != null && s.hours >= 7;
      case HabitAuto.workouts:
        final ws = weekStart(d);
        return life.finishedSessionsBetween(ws, addDays(ws, 7)) >= workoutsPerWeek;
      case HabitAuto.weigh:
        final ws = weekStart(d);
        for (var i = 0; i < 7; i++) {
          if (weights.containsKey(dkey(addDays(ws, i)))) return true;
        }
        return false;
    }
  }

  int get workoutsPerWeek => math.max(1, life.weekdaysOf(life.activeProgram).length);

  bool habitDoneOn(Habit h, DateTime d) => life.manualDone(h, d) || habitAutoDone(h, d);

  /// Короткая подпись прогресса для автоматических привычек.
  String? habitProgress(Habit h, DateTime d) {
    final k = dkey(d);
    switch (h.auto) {
      case HabitAuto.none:
        return null;
      case HabitAuto.steps:
        return '${fmtInt(life.stepsFor(k))} / ${fmtInt(life.stepGoal)} шагов';
      case HabitAuto.food:
        final t = totalsFor(k);
        return '${fmtInt(t.kcal)} / ${fmtInt(targetsFor(k).kcal)} ккал';
      case HabitAuto.water:
        return '${fmtInt(waterFor(k))} / ${fmtInt(targetsFor(k).waterMl)} мл';
      case HabitAuto.sleep:
        final s = life.sleepFor(k);
        return s == null ? 'сон не записан' : '${fmt1(s.hours)} ч';
      case HabitAuto.workouts:
        final ws = weekStart(d);
        return '${life.finishedSessionsBetween(ws, addDays(ws, 7))} / $workoutsPerWeek за неделю';
      case HabitAuto.weigh:
        return habitAutoDone(h, d) ? 'вес записан' : 'вес не записан';
    }
  }

  /// Доля выполненных ежедневных привычек за день (0..1). null — нет включённых привычек.
  double? dailyRatio(DateTime d) {
    final list = life.habitsOf(HabitPeriod.daily);
    if (list.isEmpty) return null;
    final done = list.where((h) => habitDoneOn(h, d)).length;
    return done / list.length;
  }

  /// Дней подряд, когда выполнено не меньше 80% ежедневных привычек.
  /// Сегодня засчитывается, если уже выполнено; иначе серия считается со вчера.
  int dayStreak() {
    var d = today();
    final r0 = dailyRatio(d);
    if (r0 == null) return 0;
    if (r0 < 0.8) d = addDays(d, -1);
    var n = 0;
    while (n < 3650) {
      final r = dailyRatio(d);
      if (r == null || r < 0.8) break;
      n++;
      d = addDays(d, -1);
    }
    return n;
  }

  /// Серия по одной привычке: дней / недель / месяцев подряд.
  int habitStreak(Habit h) {
    DateTime step(DateTime d) => switch (h.period) {
          HabitPeriod.daily => addDays(d, -1),
          HabitPeriod.weekly => addDays(weekStart(d), -7),
          HabitPeriod.monthly => DateTime(d.year, d.month - 1, 1),
        };
    var d = today();
    if (!habitDoneOn(h, d)) d = step(d);
    var n = 0;
    while (n < 1000 && habitDoneOn(h, d)) {
      n++;
      d = step(d);
    }
    return n;
  }

  /// Процент выполнения ежедневных привычек за последние [days] дней (включая сегодня).
  int dailyCompletionPercent(int days) {
    var sum = 0.0;
    var cnt = 0;
    for (var i = 0; i < days; i++) {
      final r = dailyRatio(addDays(today(), -i));
      if (r == null) continue;
      sum += r;
      cnt++;
    }
    return cnt == 0 ? 0 : (sum / cnt * 100).round();
  }
}
