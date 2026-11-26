import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../arc/arc_service.dart';

/// Партия с другом на сервере Winter Chat (шахматы или гонка в сапёр).
class GameRec {
  final String id, kind, status, host, guest, winner, result;
  final String hostName, guestName;
  final Map<String, dynamic> state, hostState, guestState;
  final int seq;
  final DateTime? updated;

  const GameRec({
    required this.id,
    required this.kind,
    required this.status,
    required this.host,
    required this.guest,
    this.winner = '',
    this.result = '',
    this.hostName = '',
    this.guestName = '',
    this.state = const {},
    this.hostState = const {},
    this.guestState = const {},
    this.seq = 0,
    this.updated,
  });

  static Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static String _name(Object? u) {
    if (u is! Map) return '';
    final n = '${u['name'] ?? ''}'.trim();
    return n.isNotEmpty ? n : '${u['username'] ?? ''}';
  }

  factory GameRec.fromJson(Map j) {
    final ex = (j['expand'] as Map?) ?? const {};
    return GameRec(
      id: '${j['id']}',
      kind: '${j['kind'] ?? ''}',
      status: '${j['status'] ?? ''}',
      host: '${j['host'] ?? ''}',
      guest: '${j['guest'] ?? ''}',
      winner: '${j['winner'] ?? ''}',
      result: '${j['result'] ?? ''}',
      hostName: _name(ex['host']),
      guestName: _name(ex['guest']),
      state: _map(j['state']),
      hostState: _map(j['host_state']),
      guestState: _map(j['guest_state']),
      seq: (j['seq'] as num?)?.toInt() ?? 0,
      updated: DateTime.tryParse('${j['updated'] ?? ''}'.replaceFirst(' ', 'T')),
    );
  }

  bool get open => status == 'open';
  bool get playing => status == 'playing';
  bool get done => status == 'done';
  bool isHost(String me) => host == me;
  bool mine(String me) => host == me || guest == me;

  String opponentName(String me) => isHost(me) ? (guest.isEmpty ? '' : guestName) : hostName;
  Map<String, dynamic> myState(String me) => isHost(me) ? hostState : guestState;
  Map<String, dynamic> theirState(String me) => isHost(me) ? guestState : hostState;
}

class Friend {
  final String id, name;
  const Friend(this.id, this.name);
}

class GamesError implements Exception {
  final String message;
  const GamesError(this.message);
  @override
  String toString() => message;
}

/// Связь с сервером: тот же вход, что в Winter Arc (логин Winter Chat).
class GamesService {
  GamesService._();
  static final I = GamesService._();

  ArcService get _arc => ArcService.I;
  bool get connected => _arc.connected;
  String get me => _arc.userId;
  String get myName => _arc.name;

  Map<String, String> get _h => {'Authorization': _arc.token, 'Content-Type': 'application/json'};

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('${_arc.server}$path').replace(queryParameters: q);

  Future<http.Response> _send(Future<http.Response> Function() f) async {
    try {
      final r = await f().timeout(const Duration(seconds: 15));
      if (r.statusCode == 401) throw const GamesError('Вход устарел — войди заново в Winter Arc');
      if (r.statusCode >= 300) throw GamesError(_err(r));
      return r;
    } on TimeoutException {
      throw const GamesError('Сервер не отвечает — ноутбук с сервером выключен?');
    } on SocketException {
      throw const GamesError('Нет связи с сервером');
    } on http.ClientException {
      throw const GamesError('Нет связи с сервером');
    }
  }

  static String _err(http.Response r) {
    try {
      final m = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['message'];
      if (m is String && m.isNotEmpty) {
        if (r.statusCode == 404) return 'Партия не найдена — возможно, её удалили';
        return m;
      }
    } catch (_) {}
    return r.statusCode == 404 ? 'На сервере нет игр — обнови сервер Winter Chat' : 'Ошибка сервера (${r.statusCode})';
  }

  dynamic _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  /// Поддерживает ли сервер игры (старый сервер — нет).
  Future<bool> serverSupports() async {
    final r = await _send(() => http.get(_u('/api/wc/info')));
    final j = _json(r);
    return j is Map && j['games'] is Map;
  }

  static const _expand = 'host,guest';

  /// Мои партии (идут и приглашения) + открытые приглашения друзей.
  Future<List<GameRec>> active(String kind) async {
    final r = await _send(() => http.get(
          _u('/api/collections/games/records', {
            'filter': "kind = '$kind' && status != 'done'",
            'sort': '-updated',
            'perPage': '50',
            'expand': _expand,
          }),
          headers: _h,
        ));
    return [for (final it in (_json(r)['items'] as List).cast<Map>()) GameRec.fromJson(it)];
  }

  Future<List<GameRec>> history(String kind) async {
    final r = await _send(() => http.get(
          _u('/api/collections/games/records', {
            'filter': "kind = '$kind' && status = 'done' && (host = '$me' || guest = '$me')",
            'sort': '-updated',
            'perPage': '20',
            'expand': _expand,
          }),
          headers: _h,
        ));
    return [for (final it in (_json(r)['items'] as List).cast<Map>()) GameRec.fromJson(it)];
  }

  Future<List<Friend>> friends() async {
    final r = await _send(() => http.get(
          _u('/api/collections/users/records', {'perPage': '200', 'sort': 'name', 'fields': 'id,name,username'}),
          headers: _h,
        ));
    return [
      for (final it in (_json(r)['items'] as List).cast<Map>())
        if ('${it['id']}' != me) Friend('${it['id']}', '${it['name'] ?? ''}'.trim().isEmpty ? '${it['username']}' : '${it['name']}'),
    ];
  }

  Future<GameRec> get(String id) async {
    final r = await _send(() => http.get(_u('/api/collections/games/records/$id', {'expand': _expand}), headers: _h));
    return GameRec.fromJson(_json(r) as Map);
  }

  Future<GameRec> create(String kind, Map<String, dynamic> state, {String? guest}) async {
    final r = await _send(() => http.post(
          _u('/api/collections/games/records', {'expand': _expand}),
          headers: _h,
          body: jsonEncode({'kind': kind, 'status': 'open', 'state': state, if (guest != null) 'guest': guest}),
        ));
    return GameRec.fromJson(_json(r) as Map);
  }

  Future<GameRec> join(String id) async {
    final r = await _send(() => http.patch(
          _u('/api/collections/games/records/$id', {'expand': _expand}),
          headers: _h,
          body: jsonEncode({'guest': me, 'status': 'playing'}),
        ));
    return GameRec.fromJson(_json(r) as Map);
  }

  /// Изменить партию. Для шахмат передаётся следующий seq — сервер не примет ход по старой позиции.
  Future<GameRec> update(GameRec g, Map<String, dynamic> body, {bool nextSeq = true}) async {
    final r = await _send(() => http.patch(
          _u('/api/collections/games/records/${g.id}', {'expand': _expand}),
          headers: _h,
          body: jsonEncode({...body, if (nextSeq) 'seq': g.seq + 1}),
        ));
    return GameRec.fromJson(_json(r) as Map);
  }

  /// Мой прогресс в сапёре (пишется только своё поле).
  Future<GameRec> myProgress(GameRec g, Map<String, dynamic> state) {
    final field = g.isHost(me) ? 'host_state' : 'guest_state';
    return update(g, {field: state}, nextSeq: false);
  }

  Future<void> delete(String id) async {
    await _send(() => http.delete(_u('/api/collections/games/records/$id'), headers: _h));
  }
}
