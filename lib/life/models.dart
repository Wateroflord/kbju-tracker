// Модели для разделов «Сегодня», привычки, шаги, сон, тренировки, уход, напоминания.

import '../models.dart' show enumByName;
import '../util.dart';
import '../i18n/i18n.dart';

// ---------------- Привычки ----------------

enum HabitPeriod { daily, weekly, monthly }

/// Как привычка отмечается автоматически.
enum HabitAuto { none, steps, food, water, sleep, workouts, weigh, learn, mind, mood }

class Habit {
  final String id;
  final String title;
  final HabitPeriod period;
  final HabitAuto auto;
  final String icon; // ключ иконки, см. habitIcon()
  final bool builtin;
  final bool enabled;

  const Habit({
    required this.id,
    required this.title,
    required this.period,
    this.auto = HabitAuto.none,
    this.icon = 'check',
    this.builtin = false,
    this.enabled = true,
  });

  Habit copyWith({bool? enabled, String? title}) => Habit(
        id: id,
        title: title ?? this.title,
        period: period,
        auto: auto,
        icon: icon,
        builtin: builtin,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'period': period.name,
        'auto': auto.name,
        'icon': icon,
        'builtin': builtin,
        'enabled': enabled,
      };

  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        period: enumByName(HabitPeriod.values, j['period'], HabitPeriod.daily),
        auto: enumByName(HabitAuto.values, j['auto'], HabitAuto.none),
        icon: j['icon']?.toString() ?? 'check',
        builtin: j['builtin'] == true,
        enabled: j['enabled'] != false,
      );
}

/// Ключ периода: день — 2026-10-28, неделя — W2026-10-26 (понедельник), месяц — M2026-10.
String periodKey(HabitPeriod p, DateTime d) => switch (p) {
      HabitPeriod.daily => dkey(d),
      HabitPeriod.weekly => 'W${dkey(weekStart(d))}',
      HabitPeriod.monthly => 'M${d.year}-${two(d.month)}',
    };

DateTime weekStart(DateTime d) => addDays(dayOnly(d), -(d.weekday - 1));

// ---------------- Сон ----------------

class SleepEntry {
  final int bed; // ms since epoch
  final int wake; // ms since epoch
  const SleepEntry(this.bed, this.wake);

  double get hours => (wake - bed) / 3600000.0;

  Map<String, dynamic> toJson() => {'bed': bed, 'wake': wake};
  factory SleepEntry.fromJson(Map<String, dynamic> j) =>
      SleepEntry(asInt(j['bed']), asInt(j['wake']));
}

// ---------------- Тренировки ----------------

class Exercise {
  final String id;
  final String name;
  final String technique;
  final String easier;
  final bool bodyweight; // без отягощения: вес не обязателен
  final bool timed; // считается в секундах (планка)
  final bool custom;

  const Exercise({
    required this.id,
    required this.name,
    this.technique = '',
    this.easier = '',
    this.bodyweight = false,
    this.timed = false,
    this.custom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'technique': technique,
        'easier': easier,
        'bodyweight': bodyweight,
        'timed': timed,
        'custom': custom,
      };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        technique: j['technique']?.toString() ?? '',
        easier: j['easier']?.toString() ?? '',
        bodyweight: j['bodyweight'] == true,
        timed: j['timed'] == true,
        custom: j['custom'] == true,
      );
}

/// Упражнение в плане тренировки. repMax == 0 — «до отказа».
class PlanExercise {
  final String exId;
  final int sets;
  final int repMin;
  final int repMax;

  const PlanExercise(this.exId, this.sets, this.repMin, this.repMax);

  bool get toFailure => repMax == 0;

  String get scheme {
    if (toFailure) return trf('{0} × до отказа −1–2', [sets]);
    if (repMin == repMax) return '$sets × $repMin';
    return '$sets × $repMin–$repMax';
  }

  Map<String, dynamic> toJson() => {'ex': exId, 'sets': sets, 'min': repMin, 'max': repMax};
  factory PlanExercise.fromJson(Map<String, dynamic> j) => PlanExercise(
        j['ex']?.toString() ?? '',
        asInt(j['sets'], 3),
        asInt(j['min'], 8),
        asInt(j['max'], 12),
      );
}

class WorkoutDay {
  final String id;
  final String title;
  final List<PlanExercise> exercises;
  const WorkoutDay({required this.id, required this.title, required this.exercises});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory WorkoutDay.fromJson(Map<String, dynamic> j) => WorkoutDay(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        exercises: ((j['exercises'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => PlanExercise.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class Program {
  final String id;
  final String title;
  final String desc;
  final List<WorkoutDay> days; // чередуются по кругу
  final List<int> weekdays; // 1 = понедельник
  final bool custom;

  const Program({
    required this.id,
    required this.title,
    this.desc = '',
    required this.days,
    this.weekdays = const [1, 3, 5],
    this.custom = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'desc': desc,
        'days': days.map((d) => d.toJson()).toList(),
        'weekdays': weekdays,
        'custom': custom,
      };

  factory Program.fromJson(Map<String, dynamic> j) => Program(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        desc: j['desc']?.toString() ?? '',
        days: ((j['days'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => WorkoutDay.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        weekdays: ((j['weekdays'] as List?) ?? const [1, 3, 5]).map((e) => asInt(e)).toList(),
        custom: j['custom'] == true,
      );
}

class SetLog {
  final double weight;
  final int reps; // для упражнений на время — секунды
  final bool done;
  const SetLog({this.weight = 0, this.reps = 0, this.done = false});

  SetLog copyWith({double? weight, int? reps, bool? done}) =>
      SetLog(weight: weight ?? this.weight, reps: reps ?? this.reps, done: done ?? this.done);

  Map<String, dynamic> toJson() => {'w': weight, 'r': reps, 'd': done};
  factory SetLog.fromJson(Map<String, dynamic> j) =>
      SetLog(weight: asDouble(j['w']), reps: asInt(j['r']), done: j['d'] == true);
}

class SessionExercise {
  final String exId;
  final List<SetLog> sets;
  const SessionExercise(this.exId, this.sets);

  Map<String, dynamic> toJson() => {'ex': exId, 'sets': sets.map((s) => s.toJson()).toList()};
  factory SessionExercise.fromJson(Map<String, dynamic> j) => SessionExercise(
        j['ex']?.toString() ?? '',
        ((j['sets'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => SetLog.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class Session {
  final String id;
  final String date; // ключ дня
  final String programId;
  final String dayId;
  final String title;
  final int startedAt;
  final int finishedAt; // 0 — не завершена
  final List<SessionExercise> exercises;

  const Session({
    required this.id,
    required this.date,
    required this.programId,
    required this.dayId,
    required this.title,
    required this.startedAt,
    this.finishedAt = 0,
    required this.exercises,
  });

  bool get finished => finishedAt > 0;

  Session copyWith({int? finishedAt, List<SessionExercise>? exercises}) => Session(
        id: id,
        date: date,
        programId: programId,
        dayId: dayId,
        title: title,
        startedAt: startedAt,
        finishedAt: finishedAt ?? this.finishedAt,
        exercises: exercises ?? this.exercises,
      );

  /// Тоннаж: сумма вес × повторы по выполненным подходам.
  double get volume {
    var v = 0.0;
    for (final e in exercises) {
      for (final s in e.sets) {
        if (s.done) v += s.weight * s.reps;
      }
    }
    return v;
  }

  int get doneSets => exercises.fold(0, (a, e) => a + e.sets.where((s) => s.done).length);

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'program': programId,
        'day': dayId,
        'title': title,
        'start': startedAt,
        'finish': finishedAt,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory Session.fromJson(Map<String, dynamic> j) => Session(
        id: j['id']?.toString() ?? '',
        date: j['date']?.toString() ?? todayKey(),
        programId: j['program']?.toString() ?? '',
        dayId: j['day']?.toString() ?? '',
        title: j['title']?.toString() ?? tr('Тренировка'),
        startedAt: asInt(j['start']),
        finishedAt: asInt(j['finish']),
        exercises: ((j['exercises'] as List?) ?? const [])
            .whereType<Map>()
            .map((m) => SessionExercise.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

// ---------------- Уход и покупки ----------------

class ShopItem {
  final String id;
  final String category;
  final String name;
  final double pricePln;
  final double? pricePlnMax;
  final String note;
  final bool bought;

  const ShopItem({
    required this.id,
    required this.category,
    required this.name,
    required this.pricePln,
    this.pricePlnMax,
    this.note = '',
    this.bought = false,
  });

  ShopItem copyWith({bool? bought, String? name, double? pricePln, String? note}) => ShopItem(
        id: id,
        category: category,
        name: name ?? this.name,
        pricePln: pricePln ?? this.pricePln,
        pricePlnMax: pricePln != null ? null : pricePlnMax,
        note: note ?? this.note,
        bought: bought ?? this.bought,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'cat': category,
        'name': name,
        'pln': pricePln,
        'plnMax': pricePlnMax,
        'note': note,
        'bought': bought,
      };

  factory ShopItem.fromJson(Map<String, dynamic> j) => ShopItem(
        id: j['id']?.toString() ?? '',
        category: j['cat']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        pricePln: asDouble(j['pln']),
        pricePlnMax: j['plnMax'] == null ? null : asDouble(j['plnMax']),
        note: j['note']?.toString() ?? '',
        bought: j['bought'] == true,
      );
}

// ---------------- Напоминания ----------------

class Reminder {
  final String id;
  final String title;
  final String body;
  final bool enabled;
  final int hour;
  final int minute;
  final List<int> weekdays; // пусто — каждый день
  final bool fromProgram; // дни берутся из программы тренировок

  const Reminder({
    required this.id,
    required this.title,
    required this.body,
    this.enabled = false,
    required this.hour,
    required this.minute,
    this.weekdays = const [],
    this.fromProgram = false,
  });

  Reminder copyWith({bool? enabled, int? hour, int? minute}) => Reminder(
        id: id,
        title: title,
        body: body,
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        weekdays: weekdays,
        fromProgram: fromProgram,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'enabled': enabled,
        'hour': hour,
        'minute': minute,
      };
}

// ---------------- Фото прогресса ----------------

class ProgressPhoto {
  final String date;
  final String path;
  const ProgressPhoto(this.date, this.path);

  Map<String, dynamic> toJson() => {'date': date, 'path': path};
  factory ProgressPhoto.fromJson(Map<String, dynamic> j) =>
      ProgressPhoto(j['date']?.toString() ?? todayKey(), j['path']?.toString() ?? '');
}

// ---------------- Самочувствие ----------------

/// Запись дневника: настроение, энергия, стресс (1–5) и заметка.
class MoodEntry {
  final int mood;
  final int energy;
  final int stress;
  final String note;
  const MoodEntry({required this.mood, required this.energy, required this.stress, this.note = ''});

  Map<String, dynamic> toJson() => {'mood': mood, 'energy': energy, 'stress': stress, 'note': note};

  factory MoodEntry.fromJson(Map<String, dynamic> j) => MoodEntry(
        mood: asInt(j['mood'], 3).clamp(1, 5).toInt(),
        energy: asInt(j['energy'], 3).clamp(1, 5).toInt(),
        stress: asInt(j['stress'], 3).clamp(1, 5).toInt(),
        note: j['note']?.toString() ?? '',
      );
}
