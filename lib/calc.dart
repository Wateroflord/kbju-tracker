import 'dart:math' as math;

import 'models.dart';

/// Базовый обмен по формуле Миффлина — Сан Жеора.
double calcBmr(Profile p) =>
    10 * p.weightKg + 6.25 * p.heightCm - 5 * p.age + (p.sex == Sex.male ? 5 : -161);

ActivityLevel activityOf(Profile p) =>
    activityLevels[math.min(math.max(p.activity, 0), activityLevels.length - 1)];

/// Суточный расход с учётом активности.
double calcTdee(Profile p) => calcBmr(p) * activityOf(p).factor;

/// Нормы по программе (набор / сушка / поддержание).
Targets autoTargets(Profile p) {
  final male = p.sex == Sex.male;
  final tdee = calcTdee(p);

  double kcal = switch (p.goal) {
    Goal.cut => tdee * 0.80,
    Goal.maintain => tdee,
    Goal.bulk => tdee * 1.12,
  };
  // Безопасный минимум калорий.
  kcal = math.max(kcal, male ? 1500.0 : 1200.0);

  final w = p.weightKg;
  final proteinPerKg = switch (p.goal) {
    Goal.cut => 2.0,
    Goal.maintain => 1.6,
    Goal.bulk => 1.8,
  };
  double fatPerKg = male ? 0.9 : 1.0;
  if (p.goal == Goal.cut) fatPerKg -= 0.1;

  final double protein = math.min(w * proteinPerKg, 230.0);
  double fat = w * fatPerKg;
  double carbs = (kcal - protein * 4 - fat * 9) / 4;
  if (carbs < 60) {
    fat = math.max(w * 0.6, (kcal - protein * 4 - 60 * 4) / 9);
    carbs = math.max(0.0, (kcal - protein * 4 - fat * 9) / 4);
  }

  final water = ((w * (male ? 35 : 31)) / 250).round() * 250;

  return Targets(
    kcal: (kcal / 10).round() * 10,
    protein: protein.round(),
    fat: fat.round(),
    carbs: carbs.round(),
    waterMl: water,
  );
}

/// Итоговые нормы: свои (если включены) или автоматические.
Targets computeTargets(Profile p) {
  final auto = autoTargets(p);
  final c = p.custom;
  if (p.customTargets && c != null) {
    return Targets(
      kcal: c.kcal,
      protein: c.protein,
      fat: c.fat,
      carbs: c.carbs,
      waterMl: auto.waterMl,
    );
  }
  return auto;
}

/// Соблюдение нормы калорий: ±10% — в норме.
DayStatus dayStatus(double eaten, int target) {
  if (eaten <= 0) return DayStatus.none;
  if (target <= 0) return DayStatus.good;
  final r = eaten / target;
  if (r < 0.9) return DayStatus.under;
  if (r > 1.1) return DayStatus.over;
  return DayStatus.good;
}
