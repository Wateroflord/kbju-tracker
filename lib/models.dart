import 'package:flutter/material.dart';

import 'util.dart';
import 'i18n/i18n.dart';

enum Sex { male, female }

enum Goal { bulk, cut, maintain }

enum Meal { breakfast, lunch, dinner, snack }

T enumByName<T extends Enum>(List<T> values, dynamic name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

extension GoalX on Goal {
  String get title => switch (this) {
        Goal.bulk => tr('Набор мышц'),
        Goal.cut => tr('Сушка'),
        Goal.maintain => tr('Поддержание'),
      };

  String get desc => switch (this) {
        Goal.bulk => tr('Профицит ~12%, больше белка и углеводов'),
        Goal.cut => tr('Дефицит ~20%, высокий белок для сохранения мышц'),
        Goal.maintain => tr('Калории на уровне расхода, стабильный вес'),
      };

  IconData get icon => switch (this) {
        Goal.bulk => Icons.fitness_center,
        Goal.cut => Icons.local_fire_department_outlined,
        Goal.maintain => Icons.balance,
      };
}

extension MealX on Meal {
  String get title => switch (this) {
        Meal.breakfast => tr('Завтрак'),
        Meal.lunch => tr('Обед'),
        Meal.dinner => tr('Ужин'),
        Meal.snack => tr('Перекус'),
      };

  IconData get icon => switch (this) {
        Meal.breakfast => Icons.free_breakfast_outlined,
        Meal.lunch => Icons.lunch_dining_outlined,
        Meal.dinner => Icons.dinner_dining_outlined,
        Meal.snack => Icons.local_cafe_outlined,
      };

  static Meal byTime(DateTime t) {
    if (t.hour < 11) return Meal.breakfast;
    if (t.hour < 15) return Meal.lunch;
    if (t.hour < 18) return Meal.snack;
    return Meal.dinner;
  }
}

class ActivityLevel {
  final String title;
  final String desc;
  final double factor;
  const ActivityLevel(this.title, this.desc, this.factor);
}

const activityLevels = [
  ActivityLevel('Минимальная', 'Сидячая работа, без тренировок', 1.2),
  ActivityLevel('Низкая', 'Тренировки 1–3 раза в неделю', 1.375),
  ActivityLevel('Средняя', 'Тренировки 3–5 раз в неделю', 1.55),
  ActivityLevel('Высокая', 'Тренировки 6–7 раз в неделю', 1.725),
  ActivityLevel('Очень высокая', 'Физическая работа + тренировки', 1.9),
];

class Targets {
  final int kcal;
  final int protein;
  final int fat;
  final int carbs;
  final int waterMl;

  const Targets({
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.waterMl,
  });

  static const zero = Targets(kcal: 0, protein: 0, fat: 0, carbs: 0, waterMl: 0);

  Map<String, dynamic> toJson() => {
        'kcal': kcal,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        'waterMl': waterMl,
      };

  factory Targets.fromJson(Map<String, dynamic> j) => Targets(
        kcal: asInt(j['kcal']),
        protein: asInt(j['protein']),
        fat: asInt(j['fat']),
        carbs: asInt(j['carbs']),
        waterMl: asInt(j['waterMl']),
      );
}

class Profile {
  final Sex sex;
  final int age;
  final double heightCm;
  final double weightKg;
  final double? targetWeightKg;
  final int activity;
  final Goal goal;
  final bool customTargets;
  final Targets? custom;

  const Profile({
    required this.sex,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    this.targetWeightKg,
    required this.activity,
    required this.goal,
    this.customTargets = false,
    this.custom,
  });

  Profile copyWith({
    double? weightKg,
    Goal? goal,
  }) =>
      Profile(
        sex: sex,
        age: age,
        heightCm: heightCm,
        weightKg: weightKg ?? this.weightKg,
        targetWeightKg: targetWeightKg,
        activity: activity,
        goal: goal ?? this.goal,
        customTargets: customTargets,
        custom: custom,
      );

  Map<String, dynamic> toJson() => {
        'sex': sex.name,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'targetWeightKg': targetWeightKg,
        'activity': activity,
        'goal': goal.name,
        'customTargets': customTargets,
        'custom': custom?.toJson(),
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        sex: enumByName(Sex.values, j['sex'], Sex.male),
        age: asInt(j['age'], 25),
        heightCm: asDouble(j['heightCm'], 175),
        weightKg: asDouble(j['weightKg'], 75),
        targetWeightKg: j['targetWeightKg'] == null ? null : asDouble(j['targetWeightKg']),
        activity: asInt(j['activity'], 1),
        goal: enumByName(Goal.values, j['goal'], Goal.maintain),
        customTargets: j['customTargets'] == true,
        custom: j['custom'] is Map
            ? Targets.fromJson(Map<String, dynamic>.from(j['custom'] as Map))
            : null,
      );
}

class FoodEntry {
  final String id;
  final String date; // ключ дня
  final int time; // миллисекунды, для сортировки
  final Meal meal;
  final String name;
  final double grams;
  final double kcal;
  final double protein;
  final double fat;
  final double carbs;
  final String? photo; // относительный путь, например photos/123.jpg

  const FoodEntry({
    required this.id,
    required this.date,
    required this.time,
    required this.meal,
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.photo,
  });

  FoodEntry copyWith({
    Meal? meal,
    String? name,
    double? grams,
    double? kcal,
    double? protein,
    double? fat,
    double? carbs,
  }) =>
      FoodEntry(
        id: id,
        date: date,
        time: time,
        meal: meal ?? this.meal,
        name: name ?? this.name,
        grams: grams ?? this.grams,
        kcal: kcal ?? this.kcal,
        protein: protein ?? this.protein,
        fat: fat ?? this.fat,
        carbs: carbs ?? this.carbs,
        photo: photo,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'time': time,
        'meal': meal.name,
        'name': name,
        'grams': grams,
        'kcal': kcal,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
        'photo': photo,
      };

  factory FoodEntry.fromJson(Map<String, dynamic> j) => FoodEntry(
        id: j['id']?.toString() ?? '${DateTime.now().microsecondsSinceEpoch}',
        date: j['date']?.toString() ?? todayKey(),
        time: asInt(j['time']),
        meal: enumByName(Meal.values, j['meal'], Meal.snack),
        name: j['name']?.toString() ?? tr('Еда'),
        grams: asDouble(j['grams']),
        kcal: asDouble(j['kcal']),
        protein: asDouble(j['protein']),
        fat: asDouble(j['fat']),
        carbs: asDouble(j['carbs']),
        photo: j['photo']?.toString(),
      );
}

class GoalChange {
  final String date;
  final Goal? from;
  final Goal to;
  const GoalChange(this.date, this.from, this.to);

  Map<String, dynamic> toJson() => {'date': date, 'from': from?.name, 'to': to.name};

  factory GoalChange.fromJson(Map<String, dynamic> j) => GoalChange(
        j['date']?.toString() ?? todayKey(),
        j['from'] == null ? null : enumByName(Goal.values, j['from'], Goal.maintain),
        enumByName(Goal.values, j['to'], Goal.maintain),
      );
}

class Totals {
  double kcal = 0, protein = 0, fat = 0, carbs = 0;
  int count = 0;

  void add(FoodEntry e) {
    kcal += e.kcal;
    protein += e.protein;
    fat += e.fat;
    carbs += e.carbs;
    count++;
  }
}

enum DayStatus { none, under, good, over }
