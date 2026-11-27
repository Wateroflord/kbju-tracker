/// Общие доски задач — модели (чистая логика, проверяется тестами).
library;

const boardStatuses = ['todo', 'doing', 'done'];

String statusTitle(String s) => switch (s) {
      'doing' => 'В работе',
      'done' => 'Готово',
      _ => 'Надо сделать',
    };

/// Следующая колонка: Надо → В работе → Готово (из «Готово» — обратно в «Надо»).
String nextStatus(String s) => switch (s) {
      'todo' => 'doing',
      'doing' => 'done',
      _ => 'todo',
    };

String _userName(Object? u) {
  if (u is! Map) return '';
  final n = '${u['name'] ?? ''}'.trim();
  return n.isNotEmpty ? n : '${u['username'] ?? ''}';
}

class SharedBoard {
  final String id, name, owner;
  final int color;
  final List<String> members;
  final Map<String, String> names; // id → имя (из expand)

  const SharedBoard({
    required this.id,
    required this.name,
    required this.owner,
    this.color = 0,
    this.members = const [],
    this.names = const {},
  });

  factory SharedBoard.fromJson(Map j) {
    final ex = (j['expand'] as Map?) ?? const {};
    final names = <String, String>{};
    final m = ex['members'];
    if (m is List) {
      for (final u in m) {
        if (u is Map && u['id'] != null) names['${u['id']}'] = _userName(u);
      }
    }
    final o = ex['owner'];
    if (o is Map && o['id'] != null) names['${o['id']}'] = _userName(o);
    return SharedBoard(
      id: '${j['id']}',
      name: '${j['name'] ?? ''}',
      owner: '${j['owner'] ?? ''}',
      color: (j['color'] as num?)?.toInt() ?? 0,
      members: [for (final x in (j['members'] as List? ?? const [])) '$x'],
      names: names,
    );
  }

  String nameOf(String userId) => names[userId] ?? '';
  bool isOwner(String me) => owner == me;

  /// Участники, кроме меня: «Вова, Петя».
  String othersText(String me) {
    final others = [for (final id in members) if (id != me) nameOf(id)].where((n) => n.isNotEmpty).toList();
    return others.isEmpty ? 'Пока только ты' : 'С тобой: ${others.join(', ')}';
  }
}

class BoardTask {
  final String id, board, title, note, status, assignee, author;
  final int pomodoros;
  final double sort;
  final DateTime? updated;

  const BoardTask({
    required this.id,
    required this.board,
    required this.title,
    this.note = '',
    this.status = 'todo',
    this.assignee = '',
    this.author = '',
    this.pomodoros = 0,
    this.sort = 0,
    this.updated,
  });

  factory BoardTask.fromJson(Map j) => BoardTask(
        id: '${j['id']}',
        board: '${j['board'] ?? ''}',
        title: '${j['title'] ?? ''}',
        note: '${j['note'] ?? ''}',
        status: boardStatuses.contains(j['status']) ? '${j['status']}' : 'todo',
        assignee: '${j['assignee'] ?? ''}',
        author: '${j['author'] ?? ''}',
        pomodoros: (j['pomodoros'] as num?)?.toInt() ?? 0,
        sort: (j['sort'] as num?)?.toDouble() ?? 0,
        updated: DateTime.tryParse('${j['updated'] ?? ''}'.replaceFirst(' ', 'T')),
      );
}

/// Задачи колонки по порядку: сначала по sort, потом новые изменения выше.
List<BoardTask> column(Iterable<BoardTask> tasks, String status) {
  final l = tasks.where((t) => t.status == status).toList();
  l.sort((a, b) {
    final c = a.sort.compareTo(b.sort);
    if (c != 0) return c;
    final ua = a.updated ?? DateTime(2000), ub = b.updated ?? DateTime(2000);
    return ub.compareTo(ua);
  });
  return l;
}

/// Сколько задач у каждого в работе и сделано — для шапки доски.
Map<String, int> doneBy(Iterable<BoardTask> tasks) {
  final out = <String, int>{};
  for (final t in tasks) {
    if (t.status != 'done' || t.assignee.isEmpty) continue;
    out[t.assignee] = (out[t.assignee] ?? 0) + 1;
  }
  return out;
}

/// Экранирование строки для фильтра PocketBase.
String pbQuote(String s) => "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";
