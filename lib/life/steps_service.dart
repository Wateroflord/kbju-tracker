import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

import '../store.dart';
import '../util.dart';
import '../i18n/i18n.dart';

/// Подсчёт шагов.
/// 1) Health Connect — точнее всего: туда пишут Google Fit, Samsung Health, часы.
/// 2) Датчик шагов телефона — фоновая служба Android считает шаги постоянно,
///    даже когда приложение закрыто (в шторке висит уведомление «Шаги сегодня»).
/// 3) Ручной ввод.
class StepsService {
  StepsService._();
  static final StepsService instance = StepsService._();

  AppStore? _store;
  static const _channel = MethodChannel('kbju/steps');
  Timer? _poll;
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
          await _startNative();
        } else {
          status.value = tr('Нет разрешения на физическую активность — включи датчик заново');
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
    if (s == null) return tr('Приложение ещё загружается');
    try {
      await _configure();
      final sdk = await _health.getHealthConnectSdkStatus();
      if (sdk != HealthConnectSdkStatus.sdkAvailable) {
        return tr('Health Connect не установлен или требует обновления. Установи «Health Connect» из Google Play и попробуй снова.');
      }
      final ok = await _health.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );
      if (!ok) return tr('Доступ к шагам в Health Connect не выдан');
      await _stopNative();
      s.life.stepSource = 'health';
      await syncHealth();
      return null;
    } catch (e) {
      return trf('Не удалось подключить Health Connect: {0}', [e]);
    }
  }

  Future<void> installHealthConnect() async {
    try {
      await _configure();
      await _health.installHealthConnect();
    } catch (e) {
      status.value = trf('Не удалось открыть Google Play: {0}', [e]);
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

  // ---------- Датчик шагов (фоновая служба) ----------

  Future<String?> connectSensor() async {
    final s = _store;
    if (s == null) return tr('Приложение ещё загружается');
    try {
      final has = await _channel.invokeMethod<bool>('hasSensor') ?? false;
      if (!has) return tr('В этом телефоне нет датчика шагов. Используй Health Connect или ручной ввод.');
    } catch (_) {}
    final p = await Permission.activityRecognition.request();
    if (!p.isGranted) {
      return p.isPermanentlyDenied
          ? tr('Разрешение запрещено. Включи «Физическая активность» в настройках приложения.')
          : tr('Без разрешения на физическую активность датчик шагов недоступен');
    }
    // Уведомление нужно, чтобы видеть шаги в шторке (Android 13+ спрашивает отдельно).
    await Permission.notification.request();
    s.life.stepSource = 'sensor';
    await _startNative();
    s.life.touch();
    return null;
  }

  Future<void> _startNative() async {
    try {
      await _channel.invokeMethod('start');
      status.value = '';
    } catch (e) {
      status.value = trf('Не удалось запустить шагомер: {0}', [e]);
      return;
    }
    await syncNative();
    _poll ??= Timer.periodic(const Duration(seconds: 15), (_) => syncNative());
  }

  Future<void> _stopNative() async {
    _poll?.cancel();
    _poll = null;
    try {
      await _channel.invokeMethod('stop');
    } catch (_) {}
  }

  /// Забирает шаги по дням из фоновой службы.
  Future<void> syncNative() async {
    final s = _store;
    if (s == null || s.life.stepSource != 'sensor') return;
    try {
      final raw = await _channel.invokeMethod<String>('days') ?? '{}';
      final m = jsonDecode(raw);
      if (m is! Map) return;
      var changed = false;
      m.forEach((k, v) {
        final key = k.toString();
        final n = asInt(v);
        if (n > s.life.stepsFor(key)) {
          s.life.steps[key] = n;
          changed = true;
        }
      });
      if (changed) s.life.touch();
    } catch (e) {
      debugPrint('steps sync: $e');
    }
  }

  /// Попросить Android не усыплять шагомер (важно на Xiaomi, Huawei, Samsung).
  Future<bool> requestNoBatteryLimit() async {
    final st = await Permission.ignoreBatteryOptimizations.request();
    return st.isGranted;
  }

  Future<bool> get batteryUnrestricted => Permission.ignoreBatteryOptimizations.isGranted;

  /// Приложение свернули — опрос не нужен, служба продолжает считать сама.
  void onPause() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> useManual() async {
    await _stopNative();
    final s = _store;
    if (s == null) return;
    s.life.stepSource = 'manual';
    status.value = '';
    s.life.touch();
  }

  Future<void> openSettings() => openAppSettings();
}
