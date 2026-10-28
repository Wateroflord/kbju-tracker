import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import '../store.dart';
import '../util.dart';

/// Подсчёт шагов.
/// 1) Health Connect — точнее всего: туда пишут Google Fit, Samsung Health, часы.
/// 2) Датчик шагов телефона — считает, пока приложение запущено или недавно открывалось.
/// 3) Ручной ввод.
class StepsService {
  StepsService._();
  static final StepsService instance = StepsService._();

  AppStore? _store;
  StreamSubscription<StepCount>? _sub;
  final Health _health = Health();
  bool _healthConfigured = false;

  /// Последняя ошибка или подсказка для экрана шагов.
  final ValueNotifier<String> status = ValueNotifier('');

  Future<void> init(AppStore store) async {
    _store = store;
    await _resumeSource();
  }

  Future<void> onResume() => _resumeSource();

  Future<void> _resumeSource() async {
    final s = _store;
    if (s == null) return;
    switch (s.life.stepSource) {
      case 'health':
        await syncHealth();
      case 'sensor':
        if (await Permission.activityRecognition.isGranted) {
          _listenSensor();
        } else {
          status.value = 'Нет разрешения на физическую активность';
        }
      default:
        break;
    }
  }

  // ---------- Health Connect ----------

  Future<void> _configure() async {
    if (_healthConfigured) return;
    await _health.configure();
    _healthConfigured = true;
  }

  /// Возвращает null при успехе или текст ошибки.
  Future<String?> connectHealth() async {
    final s = _store;
    if (s == null) return 'Приложение ещё загружается';
    try {
      await _configure();
      final sdk = await _health.getHealthConnectSdkStatus();
      if (sdk != HealthConnectSdkStatus.sdkAvailable) {
        return 'Health Connect не установлен или требует обновления. '
            'Установи «Health Connect» из Google Play и попробуй снова.';
      }
      final ok = await _health.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );
      if (!ok) return 'Доступ к шагам в Health Connect не выдан';
      await _sub?.cancel();
      _sub = null;
      s.life.stepSource = 'health';
      await syncHealth();
      return null;
    } catch (e) {
      return 'Не удалось подключить Health Connect: $e';
    }
  }

  Future<void> installHealthConnect() async {
    try {
      await _configure();
      await _health.installHealthConnect();
    } catch (e) {
      status.value = 'Не удалось открыть Google Play: $e';
    }
  }

  /// Подтягивает шаги за последние [days] дней.
  Future<void> syncHealth({int days = 14}) async {
    final s = _store;
    if (s == null) return;
    try {
      await _configure();
      final now = DateTime.now();
      for (var i = 0; i < days; i++) {
        final start = addDays(dayOnly(now), -i);
        final end = i == 0 ? now : addDays(start, 1);
        final v = await _health.getTotalStepsInInterval(start, end);
        if (v != null) s.life.steps[dkey(start)] = v;
      }
      status.value = '';
      s.life.touch();
    } catch (e) {
      status.value = 'Health Connect: $e';
    }
  }

  // ---------- Датчик шагов ----------

  Future<String?> connectSensor() async {
    final s = _store;
    if (s == null) return 'Приложение ещё загружается';
    final p = await Permission.activityRecognition.request();
    if (!p.isGranted) {
      return p.isPermanentlyDenied
          ? 'Разрешение запрещено. Включи «Физическая активность» в настройках приложения.'
          : 'Без разрешения на физическую активность датчик шагов недоступен';
    }
    s.life.stepSource = 'sensor';
    s.life.stepSensorLast = -1; // первая отметка станет точкой отсчёта
    _listenSensor();
    s.life.touch();
    return null;
  }

  void _listenSensor() {
    _sub ??= Pedometer.stepCountStream.listen(
      (e) {
        status.value = '';
        _store?.life.applySensorReading(e.steps, DateTime.now());
      },
      onError: (Object e) {
        status.value = 'Датчик шагов недоступен на этом телефоне';
      },
      cancelOnError: false,
    );
  }

  Future<void> useManual() async {
    await _sub?.cancel();
    _sub = null;
    final s = _store;
    if (s == null) return;
    s.life.stepSource = 'manual';
    status.value = '';
    s.life.touch();
  }

  Future<void> openSettings() => openAppSettings();
}
