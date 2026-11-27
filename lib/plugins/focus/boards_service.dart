import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../arc/arc_service.dart';
import '../../games/games_service.dart' show Friend, GamesError, GamesService;
import 'boards_model.dart';

class BoardsError implements Exception {
  final String message;
  const BoardsError(this.message);
  @override
  String toString() => message;
}

/// Общие доски на сервере Winter Chat. Вход — тот же, что в Winter Arc (логин Winter Chat).
class BoardsService {
  BoardsService._();
  static final I = BoardsService._();

  ArcService get _arc => ArcService.I;
  bool get connected => _arc.connected;
  String get me => _arc.userId;
  String get myName => _arc.name;

  Map<String, String> get _h => {'Authorization': _arc.token, 'Content-Type': 'application/json'};

  Uri _u(String path, [Map<String, String>? q]) => Uri.parse('${_arc.server}$path').replace(queryParameters: q);

  Future<http.Response> _send(Future<http.Response> Function() f) async {
    try {
      final r = await f().timeout(const Duration(seconds: 15));
      if (r.statusCode == 401) throw const BoardsError('Вход устарел — войди заново в Winter Arc');
      if (r.statusCode >= 300) throw BoardsError(_err(r));
      return r;
    } on TimeoutException {
      throw const BoardsError('Сервер не отвечает — ноутбук с сервером выключен?');
    } on SocketException {
      throw const BoardsError('Нет связи с сервером');
    } on http.ClientException {
      throw const BoardsError('Нет связи с сервером');
    }
  }

  static String _err(http.Response r) {
    try {
      final m = (jsonDecode(utf8.decode(r.bodyBytes)) as Map)['message'];
      if (m is String && m.isNotEmpty) {
        if (r.statusCode == 404) return 'Не найдено — возможно, это удалили';
        return m;
      }
    } catch (_) {}
    return r.statusCode == 404 ? 'На сервере нет общих досок — обнови сервер Winter Chat' : 'Ошибка сервера (${r.statusCode})';
  }

  dynamic _json(http.Response r) => jsonDecode(utf8.decode(r.bodyBytes));

  /// Поддерживает ли сервер общие доски (старый сервер — нет).
  Future<bool> serverSupports() async {
    final r = await _send(() => http.get(_u('/api/wc/info')));
    final j = _json(r);
    return j is Map && j['boards'] == 1;
  }

  Future<List<SharedBoard>> boards() async {
    final r = await _send(() => http.get(
          _u('/api/collections/boards/records', {'sort': 'name', 'perPage': '100', 'expand': 'owner,members'}),
          headers: _h,
        ));
    return [for (final it in (_json(r)['items'] as List).cast<Map>()) SharedBoard.fromJson(it)];
  }

  Future<SharedBoard> board(String id) async {
    final r = await _send(() => http.get(_u('/api/collections/boards/records/$id', {'expand': 'owner,members'}), headers: _h));
    return SharedBoard.fromJson(_json(r) as Map);
  }

  Future<SharedBoard> createBoard(String name, int color, List<String> members) async {
    final r = await _send(() => http.post(
          _u('/api/collections/boards/records', {'expand': 'owner,members'}),
          headers: _h,
          body: jsonEncode({'name': name, 'color': color, 'members': members}),
        ));
    return SharedBoard.fromJson(_json(r) as Map);
  }

  Future<SharedBoard> updateBoard(String id, Map<String, dynamic> fields) async {
    final r = await _send(() => http.patch(
          _u('/api/collections/boards/records/$id', {'expand': 'owner,members'}),
          headers: _h,
          body: jsonEncode(fields),
        ));
    return SharedBoard.fromJson(_json(r) as Map);
  }

  Future<void> deleteBoard(String id) async {
    await _send(() => http.delete(_u('/api/collections/boards/records/$id'), headers: _h));
  }

  /// Выйти из чужой доски.
  Future<void> leave(SharedBoard b) => updateBoard(b.id, {'members': [for (final m in b.members) if (m != me) m]});

  Future<List<BoardTask>> tasks(String boardId) async {
    final r = await _send(() => http.get(
          _u('/api/collections/board_tasks/records', {
            'filter': 'board = ${pbQuote(boardId)}',
            'sort': 'sort,-updated',
            'perPage': '500',
          }),
          headers: _h,
        ));
    return [for (final it in (_json(r)['items'] as List).cast<Map>()) BoardTask.fromJson(it)];
  }

  Future<BoardTask> createTask(String boardId, String title, {String status = 'todo', String assignee = '', double sort = 0}) async {
    final r = await _send(() => http.post(
          _u('/api/collections/board_tasks/records'),
          headers: _h,
          body: jsonEncode({'board': boardId, 'title': title, 'status': status, 'assignee': assignee, 'sort': sort}),
        ));
    return BoardTask.fromJson(_json(r) as Map);
  }

  Future<BoardTask> updateTask(String id, Map<String, dynamic> fields) async {
    final r = await _send(() => http.patch(_u('/api/collections/board_tasks/records/$id'), headers: _h, body: jsonEncode(fields)));
    return BoardTask.fromJson(_json(r) as Map);
  }

  /// Прибавить помидоры задаче (атомарно на сервере — два человека не перезапишут друг друга).
  Future<void> addPomodoros(String id, int n) async {
    await _send(() => http.patch(_u('/api/collections/board_tasks/records/$id'), headers: _h, body: jsonEncode({'pomodoros+': n})));
  }

  Future<void> deleteTask(String id) async {
    await _send(() => http.delete(_u('/api/collections/board_tasks/records/$id'), headers: _h));
  }

  /// Друзья с сервера (все, кроме меня).
  Future<List<Friend>> friends() async {
    try {
      return await GamesService.I.friends();
    } on GamesError catch (e) {
      throw BoardsError(e.message);
    }
  }
}
