import 'util.dart';

/// Тренировка, пришедшая из Health Connect (часы, Samsung Health, Google Fit).
class HcWorkout {
  final int start; // ms
  final int end; // ms
  final String type; // тип из Health Connect, например RUNNING
  final int kcal; // 0 — неизвестно
  final int meters; // 0 — неизвестно

  const HcWorkout({required this.start, required this.end, required this.type, this.kcal = 0, this.meters = 0});

  int get minutes => ((end - start) / 60000).round();

  Map<String, dynamic> toJson() => {
        'id': '$start',
        'start': start,
        'end': end,
        'type': type,
        if (kcal > 0) 'kcal': kcal,
        if (meters > 0) 'meters': meters,
      };

  factory HcWorkout.fromJson(Map<String, dynamic> j) => HcWorkout(
        start: asInt(j['start']),
        end: asInt(j['end']),
        type: j['type']?.toString() ?? 'OTHER',
        kcal: asInt(j['kcal']),
        meters: asInt(j['meters']),
      );
}

/// Вкладки, которые можно скрыть.
const hideableTabs = ['training', 'care', 'learn'];

/// Настройки и данные, добавленные позже: скрытые вкладки, Health Connect.
/// Сохраняются в общем JSON под ключом `extra`.
class ExtraStore {
  final void Function() _notify;
  ExtraStore(this._notify);

  final Set<String> hiddenTabs = {};

  // Health Connect: что подтягивать
  bool hcWeight = false;
  bool hcSleep = false;
  bool hcWorkouts = false;
  int hcLastSync = 0; // ms

  /// Тренировки с часов: день -> список
  final Map<String, List<HcWorkout>> hcLog = {};

  bool get hcAny => hcWeight || hcSleep || hcWorkouts;

  void reset({bool silent = false}) {
    hiddenTabs.clear();
    hcWeight = false;
    hcSleep = false;
    hcWorkouts = false;
    hcLastSync = 0;
    hcLog.clear();
    if (!silent) _notify();
  }

  Map<String, dynamic> toJson() => {
        'hiddenTabs': hiddenTabs.toList()..sort(),
        'hcWeight': hcWeight,
        'hcSleep': hcSleep,
        'hcWorkouts': hcWorkouts,
        'hcLastSync': hcLastSync,
        'hcLog': hcLog.map((k, v) => MapEntry(k, v.map((w) => w.toJson()).toList())),
      };

  void load(dynamic raw) {
    reset(silent: true);
    if (raw is! Map) return;
    final j = Map<String, dynamic>.from(raw);
    final ht = j['hiddenTabs'];
    if (ht is List) hiddenTabs.addAll(ht.map((e) => e.toString()).where(hideableTabs.contains));
    hcWeight = j['hcWeight'] == true;
    hcSleep = j['hcSleep'] == true;
    hcWorkouts = j['hcWorkouts'] == true;
    hcLastSync = asInt(j['hcLastSync']);
    final log = j['hcLog'];
    if (log is Map) {
      log.forEach((k, v) {
        if (v is List) {
          final list = v.whereType<Map>().map((m) => HcWorkout.fromJson(Map<String, dynamic>.from(m))).where((w) => w.end > w.start).toList();
          if (list.isNotEmpty) hcLog[k.toString()] = list;
        }
      });
    }
  }

  bool tabVisible(String id) => !hiddenTabs.contains(id);

  void setTabVisible(String id, bool v) {
    if (v) {
      hiddenTabs.remove(id);
    } else {
      hiddenTabs.add(id);
    }
    _notify();
  }

  void setHc({bool? weight, bool? sleep, bool? workouts}) {
    if (weight != null) hcWeight = weight;
    if (sleep != null) hcSleep = sleep;
    if (workouts != null) hcWorkouts = workouts;
    _notify();
  }

  /// Записать тренировки за день (заменяет прежние данные этого дня).
  void setHcDay(String day, List<HcWorkout> list) {
    if (list.isEmpty) {
      hcLog.remove(day);
    } else {
      hcLog[day] = list..sort((a, b) => a.start.compareTo(b.start));
    }
  }

  void touchSync() {
    hcLastSync = DateTime.now().millisecondsSinceEpoch;
    _notify();
  }

  /// Тренировки с часов за последние [days] дней, новые сверху.
  List<HcWorkout> recentWorkouts({int days = 14}) {
    final from = dkey(addDays(today(), -days + 1));
    final out = <HcWorkout>[];
    hcLog.forEach((k, v) {
      if (k.compareTo(from) >= 0) out.addAll(v);
    });
    out.sort((a, b) => b.start.compareTo(a.start));
    return out;
  }
}
