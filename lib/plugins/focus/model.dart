/// Фокус — помидоры, проекты и задачи (чистая логика, проверяется тестами).
library;

enum Phase { work, shortBreak, longBreak }

class FocusSettings {
  final int work, shortBreak, longBreak, longEvery;
  final bool autoBreak;
  const FocusSettings({this.work = 25, this.shortBreak = 5, this.longBreak = 15, this.longEvery = 4, this.autoBreak = true});

  int minutesOf(Phase p) => switch (p) {
        Phase.work => work,
        Phase.shortBreak => shortBreak,
        Phase.longBreak => longBreak,
      };

  Map<String, dynamic> toJson() => {'w': work, 's': shortBreak, 'l': longBreak, 'e': longEvery, 'a': autoBreak};

  static FocusSettings fromJson(dynamic j) {
    if (j is! Map) return const FocusSettings();
    int i(String k, int d, int max) {
      final v = j[k];
      return (v is num ? v.toInt() : d).clamp(1, max);
    }
    return FocusSettings(
      work: i('w', 25, 180),
      shortBreak: i('s', 5, 60),
      longBreak: i('l', 15, 90),
      longEvery: i('e', 4, 12),
      autoBreak: j['a'] != false,
    );
  }

  FocusSettings copyWith({int? work, int? shortBreak, int? longBreak, int? longEvery, bool? autoBreak}) => FocusSettings(
        work: work ?? this.work,
        shortBreak: shortBreak ?? this.shortBreak,
        longBreak: longBreak ?? this.longBreak,
        longEvery: longEvery ?? this.longEvery,
        autoBreak: autoBreak ?? this.autoBreak,
      );
}

/// Что после фазы: после работы — короткий перерыв, каждый [longEvery]-й — длинный; после перерыва — работа.
/// [doneWork] — сколько рабочих помидоров уже сделано в этом цикле (включая только что законченный).
Phase nextPhase(Phase current, int doneWork, int longEvery) {
  if (current != Phase.work) return Phase.work;
  return doneWork > 0 && doneWork % longEvery == 0 ? Phase.longBreak : Phase.shortBreak;
}

class FocusProject {
  final String id, name;
  final int color;
  final bool archived;
  const FocusProject(this.id, this.name, this.color, {this.archived = false});

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 'c': color, if (archived) 'a': true};

  static FocusProject? fromJson(dynamic j) {
    if (j is! Map || j['id'] == null) return null;
    return FocusProject(j['id'].toString(), j['n']?.toString() ?? '', (j['c'] as num?)?.toInt() ?? 0, archived: j['a'] == true);
  }

  FocusProject copyWith({String? name, int? color, bool? archived}) =>
      FocusProject(id, name ?? this.name, color ?? this.color, archived: archived ?? this.archived);
}

class FocusTask {
  final String id, project, title;
  final bool done;
  final int pomodoros;
  const FocusTask(this.id, this.project, this.title, {this.done = false, this.pomodoros = 0});

  Map<String, dynamic> toJson() => {'id': id, 'p': project, 't': title, if (done) 'd': true, if (pomodoros > 0) 'n': pomodoros};

  static FocusTask? fromJson(dynamic j) {
    if (j is! Map || j['id'] == null) return null;
    return FocusTask(j['id'].toString(), j['p']?.toString() ?? '', j['t']?.toString() ?? '',
        done: j['d'] == true, pomodoros: (j['n'] as num?)?.toInt() ?? 0);
  }

  FocusTask copyWith({String? title, bool? done, int? pomodoros}) =>
      FocusTask(id, project, title ?? this.title, done: done ?? this.done, pomodoros: pomodoros ?? this.pomodoros);
}

/// Запись в журнале: сколько минут фокуса в какой день и по какому проекту.
class FocusLog {
  final String day, project;
  final int minutes;
  const FocusLog(this.day, this.project, this.minutes);

  Map<String, dynamic> toJson() => {'d': day, 'p': project, 'm': minutes};

  static FocusLog? fromJson(dynamic j) {
    if (j is! Map) return null;
    final m = (j['m'] as num?)?.toInt() ?? 0;
    if (m <= 0) return null;
    return FocusLog(j['d']?.toString() ?? '', j['p']?.toString() ?? '', m);
  }
}

/// Минуты по дням: ключ — yyyy-MM-dd.
Map<String, int> minutesByDay(Iterable<FocusLog> logs, {String? project}) {
  final out = <String, int>{};
  for (final l in logs) {
    if (project != null && l.project != project) continue;
    out[l.day] = (out[l.day] ?? 0) + l.minutes;
  }
  return out;
}

/// Минуты по проектам за дни [from]…[to] включительно.
Map<String, int> minutesByProject(Iterable<FocusLog> logs, String from, String to) {
  final out = <String, int>{};
  for (final l in logs) {
    if (l.day.compareTo(from) < 0 || l.day.compareTo(to) > 0) continue;
    out[l.project] = (out[l.project] ?? 0) + l.minutes;
  }
  return out;
}

/// Серия: сколько дней подряд (до сегодня включительно или до вчера) был хоть один помидор.
int focusStreak(Map<String, int> byDay, DateTime today) {
  String k(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  var d = DateTime(today.year, today.month, today.day);
  if ((byDay[k(d)] ?? 0) == 0) d = DateTime(d.year, d.month, d.day - 1);
  var n = 0;
  while ((byDay[k(d)] ?? 0) > 0) {
    n++;
    d = DateTime(d.year, d.month, d.day - 1);
  }
  return n;
}

/// «1 ч 25 мин», «40 мин».
String durText(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m мин';
  return m == 0 ? '$h ч' : '$h ч $m мин';
}
