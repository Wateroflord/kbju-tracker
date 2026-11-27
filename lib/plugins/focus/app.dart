import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/notify.dart';
import '../common/ui.dart';
import '../common/wav.dart';
import 'boards_screen.dart';
import 'boards_service.dart';
import 'model.dart';

const _accent = Color(0xFFFF7A6B);
const projectColors = [
  Color(0xFFFF7A6B),
  Color(0xFF7FD8FF),
  Color(0xFF6EE7B7),
  Color(0xFFFFC46B),
  Color(0xFFB48CFF),
  Color(0xFFFF78AA),
  Color(0xFF9AD0FF),
  Color(0xFFE8D5A8),
];

String _dk(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class FocusApp extends StatelessWidget {
  const FocusApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Фокус',
        debugShowCheckedModeBanner: false,
        theme: winterTheme(_accent),
        home: const FocusHome(),
      );
}

/// Данные и таймер. Таймер хранит время окончания — если приложение закрыть, он «доживёт» до конца
/// и при следующем открытии помидор будет засчитан.
class FocusStore extends ChangeNotifier {
  static final I = FocusStore._();
  FocusStore._();

  final _file = JsonStore('focus.json');
  bool loaded = false;
  FocusSettings settings = const FocusSettings();
  List<FocusProject> projects = [];
  List<FocusTask> tasks = [];
  List<FocusLog> logs = [];

  Phase phase = Phase.work;
  int? endsAt; // мс — таймер идёт
  int? pausedLeft; // мс — пауза
  int doneInCycle = 0;
  String? project, task;

  /// Задача с общей доски, на которую идут помидоры (вместо своей задачи).
  String? boardTask;
  String boardTaskTitle = '', boardName = '';

  /// Помидоры для задач досок, которые не удалось отправить (нет связи): id задачи → сколько.
  Map<String, int> boardPending = {};

  bool get running => endsAt != null;
  bool get paused => pausedLeft != null;
  bool get idle => !running && !paused;

  Future<void> load() async {
    if (loaded) return;
    final j = await _file.read();
    settings = FocusSettings.fromJson(j['settings']);
    projects = (j['projects'] as List? ?? []).map(FocusProject.fromJson).whereType<FocusProject>().toList();
    tasks = (j['tasks'] as List? ?? []).map(FocusTask.fromJson).whereType<FocusTask>().toList();
    logs = (j['logs'] as List? ?? []).map(FocusLog.fromJson).whereType<FocusLog>().toList();
    final t = j['timer'];
    if (t is Map) {
      phase = Phase.values.firstWhere((p) => p.name == t['phase'], orElse: () => Phase.work);
      endsAt = (t['endsAt'] as num?)?.toInt();
      pausedLeft = (t['left'] as num?)?.toInt();
      doneInCycle = (t['cycle'] as num?)?.toInt() ?? 0;
    }
    project = j['project']?.toString();
    task = j['task']?.toString();
    final b = j['board'];
    if (b is Map && b['task'] != null) {
      boardTask = '${b['task']}';
      boardTaskTitle = '${b['title'] ?? ''}';
      boardName = '${b['name'] ?? ''}';
    }
    boardPending = {
      for (final e in ((j['boardPending'] as Map?) ?? const {}).entries)
        if (e.value is num && (e.value as num) > 0) '${e.key}': (e.value as num).toInt(),
    };
    if (projects.isEmpty) projects = [const FocusProject('main', 'Общее', 0)];
    if (project == null || !projects.any((p) => p.id == project && !p.archived)) {
      project = projects.firstWhere((p) => !p.archived, orElse: () => projects.first).id;
    }
    loaded = true;
  }

  Future<void> save() async {
    notifyListeners();
    await _file.write({
      'v': 1,
      'settings': settings.toJson(),
      'projects': [for (final p in projects) p.toJson()],
      'tasks': [for (final t in tasks) t.toJson()],
      'logs': [for (final l in logs) l.toJson()],
      'timer': {'phase': phase.name, 'endsAt': endsAt, 'left': pausedLeft, 'cycle': doneInCycle},
      'project': project,
      'task': task,
      if (boardTask != null) 'board': {'task': boardTask, 'title': boardTaskTitle, 'name': boardName},
      if (boardPending.isNotEmpty) 'boardPending': boardPending,
    });
  }

  /// Помидоры пойдут задаче с общей доски.
  Future<void> focusBoardTask(String id, String title, String board) async {
    boardTask = id;
    boardTaskTitle = title;
    boardName = board;
    task = null;
    await save();
  }

  Future<void> clearBoardTask() async {
    boardTask = null;
    boardTaskTitle = '';
    boardName = '';
    await save();
  }

  /// Отправить на сервер помидоры, которые ждут связи.
  Future<void> flushBoard() async {
    if (boardPending.isEmpty || !BoardsService.I.connected) return;
    final left = <String, int>{};
    for (final e in boardPending.entries) {
      try {
        await BoardsService.I.addPomodoros(e.key, e.value);
      } on BoardsError catch (err) {
        // Задачу удалили — забываем; нет связи — попробуем позже.
        if (!err.message.startsWith('Не найдено')) left[e.key] = e.value;
      } catch (_) {
        left[e.key] = e.value;
      }
    }
    boardPending = left;
    await save();
  }

  String newId() => '${DateTime.now().microsecondsSinceEpoch}';

  FocusProject? get currentProject {
    for (final p in projects) {
      if (p.id == project) return p;
    }
    return null;
  }

  FocusTask? get currentTask {
    for (final t in tasks) {
      if (t.id == task) return t;
    }
    return null;
  }

  int leftMs(int now) => endsAt != null ? math.max(0, endsAt! - now) : (pausedLeft ?? settings.minutesOf(phase) * 60000);

  static const _notifyId = 300001;

  Future<void> start() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    endsAt = now + (pausedLeft ?? settings.minutesOf(phase) * 60000);
    pausedLeft = null;
    await PluginNotify.requestPermission();
    await _scheduleEnd();
    await save();
  }

  Future<void> pause() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    pausedLeft = leftMs(now);
    endsAt = null;
    await PluginNotify.cancel(_notifyId);
    await save();
  }

  /// Сбросить текущую фазу. Если это была работа — засчитать уже отработанные минуты (без помидора).
  Future<void> reset() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (phase == Phase.work && !idle) {
      final spent = (settings.work * 60000 - leftMs(now)) ~/ 60000;
      if (spent >= 1) _log(spent);
    }
    endsAt = null;
    pausedLeft = null;
    await PluginNotify.cancel(_notifyId);
    await save();
  }

  /// Пропустить фазу (перерыв не нужен / работа сорвалась).
  Future<void> skip() async {
    await reset();
    phase = phase == Phase.work ? Phase.shortBreak : Phase.work;
    await save();
  }

  /// Проверить, не закончилась ли фаза. true — закончилась только что.
  Future<bool> tick() async {
    if (endsAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now < endsAt!) return false;
    final finished = phase;
    endsAt = null;
    pausedLeft = null;
    if (finished == Phase.work) {
      _log(settings.work);
      doneInCycle++;
      final t = currentTask;
      if (t != null) tasks = [for (final x in tasks) x.id == t.id ? x.copyWith(pomodoros: x.pomodoros + 1) : x];
      final bt = boardTask;
      if (bt != null) {
        boardPending = {...boardPending, bt: (boardPending[bt] ?? 0) + 1};
        unawaited(flushBoard());
      }
    }
    phase = nextPhase(finished, doneInCycle, settings.longEvery);
    if (phase == Phase.longBreak) doneInCycle = 0;
    // Перерыв запускается сам (если включено), работа — только по кнопке.
    if (phase != Phase.work && settings.autoBreak) {
      endsAt = now + settings.minutesOf(phase) * 60000;
      await _scheduleEnd();
    }
    await save();
    return true;
  }

  void _log(int minutes) {
    final day = _dk(DateTime.now());
    final p = project ?? '';
    final i = logs.indexWhere((l) => l.day == day && l.project == p);
    if (i >= 0) {
      logs[i] = FocusLog(day, p, logs[i].minutes + minutes);
    } else {
      logs.add(FocusLog(day, p, minutes));
    }
  }

  Future<void> _scheduleEnd() async {
    if (endsAt == null) return;
    final (title, body) = switch (phase) {
      Phase.work => ('🍅 Помидор готов!', 'Время отдохнуть ${settings.shortBreak} мин. ${currentProject?.name ?? ''}'),
      Phase.shortBreak => ('Перерыв закончился', 'Возвращайся к работе 💪'),
      Phase.longBreak => ('Длинный перерыв закончился', 'Новый круг — поехали 💪'),
    };
    await PluginNotify.schedule(_notifyId, title, body, DateTime.fromMillisecondsSinceEpoch(endsAt!),
        channel: 'focus', channelName: 'Фокус', exact: true);
  }
}

String _phaseName(Phase p) => switch (p) {
      Phase.work => 'Работа',
      Phase.shortBreak => 'Короткий перерыв',
      Phase.longBreak => 'Длинный перерыв',
    };

class FocusHome extends StatefulWidget {
  const FocusHome({super.key});

  @override
  State<FocusHome> createState() => _FocusHomeState();
}

class _FocusHomeState extends State<FocusHome> with WidgetsBindingObserver {
  final st = FocusStore.I;
  Timer? _t;
  final _player = AudioPlayer();
  final _taskCtl = TextEditingController();
  bool showDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    st.addListener(_changed);
    st.load().then((_) async {
      await st.tick();
      if (mounted) setState(() {});
    });
    _t = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      if (!st.loaded) return;
      if (await st.tick()) _ding();
      if (st.running && mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      st.tick();
      st.flushBoard();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    st.removeListener(_changed);
    _t?.cancel();
    _player.dispose();
    _taskCtl.dispose();
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  Future<void> _ding() async {
    HapticFeedback.heavyImpact();
    try {
      final path = await tempSound('winter_focus_chime.wav', () => chimeWav([784, 988, 1175]));
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } catch (_) {}
  }

  Future<void> _addProject() async {
    final name = await _askText('Новый проект', 'Например: моя игра, учёба, работа');
    if (name == null || name.isEmpty) return;
    final p = FocusProject(st.newId(), name, st.projects.length % projectColors.length);
    st.projects = [...st.projects, p];
    st.project = p.id;
    st.task = null;
    await st.save();
  }

  Future<String?> _askText(String title, String hint, {String initial = ''}) {
    final ctl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          onSubmitted: (v) => Navigator.pop(c, v.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('Готово')),
        ],
      ),
    );
  }

  void _addTask() {
    final t = _taskCtl.text.trim();
    if (t.isEmpty || st.project == null) return;
    final task = FocusTask(st.newId(), st.project!, t);
    st.tasks = [...st.tasks, task];
    st.task ??= task.id;
    _taskCtl.clear();
    st.save();
  }

  Future<void> _taskMenu(FocusTask t) async {
    final a = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('Переименовать'), onTap: () => Navigator.pop(c, 'rename')),
          ListTile(leading: const Icon(Icons.delete_outline, color: W.bad), title: const Text('Удалить'), onTap: () => Navigator.pop(c, 'delete')),
        ]),
      ),
    );
    if (a == 'rename') {
      final n = await _askText('Задача', '', initial: t.title);
      if (n != null && n.isNotEmpty) {
        st.tasks = [for (final x in st.tasks) x.id == t.id ? x.copyWith(title: n) : x];
        await st.save();
      }
    } else if (a == 'delete') {
      st.tasks = st.tasks.where((x) => x.id != t.id).toList();
      if (st.task == t.id) st.task = null;
      await st.save();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!st.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final now = DateTime.now().millisecondsSinceEpoch;
    final total = st.settings.minutesOf(st.phase) * 60000;
    final left = st.leftMs(now);
    final secs = (left / 1000).ceil();
    final color = st.phase == Phase.work ? (projectColors[(st.currentProject?.color ?? 0) % projectColors.length]) : W.good;
    final projTasks = st.tasks.where((t) => t.project == st.project).toList();
    final open = projTasks.where((t) => !t.done).toList();
    final done = projTasks.where((t) => t.done).toList();
    final today = _dk(DateTime.now());
    final byDay = minutesByDay(st.logs);
    final todayMin = byDay[today] ?? 0;
    final streak = focusStreak(byDay, DateTime.now());
    final active = st.projects.where((p) => !p.archived).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Фокус'),
        actions: [
          IconButton(
            tooltip: 'Общие доски с друзьями',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SharedBoardsScreen())),
          ),
          IconButton(
            tooltip: 'Статистика',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FocusStats())),
          ),
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FocusSettingsScreen())),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in active)
            Chip2(p.name, selected: p.id == st.project, onTap: () {
              if (!st.idle && st.phase == Phase.work && p.id != st.project) {
                toast(context, 'Сначала останови помидор — он считается в текущий проект');
                return;
              }
              st.project = p.id;
              st.task = null;
              st.save();
            }),
          Chip2('+ проект', onTap: _addProject),
        ]),
        const SizedBox(height: 18),
        Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: CustomPaint(
              painter: _Ring(1 - left / total, color),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_phaseName(st.phase), style: W.small.copyWith(color: color)),
                  Text(
                    '${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: W.text, fontFeatures: [FontFeature.tabularFigures()]),
                  ),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < st.settings.longEvery; i++)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: i < st.doneInCycle ? color : W.border),
                      ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
        if (st.boardTask != null) ...[
          const SizedBox(height: 12),
          WCard(
            borderColor: color,
            padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
            child: Row(children: [
              const Icon(Icons.groups_outlined, color: W.ice, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(st.boardTaskTitle, style: W.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    'Общая доска «${st.boardName}» — помидоры видны всем'
                    '${st.boardPending.isNotEmpty ? ' · ждут связи: ${st.boardPending.values.fold<int>(0, (a, b) => a + b)}' : ''}',
                    style: W.small,
                  ),
                ]),
              ),
              IconButton(tooltip: 'Убрать', icon: const Icon(Icons.close, size: 18, color: W.muted), onPressed: st.clearBoardTask),
            ]),
          ),
        ],
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.outlined(
            tooltip: 'Сбросить',
            onPressed: st.idle ? null : st.reset,
            icon: const Icon(Icons.replay),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 150,
            height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: W.bg),
              onPressed: st.running ? st.pause : st.start,
              icon: Icon(st.running ? Icons.pause : Icons.play_arrow),
              label: Text(st.running ? 'Пауза' : (st.paused ? 'Дальше' : 'Старт'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 16),
          IconButton.outlined(
            tooltip: st.phase == Phase.work ? 'Пропустить → перерыв' : 'Пропустить перерыв',
            onPressed: st.skip,
            icon: const Icon(Icons.skip_next),
          ),
        ]),
        const SizedBox(height: 14),
        Center(
          child: Text(
            [
              'Сегодня: ${durText(todayMin)}',
              if (streak > 1) 'серия $streak дн. 🔥',
            ].join(' · '),
            style: W.small,
          ),
        ),
        Section('Задачи · ${st.currentProject?.name ?? ''}'),
        if (open.isEmpty) const Text('Разбей работу на маленькие задачи — так проще начать.', style: W.small),
        for (final t in open)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: WCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              borderColor: t.id == st.task ? color : null,
              onTap: () {
                st.task = st.task == t.id ? null : t.id;
                if (st.task != null) {
                  st.boardTask = null;
                  st.boardTaskTitle = '';
                }
                st.save();
              },
              child: Row(children: [
                Checkbox(
                  value: false,
                  onChanged: (_) {
                    st.tasks = [for (final x in st.tasks) x.id == t.id ? x.copyWith(done: true) : x];
                    if (st.task == t.id) st.task = null;
                    HapticFeedback.lightImpact();
                    st.save();
                  },
                ),
                Expanded(child: Text(t.title, style: W.body)),
                if (t.pomodoros > 0) Text('🍅×${t.pomodoros}', style: W.small),
                if (t.id == st.task) Padding(padding: const EdgeInsets.only(left: 6), child: Icon(Icons.adjust, size: 18, color: color)),
                IconButton(icon: const Icon(Icons.more_vert, size: 20), onPressed: () => _taskMenu(t)),
              ]),
            ),
          ),
        const SizedBox(height: 4),
        TextField(
          controller: _taskCtl,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Новая задача',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: _addTask),
          ),
          onSubmitted: (_) => _addTask(),
        ),
        if (open.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Нажми на задачу — помидоры будут засчитываться ей.', style: W.small),
          ),
        const SizedBox(height: 12),
        WCard(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SharedBoardsScreen())),
          child: const Row(children: [
            Icon(Icons.groups_outlined, color: W.ice),
            SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Общие доски', style: W.h2),
                Text('Задачи проекта с другом — например FalseMemory', style: W.small),
              ]),
            ),
            Icon(Icons.chevron_right, color: W.muted),
          ]),
        ),
        if (done.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => showDone = !showDone),
            child: Text(showDone ? 'Скрыть сделанные' : 'Сделано: ${done.length}'),
          ),
          if (showDone)
            for (final t in done)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  value: true,
                  onChanged: (_) {
                    st.tasks = [for (final x in st.tasks) x.id == t.id ? x.copyWith(done: false) : x];
                    st.save();
                  },
                ),
                title: Text(t.title, style: W.body.copyWith(decoration: TextDecoration.lineThrough, color: W.muted)),
                trailing: t.pomodoros > 0 ? Text('🍅×${t.pomodoros}', style: W.small) : null,
                onLongPress: () => _taskMenu(t),
              ),
        ],
      ]),
    );
  }
}

class _Ring extends CustomPainter {
  final double progress;
  final Color color;
  _Ring(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    canvas.drawCircle(c, r, Paint()
      ..color = W.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_Ring old) => old.progress != progress || old.color != color;
}

// ───────────────────────────── Статистика ─────────────────────────────

class FocusStats extends StatefulWidget {
  const FocusStats({super.key});

  @override
  State<FocusStats> createState() => _FocusStatsState();
}

class _FocusStatsState extends State<FocusStats> {
  final st = FocusStore.I;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = [for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i)];
    final byDay = minutesByDay(st.logs);
    final maxMin = days.map((d) => byDay[_dk(d)] ?? 0).fold<int>(30, (a, b) => math.max(a, b));
    final week = minutesByProject(st.logs, _dk(days.first), _dk(days.last));
    final all = minutesByProject(st.logs, '0000-00-00', '9999-99-99');
    const wd = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        const Section('Последние 7 дней'),
        WCard(
          child: SizedBox(
            height: 150,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (final d in days)
                Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('${((byDay[_dk(d)] ?? 0) / 60).toStringAsFixed(1).replaceAll('.0', '')}ч', style: W.small.copyWith(fontSize: 10.5)),
                    const SizedBox(height: 3),
                    Container(
                      height: 100 * (byDay[_dk(d)] ?? 0) / maxMin,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(color: W.accent, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 4),
                    Text(wd[d.weekday - 1], style: W.small),
                  ]),
                ),
            ]),
          ),
        ),
        const Section('Проекты'),
        for (final p in st.projects)
          WCard(
            padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: projectColors[p.color % projectColors.length])),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.archived ? '${p.name} (в архиве)' : p.name, style: W.body),
                  Text('Неделя: ${durText(week[p.id] ?? 0)} · всего: ${durText(all[p.id] ?? 0)}', style: W.small),
                ]),
              ),
              PopupMenuButton<String>(
                onSelected: (a) => _projectAction(p, a),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                  const PopupMenuItem(value: 'color', child: Text('Сменить цвет')),
                  PopupMenuItem(value: 'archive', child: Text(p.archived ? 'Вернуть из архива' : 'В архив')),
                  const PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
            ]),
          ),
        const SizedBox(height: 8),
        const Text('Проект в архиве не мешает в списке, но его статистика остаётся.', style: W.small),
      ]),
    );
  }

  Future<void> _projectAction(FocusProject p, String a) async {
    switch (a) {
      case 'rename':
        final ctl = TextEditingController(text: p.name);
        final n = await showDialog<String>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Название проекта'),
            content: TextField(controller: ctl, autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Отмена')),
              FilledButton(onPressed: () => Navigator.pop(c, ctl.text.trim()), child: const Text('Готово')),
            ],
          ),
        );
        if (n == null || n.isEmpty) return;
        st.projects = [for (final x in st.projects) x.id == p.id ? x.copyWith(name: n) : x];
      case 'color':
        st.projects = [for (final x in st.projects) x.id == p.id ? x.copyWith(color: (x.color + 1) % projectColors.length) : x];
      case 'archive':
        if (!p.archived && st.projects.where((x) => !x.archived).length <= 1) {
          toast(context, 'Нужен хотя бы один активный проект');
          return;
        }
        st.projects = [for (final x in st.projects) x.id == p.id ? x.copyWith(archived: !p.archived) : x];
        if (st.project == p.id) st.project = st.projects.firstWhere((x) => !x.archived).id;
      case 'delete':
        if (st.projects.length <= 1) {
          toast(context, 'Нужен хотя бы один проект');
          return;
        }
        if (!await confirmDialog(context, 'Удалить «${p.name}»?', 'Задачи и статистика проекта пропадут.', ok: 'Удалить')) return;
        st.projects = st.projects.where((x) => x.id != p.id).toList();
        st.tasks = st.tasks.where((t) => t.project != p.id).toList();
        st.logs = st.logs.where((l) => l.project != p.id).toList();
        if (st.project == p.id) {
          st.project = st.projects.firstWhere((x) => !x.archived, orElse: () => st.projects.first).id;
          st.task = null;
        }
    }
    await st.save();
    if (mounted) setState(() {});
  }
}

// ───────────────────────────── Настройки ─────────────────────────────

class FocusSettingsScreen extends StatefulWidget {
  const FocusSettingsScreen({super.key});

  @override
  State<FocusSettingsScreen> createState() => _FocusSettingsScreenState();
}

class _FocusSettingsScreenState extends State<FocusSettingsScreen> {
  final st = FocusStore.I;

  void _set(FocusSettings s) {
    setState(() => st.settings = s);
    st.save();
  }

  Widget _stepper(String label, int value, int min, int max, int step, String unit, void Function(int) set) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: W.body)),
          IconButton(onPressed: value - step < min ? null : () => set(value - step), icon: const Icon(Icons.remove)),
          SizedBox(width: 74, child: Text('$value $unit', style: W.h2, textAlign: TextAlign.center)),
          IconButton(onPressed: value + step > max ? null : () => set(value + step), icon: const Icon(Icons.add)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final s = st.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        _stepper('Работа', s.work, 5, 120, 5, 'мин', (v) => _set(s.copyWith(work: v))),
        _stepper('Короткий перерыв', s.shortBreak, 1, 30, 1, 'мин', (v) => _set(s.copyWith(shortBreak: v))),
        _stepper('Длинный перерыв', s.longBreak, 5, 60, 5, 'мин', (v) => _set(s.copyWith(longBreak: v))),
        _stepper('Длинный — после', s.longEvery, 2, 8, 1, 'пом.', (v) => _set(s.copyWith(longEvery: v))),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: s.autoBreak,
          onChanged: (v) => _set(s.copyWith(autoBreak: v)),
          title: const Text('Перерыв запускается сам', style: W.body),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Chip2('Классика 25/5', onTap: () => _set(s.copyWith(work: 25, shortBreak: 5, longBreak: 15, longEvery: 4))),
          Chip2('Глубокая работа 50/10', onTap: () => _set(s.copyWith(work: 50, shortBreak: 10, longBreak: 30, longEvery: 3))),
          Chip2('Короткие 15/3', onTap: () => _set(s.copyWith(work: 15, shortBreak: 3, longBreak: 10, longEvery: 4))),
        ]),
        const SizedBox(height: 16),
        const WCard(
          child: Text(
            'Как работает: ставишь задачу, жмёшь «Старт» и не отвлекаешься до сигнала. Потом короткий перерыв. '
            'После нескольких помидоров — длинный. Сигнал придёт уведомлением, даже если телефон заблокирован.',
            style: W.small,
          ),
        ),
      ]),
    );
  }
}
