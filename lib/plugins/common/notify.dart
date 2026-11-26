import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../platform.dart';

/// Уведомления плагинов. У каждого плагина свой диапазон номеров:
/// КБЖУ — до 10 000, Просрочка — 10 000–99 999, Смены — 200 000–299 999, Фокус — 300 000–300 099.
class PluginNotify {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<bool> _init() async {
    if (_ready) return true;
    if (!isAndroid) return false;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      _ready = true;
    } catch (e) {
      debugPrint('plugin notifications: $e');
    }
    return _ready;
  }

  static Future<void> requestPermission() async {
    if (!await _init()) return;
    try {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    } catch (_) {}
  }

  static NotificationDetails _details(String channel, String channelName, String body) => NotificationDetails(
        android: AndroidNotificationDetails(
          channel,
          channelName,
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );

  /// Запланировать уведомление. [exact] — точно ко времени (если телефон разрешает), иначе ± несколько минут.
  static Future<void> schedule(int id, String title, String body, DateTime at,
      {required String channel, required String channelName, bool exact = false}) async {
    if (!await _init() || !at.isAfter(DateTime.now())) return;
    final when = tz.TZDateTime.from(at.toUtc(), tz.UTC);
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          _details(channel, channelName, body),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
    try {
      if (exact) {
        try {
          await go(AndroidScheduleMode.exactAllowWhileIdle);
          return;
        } on PlatformException {
          // Точные будильники не разрешены — ставим обычный.
        }
      }
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
    } catch (e) {
      debugPrint('plugin notification $id: $e');
    }
  }

  static Future<void> cancel(int id) async {
    if (!await _init()) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  /// Снять все свои уведомления из диапазона [from, to).
  static Future<void> cancelRange(int from, int to) async {
    if (!await _init()) return;
    try {
      for (final r in await _plugin.pendingNotificationRequests()) {
        if (r.id >= from && r.id < to) await _plugin.cancel(r.id);
      }
    } catch (_) {}
  }
}
