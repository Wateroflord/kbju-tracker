import 'dart:math' as math;

import '../learn/srs.dart';
import '../util.dart';
import 'content.dart';
import 'models.dart';
import '../i18n/i18n.dart';

/// Данные новых разделов. Сохраняются вместе с остальными данными приложения
/// (ключ `life` в общем JSON). При любом изменении вызывает [_notify].
class LifeStore {
  final void Function() _notify;
  LifeStore(this._notify) {
    reset(silent: true);
  }

  // Привычки
  final List<Habit> habits = [];
  final Map<String, Set<String>> habitDone = {}; // ключ периода -> id отмеченных вручную

  // Шаги
  final Map<String, int> steps = {};
  int stepGoal = 10500;
  int stepSensorLast = -1; // последнее значение датчика (шаги с перезагрузки телефона)
  String stepSensorDay = '';
  String stepSource = 'manual'; // manual | sensor | health
  bool stepsPromptHidden = false;

  // Сон
  final Map<String, SleepEntry> sleep = {}; // ключ — день пробуждения
  double sleepGoal = 8;
  int sleepStartedAt = 0; // нажата «Ложусь спать»

  // Тренировки
  final List<Exercise> customExercises = [];
  final List<Program> customPrograms = [];
  String activeProgramId = 'gym_ab';
  final List<Session> sessions = [];
  int restSeconds = 120;
  final Map<String, List<int>> weekdayOverrides = {}; // дни недели для встроенных программ

  // Уход
  String skinType = '';
  String hairConcern = '';
  final List<ShopItem> shopping = [];

  // Напоминания: только изменяемые поля
  final Map<String, Reminder> reminders = {};

  // Фото прогресса
  final List<ProgressPhoto> photos = [];

  // Изучение языков
  String learnLang = 'en';
  int learnGoalMin = 45;
  final Map<String, Map<String, CardState>> learnCards = {};
  final Map<String, Map<String, int>> learnSeconds = {};
  final Map<String, String> learnGoalText = {};

  // Разминки и растяжка: день -> выполненные комплексы
  final Map<String, List<String>> routinesDone = {};

  // Самочувствие: дневник и минуты дыхания/медитации по дням
  final Map<String, MoodEntry> moods = {};
  final Map<String, int> mindSeconds = {};

  // Полученные достижения: id -> день
  final Map<String, String> achievements = {};

  int _id = 0;
  String newId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_id++}';

  // ---------- сериализация ----------

  void reset({bool silent = false}) {
    habits
      ..clear()
      ..addAll(defaultHabits);
    habitDone.clear();
    steps.clear();
    stepGoal = 10500;
    stepSensorLast = -1;
    stepSensorDay = '';
    stepSource = 'manual';
    stepsPromptHidden = false;
    sleep.clear();
    sleepGoal = 8;
    sleepStartedAt = 0;
    customExercises.clear();
    customPrograms.clear();
    activeProgramId = 'gym_ab';
    sessions.clear();
    restSeconds = 120;
    weekdayOverrides.clear();
    skinType = '';
    hairConcern = '';
    shopping
      ..clear()
      ..addAll(defaultShopping);
    reminders
      ..clear()
      ..addEntries(defaultReminders.map((r) => MapEntry(r.id, r)));
    photos.clear();
    learnLang = 'en';
    learnGoalMin = 45;
    learnCards.clear();
    learnSeconds.clear();
    learnGoalText.clear();
    routinesDone.clear();
    moods.clear();
    mindSeconds.clear();
    achievements.clear();
    if (!silent) _notify();
  }

  Map<String, dynamic> toJson() => {
        'habits': habits.map((h) => h.toJson()).toList(),
        'habitDone': habitDone.map((k, v) => MapEntry(k, v.toList())),
        'steps': steps,
        'stepGoal': stepGoal,
        'stepSensorLast': stepSensorLast,
        'stepSensorDay': stepSensorDay,
        'stepSource': stepSource,
        'stepsPromptHidden': stepsPromptHidden,
        'sleep': sleep.map((k, v) => MapEntry(k, v.toJson())),
        'sleepGoal': sleepGoal,
        'sleepStartedAt': sleepStartedAt,
        'customExercises': customExercises.map((e) => e.toJson()).toList(),
        'customPrograms': customPrograms.map((p) => p.toJson()).toList(),
        'activeProgramId': activeProgramId,
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'restSeconds': restSeconds,
        'weekdayOverrides': weekdayOverrides,
        'skinType': skinType,
        'hairConcern': hairConcern,
        'shopping': shopping.map((s) => s.toJson()).toList(),
        'reminders': reminders.values.map((r) => r.toJson()).toList(),
        'photos': photos.map((p) => p.toJson()).toList(),
        'learnLang': learnLang,
        'learnGoalMin': learnGoalMin,
        'learnCards': learnCards.map((l, m) => MapEntry(l, m.map((k, v) => MapEntry(k, v.toJson())))),
        'learnSeconds': learnSeconds,
        'learnGoalText': learnGoalText,
        'routinesDone': routinesDone,
        'moods': moods.map((k, v) => MapEntry(k, v.toJson())),
        'mindSeconds': mindSeconds,
        'achievements': achievements,
      };

  static List<Map<String, dynamic>> _maps(dynamic v) =>
      ((v as List?) ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

  void load(dynamic raw) {
    reset(silent: true);
    if (raw is! Map) return;
    final j = Map<String, dynamic>.from(raw);

    // Привычки: встроенные берём из кода (с сохранённым вкл/выкл), свои — как есть.
    final stored = {for (final m in _maps(j['habits'])) (m['id']?.toString() ?? ''): Habit.fromJson(m)};
    habits.clear();
    for (final d in defaultHabits) {
      final s = stored[d.id];
      habits.add(s == null ? d : d.copyWith(enabled: s.enabled));
    }
    for (final h in stored.values) {
      if (!h.builtin && h.id.isNotEmpty && h.title.isNotEmpty) habits.add(h);
    }
    final done = j['habitDone'];
    if (done is Map) {
      done.forEach((k, v) {
        if (v is List) habitDone[k.toString()] = v.map((e) => e.toString()).toSet();
      });
    }

    final st = j['steps'];
    if (st is Map) st.forEach((k, v) => steps[k.toString()] = asInt(v));
    stepGoal = asInt(j['stepGoal'], 10500).clamp(1000, 100000).toInt();
    stepSensorLast = asInt(j['stepSensorLast'], -1);
    stepSensorDay = j['stepSensorDay']?.toString() ?? '';
    stepSource = j['stepSource']?.toString() ?? 'manual';
    stepsPromptHidden = j['stepsPromptHidden'] == true;

    final sl = j['sleep'];
    if (sl is Map) {
      sl.forEach((k, v) {
        if (v is Map) sleep[k.toString()] = SleepEntry.fromJson(Map<String, dynamic>.from(v));
      });
    }
    sleepGoal = asDouble(j['sleepGoal'], 8).clamp(4, 12).toDouble();
    sleepStartedAt = asInt(j['sleepStartedAt']);

    customExercises.addAll(_maps(j['customExercises']).map(Exercise.fromJson));
    customPrograms.addAll(_maps(j['customPrograms']).map(Program.fromJson));
    activeProgramId = j['activeProgramId']?.toString() ?? 'gym_ab';
    if (programById(activeProgramId) == null) activeProgramId = 'gym_ab';
    sessions.addAll(_maps(j['sessions']).map(Session.fromJson));
    restSeconds = asInt(j['restSeconds'], 120).clamp(15, 600).toInt();
    final wo = j['weekdayOverrides'];
    if (wo is Map) {
      wo.forEach((k, v) {
        if (v is List) weekdayOverrides[k.toString()] = v.map((e) => asInt(e)).where((e) => e >= 1 && e <= 7).toList();
      });
    }

    skinType = j['skinType']?.toString() ?? '';
    hairConcern = j['hairConcern']?.toString() ?? '';
    final shop = _maps(j['shopping']);
    if (shop.isNotEmpty || j.containsKey('shopping')) {
      shopping
        ..clear()
        ..addAll(shop.map(ShopItem.fromJson));
    }

    for (final m in _maps(j['reminders'])) {
      final id = m['id']?.toString() ?? '';
      final base = reminders[id];
      if (base == null) continue;
      reminders[id] = base.copyWith(
        enabled: m['enabled'] == true,
        hour: asInt(m['hour'], base.hour).clamp(0, 23).toInt(),
        minute: asInt(m['minute'], base.minute).clamp(0, 59).toInt(),
      );
    }

    photos.addAll(_maps(j['photos']).map(ProgressPhoto.fromJson).where((p) => p.path.isNotEmpty));

    final ll = j['learnLang']?.toString() ?? 'en';
    learnLang = const ['en', 'pl', 'de'].contains(ll) ? ll : 'en';
    learnGoalMin = asInt(j['learnGoalMin'], 45).clamp(5, 180).toInt();
    final lc = j['learnCards'];
    if (lc is Map) {
      lc.forEach((l, m) {
        if (m is! Map) return;
        learnCards[l.toString()] = {
          for (final e in m.entries)
            if (e.value is Map) e.key.toString(): CardState.fromJson(Map<String, dynamic>.from(e.value as Map)),
        };
      });
    }
    final ls = j['learnSeconds'];
    if (ls is Map) {
      ls.forEach((l, m) {
        if (m is Map) learnSeconds[l.toString()] = m.map((k, v) => MapEntry(k.toString(), asInt(v)));
      });
    }
    final lg = j['learnGoalText'];
    if (lg is Map) lg.forEach((k, v) => learnGoalText[k.toString()] = v.toString());
    final md = j['moods'];
    if (md is Map) {
      md.forEach((k, v) {
        if (v is Map) moods[k.toString()] = MoodEntry.fromJson(Map<String, dynamic>.from(v));
      });
    }
    final ms = j['mindSeconds'];
    if (ms is Map) ms.forEach((k, v) => mindSeconds[k.toString()] = asInt(v));
    final ac = j['achievements'];
    if (ac is Map) ac.forEach((k, v) => achievements[k.toString()] = v.toString());
    final rd = j['routinesDone'];
    if (rd is Map) {
      rd.forEach((k, v) {
        if (v is List) routinesDone[k.toString()] = v.map((e) => e.toString()).toList();
      });
    }
  }

  // ---------- самочувствие ----------

  void setMood(String day, MoodEntry e) {
    moods[day] = e;
    _notify();
  }

  void deleteMood(String day) {
    moods.remove(day);
    _notify();
  }

  int mindSecondsOn(String day) => mindSeconds[day] ?? 0;

  void addMindSeconds(int sec) {
    if (sec <= 0) return;
    final k = todayKey();
    mindSeconds[k] = mindSecondsOn(k) + sec;
    _notify();
  }

  int get mindTotalMinutes => mindSeconds.values.fold(0, (s, v) => s + v) ~/ 60;

  void unlockAchievements(List<String> ids) {
    final d = todayKey();
    for (final id in ids) {
      achievements.putIfAbsent(id, () => d);
    }
    _notify();
  }

  // ---------- разминки ----------

  void markRoutine(String id) {
    routinesDone.putIfAbsent(todayKey(), () => []).add(id);
    _notify();
  }

  int get routinesTotal => routinesDone.values.fold(0, (s, l) => s + l.length);

  // ---------- привычки ----------

  List<Habit> habitsOf(HabitPeriod p, {bool onlyEnabled = true}) =>
      habits.where((h) => h.period == p && (!onlyEnabled || h.enabled)).toList();

  bool manualDone(Habit h, DateTime d) => habitDone[periodKey(h.period, d)]?.contains(h.id) ?? false;

  void toggleHabit(Habit h, DateTime d) {
    final k = periodKey(h.period, d);
    final set = habitDone.putIfAbsent(k, () => <String>{});
    if (!set.remove(h.id)) set.add(h.id);
    if (set.isEmpty) habitDone.remove(k);
    _notify();
  }

  void setHabitEnabled(String id, bool v) {
    final i = habits.indexWhere((h) => h.id == id);
    if (i < 0) return;
    habits[i] = habits[i].copyWith(enabled: v);
    _notify();
  }

  void addHabit(String title, HabitPeriod period, String icon) {
    final t = title.trim();
    if (t.isEmpty) return;
    habits.add(Habit(id: newId('h'), title: t, period: period, icon: icon));
    _notify();
  }

  void renameHabit(String id, String title) {
    final i = habits.indexWhere((h) => h.id == id);
    if (i < 0 || title.trim().isEmpty) return;
    habits[i] = habits[i].copyWith(title: title.trim());
    _notify();
  }

  void deleteHabit(String id) {
    habits.removeWhere((h) => h.id == id && !h.builtin);
    for (final s in habitDone.values) {
      s.remove(id);
    }
    _notify();
  }

  // ---------- шаги ----------

  int stepsFor(String key) => steps[key] ?? 0;

  void setSteps(String key, int v) {
    steps[key] = math.max(0, v);
    _notify();
  }

  void setStepGoal(int v) {
    stepGoal = v.clamp(1000, 100000).toInt();
    _notify();
  }

  /// Новое показание датчика (шаги с момента включения телефона).
  void applySensorReading(int value, DateTime now) {
    final k = dkey(now);
    if (stepSensorLast < 0) {
      stepSensorLast = value;
      stepSensorDay = k;
      _notify();
      return;
    }
    var delta = value - stepSensorLast;
    if (delta < 0) delta = value; // телефон перезагружали
    if (delta > 0 && delta < 100000) steps[k] = stepsFor(k) + delta;
    stepSensorLast = value;
    stepSensorDay = k;
    _notify();
  }

  /// Сообщить об изменении полей, изменённых снаружи.
  void touch() => _notify();

  /// Длина шага ~0,76 м → км.
  static double stepsToKm(int s) => s * 0.00076;

  /// ~100 шагов в минуту.
  static int stepsToMinutes(int s) => (s / 100).round();

  // ---------- сон ----------

  /// Сон за ночь, после которой наступил день [key].
  SleepEntry? sleepFor(String key) => sleep[key];

  void setSleep(String wakeKey, SleepEntry e) {
    sleep[wakeKey] = e;
    _notify();
  }

  void deleteSleep(String key) {
    sleep.remove(key);
    _notify();
  }

  void setSleepGoal(double h) {
    sleepGoal = h.clamp(4, 12).toDouble();
    _notify();
  }

  void startSleep() {
    sleepStartedAt = DateTime.now().millisecondsSinceEpoch;
    _notify();
  }

  /// Возвращает записанный сон или null, если «Ложусь спать» не нажимали.
  SleepEntry? finishSleep() {
    if (sleepStartedAt == 0) return null;
    final now = DateTime.now();
    final e = SleepEntry(sleepStartedAt, now.millisecondsSinceEpoch);
    sleepStartedAt = 0;
    if (e.hours > 0.2 && e.hours < 20) sleep[dkey(now)] = e;
    _notify();
    return e;
  }

  void cancelSleep() {
    sleepStartedAt = 0;
    _notify();
  }

  // ---------- тренировки ----------

  List<Program> get programs => [...builtinPrograms, ...customPrograms];

  Program? programById(String id) {
    for (final p in programs) {
      if (p.id == id) return p;
    }
    return null;
  }

  Program get activeProgram => programById(activeProgramId) ?? builtinPrograms.first;

  List<Exercise> get allExercises => [...builtinExercises, ...customExercises];

  Exercise exerciseById(String id) {
    for (final e in allExercises) {
      if (e.id == id) return e;
    }
    return Exercise(id: id, name: tr('Упражнение'));
  }

  void setActiveProgram(String id) {
    if (programById(id) == null) return;
    activeProgramId = id;
    _notify();
  }

  List<int> weekdaysOf(Program p) => weekdayOverrides[p.id] ?? p.weekdays;

  void setWeekdays(Program p, List<int> days) {
    final sorted = [...days]..sort();
    if (p.custom) {
      saveProgram(Program(id: p.id, title: p.title, desc: p.desc, days: p.days, weekdays: sorted, custom: true));
    } else {
      weekdayOverrides[p.id] = sorted;
      _notify();
    }
  }

  bool isTrainingDay(DateTime d) => weekdaysOf(activeProgram).contains(d.weekday);

  /// Какой день программы следующий (по последней завершённой тренировке этой программы).
  WorkoutDay nextDay([Program? program]) {
    final p = program ?? activeProgram;
    if (p.days.isEmpty) return WorkoutDay(id: 'empty', title: tr('Тренировка'), exercises: []);
    for (var i = sessions.length - 1; i >= 0; i--) {
      final s = sessions[i];
      if (s.programId == p.id && s.finished) {
        final idx = p.days.indexWhere((d) => d.id == s.dayId);
        return p.days[(idx + 1) % p.days.length];
      }
    }
    return p.days.first;
  }

  List<Session> sessionsOn(String key) => sessions.where((s) => s.date == key).toList();

  Session? get activeSession {
    for (var i = sessions.length - 1; i >= 0; i--) {
      if (!sessions[i].finished) return sessions[i];
    }
    return null;
  }

  int finishedSessionsBetween(DateTime from, DateTime toExclusive) {
    final a = dkey(from), b = dkey(toExclusive);
    return sessions.where((s) => s.finished && s.date.compareTo(a) >= 0 && s.date.compareTo(b) < 0).length;
  }

  /// Последние выполненные подходы упражнения (из последней завершённой тренировки, где оно было).
  List<SetLog>? lastSetsOf(String exId, {String? exceptSessionId}) {
    for (var i = sessions.length - 1; i >= 0; i--) {
      final s = sessions[i];
      if (!s.finished || s.id == exceptSessionId) continue;
      for (final e in s.exercises) {
        if (e.exId == exId && e.sets.any((x) => x.done)) return e.sets.where((x) => x.done).toList();
      }
    }
    return null;
  }

  Session startSession(Program p, WorkoutDay day) {
    final s = Session(
      id: newId('s'),
      date: todayKey(),
      programId: p.id,
      dayId: day.id,
      title: day.title,
      startedAt: DateTime.now().millisecondsSinceEpoch,
      exercises: [
        for (final pe in day.exercises)
          SessionExercise(pe.exId, _prefill(pe)),
      ],
    );
    sessions.add(s);
    _notify();
    return s;
  }

  List<SetLog> _prefill(PlanExercise pe) {
    final last = lastSetsOf(pe.exId);
    final w = (last != null && last.isNotEmpty) ? last.first.weight : 0.0;
    final defReps = pe.toFailure ? 0 : pe.repMin;
    return List.generate(pe.sets, (i) {
      final prev = (last != null && i < last.length) ? last[i] : null;
      return SetLog(weight: prev?.weight ?? w, reps: prev?.reps ?? defReps);
    });
  }

  void updateSession(Session s) {
    final i = sessions.indexWhere((x) => x.id == s.id);
    if (i < 0) return;
    sessions[i] = s;
    _notify();
  }

  void finishSession(String id) {
    final i = sessions.indexWhere((x) => x.id == id);
    if (i < 0) return;
    sessions[i] = sessions[i].copyWith(finishedAt: DateTime.now().millisecondsSinceEpoch);
    _notify();
  }

  void deleteSession(String id) {
    sessions.removeWhere((x) => x.id == id);
    _notify();
  }

  void setRestSeconds(int v) {
    restSeconds = v.clamp(15, 600).toInt();
    _notify();
  }

  void addExercise(Exercise e) {
    customExercises.add(e);
    _notify();
  }

  void deleteExercise(String id) {
    customExercises.removeWhere((e) => e.id == id);
    _notify();
  }

  void saveProgram(Program p) {
    final i = customPrograms.indexWhere((x) => x.id == p.id);
    if (i < 0) {
      customPrograms.add(p);
    } else {
      customPrograms[i] = p;
    }
    _notify();
  }

  void deleteProgram(String id) {
    customPrograms.removeWhere((p) => p.id == id);
    if (activeProgramId == id) activeProgramId = 'gym_ab';
    _notify();
  }

  // ---------- уход ----------

  void setSkinType(String v) {
    skinType = v;
    _notify();
  }

  void setHairConcern(String v) {
    hairConcern = v;
    _notify();
  }

  void toggleBought(String id) {
    final i = shopping.indexWhere((s) => s.id == id);
    if (i < 0) return;
    shopping[i] = shopping[i].copyWith(bought: !shopping[i].bought);
    _notify();
  }

  void saveShopItem(ShopItem item) {
    final i = shopping.indexWhere((s) => s.id == item.id);
    if (i < 0) {
      shopping.add(item);
    } else {
      shopping[i] = item;
    }
    _notify();
  }

  void deleteShopItem(String id) {
    shopping.removeWhere((s) => s.id == id);
    _notify();
  }

  // ---------- напоминания ----------

  List<Reminder> get reminderList => defaultReminders.map((d) => reminders[d.id] ?? d).toList();

  void updateReminder(Reminder r) {
    reminders[r.id] = r;
    _notify();
  }

  // ---------- фото ----------

  void addPhoto(ProgressPhoto p) {
    photos.add(p);
    photos.sort((a, b) => a.date.compareTo(b.date));
    _notify();
  }

  void deletePhoto(String path) {
    photos.removeWhere((p) => p.path == path);
    _notify();
  }
}
