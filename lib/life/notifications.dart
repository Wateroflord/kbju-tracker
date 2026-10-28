import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../store.dart';
import 'models.dart';

/// Локальные напоминания (работают без интернета).
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> _init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    try {
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      debugPrint('timezone: $e');
    }
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

  /// Перепланировать все напоминания по текущим настройкам.
  Future<void> sync(AppStore store) async {
    try {
      await _init();
      await _plugin.cancelAll();
      final list = store.life.reminderList;
      for (var i = 0; i < list.length; i++) {
        final r = list[i];
        if (!r.enabled) continue;
        final days = r.fromProgram ? store.life.weekdaysOf(store.life.activeProgram) : r.weekdays;
        if (days.isEmpty) {
          await _schedule(i * 10, r, null);
        } else {
          for (final d in days) {
            await _schedule(i * 10 + d, r, d);
          }
        }
      }
    } catch (e) {
      debugPrint('notifications sync failed: $e');
    }
  }

  Future<void> _schedule(int id, Reminder r, int? weekday) async {
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, r.hour, r.minute);
    if (weekday != null) {
      while (at.weekday != weekday || !at.isAfter(now)) {
        at = at.add(const Duration(days: 1));
      }
    } else if (!at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id,
      r.title,
      r.body,
      at,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          'Напоминания',
          channelDescription: 'Вода, уход, тренировки, сон',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents:
          weekday == null ? DateTimeComponents.time : DateTimeComponents.dayOfWeekAndTime,
    );
  }
}
