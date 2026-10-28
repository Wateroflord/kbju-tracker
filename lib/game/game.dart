import 'package:flutter/material.dart';

import '../learn/learn_logic.dart';
import '../models.dart';
import '../store.dart';
import '../util.dart';
import '../i18n/i18n.dart';

/// Уровни и опыт. Опыт считается заново из истории, поэтому его нельзя «потерять».
class XpPart {
  final String title;
  final int xp;
  const XpPart(this.title, this.xp);
}

class GameStats {
  int foodDays = 0, normDays = 0, waterDays = 0, stepDays = 0, sleepNights = 0;
  int bestSteps = 0, bestNormStreak = 0, bestStepStreak = 0;
  int workouts = 0, weighWeeks = 0, weighIns = 0, measures = 0, photos = 0;
  int habitChecks = 0, knownWords = 0, learnMinutes = 0, routines = 0, mindMinutes = 0;
  int moods = 0, fastsReached = 0, fasts = 0, products = 0, favorites = 0, expenses = 0;
  final List<XpPart> parts = [];
  int xp = 0;

  int get level => levelFor(xp);
}

/// Сколько опыта нужно, чтобы дойти до уровня L (L = 1 — старт).
int xpForLevel(int l) => 50 * (l - 1) * l;

int levelFor(int xp) {
  var l = 1;
  while (xpForLevel(l + 1) <= xp) {
    l++;
  }
  return l;
}

String levelTitle(int l) {
  if (l < 5) return tr('Новичок');
  if (l < 10) return tr('Любитель');
  if (l < 15) return tr('Атлет');
  if (l < 20) return tr('Профи');
  if (l < 30) return tr('Мастер');
  return tr('Легенда');
}

int _bestStreak(Iterable<String> keys) {
  final sorted = keys.toSet().toList()..sort();
  var best = 0, cur = 0;
  DateTime? prev;
  for (final k in sorted) {
    final d = parseKey(k);
    cur = (prev != null && daysBetween(prev, d) == 1) ? cur + 1 : 1;
    if (cur > best) best = cur;
    prev = d;
  }
  return best;
}

GameStats computeGame(AppStore store) {
  final g = GameStats();
  final life = store.life;
  final all = store.allTotals();
  final normKeys = <String>[];
  for (final e in all.entries) {
    if (e.value.count == 0) continue;
    g.foodDays++;
    if (store.statusFor(e.key, e.value) == DayStatus.good) {
      g.normDays++;
      normKeys.add(e.key);
    }
  }
  for (final e in store.water.entries) {
    final t = store.targetsFor(e.key).waterMl;
    if (t > 0 && e.value >= t) g.waterDays++;
  }
  final stepKeys = <String>[];
  for (final e in life.steps.entries) {
    if (e.value > g.bestSteps) g.bestSteps = e.value;
    if (e.value >= life.stepGoal) {
      g.stepDays++;
      stepKeys.add(e.key);
    }
  }
  g.bestNormStreak = _bestStreak(normKeys);
  g.bestStepStreak = _bestStreak(stepKeys);
  g.sleepNights = life.sleep.values.where((s) => s.hours >= 7).length;
  g.workouts = life.sessions.where((s) => s.finished).length;
  g.weighIns = store.weights.length;
  g.weighWeeks = store.weights.keys.map((k) => dkey(addDays(parseKey(k), -(parseKey(k).weekday - 1)))).toSet().length;
  g.measures = store.food.measures.length;
  g.photos = life.photos.length;
  g.habitChecks = life.habitDone.values.fold(0, (s, v) => s + v.length);
  for (final l in const ['en', 'pl', 'de']) {
    g.knownWords += life.knownCount(l);
    g.learnMinutes += life.totalSeconds(l) ~/ 60;
  }
  g.routines = life.routinesTotal;
  g.mindMinutes = life.mindTotalMinutes;
  g.moods = life.moods.length;
  g.fasts = store.food.fasts.length;
  g.fastsReached = store.food.fasts.where((f) => f.reached).length;
  g.products = store.food.products.length;
  g.favorites = store.food.favorites.length;
  g.expenses = store.food.expenses.length;

  void add(String title, int xp) {
    if (xp <= 0) return;
    g.parts.add(XpPart(title, xp));
    g.xp += xp;
  }

  add(tr('Дни с записью еды × 10'), g.foodDays * 10);
  add(tr('Калории в норме × 10'), g.normDays * 10);
  add(tr('Вода по норме × 5'), g.waterDays * 5);
  add(tr('Норма шагов × 10'), g.stepDays * 10);
  add(tr('Сон 7+ часов × 5'), g.sleepNights * 5);
  add(tr('Тренировки × 30'), g.workouts * 30);
  add(tr('Взвешивания × 5'), g.weighIns * 5);
  add(tr('Замеры и фото × 10'), (g.measures + g.photos) * 10);
  add(tr('Отмеченные привычки × 3'), g.habitChecks * 3);
  add(tr('Выученные слова × 2'), g.knownWords * 2);
  add(tr('Минуты учёбы × 1'), g.learnMinutes);
  add(tr('Разминки и растяжки × 10'), g.routines * 10);
  add(tr('Минуты дыхания × 1'), g.mindMinutes);
  add(tr('Записи настроения × 3'), g.moods * 3);
  add(tr('Голодания с целью × 15'), g.fastsReached * 15);
  return g;
}

/// Достижение: [progress] возвращает текущее значение, [target] — цель.
class Achievement {
  final String id;
  final String title;
  final String desc;
  final IconData icon;
  final int target;
  final int Function(GameStats g) progress;
  const Achievement(this.id, this.title, this.desc, this.icon, this.target, this.progress);
}

final achievements = <Achievement>[
  Achievement('food_1', 'Первый шаг', 'Записать еду в дневник', Icons.restaurant_outlined, 1, (g) => g.foodDays),
  Achievement('food_7', 'Неделя дневника', '7 дней с записью еды', Icons.menu_book_outlined, 7, (g) => g.foodDays),
  Achievement('food_30', 'Месяц дневника', '30 дней с записью еды', Icons.auto_stories_outlined, 30, (g) => g.foodDays),
  Achievement('norm_7', 'Точно в цель', '7 дней подряд калории в норме', Icons.track_changes, 7, (g) => g.bestNormStreak),
  Achievement('water_7', 'Водный баланс', '7 дней вода по норме', Icons.water_drop_outlined, 7, (g) => g.waterDays),
  Achievement('steps_10k', '10 000 шагов', 'Пройти 10 000 шагов за день', Icons.directions_walk, 10000, (g) => g.bestSteps),
  Achievement('steps_20k', 'Марафонец', 'Пройти 20 000 шагов за день', Icons.directions_run, 20000, (g) => g.bestSteps),
  Achievement('steps_7', 'Неделя на ногах', '7 дней подряд норма шагов', Icons.hiking, 7, (g) => g.bestStepStreak),
  Achievement('sleep_7', 'Высыпаюсь', '7 ночей по 7+ часов', Icons.bedtime_outlined, 7, (g) => g.sleepNights),
  Achievement('workout_1', 'Первая тренировка', 'Завершить тренировку', Icons.fitness_center, 1, (g) => g.workouts),
  Achievement('workout_10', 'Втянулся', '10 тренировок', Icons.sports_gymnastics, 10, (g) => g.workouts),
  Achievement('workout_50', 'Железная воля', '50 тренировок', Icons.emoji_events_outlined, 50, (g) => g.workouts),
  Achievement('routine_5', 'Гибкость', '5 разминок или растяжек', Icons.self_improvement, 5, (g) => g.routines),
  Achievement('weigh_4', 'Под контролем', 'Взвешиваться 4 разные недели', Icons.monitor_weight_outlined, 4, (g) => g.weighWeeks),
  Achievement('measure_1', 'Сантиметр', 'Записать замеры тела', Icons.straighten, 1, (g) => g.measures),
  Achievement('photo_1', 'До и после', 'Сделать фото прогресса', Icons.photo_camera_outlined, 1, (g) => g.photos),
  Achievement('words_50', 'Первые слова', 'Выучить 50 слов', Icons.translate, 50, (g) => g.knownWords),
  Achievement('words_200', 'Словарный запас', 'Выучить 200 слов', Icons.school_outlined, 200, (g) => g.knownWords),
  Achievement('learn_5h', '5 часов практики', 'Позаниматься языком 5 часов', Icons.timer_outlined, 300, (g) => g.learnMinutes),
  Achievement('learn_20h', 'Метод 20 часов', 'Набрать 20 часов практики языка', Icons.workspace_premium_outlined, 1200, (g) => g.learnMinutes),
  Achievement('fast_1', 'Окно закрыто', 'Довести голодание до цели', Icons.timer, 1, (g) => g.fastsReached),
  Achievement('fast_10', 'Режим', '10 голоданий с целью', Icons.hourglass_bottom, 10, (g) => g.fastsReached),
  Achievement('mind_60', 'Спокойствие', '60 минут дыхания и медитации', Icons.air, 60, (g) => g.mindMinutes),
  Achievement('mood_14', 'Знаю себя', '14 записей в дневнике настроения', Icons.sentiment_satisfied_outlined, 14, (g) => g.moods),
  Achievement('barcode_1', 'Сканер', 'Добавить товар по штрихкоду', Icons.qr_code_scanner, 1, (g) => g.products),
  Achievement('fav_5', 'Любимое', '5 продуктов в избранном', Icons.star_border, 5, (g) => g.favorites),
  Achievement('money_10', 'Считаю деньги', '10 записей расходов на еду', Icons.account_balance_wallet_outlined, 10, (g) => g.expenses),
  Achievement('level_10', 'Десятка', 'Дойти до 10 уровня', Icons.military_tech_outlined, 10, (g) => g.level),
];

/// Отметить новые достижения (с датой). Возвращает только что полученные.
List<Achievement> syncAchievements(AppStore store, GameStats g) {
  final got = store.life.achievements;
  final fresh = <Achievement>[];
  for (final a in achievements) {
    if (got.containsKey(a.id)) continue;
    if (a.progress(g) >= a.target) fresh.add(a);
  }
  if (fresh.isNotEmpty) store.life.unlockAchievements([for (final a in fresh) a.id]);
  return fresh;
}
