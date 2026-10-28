import '../gemini.dart';
import '../learn/learn_logic.dart';
import '../life/eval.dart';
import '../models.dart';
import '../store.dart';
import '../util.dart';

/// Сводка недели (понедельник–воскресенье) для отчёта.
class WeekStats {
  final DateTime monday;
  int days = 0; // дней прошло (для текущей недели меньше 7)
  int logged = 0;
  int inNorm = 0;
  double kcal = 0, protein = 0, fat = 0, carbs = 0;
  double tKcal = 0, tProtein = 0, tFat = 0, tCarbs = 0;
  int waterDaysOk = 0;
  double? weightStart, weightEnd;
  int stepsDays = 0;
  int stepsSum = 0;
  int sleepNights = 0;
  double sleepSum = 0;
  int workouts = 0;
  int habitsPercent = 0;
  int learnMinutes = 0;
  int fasts = 0;
  double spentPln = 0;

  WeekStats(this.monday);

  double get avgKcal => logged == 0 ? 0 : kcal / logged;
  double get avgProtein => logged == 0 ? 0 : protein / logged;
  double get avgFat => logged == 0 ? 0 : fat / logged;
  double get avgCarbs => logged == 0 ? 0 : carbs / logged;
  double get avgTKcal => logged == 0 ? 0 : tKcal / logged;
  double get avgTProtein => logged == 0 ? 0 : tProtein / logged;
  double get avgTFat => logged == 0 ? 0 : tFat / logged;
  double get avgTCarbs => logged == 0 ? 0 : tCarbs / logged;
  int get avgSteps => stepsDays == 0 ? 0 : (stepsSum / stepsDays).round();
  double get avgSleep => sleepNights == 0 ? 0 : sleepSum / sleepNights;
  double? get weightChange => (weightStart != null && weightEnd != null) ? weightEnd! - weightStart! : null;
  bool get empty => logged == 0 && stepsDays == 0 && workouts == 0 && sleepNights == 0;
}

WeekStats computeWeek(AppStore store, DateTime monday) {
  final w = WeekStats(monday);
  final now = today();
  final all = store.allTotals();
  double habitSum = 0;
  int habitDays = 0;
  for (var i = 0; i < 7; i++) {
    final d = addDays(monday, i);
    if (d.isAfter(now)) break;
    w.days++;
    final k = dkey(d);
    final t = all[k];
    if (t != null && t.count > 0) {
      final tg = store.targetsFor(k);
      w.logged++;
      w.kcal += t.kcal;
      w.protein += t.protein;
      w.fat += t.fat;
      w.carbs += t.carbs;
      w.tKcal += tg.kcal;
      w.tProtein += tg.protein;
      w.tFat += tg.fat;
      w.tCarbs += tg.carbs;
      if (store.statusFor(k, t) == DayStatus.good) w.inNorm++;
      if (tg.waterMl > 0 && store.waterFor(k) >= tg.waterMl) w.waterDaysOk++;
    }
    final st = store.life.stepsFor(k);
    if (st > 0) {
      w.stepsDays++;
      w.stepsSum += st;
    }
    final sl = store.life.sleepFor(k);
    if (sl != null) {
      w.sleepNights++;
      w.sleepSum += sl.hours;
    }
    final r = store.dailyRatio(d);
    if (r != null) {
      habitSum += r;
      habitDays++;
    }
    w.learnMinutes += store.life.secondsOn(k) ~/ 60;
  }
  w.workouts = store.life.finishedSessionsBetween(monday, addDays(monday, 7));
  w.habitsPercent = habitDays == 0 ? 0 : (habitSum / habitDays * 100).round();

  // Вес: последнее взвешивание до недели (или первое в неделе) и последнее в неделе.
  final a = dkey(monday), b = dkey(addDays(monday, 7));
  for (final e in store.weightSeries) {
    if (e.key.compareTo(a) < 0) w.weightStart = e.value;
    if (e.key.compareTo(a) >= 0 && e.key.compareTo(b) < 0) {
      w.weightStart ??= e.value;
      w.weightEnd = e.value;
    }
  }
  final f = store.food;
  final ms = monday.millisecondsSinceEpoch, me = addDays(monday, 7).millisecondsSinceEpoch;
  w.fasts = f.fasts.where((x) => x.start >= ms && x.start < me).length;
  for (final e in f.expenses) {
    if (e.date.compareTo(a) >= 0 && e.date.compareTo(b) < 0) w.spentPln += f.toPln(e);
  }
  return w;
}

String _f(double v) => v.toStringAsFixed(1);

/// Запрос к ИИ: разбор недели простым текстом на языке интерфейса.
Future<String> requestWeekReport(AppStore store, WeekStats w) {
  final p = store.profile;
  final b = StringBuffer()
    ..writeln('You are a friendly, practical nutrition and fitness coach.')
    ..writeln('Analyze the user\'s week and give short, specific advice.');
  if (p != null) {
    b.writeln('User: ${p.sex.name}, ${p.age} years, ${_f(p.heightCm)} cm, ${_f(p.weightKg)} kg, '
        'goal: ${p.goal.name} (bulk = muscle gain, cut = fat loss, maintain = maintenance)'
        '${p.targetWeightKg != null ? ', target weight ${_f(p.targetWeightKg!)} kg' : ''}.');
  }
  b
    ..writeln('Week starting ${dkey(w.monday)}, ${w.days} days so far.')
    ..writeln('Food logged on ${w.logged} days; calories within ±10% of target on ${w.inNorm} days.')
    ..writeln('Average per logged day: ${w.avgKcal.round()} kcal (target ${w.avgTKcal.round()}), '
        'protein ${w.avgProtein.round()} g (target ${w.avgTProtein.round()}), '
        'fat ${w.avgFat.round()} g (target ${w.avgTFat.round()}), '
        'carbs ${w.avgCarbs.round()} g (target ${w.avgTCarbs.round()}).')
    ..writeln('Water target reached on ${w.waterDaysOk} days.')
    ..writeln(w.weightChange == null ? 'No weigh-ins this week.' : 'Weight change: ${_f(w.weightChange!)} kg (now ${_f(w.weightEnd!)} kg).')
    ..writeln(w.stepsDays == 0 ? 'No step data.' : 'Average steps: ${w.avgSteps} per day (goal ${store.life.stepGoal}).')
    ..writeln(w.sleepNights == 0 ? 'No sleep data.' : 'Average sleep: ${_f(w.avgSleep)} h (goal ${_f(store.life.sleepGoal)} h).')
    ..writeln('Workouts completed: ${w.workouts} (planned ${store.workoutsPerWeek} per week).')
    ..writeln('Daily habits completion: ${w.habitsPercent}%.')
    ..writeln('Language learning: ${w.learnMinutes} minutes.')
    ..writeln('Intermittent fasts: ${w.fasts}.')
    ..writeln('Food spending: ${w.spentPln.round()} PLN.')
    ..writeln()
    ..writeln('Write the answer in ${GeminiService.outLang}. Plain text only: no markdown, no asterisks, no # headings.')
    ..writeln('Use exactly these 4 sections, each title on its own line ending with a colon, '
        'and items as lines starting with "- ":')
    ..writeln('1) Summary of the week (2-3 sentences). 2) What went well (2-3 items). '
        '3) What to improve (2-3 items, concrete numbers). 4) Plan for next week (3 concrete actions).')
    ..writeln('Be encouraging but honest. Max 200 words. If data is missing, say what to start tracking. '
        'No medical diagnoses.');
  return GeminiService.generate(apiKey: store.apiKey, model: store.model, prompt: b.toString());
}
