import '../store.dart';
import '../util.dart';
import '../i18n/i18n.dart';
import '../learn/learn_logic.dart';

/// Наблюдение: как привычки связаны с самочувствием и едой.
class Insight {
  final String text;
  final bool good; // зелёным (полезная связь) или красным (вредная)
  const Insight(this.text, this.good);
}

double _avg(List<double> v) => v.isEmpty ? 0.0 : v.reduce((a, b) => a + b) / v.length;

String _pts(double d) => fmt1(d.abs());

/// Сравниваем дни «с» и «без» за последние 60 дней. Нужно хотя бы 3 дня в каждой группе.
List<Insight> computeInsights(AppStore store) {
  final life = store.life;
  final out = <Insight>[];
  final now = today();
  final days = [for (var i = 0; i < 60; i++) addDays(now, -i)];
  const minN = 3;

  // Наблюдения по настроению/энергии/стрессу.
  void compare(String Function(double diff) text, bool? Function(DateTime d) test, double? Function(String k) metric,
      {double threshold = 0.4, bool higherIsGood = true}) {
    final a = <double>[], b = <double>[];
    for (final d in days) {
      final k = dkey(d);
      final m = metric(k);
      final t = test(d);
      if (m == null || t == null) continue;
      (t ? a : b).add(m);
    }
    if (a.length < minN || b.length < minN) return;
    final diff = _avg(a) - _avg(b);
    if (diff.abs() < threshold) return;
    out.add(Insight(text(diff), (diff > 0) == higherIsGood));
  }

  double? mood(String k) => life.moods[k]?.mood.toDouble();
  double? energy(String k) => life.moods[k]?.energy.toDouble();
  double? stress(String k) => life.moods[k]?.stress.toDouble();

  bool? sleptWell(DateTime d) {
    final s = life.sleepFor(dkey(d));
    return s == null ? null : s.hours >= 7;
  }

  bool? workedOut(DateTime d) => life.sessionsOn(dkey(d)).any((s) => s.finished);

  bool? walked(DateTime d) {
    final s = life.stepsFor(dkey(d));
    return s == 0 ? null : s >= life.stepGoal;
  }

  bool? foodOk(DateTime d) {
    final k = dkey(d);
    final t = store.totalsFor(k);
    if (t.count == 0) return null;
    final tg = store.targetsFor(k).kcal;
    return tg > 0 && (t.kcal - tg).abs() <= tg * 0.1;
  }

  bool? mindful(DateTime d) => life.mindSecondsOn(dkey(d)) >= 120 || life.secondsOn(dkey(d)) >= 600;

  compare((x) => x > 0
      ? trf('После сна 7+ часов энергия выше на {0} балла', [_pts(x)])
      : trf('После сна 7+ часов энергия почему-то ниже на {0} балла', [_pts(x)]), sleptWell, energy);
  compare((x) => x > 0
      ? trf('В дни с тренировкой настроение лучше на {0} балла', [_pts(x)])
      : trf('В дни с тренировкой настроение ниже на {0} балла — возможно, нагрузка великовата', [_pts(x)]),
      workedOut, mood);
  compare((x) => x > 0
      ? trf('Когда проходишь норму шагов, настроение выше на {0} балла', [_pts(x)])
      : trf('В дни с нормой шагов настроение ниже на {0} балла', [_pts(x)]), walked, mood);
  compare((x) => x > 0
      ? trf('Когда калории в норме, энергии больше на {0} балла', [_pts(x)])
      : trf('Когда калории в норме, энергии меньше на {0} балла — проверь, хватает ли еды', [_pts(x)]), foodOk, energy);
  compare((x) => x < 0
      ? trf('В дни с дыханием, медитацией или учёбой стресс ниже на {0} балла', [_pts(x)])
      : trf('В дни с дыханием или учёбой стресс выше на {0} балла', [_pts(x)]), mindful, stress, higherIsGood: false);
  compare((x) => x < 0
      ? trf('После хорошего сна стресс ниже на {0} балла', [_pts(x)])
      : trf('После хорошего сна стресс выше на {0} балла', [_pts(x)]), sleptWell, stress, higherIsGood: false);

  // Сон и калории: «когда спишь меньше 7 часов, ешь больше».
  final shortSleep = <double>[], goodSleep = <double>[];
  for (final d in days) {
    final k = dkey(d);
    final s = life.sleepFor(k);
    final t = store.totalsFor(k);
    if (s == null || t.count == 0) continue;
    (s.hours < 7 ? shortSleep : goodSleep).add(t.kcal);
  }
  if (shortSleep.length >= minN && goodSleep.length >= minN) {
    final diff = _avg(shortSleep) - _avg(goodSleep);
    if (diff.abs() >= 150) {
      out.add(Insight(
        diff > 0
            ? trf('Когда спишь меньше 7 часов, ешь в среднем на {0} ккал больше', [fmtInt(diff)])
            : trf('Когда спишь меньше 7 часов, ешь на {0} ккал меньше', [fmtInt(diff.abs())]),
        diff < 0,
      ));
    }
  }
  return out;
}
