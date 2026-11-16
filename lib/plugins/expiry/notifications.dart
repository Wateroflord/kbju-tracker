import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'storage.dart';

/// Уведомления: одно на день, со списком всего, что пора проверить.
class Notifier {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ));
      _ready = true;
    } catch (e) {
      debugPrint('Уведомления не запустились: $e');
    }
  }

  static Future<void> requestPermission() async {
    if (!_ready) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Разрешение на уведомления: $e');
    }
  }

  static NotificationDetails _details(String bigText) => NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry',
          'Сроки годности',
          channelDescription: 'Напоминания о скорой просрочке',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(bigText),
        ),
      );

  static Future<void> showTest() async {
    if (!_ready) return;
    try {
      await _plugin.show(
        999999,
        'Уведомления работают ✅',
        'Так будут выглядеть напоминания о просрочке',
        _details('Так будут выглядеть напоминания о просрочке'),
      );
    } catch (e) {
      debugPrint('Тестовое уведомление: $e');
    }
  }

  static Future<void> reschedule(AppStore store) async {
    if (!_ready) return;
    try {
      // Только свои уведомления (номера от 10000): напоминания КБЖУ не трогаем.
      for (final r in await _plugin.pendingNotificationRequests()) {
        if (r.id >= 10000) await _plugin.cancel(r.id);
      }
      final now = DateTime.now();
      final Map<DateTime, List<String>> byDay = {};

      for (final item in store.items.where((i) => !i.removed)) {
        final exp = DateTime(item.expiry.year, item.expiry.month, item.expiry.day);
        final days = <DateTime>{
          DateTime(exp.year, exp.month, exp.day - store.warnDays),
          exp,
          DateTime(exp.year, exp.month, exp.day + 1), // уже просрочено
        };
        for (final day in days) {
          final fire = DateTime(
              day.year, day.month, day.day, store.notifyHour, store.notifyMinute);
          if (fire.isBefore(now)) continue;
          final left = daysBetween(day, exp);
          final line =
              '${item.shelf.emoji} ${item.name} ×${item.quantity} — ${statusText(left)}';
          byDay.putIfAbsent(day, () => <String>[]).add(line);
        }
      }

      final keys = byDay.keys.toList()..sort();
      var count = 0;
      for (final day in keys) {
        if (count >= 60) break; // у Android есть лимит на число будильников
        count++;
        final lines = byDay[day]!;
        final fire = DateTime(
            day.year, day.month, day.day, store.notifyHour, store.notifyMinute);
        final when = tz.TZDateTime.from(fire, tz.UTC);
        final id = daysBetween(DateTime(1970, 1, 1), day);
        await _plugin.zonedSchedule(
          id,
          'Проверь просрочку: ${lines.length} поз.',
          lines.first,
          when,
          _details(lines.join('\n')),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('Ошибка планирования уведомлений: $e');
    }
  }
}
