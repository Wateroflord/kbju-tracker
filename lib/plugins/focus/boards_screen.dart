import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../arc/arc_service.dart';
import '../../games/games_service.dart' show Friend;
import '../../kbju_app.dart';
import '../../screens/arc_screen.dart';
import '../common/ui.dart';
import '../shell.dart';
import 'boards_model.dart';
import 'boards_service.dart';

const _boardColors = [
  Color(0xFFFF7A6B),
  Color(0xFF7FD8FF),
  Color(0xFF6EE7B7),
  Color(0xFFFFC46B),
  Color(0xFFB48CFF),
  Color(0xFFFF78AA),
];

Color _colorOf(int i) => _boardColors[(i % _boardColors.length + _boardColors.length) % _boardColors.length];

Future<void> _openArc() async {
  await WinterShell.switchTo('kbju');
  for (var i = 0; i < 40 && kbjuNavKey.currentState == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
  kbjuNavKey.currentState?.push(MaterialPageRoute(builder: (_) => const ArcScreen()));
}

/// Выбрать друзей с сервера (несколько).
Future<List<String>?> _pickFriends(BuildContext context, List<Friend> friends, Set<String> selected, {String title = 'Кто в проекте?'}) {
  final sel = {...selected};
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.75),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(title, style: W.h2)),
            Flexible(
              child: ListView(shrinkWrap: true, children: [
                if (friends.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('На сервере пока нет друзей.', style: W.small)),
                for (final f in friends)
                  CheckboxListTile(
                    value: sel.contains(f.id),
                    onChanged: (v) => set(() => v == true ? sel.add(f.id) : sel.remove(f.id)),
                    title: Text(f.name),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton(onPressed: () => Navigator.pop(c, sel.toList()), child: const Text('Готово')),
            ),
          ]),
        ),
      ),
    ),
  );
}

// ───────────────────────────── Список досок ─────────────────────────────

/// Общие доски с друзьями: проект на несколько человек (например FalseMemory).
class SharedBoardsScreen extends StatefulWidget {
  const SharedBoardsScreen({super.key});

  @override
  State<SharedBoardsScreen> createState() => _SharedBoardsScreenState();
}

class _SharedBoardsScreenState extends State<SharedBoardsScreen> {
  final svc = BoardsService.I;
  bool loading = true, supported = true, busy = false;
  String? error;
  List<SharedBoard> boards = [];

  @override
  void initState() {
    super.initState();
    ArcService.I.addListener(_arcChanged);
    _load();
  }

  @override
  void dispose() {
    ArcService.I.removeListener(_arcChanged);
    super.dispose();
  }

  void _arcChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    if (!svc.connected) {
      if (mounted) setState(() => loading = false);
      return;
    }
    if (mounted) setState(() => loading = true);
    try {
      supported = await svc.serverSupports();
      if (supported) boards = await svc.boards();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _create() async {
    final name = TextEditingController();
    var color = 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Новая общая доска'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Например: FalseMemory'),
              onSubmitted: (_) => Navigator.pop(c, true),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 8, children: [
              for (var i = 0; i < _boardColors.length; i++)
                GestureDetector(
                  onTap: () => set(() => color = i),
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: _boardColors[i],
                    child: color == i ? const Icon(Icons.check, size: 16, color: W.bg) : null,
                  ),
                ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Дальше')),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    if (ok != true || n.isEmpty || !mounted) return;
    setState(() => busy = true);
    try {
      final friends = await svc.friends();
      if (!mounted) return;
      final members = await _pickFriends(context, friends, {}, title: 'Кого позвать в «$n»?');
      if (members == null || !mounted) return;
      final b = await svc.createBoard(n, color, members);
      if (!mounted) return;
      await _load();
      if (mounted) await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BoardScreen(board: b)));
      _load();
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Общие доски'),
          actions: [if (svc.connected) IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
        ),
        floatingActionButton: svc.connected && supported
            ? FloatingActionButton.extended(onPressed: busy ? null : _create, icon: const Icon(Icons.add), label: const Text('Доска'))
            : null,
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
            const Text(
              'Задачи для проекта на несколько человек — например FalseMemory с другом. '
              'Доска лежит на сервере Winter Chat: изменения видны всем участникам на телефоне и ПК.',
              style: W.small,
            ),
            const SizedBox(height: 12),
            if (!svc.connected)
              WCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Нужен вход на сервер друзей', style: W.h2),
                  const SizedBox(height: 4),
                  const Text(
                    'Войди в Winter Arc в КБЖУ тем же логином и паролем, что в Winter Chat, — и возвращайся сюда.',
                    style: W.small,
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(onPressed: _openArc, icon: const Icon(Icons.login), label: const Text('Открыть Winter Arc')),
                ]),
              )
            else if (loading && boards.isEmpty)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (!supported)
              const WCard(
                child: Text(
                  'Сервер Winter Chat пока не умеет общие доски. Обнови сервер на ноутбуке через Winter Hub — и попробуй снова.',
                  style: W.body,
                ),
              )
            else ...[
              if (error != null)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: WCard(borderColor: W.bad, child: Text(error!, style: W.body))),
              if (boards.isEmpty && error == null)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Center(child: Text('Досок пока нет.\nНажми «+ Доска» и позови друга.', style: W.small, textAlign: TextAlign.center)),
                ),
              for (final b in boards)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: WCard(
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => BoardScreen(board: b)));
                      _load();
                    },
                    child: Row(children: [
                      Container(width: 8, height: 40, decoration: BoxDecoration(color: _colorOf(b.color), borderRadius: BorderRadius.circular(4))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(b.name, style: W.h2),
                          Text(b.othersText(svc.me), style: W.small),
                        ]),
                      ),
                      const Icon(Icons.chevron_right, color: W.muted),
                    ]),
                  ),
                ),
            ],
          ]),
        ),
      );
}

// ───────────────────────────── Доска ─────────────────────────────

class BoardScreen extends StatefulWidget {
  final SharedBoard board;
  const BoardScreen({super.key, required this.board});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final svc = BoardsService.I;
  late SharedBoard board = widget.board;
  List<BoardTask> tasks = [];
  bool loading = true;
  String? error;
  Timer? _timer;
  final _newCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    // Друг мог что-то поменять — обновляем раз в 20 секунд, пока доска открыта.
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _newCtl.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final t = await svc.tasks(board.id);
      final b = quiet ? board : await svc.board(board.id);
      tasks = t;
      board = b;
      error = null;
    } catch (e) {
      if (!quiet) error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  /// Изменить задачу на сервере и показать, что вернул сервер.
  Future<void> _update(BoardTask t, Map<String, dynamic> fields) async {
    try {
      final upd = await svc.updateTask(t.id, fields);
      tasks = [for (final x in tasks) x.id == t.id ? upd : x];
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  Future<void> _add(String status) async {
    final title = _newCtl.text.trim();
    if (title.isEmpty) return;
    _newCtl.clear();
    try {
      final col = column(tasks, status);
      final sort = col.isEmpty ? 0.0 : col.last.sort + 1;
      final t = await svc.createTask(board.id, title, status: status, sort: sort);
      tasks = [...tasks, t];
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        _newCtl.text = title;
        toast(context, '$e');
      }
    }
  }

  Future<void> _move(BoardTask t, String status) async {
    HapticFeedback.lightImpact();
    final col = column(tasks, status);
    final sort = col.isEmpty ? 0.0 : col.last.sort + 1;
    final fields = <String, dynamic>{'status': status, 'sort': sort};
    // Взял в работу и ни на ком не висит — значит, взял себе.
    if (status == 'doing' && t.assignee.isEmpty) fields['assignee'] = svc.me;
    await _update(t, fields);
  }

  Future<void> _edit(BoardTask t) async {
    final title = TextEditingController(text: t.title);
    final note = TextEditingController(text: t.note);
    var status = t.status;
    var assignee = t.assignee;
    final r = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextField(
                controller: title,
                textCapitalization: TextCapitalization.sentences,
                style: W.h2,
                decoration: const InputDecoration(labelText: 'Задача', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Подробности (необязательно)', border: OutlineInputBorder()),
              ),
              const Section('Где'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final s in boardStatuses) Chip2(statusTitle(s), selected: status == s, onTap: () => set(() => status = s)),
              ]),
              const Section('Кто делает'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Chip2('Никто', selected: assignee.isEmpty, onTap: () => set(() => assignee = '')),
                for (final m in board.members)
                  Chip2(m == svc.me ? 'Я' : (board.nameOf(m).isEmpty ? '?' : board.nameOf(m)), selected: assignee == m, onTap: () => set(() => assignee = m)),
              ]),
              if (t.author.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text('Добавил: ${t.author == svc.me ? 'ты' : board.nameOf(t.author)}', style: W.small),
              ],
              const SizedBox(height: 14),
              Row(children: [
                TextButton(onPressed: () => Navigator.pop(c, 'delete'), child: const Text('Удалить', style: TextStyle(color: W.bad))),
                const Spacer(),
                FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Сохранить')),
              ]),
            ]),
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (r == 'delete') {
      if (!await confirmDialog(context, 'Удалить задачу?', '«${t.title}» пропадёт у всех участников доски.', ok: 'Удалить')) return;
      try {
        await svc.deleteTask(t.id);
        tasks = [for (final x in tasks) if (x.id != t.id) x];
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) toast(context, '$e');
      }
      return;
    }
    if (r != 'save') return;
    final nt = title.text.trim();
    if (nt.isEmpty) return;
    final fields = <String, dynamic>{};
    if (nt != t.title) fields['title'] = nt;
    if (note.text.trim() != t.note) fields['note'] = note.text.trim();
    if (assignee != t.assignee) fields['assignee'] = assignee;
    if (status != t.status) {
      final col = column(tasks, status);
      fields['status'] = status;
      fields['sort'] = col.isEmpty ? 0.0 : col.last.sort + 1;
    }
    if (fields.isNotEmpty) await _update(t, fields);
  }

  Future<void> _boardMenu() async {
    final owner = board.isOwner(svc.me);
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (owner) ListTile(leading: const Icon(Icons.group_add_outlined), title: const Text('Участники'), onTap: () => Navigator.pop(c, 'members')),
          if (owner) ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Переименовать'), onTap: () => Navigator.pop(c, 'rename')),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('Убрать готовые'),
            subtitle: const Text('Удалить все задачи из «Готово»', style: W.small),
            onTap: () => Navigator.pop(c, 'clear'),
          ),
          if (owner)
            ListTile(leading: const Icon(Icons.delete_outline, color: W.bad), title: const Text('Удалить доску'), onTap: () => Navigator.pop(c, 'delete'))
          else
            ListTile(leading: const Icon(Icons.logout, color: W.bad), title: const Text('Выйти из доски'), onTap: () => Navigator.pop(c, 'leave')),
        ]),
      ),
    );
    if (a == null || !mounted) return;
    try {
      switch (a) {
        case 'members':
          final friends = await svc.friends();
          if (!mounted) return;
          final pick = await _pickFriends(context, friends, {...board.members}..remove(svc.me));
          if (pick == null) return;
          board = await svc.updateBoard(board.id, {'members': [svc.me, ...pick]});
        case 'rename':
          final ctl = TextEditingController(text: board.name);
          final n = await showDialog<String>(
            context: context,
            builder: (c) => AlertDialog(
              title: const Text('Название доски'),
              content: TextField(controller: ctl, autofocus: true, onSubmitted: (v) => Navigator.pop(c, v.trim())),
              actions: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
                FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('Готово')),
              ],
            ),
          );
          if (n == null || n.isEmpty) return;
          board = await svc.updateBoard(board.id, {'name': n});
        case 'clear':
          final done = tasks.where((t) => t.status == 'done').toList();
          if (done.isEmpty) return;
          if (!await confirmDialog(context, 'Убрать готовые?', 'Удалится задач: ${done.length}. У друга тоже.', ok: 'Убрать')) return;
          for (final t in done) {
            await svc.deleteTask(t.id);
          }
          tasks = [for (final t in tasks) if (t.status != 'done') t];
        case 'delete':
          if (!await confirmDialog(context, 'Удалить доску?', '«${board.name}» и все задачи пропадут у всех участников.', ok: 'Удалить')) return;
          await svc.deleteBoard(board.id);
          if (mounted) Navigator.pop(context);
          return;
        case 'leave':
          if (!await confirmDialog(context, 'Выйти из доски?', 'Доска «${board.name}» пропадёт из твоего списка. Вернуть может хозяин.', ok: 'Выйти')) return;
          await svc.leave(board);
          if (mounted) Navigator.pop(context);
          return;
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorOf(board.color);
    final stats = doneBy(tasks);
    return DefaultTabController(
      length: boardStatuses.length,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: Text(board.name),
            actions: [
              IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh)),
              IconButton(onPressed: _boardMenu, icon: const Icon(Icons.more_vert)),
            ],
            bottom: TabBar(
              indicatorColor: color,
              labelColor: color,
              unselectedLabelColor: W.muted,
              tabs: [
                for (final s in boardStatuses) Tab(text: '${statusTitle(s)} ${column(tasks, s).length}'),
              ],
            ),
          ),
          body: loading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(children: [
                  for (final s in boardStatuses)
                    RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
                        if (error != null)
                          Padding(padding: const EdgeInsets.only(bottom: 10), child: WCard(borderColor: W.bad, child: Text(error!, style: W.body))),
                        if (s == 'todo') ...[
                          Text(board.othersText(svc.me), style: W.small),
                          if (stats.isNotEmpty)
                            Text(
                              'Сделано: ${stats.entries.map((e) => '${e.key == svc.me ? 'ты' : board.nameOf(e.key)} — ${e.value}').join(', ')}',
                              style: W.small,
                            ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _newCtl,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Новая задача',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => _add('todo')),
                            ),
                            onSubmitted: (_) => _add('todo'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (column(tasks, s).isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: Center(
                              child: Text(
                                switch (s) {
                                  'doing' => 'Сейчас никто ничего не делает.\nНажми ▶ у задачи в «Надо сделать».',
                                  'done' => 'Готовых задач пока нет.',
                                  _ => 'Задач нет — добавь первую.',
                                },
                                style: W.small,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        for (final t in column(tasks, s)) _taskCard(t, color),
                      ]),
                    ),
                ]),
        );
      }),
    );
  }

  Widget _taskCard(BoardTask t, Color color) {
    final who = t.assignee.isEmpty ? '' : (t.assignee == svc.me ? 'Я' : board.nameOf(t.assignee));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WCard(
        onTap: () => _edit(t),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        borderColor: t.assignee == svc.me && t.status == 'doing' ? color : null,
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                t.title,
                style: W.body.copyWith(
                  decoration: t.status == 'done' ? TextDecoration.lineThrough : null,
                  color: t.status == 'done' ? W.muted : W.text,
                ),
              ),
              if (t.note.isNotEmpty) Text(t.note, style: W.small, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (who.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text(who, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
          ),
          if (t.status != 'todo')
            IconButton(
              tooltip: 'Назад',
              icon: const Icon(Icons.undo, size: 20, color: W.muted),
              onPressed: () => _move(t, t.status == 'done' ? 'doing' : 'todo'),
            ),
          if (t.status != 'done')
            IconButton(
              tooltip: t.status == 'todo' ? 'Взять в работу' : 'Готово',
              icon: Icon(t.status == 'todo' ? Icons.play_arrow_rounded : Icons.check_rounded, color: color),
              onPressed: () => _move(t, nextStatus(t.status)),
            ),
        ]),
      ),
    );
  }
}
