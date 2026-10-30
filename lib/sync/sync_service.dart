import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../i18n/i18n.dart';
import '../store.dart';
import 'merge.dart';

/// Адрес для подключения: какие IP, порт и одноразовый код.
class SyncTicket {
  final List<String> hosts;
  final int port;
  final String token;
  const SyncTicket(this.hosts, this.port, this.token);

  String get qr => 'kbju-sync:${hosts.join(',')}:$port:$token';

  static SyncTicket? parse(String s) {
    final t = s.trim();
    final m = RegExp(r'^kbju-sync:([^:]+):(\d+):(\w+)$').firstMatch(t);
    if (m != null) return SyncTicket(m.group(1)!.split(','), int.parse(m.group(2)!), m.group(3)!);
    return null;
  }
}

/// Синхронизация телефон ↔ ПК по домашнему Wi-Fi, без интернета и серверов.
/// Одно устройство (обычно ПК) «принимает» и показывает QR, второе (телефон) сканирует и отправляет свои данные.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  HttpServer? _server;
  SyncTicket? ticket;
  String status = '';
  int lastSync = 0;
  AppStore? _store;

  bool get hosting => _server != null;

  String _basePath(AppStore s) => '${s.docsPath}${Platform.pathSeparator}sync_base.json';

  Future<Map<String, dynamic>?> _loadBase(AppStore s) async {
    try {
      final f = File(_basePath(s));
      if (await f.exists()) {
        final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        lastSync = (j['_at'] as num?)?.toInt() ?? 0;
        return Map<String, dynamic>.from(j['data'] as Map);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveBase(AppStore s, Map<String, dynamic> data) async {
    lastSync = DateTime.now().millisecondsSinceEpoch;
    try {
      await File(_basePath(s)).writeAsString(jsonEncode({'_at': lastSync, 'data': data}));
    } catch (_) {}
  }

  Future<void> loadInfo(AppStore s) async {
    await _loadBase(s);
    notifyListeners();
  }

  /// Данные без полей, которые у каждого устройства свои.
  static Map<String, dynamic> _strip(Map<String, dynamic> full) {
    final out = jsonDecode(jsonEncode(full)) as Map<String, dynamic>;
    for (final path in deviceLocalPaths) {
      Map? m = out;
      for (var i = 0; i < path.length - 1; i++) {
        final n = m?[path[i]];
        m = n is Map ? n : null;
      }
      m?.remove(path.last);
    }
    return out;
  }

  /// Фото, которые лежат в папке приложения (относительные пути вида photos/123.jpg).
  static Future<List<String>> _photos(AppStore s) async {
    final dir = Directory('${s.docsPath}${Platform.pathSeparator}photos');
    if (!await dir.exists()) return [];
    final out = <String>[];
    await for (final e in dir.list()) {
      if (e is File) out.add('photos/${e.uri.pathSegments.last}');
    }
    return out;
  }

  static bool _safe(String p) => p.startsWith('photos/') && !p.contains('..') && !p.contains('\\');

  File _photoFile(AppStore s, String rel) => File('${s.docsPath}${Platform.pathSeparator}${rel.replaceAll('/', Platform.pathSeparator)}');

  // ---------- приём (ПК) ----------

  Future<SyncTicket?> startHost(AppStore s) async {
    if (_server != null) return ticket;
    _store = s;
    await _loadBase(s);
    final rnd = math.Random.secure();
    final token = List.generate(6, (_) => rnd.nextInt(10)).join();
    for (final port in [4747, 4748, 4749, 5757]) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, port, shared: false);
        break;
      } catch (_) {}
    }
    if (_server == null) {
      status = tr('Не удалось открыть порт для синхронизации');
      notifyListeners();
      return null;
    }
    final hosts = <String>[];
    try {
      for (final i in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in i.addresses) {
          if (!a.isLoopback && !a.address.startsWith('169.254')) hosts.add(a.address);
        }
      }
    } catch (_) {}
    // Сначала обычные домашние адреса 192.168.* и 10.*.
    hosts.sort((a, b) => (a.startsWith('192.168') ? 0 : a.startsWith('10.') ? 1 : 2).compareTo(b.startsWith('192.168') ? 0 : b.startsWith('10.') ? 1 : 2));
    ticket = SyncTicket(hosts.isEmpty ? ['127.0.0.1'] : hosts, _server!.port, token);
    status = tr('Жду телефон…');
    _server!.listen(_handle, onError: (_) {});
    notifyListeners();
    return ticket;
  }

  Future<void> stopHost() async {
    await _server?.close(force: true);
    _server = null;
    ticket = null;
    notifyListeners();
  }

  Future<void> _handle(HttpRequest req) async {
    final s = _store;
    final t = ticket;
    try {
      if (s == null || t == null || req.uri.queryParameters['k'] != t.token) {
        req.response.statusCode = 403;
        await req.response.close();
        return;
      }
      final path = req.uri.path;
      if (path == '/sync' && req.method == 'POST') {
        final body = jsonDecode(await utf8.decoder.bind(req).join()) as Map<String, dynamic>;
        final remote = Map<String, dynamic>.from(body['data'] as Map);
        final remoteMod = (body['mod'] as num?)?.toInt() ?? 0;
        final localFull = s.exportData();
        final local = _strip(localFull);
        final myBase = await _loadBase(s);
        final base = myBase != null && fingerprint(myBase) == body['base'] ? myBase : null;
        final merged = Map<String, dynamic>.from(merge3(base, local, remote, aNewer: s.modifiedAt >= remoteMod) as Map);
        final mod = math.max(s.modifiedAt, remoteMod);
        s.importData(keepLocal(merged, localFull), modified: mod);
        await _saveBase(s, merged);
        final mine = (await _photos(s)).toSet();
        final theirs = ((body['photos'] as List?) ?? const []).map((e) => '$e').toSet();
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode({
          'data': merged,
          'mod': mod,
          'need': theirs.difference(mine).toList(),
          'have': mine.difference(theirs).toList(),
        }));
        status = tr('Синхронизировано с телефоном');
        notifyListeners();
      } else if (path == '/photo') {
        final rel = req.uri.queryParameters['p'] ?? '';
        if (!_safe(rel)) {
          req.response.statusCode = 400;
        } else if (req.method == 'PUT') {
          final bytes = await req.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
          final f = _photoFile(s, rel);
          await f.parent.create(recursive: true);
          await f.writeAsBytes(bytes, flush: true);
        } else {
          final f = _photoFile(s, rel);
          if (await f.exists()) {
            req.response.headers.contentType = ContentType('image', 'jpeg');
            req.response.add(await f.readAsBytes());
          } else {
            req.response.statusCode = 404;
          }
        }
      } else if (path == '/ping') {
        req.response.write('kbju');
      } else {
        req.response.statusCode = 404;
      }
    } catch (e) {
      req.response.statusCode = 500;
      status = trf('Ошибка синхронизации: {0}', [e]);
      notifyListeners();
    }
    await req.response.close();
  }

  // ---------- отправка (телефон) ----------

  /// Синхронизироваться с устройством по билету из QR. Возвращает текст результата.
  Future<String> syncWith(AppStore s, SyncTicket t) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      String? host;
      for (final h in t.hosts) {
        try {
          final r = await (await client.get(h, t.port, '/ping?k=${t.token}')).close().timeout(const Duration(seconds: 5));
          await r.drain<void>();
          if (r.statusCode == 200) {
            host = h;
            break;
          }
        } catch (_) {}
      }
      if (host == null) {
        return tr('ПК не отвечает. Проверь, что телефон и ПК в одной сети Wi-Fi и на ПК открыт экран синхронизации.');
      }
      final base = await _loadBase(s);
      final localFull = s.exportData();
      final req = await client.post(host, t.port, '/sync?k=${t.token}');
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'data': _strip(localFull),
        'mod': s.modifiedAt,
        'base': base == null ? '' : fingerprint(base),
        'photos': await _photos(s),
      }));
      final res = await req.close().timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return trf('Ошибка синхронизации: {0}', [res.statusCode]);
      final j = jsonDecode(await utf8.decoder.bind(res).join()) as Map<String, dynamic>;
      final merged = Map<String, dynamic>.from(j['data'] as Map);
      s.importData(keepLocal(merged, localFull), modified: (j['mod'] as num?)?.toInt());
      await _saveBase(s, merged);
      var up = 0, down = 0;
      for (final p in ((j['need'] as List?) ?? const []).map((e) => '$e')) {
        if (!_safe(p)) continue;
        final f = _photoFile(s, p);
        if (!await f.exists()) continue;
        final r = await client.put(host, t.port, '/photo?k=${t.token}&p=${Uri.encodeQueryComponent(p)}');
        r.add(await f.readAsBytes());
        await (await r.close()).drain<void>();
        up++;
      }
      for (final p in ((j['have'] as List?) ?? const []).map((e) => '$e')) {
        if (!_safe(p)) continue;
        final r = await (await client.get(host, t.port, '/photo?k=${t.token}&p=${Uri.encodeQueryComponent(p)}')).close();
        if (r.statusCode != 200) {
          await r.drain<void>();
          continue;
        }
        final bytes = await r.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
        final f = _photoFile(s, p);
        await f.parent.create(recursive: true);
        await f.writeAsBytes(bytes, flush: true);
        down++;
      }
      notifyListeners();
      return tr('Готово! Данные на телефоне и ПК одинаковые.') + (up + down > 0 ? ' ${trf('Фото: отправлено {0}, получено {1}.', [up, down])}' : '');
    } catch (e) {
      return trf('Ошибка синхронизации: {0}', [e]);
    } finally {
      client.close();
    }
  }
}
