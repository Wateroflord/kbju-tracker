import '../life/eval.dart';
import '../models.dart';
import '../store.dart';
import '../util.dart';

/// Очки дисциплины Winter Arc за один день (максимум 100).
///
/// - Питание: калории в норме — 30, записал еду, но мимо нормы — 10.
/// - Вода: выпил норму — 10.
/// - Сон: 7+ часов — 20, 6–7 часов — 10.
/// - Шаги: норма — 20, хотя бы 70% нормы — 10.
/// - Тренировка: завершённая тренировка — 20 (в неделю считается не больше,
///   чем тренировок в плане, чтобы нельзя было набить очки лишними).
class ArcDay {
  final String day;
  final int food, water, sleep, steps, workout;
  const ArcDay(this.day, {this.food = 0, this.water = 0, this.sleep = 0, this.steps = 0, this.workout = 0});

  int get total => food + water + sleep + steps + workout;

  Map<String, dynamic> toJson() =>
      {'day': day, 'food': food, 'water': water, 'sleep': sleep, 'steps': steps, 'workout': workout};

  bool sameAs(Map r) =>
      (r['food'] as num?)?.toInt() == food &&
      (r['water'] as num?)?.toInt() == water &&
      (r['sleep'] as num?)?.toInt() == sleep &&
      (r['steps'] as num?)?.toInt() == steps &&
      (r['workout'] as num?)?.toInt() == workout;
}

class ArcRules {
  static const max = {'food': 30, 'water': 10, 'sleep': 20, 'steps': 20, 'workout': 20};
  static const days = 365;

  static int food(DayStatus s) => switch (s) {
        DayStatus.good => 30,
        DayStatus.under || DayStatus.over => 10,
        DayStatus.none => 0,
      };

  static int water(int drunkMl, int targetMl) => targetMl > 0 && drunkMl >= targetMl ? 10 : 0;

  static int sleep(double hours) => hours >= 7 ? 20 : (hours >= 6 ? 10 : 0);

  static int steps(int steps, int goal) {
    if (goal <= 0 || steps <= 0) return 0;
    if (steps >= goal) return 20;
    return steps >= goal * 0.7 ? 10 : 0;
  }

  /// Дни тренировок, которые идут в зачёт: в каждой неделе (с понедельника)
  /// не больше [perWeek] первых дней с завершённой тренировкой.
  static Set<String> countedWorkoutDays(Iterable<String> workoutDays, int perWeek) {
    final byWeek = <String, List<String>>{};
    for (final d in workoutDays.toSet()) {
      final p = parseKey(d);
      final week = dkey(addDays(p, -(p.weekday - 1)));
      (byWeek[week] ??= []).add(d);
    }
    final out = <String>{};
    for (final list in byWeek.values) {
      list.sort();
      out.addAll(list.take(perWeek < 1 ? 1 : perWeek));
    }
    return out;
  }
}

/// Очки за дни с [from] по [to] включительно (ключи ГГГГ-ММ-ДД).
List<ArcDay> arcScores(AppStore store, String from, String to) {
  final life = store.life;
  final workoutDays = life.sessions.where((s) => s.finished).map((s) => s.date);
  final counted = ArcRules.countedWorkoutDays(workoutDays, store.workoutsPerWeek);
  final out = <ArcDay>[];
  var d = parseKey(from);
  final end = parseKey(to);
  while (!d.isAfter(end)) {
    final k = dkey(d);
    out.add(ArcDay(
      k,
      food: ArcRules.food(store.statusFor(k)),
      water: ArcRules.water(store.water[k] ?? 0, store.targetsFor(k).waterMl),
      sleep: ArcRules.sleep(life.sleepFor(k)?.hours ?? 0),
      steps: ArcRules.steps(life.steps[k] ?? 0, life.stepGoal),
      workout: counted.contains(k) ? 20 : 0,
    ));
    d = addDays(d, 1);
  }
  return out;
}
