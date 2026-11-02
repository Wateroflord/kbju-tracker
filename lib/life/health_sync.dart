import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

import '../extra_store.dart';
import '../platform.dart';
import '../store.dart';
import '../util.dart';
import '../i18n/i18n.dart';
import 'models.dart';

/// Вес, сон и тренировки из Health Connect (умные весы, часы, Samsung Health, Google Fit).
/// Шаги подтягивает [StepsService], здесь — всё остальное.
class HealthSync {
  HealthSync._();
  static final HealthSync instance = HealthSync._();

  final Health _health = Health();
  bool _configured = false;
  bool _busy = false;

  /// Последняя ошибка для экрана настроек.
  final ValueNotifier<String> status = ValueNotifier('');

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  List<HealthDataType> _types(AppStore s) => [
        if (s.extra.hcWeight) HealthDataType.WEIGHT,
        if (s.extra.hcSleep) HealthDataType.SLEEP_SESSION,
        if (s.extra.hcWorkouts) ...[
          HealthDataType.WORKOUT,
          HealthDataType.TOTAL_CALORIES_BURNED,
          HealthDataType.DISTANCE_DELTA,
        ],
      ];

  /// Запросить доступ к выбранным данным и сразу синхронизировать.
  /// Возвращает null при успехе или текст ошибки.
  Future<String?> connect(AppStore s) async {
    if (!isAndroid) return tr('Health Connect есть только на телефоне — синхронизируй его с ПК, и данные появятся здесь');
    final types = _types(s);
    if (types.isEmpty) return tr('Выбери, что подтягивать');
    try {
      await _configure();
      final sdk = await _health.getHealthConnectSdkStatus();
      if (sdk != HealthConnectSdkStatus.sdkAvailable) {
        return tr('Health Connect не установлен или требует обновления. Установи «Health Connect» из Google Play и попробуй снова.');
      }
      final ok = await _health.requestAuthorization(
        types,
        permissions: [for (final _ in types) HealthDataAccess.READ],
      );
      if (!ok) return tr('Доступ в Health Connect не выдан');
      final n = await sync(s);
      return n == null ? status.value : null;
    } catch (e) {
      return trf('Не удалось подключить Health Connect: {0}', [e]);
    }
  }

  /// Подтянуть данные за [days] дней. Возвращает число новых записей или null при ошибке.
  Future<int?> sync(AppStore s, {int days = 30}) async {
    if (!isAndroid || !s.extra.hcAny || _busy) return 0;
    _busy = true;
    try {
      await _configure();
      final now = DateTime.now();
      final start = addDays(dayOnly(now), -days + 1);
      final weights = <String, double>{};
      final weightTime = <String, DateTime>{};
      final sleep = <String, SleepEntry>{};

      if (s.extra.hcWeight) {
        for (final p in await _read(HealthDataType.WEIGHT, start, now)) {
          final v = p.value;
          if (v is! NumericHealthValue) continue;
          final k = dkey(p.dateFrom);
          final prev = weightTime[k];
          if (prev == null || p.dateFrom.isAfter(prev)) {
            weights[k] = v.numericValue.toDouble();
            weightTime[k] = p.dateFrom;
          }
        }
      }

      if (s.extra.hcSleep) {
        for (final p in await _read(HealthDataType.SLEEP_SESSION, start, now)) {
          final e = SleepEntry(p.dateFrom.millisecondsSinceEpoch, p.dateTo.millisecondsSinceEpoch);
          final k = dkey(p.dateTo);
          final prev = sleep[k];
          // Если за ночь несколько записей (дневной сон), берём самую длинную.
          if (prev == null || e.hours > prev.hours) sleep[k] = e;
        }
      }

      var workouts = 0;
      if (s.extra.hcWorkouts) {
        final byDay = <String, List<HcWorkout>>{};
        for (final p in await _read(HealthDataType.WORKOUT, start, now)) {
          final v = p.value;
          var type = 'OTHER';
          var kcal = 0, meters = 0;
          if (v is WorkoutHealthValue) {
            type = v.workoutActivityType.name;
            kcal = (v.totalEnergyBurned ?? 0).round();
            meters = (v.totalDistance ?? 0).round();
          }
          final w = HcWorkout(
            start: p.dateFrom.millisecondsSinceEpoch,
            end: p.dateTo.millisecondsSinceEpoch,
            type: type,
            kcal: kcal,
            meters: meters,
          );
          if (w.minutes < 3) continue;
          final list = byDay.putIfAbsent(dkey(p.dateFrom), () => []);
          if (!list.any((x) => x.start == w.start)) list.add(w);
        }
        for (var i = 0; i < days; i++) {
          final k = dkey(addDays(start, i));
          final list = byDay[k] ?? const <HcWorkout>[];
          workouts += list.length;
          s.extra.setHcDay(k, [...list]);
        }
      }

      final n = s.applyHealth(weights: weights, sleep: sleep);
      status.value = '';
      return n + workouts;
    } catch (e) {
      status.value = 'Health Connect: $e';
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<List<HealthDataPoint>> _read(HealthDataType t, DateTime from, DateTime to) async {
    try {
      return await _health.getHealthDataFromTypes(types: [t], startTime: from, endTime: to);
    } catch (e) {
      debugPrint('health read $t: $e');
      return const [];
    }
  }
}

/// Название тренировки из Health Connect.
String hcWorkoutTitle(String type) {
  final t = type.toUpperCase();
  if (t.contains('RUNNING')) return tr('Бег');
  if (t.contains('WALKING') || t.contains('HIKING')) return tr('Ходьба');
  if (t.contains('BIKING') || t.contains('CYCLING')) return tr('Велосипед');
  if (t.contains('SWIMMING')) return tr('Плавание');
  if (t.contains('STRENGTH') || t.contains('WEIGHT')) return tr('Силовая');
  if (t.contains('YOGA') || t.contains('PILATES')) return tr('Йога');
  if (t.contains('HIGH_INTENSITY') || t.contains('HIIT')) return tr('Интервальная');
  if (t.contains('SOCCER') || t.contains('FOOTBALL')) return tr('Футбол');
  if (t.contains('BASKETBALL')) return tr('Баскетбол');
  if (t.contains('ELLIPTICAL')) return tr('Эллипс');
  if (t.contains('ROWING')) return tr('Гребля');
  if (t.contains('DANC')) return tr('Танцы');
  if (t.contains('BOXING') || t.contains('MARTIAL')) return tr('Единоборства');
  return tr('Тренировка');
}
