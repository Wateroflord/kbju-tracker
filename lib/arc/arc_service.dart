import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../store.dart';
import '../util.dart';
import 'arc_score.dart';

/// Место в рейтинге Winter Arc.
class ArcRow {
  final String userId, name;
  final int points, days, streak, today;
  const ArcRow(this.userId, this.name, {this.points = 0, this.days = 0, this.streak = 0, this.today = 0});
}

enum ArcPeriod { today, week, arc }

/// Связь с сервером Winter Chat: вход тем же логином, отправка своих очков,
/// загрузка рейтинга друзей. Данные входа хранятся в kbju_arc.json —
/// этот файл не попадает ни в резервную копию, ни в экспорт.
class ArcService extends ChangeNotifier {
  ArcService._();
  static final ArcService I = ArcService._();

  String server = '', token = '', userId = '', name = '';
  String start = '', end = '';
  List<Map<String, dynamic>> records = [];
  String? error;
  bool busy = false;
  DateTime? syncedAt;
  String _docs = '';

  bool get connected => token.isNotEmpty && server.isNotEmpty;
  File get _file => File('$_docs/kbju_arc.json');

  Future<void> load(AppStore store) async {
    _docs = store.docsPath;
    if (_docs.isEmpty) return;
    try {
      if (await _file.exists()) {
        final j = jsonDecode(await _file.readAsString()) as Map;
        server = '${j['server'] ?? ''}';
        token = '${j['token'] ?? ''}';
        userId = '${j['userId'] ?? ''}';
        name = '${j['name'] ?? ''}';
        start = '${j['start'] ?? ''}';
        end = '${j['end'] ?? ''}';
        records = [for (final r in (j['records'] as List? ?? const [])) Map<String, dynamic>.from(r as Map)];
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> _save() async {
    if (_docs.isEmpty) return;
    try {
      await _file.writeAsString(jsonEncode({
        'server': server,
        'token': token,
        'userId': userId,
        'name': name,
        'start': start,
        'end': end,
        'records': records,
      }));
    } catch (_) {}
  }

  /// «192.168.1.5» → «http://192.168.1.5:8090» (как в Winter Chat).
  static String normalizeUrl(String input) {
    var s = input.trim();
    while (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.isEmpty) return s;
    if (!s.contains('://')) s = 'http://$s';
    final uri = Uri.tryParse(s);
    if (uri == null || uri.host.isEmpty) return s;
    final hasPort = RegExp(r':\d+$').hasMatch(uri.authority);
    return Uri(scheme: uri.scheme, host: uri.host, port: hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 8090))
        .toString()
        .replaceAll(RegExp(r'/$'), '');
  }

  Map<String, String> get _auth => {'Authorization': token, 'Content-Type': 'application/json'};

  static String _err(http.Response r, String fallback) {
    try {
      final m = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['message'];
      if (m is String && m.isNotEmpty) return m;
    } catch (_) {}
    return fallback;
  }

  Future<void> _loadInfo() async {
    final r = await http.get(Uri.parse('$server/api/wc/info')).timeout(const Duration(seconds: 10));
    final j = jsonDecode(r.body) as Map;
    if (j['app'] != 'winter-chat') throw 'По этому адресу не сервер Winter Chat';
    final arc = j['arc'];
    if (arc is! Map) throw 'На сервере старая версия Winter Chat — обнови сервер на ноутбуке';
    start = '${arc['start']}';
    end = '${arc['end']}';
  }

  /// Вход логином и паролем Winter Chat. Возвращает текст ошибки или null.
  Future<String?> login(AppStore store, String address, String username, String password) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      server = normalizeUrl(address);
      if (server.isEmpty) return 'Введи адрес сервера';
      try {
        await _loadInfo();
      } on TimeoutException {
        return 'Сервер не отвечает. Проверь адрес и что ноутбук с сервером включён.';
      } on SocketException {
        return 'Не удалось подключиться к $server';
      }
      final r = await http
          .post(Uri.parse('$server/api/collections/users/auth-with-password'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'identity': username.trim(), 'password': password}))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return r.statusCode == 429 ? 'Слишком много попыток, подожди минуту' : 'Неверный логин или пароль';
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      token = '${j['token']}';
      final rec = (j['record'] as Map?) ?? const {};
      userId = '${rec['id']}';
      name = '${rec['name'] ?? ''}'.trim().isNotEmpty ? '${rec['name']}' : '${rec['username']}';
      await _save();
      await sync(store);
      return null;
    } catch (e) {
      return e is String ? e : 'Ошибка: $e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    token = '';
    userId = '';
    name = '';
    records = [];
    await _save();
    notifyListeners();
  }

  int get dayNumber {
    if (start.isEmpty) return 0;
    return daysBetween(parseKey(start), today()) + 1;
  }

  bool get running => dayNumber >= 1 && dayNumber <= ArcRules.days;

  /// Отправить свои очки за последние 7 дней и загрузить рейтинг.
  Future<void> sync(AppStore store) async {
    if (!connected) return;
    busy = true;
    notifyListeners();
    try {
      await _loadInfo();
      if (running) await _push(store);
      await _pull();
      syncedAt = DateTime.now();
      error = null;
      await _save();
    } on TimeoutException {
      error = 'Сервер не отвечает — ноутбук с сервером выключен?';
    } on SocketException {
      error = 'Нет связи с сервером';
    } catch (e) {
      error = e is String ? e : '$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> _push(AppStore store) async {
    final t = todayKey();
    var from = dkey(addDays(today(), -6));
    if (from.compareTo(start) < 0) from = start;
    final mine = arcScores(store, from, t);
    final q = Uri.parse('$server/api/collections/arc_scores/records').replace(queryParameters: {
      'filter': "user = '$userId' && day >= '$from'",
      'perPage': '50',
    });
    final r = await http.get(q, headers: _auth).timeout(const Duration(seconds: 15));
    if (r.statusCode == 401 || r.statusCode == 403) {
      await logout();
      throw 'Вход устарел — войди заново';
    }
    if (r.statusCode != 200) throw _err(r, 'Сервер не принял запрос (${r.statusCode})');
    final existing = {
      for (final it in ((jsonDecode(utf8.decode(r.bodyBytes)) as Map)['items'] as List).cast<Map>()) '${it['day']}': it,
    };
    for (final d in mine) {
      final have = existing[d.day];
      if (have != null && d.sameAs(have)) continue;
      if (have == null && d.total == 0) continue;
      final body = jsonEncode({...d.toJson(), 'user': userId});
      final res = have == null
          ? await http.post(Uri.parse('$server/api/collections/arc_scores/records'), headers: _auth, body: body)
          : await http.patch(Uri.parse('$server/api/collections/arc_scores/records/${have['id']}'), headers: _auth, body: body);
      if (res.statusCode != 200) throw _err(res, 'Не удалось отправить очки (${res.statusCode})');
    }
  }

  Future<void> _pull() async {
    final all = <Map<String, dynamic>>[];
    for (var page = 1; page < 50; page++) {
      final q = Uri.parse('$server/api/collections/arc_scores/records').replace(queryParameters: {
        'filter': "day >= '$start' && day <= '$end'",
        'perPage': '500',
        'page': '$page',
        'expand': 'user',
        'fields': 'day,total,user,expand.user.name,expand.user.username',
      });
      final r = await http.get(q, headers: _auth).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw _err(r, 'Не удалось загрузить рейтинг (${r.statusCode})');
      final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map;
      for (final it in (j['items'] as List).cast<Map>()) {
        final u = ((it['expand'] as Map?)?['user'] as Map?) ?? const {};
        all.add({
          'day': '${it['day']}',
          'total': (it['total'] as num?)?.toInt() ?? 0,
          'user': '${it['user']}',
          'name': '${u['name'] ?? ''}'.trim().isNotEmpty ? '${u['name']}' : '${u['username'] ?? '?'}',
        });
      }
      if (page >= ((j['totalPages'] as num?)?.toInt() ?? 1)) break;
    }
    records = all;
  }

  List<ArcRow> board(ArcPeriod p) => leaderboard(records, p, todayKey(), start);

  /// Рейтинг из записей сервера (чистая логика, проверяется тестами).
  static List<ArcRow> leaderboard(List<Map<String, dynamic>> recs, ArcPeriod p, String todayKey, String start) {
    final t = parseKey(todayKey);
    final from = switch (p) {
      ArcPeriod.today => todayKey,
      ArcPeriod.week => dkey(addDays(t, -6)),
      ArcPeriod.arc => start,
    };
    final byUser = <String, Map<String, int>>{};
    final names = <String, String>{};
    for (final r in recs) {
      final u = '${r['user']}';
      names[u] = '${r['name']}';
      (byUser[u] ??= {})['${r['day']}'] = (r['total'] as num?)?.toInt() ?? 0;
    }
    final rows = <ArcRow>[];
    byUser.forEach((u, days) {
      var pts = 0, n = 0;
      days.forEach((d, v) {
        if (d.compareTo(from) >= 0 && d.compareTo(todayKey) <= 0) {
          pts += v;
          if (v > 0) n++;
        }
      });
      // Серия: дни подряд с 50+ очками (сегодня можно ещё не закрыть).
      var streak = 0;
      var d = t;
      if ((days[dkey(d)] ?? 0) < 50) d = addDays(d, -1);
      while ((days[dkey(d)] ?? 0) >= 50 && streak < 400) {
        streak++;
        d = addDays(d, -1);
      }
      rows.add(ArcRow(u, names[u] ?? '?', points: pts, days: n, streak: streak, today: days[todayKey] ?? 0));
    });
    rows.sort((a, b) => b.points != a.points ? b.points.compareTo(a.points) : b.streak.compareTo(a.streak));
    return rows;
  }
}
