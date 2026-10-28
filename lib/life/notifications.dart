import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../store.dart';
import 'models.dart';
import '../i18n/i18n.dart';

/// Локальные напоминания (работают без интернета).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Запросить разрешение на уведомления (Android 13+). true — разрешено.
  Future<bool> requestPermission() async {
    await _init();
    final ok = await _android?.requestNotificationsPermission();
    return ok ?? true;
  }

  /// Сколько дней вперёд планировать. График обновляется при каждом открытии приложения.
  static const _daysAhead = 21;

  /// Перепланировать все напоминания по текущим настройкам.
  Future<void> sync(AppStore store) async {
    try {
      await _init();
      await _plugin.cancelAll();
      final list = store.life.reminderList;
      final now = DateTime.now();
      for (var i = 0; i < list.length; i++) {
        final r = list[i];
        if (!r.enabled) continue;
        final days = r.fromProgram ? store.life.weekdaysOf(store.life.activeProgram) : r.weekdays;
        for (var d = 0; d < _daysAhead; d++) {
          final day = DateTime(now.year, now.month, now.day + d);
          if (days.isNotEmpty && !days.contains(day.weekday)) continue;
          final at = DateTime(day.year, day.month, day.day, r.hour, r.minute);
          if (!at.isAfter(now)) continue;
          await _schedule(i * 100 + d, r, at);
        }
      }
    } catch (e) {
      debugPrint('notifications sync failed: $e');
    }
  }

  Future<void> _schedule(int id, Reminder r, DateTime localTime) async {
    // Местное время -> UTC: учитывает переход на летнее/зимнее время.
    final at = tz.TZDateTime.from(localTime.toUtc(), tz.UTC);
    await _plugin.zonedSchedule(
      id,
      tr(r.title),
      tr(r.body),
      at,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          tr('Напоминания'),
          channelDescription: tr('Вода, уход, тренировки, сон'),
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
