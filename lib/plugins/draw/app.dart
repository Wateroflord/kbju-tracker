import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'course.dart';
import 'shapes.dart';
import '../common/ui.dart';

const _orange = Color(0xFFFFAA5A);
const paper = Color(0xFFF7F4EE);

class Progress {
  static final _s = JsonStore('draw_school.json');
  static Map<String, dynamic> d = {};
  static Future<void> load() async => d = await _s.read();
  static Future<void> save() => _s.write(d);

  static Set<String> get done => {...((d['done'] as List?) ?? const []).map((e) => '$e')};
  static int best(String key) => (d['best_$key'] as num?)?.toInt() ?? 0;
  static int get xp => (d['xp'] as num?)?.toInt() ?? 0;
  static List<String> get days => [...((d['days'] as List?) ?? const []).map((e) => '$e')];

  static String _today() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Отметить занятие сегодня и начислить опыт.
  static Future<void> practice(int gainXp) async {
    final ds = days;
    if (!ds.contains(_today())) ds.add(_today());
    d['days'] = ds.length > 400 ? ds.sublist(ds.length - 400) : ds;
    d['xp'] = xp + gainXp;
    await save();
  }

  static int get streak {
    final set = days.toSet();
    var n = 0;
    var day = DateTime.now();
    String k(DateTime t) => '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    if (!set.contains(k(day))) day = day.subtract(const Duration(days: 1));
    while (set.contains(k(day))) {
      n++;
      day = day.subtract(const Duration(days: 1));
    }
    return n;
  }
}

class DrawSchoolApp extends StatelessWidget {
  const DrawSchoolApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Уроки рисования',
        debugShowCheckedModeBanner: false,
        theme: winterTheme(_orange),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  @override
  void initState() {
    super.initState();
    Progress.load().then((_) => setState(() {}));
  }

  (String, String) get challenge {
    final n = DateTime.now();
    final seed = n.year * 1000 + n.month * 50 + n.day;
    final r = math.Random(seed);
    return (challengeSubjects[r.nextInt(challengeSubjects.length)], challengeConditions[r.nextInt(challengeConditions.length)]);
  }

  void go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w)).then((_) => setState(() {}));

  @override
  Widget build(BuildContext context) {
    final done = Progress.done;
    final total = course.fold<int>(0, (a, m) => a + m.lessons.length);
    final ch = challenge;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
              children: [
                const Text('Уроки рисования', style: W.h1),
                const Text('Каждый день по 15 минут — и через месяц рука станет увереннее', style: W.small),
                const SizedBox(height: 14),
                Row(children: [
                  _stat('🔥', '${Progress.streak}', 'дней подряд'),
                  const SizedBox(width: 8),
                  _stat('⭐', '${Progress.xp}', 'опыта'),
                  const SizedBox(width: 8),
                  _stat('📘', '${done.length}/$total', 'уроков'),
                ]),
                const SizedBox(height: 12),
                WCard(
                  borderColor: _orange.withValues(alpha: 0.6),
                  onTap: () => go(PracticeScreen(title: 'Задание дня', task: 'Нарисуй: ${ch.$1} — ${ch.$2}', seconds: ch.$2.contains('5 минут') ? 300 : (ch.$2.contains('10 минут') ? 600 : 0), xp: 30)),
                  child: Row(children: [
                    const Text('🎯', style: TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Задание дня', style: W.h2),
                        Text('${ch.$1[0].toUpperCase()}${ch.$1.substring(1)} — ${ch.$2}', style: W.body),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: W.muted),
                  ]),
                ),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: WCard(
                      onTap: () => go(const PracticeScreen(title: 'Свободное рисование', task: 'Рисуй что хочешь', xp: 5)),
                      child: const Row(children: [Icon(Icons.draw_outlined, color: _orange), SizedBox(width: 8), Expanded(child: Text('Свободный холст', style: W.body))]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: WCard(
                      onTap: () => go(const GestureScreen()),
                      child: const Row(children: [Icon(Icons.timer_outlined, color: _orange), SizedBox(width: 8), Expanded(child: Text('Наброски на время', style: W.body))]),
                    ),
                  ),
                ]),
                for (final m in course) ...[
                  Section('${m.emoji}  ${m.title}'),
                  for (final l in m.lessons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: WCard(
                        onTap: () => go(LessonScreen(lesson: l)),
                        child: Row(children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: done.contains(l.id) ? W.good : W.surface2, border: Border.all(color: W.border)),
                            child: done.contains(l.id) ? const Icon(Icons.check, color: W.bg, size: 20) : const Icon(Icons.play_arrow, color: _orange, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.title, style: W.h2), Text(l.about, style: W.small)])),
                        ]),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String e, String v, String label) => Expanded(
        child: WCard(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(children: [
            Text('$e $v', style: W.h2),
            Text(label, style: W.small),
          ]),
        ),
      );
}

// ---------------- Урок ----------------

class LessonScreen extends StatefulWidget {
  final Lesson lesson;
  const LessonScreen({super.key, required this.lesson});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  int i = 0;

  @override
  Widget build(BuildContext context) {
    final l = widget.lesson;
    final pages = l.pages.length;
    final total = pages + l.exercises.length;
    final isPage = i < pages;
    return Scaffold(
      appBar: AppBar(title: Text(l.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(children: [
              LinearProgressIndicator(value: (i + 1) / total, color: _orange),
              Expanded(
                child: isPage
                    ? ListView(padding: const EdgeInsets.all(16), children: [
                        Text('Теория ${i + 1} из $pages', style: W.small),
                        const SizedBox(height: 8),
                        Text(l.pages[i].text, style: W.body.copyWith(fontSize: 16)),
                        const SizedBox(height: 16),
                        if (l.pages[i].art.isNotEmpty)
                          AspectRatio(
                            aspectRatio: 1.3,
                            child: Container(
                              decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(12)),
                              child: CustomPaint(painter: GuidePainter(l.pages[i].art)),
                            ),
                          ),
                      ])
                    : ExerciseView(
                        key: ValueKey(i),
                        ex: l.exercises[i - pages],
                        id: '${l.id}_${i - pages}',
                        onDone: () => setState(() {}),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(children: [
                  if (i > 0) Expanded(child: OutlinedButton(onPressed: () => setState(() => i--), child: const Text('Назад'))),
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: W.bg),
                      onPressed: () async {
                        if (i < total - 1) {
                          setState(() => i++);
                          return;
                        }
                        final d = Progress.done..add(l.id);
                        Progress.d['done'] = d.toList();
                        await Progress.practice(20);
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(i < total - 1 ? (i == pages - 1 ? 'К практике' : 'Дальше') : 'Урок пройден'),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------- Холст для рисования ----------------

class PadStroke {
  final List<Offset> pts = [];
  final double width;
  final bool erase;
  PadStroke(this.width, this.erase);
}

class DrawPad extends StatefulWidget {
  final List<G> guide;
  final bool showGuide;
  final DrawPadController controller;
  const DrawPad({super.key, this.guide = const [], this.showGuide = true, required this.controller});

  @override
  State<DrawPad> createState() => _DrawPadState();
}

class DrawPadController extends ChangeNotifier {
  final List<PadStroke> strokes = [];
  final List<PadStroke> _redo = [];
  double width = 4;
  bool erase = false;
  Size size = Size.zero;

  void clear() {
    strokes.clear();
    _redo.clear();
    notifyListeners();
  }

  void undo() {
    if (strokes.isNotEmpty) _redo.add(strokes.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redo.isNotEmpty) strokes.add(_redo.removeLast());
    notifyListeners();
  }

  List<Offset> get points => [for (final s in strokes) if (!s.erase) ...s.pts];

  void changed() => notifyListeners();
}

class _DrawPadState extends State<DrawPad> {
  PadStroke? cur;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return LayoutBuilder(builder: (context, box) {
      c.size = Size(box.maxWidth, box.maxHeight);
      return Listener(
        onPointerDown: (e) {
          if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryMouseButton) return;
          cur = PadStroke(c.erase ? c.width * 4 : c.width, c.erase)..pts.add(e.localPosition);
          c.strokes.add(cur!);
          c._redo.clear();
          c.changed();
        },
        onPointerMove: (e) {
          if (cur == null) return;
          cur!.pts.add(e.localPosition);
          c.changed();
        },
        onPointerUp: (_) => cur = null,
        child: ListenableBuilder(
          listenable: c,
          builder: (_, __) => Container(
            decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(12)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CustomPaint(
                size: Size.infinite,
                painter: _PadPainter(c.strokes, widget.showGuide ? widget.guide : const []),
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _PadPainter extends CustomPainter {
  final List<PadStroke> strokes;
  final List<G> guide;
  _PadPainter(this.strokes, this.guide);

  @override
  void paint(Canvas canvas, Size size) {
    if (guide.isNotEmpty) GuidePainter(guide, color: const Color(0x55FF8A3D), width: 6, dashed: false).paint(canvas, size);
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final s in strokes) {
      final p = Paint()
        ..color = const Color(0xFF1B2335)
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.erase) p.blendMode = BlendMode.clear;
      if (s.pts.length == 1) {
        canvas.drawCircle(s.pts.first, s.width / 2, p..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(s.pts.first.dx, s.pts.first.dy);
      for (var i = 1; i < s.pts.length; i++) {
        path.lineTo(s.pts[i].dx, s.pts[i].dy);
      }
      canvas.drawPath(path, p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PadPainter old) => true;
}

Widget padTools(DrawPadController c, void Function(VoidCallback) set) => Row(children: [
      IconButton(tooltip: 'Карандаш', icon: Icon(Icons.edit, color: !c.erase ? _orange : W.muted), onPressed: () => set(() => c.erase = false)),
      IconButton(tooltip: 'Ластик', icon: Icon(Icons.auto_fix_normal, color: c.erase ? _orange : W.muted), onPressed: () => set(() => c.erase = true)),
      Expanded(child: Slider(value: c.width, min: 1, max: 20, activeColor: _orange, onChanged: (v) => set(() => c.width = v))),
      IconButton(tooltip: 'Отменить', icon: const Icon(Icons.undo), onPressed: c.undo),
      IconButton(tooltip: 'Очистить', icon: const Icon(Icons.delete_outline), onPressed: c.clear),
    ]);

/// Оценка обводки: насколько точно и полно повторена подсказка (0–100).
int traceScore(List<G> guide, List<Offset> user, Size size) {
  final g = [for (final s in guide) ...s.samples(size, step: 5)];
  if (g.isEmpty || user.isEmpty) return 0;
  final tol = size.shortestSide * 0.035;
  final tol2 = tol * tol;
  // Сетка для быстрого поиска ближайших точек.
  Map<int, List<Offset>> grid(List<Offset> pts) {
    final m = <int, List<Offset>>{};
    for (final p in pts) {
      (m[(p.dx ~/ tol) * 100000 + (p.dy ~/ tol)] ??= []).add(p);
    }
    return m;
  }

  bool near(Map<int, List<Offset>> m, Offset p) {
    final cx = p.dx ~/ tol, cy = p.dy ~/ tol;
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        for (final q in m[(cx + dx) * 100000 + (cy + dy)] ?? const <Offset>[]) {
          if ((q - p).distanceSquared <= tol2) return true;
        }
      }
    }
    return false;
  }

  final gg = grid(g), ug = grid(user);
  final precision = user.where((p) => near(gg, p)).length / user.length;
  final coverage = g.where((p) => near(ug, p)).length / g.length;
  return (100 * (0.5 * precision + 0.5 * coverage)).round();
}

class ExerciseView extends StatefulWidget {
  final Exercise ex;
  final String id;
  final VoidCallback onDone;
  const ExerciseView({super.key, required this.ex, required this.id, required this.onDone});

  @override
  State<ExerciseView> createState() => _ExerciseViewState();
}

class _ExerciseViewState extends State<ExerciseView> {
  final c = DrawPadController();
  int? score;
  bool guide = true;
  Timer? _t;
  int left = 0;

  @override
  void initState() {
    super.initState();
    left = widget.ex.seconds;
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _start() {
    _t?.cancel();
    c.clear();
    setState(() => left = widget.ex.seconds);
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) {
        t.cancel();
        Progress.practice(10);
        toast(context, 'Время! Посмотри на рисунки и отметь, что получилось лучше всего');
      }
    });
  }

  Future<void> _check() async {
    final s = traceScore(widget.ex.guide, c.points, c.size);
    setState(() => score = s);
    if (s > Progress.best(widget.id)) Progress.d['best_${widget.id}'] = s;
    await Progress.practice(s >= 70 ? 10 : 3);
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.ex;
    final stars = score == null ? 0 : (score! >= 85 ? 3 : score! >= 70 ? 2 : score! >= 50 ? 1 : 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(ex.task, style: W.h2),
        if (ex.trace) Text('Лучший результат: ${Progress.best(widget.id)}%', style: W.small),
        const SizedBox(height: 8),
        Expanded(child: DrawPad(controller: c, guide: ex.guide, showGuide: guide)),
        StatefulBuilder(builder: (context, set) => padTools(c, (f) => setState(f))),
        if (ex.trace)
          Row(children: [
            Switch(value: guide, activeTrackColor: _orange, onChanged: (v) => setState(() => guide = v)),
            const Text('Подсказка', style: W.small),
            const Spacer(),
            if (score != null) Text('${'★' * stars}${'☆' * (3 - stars)}  $score%', style: W.h2.copyWith(color: stars >= 2 ? W.good : W.warn)),
            const SizedBox(width: 8),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: W.bg), onPressed: _check, child: const Text('Проверить')),
          ])
        else if (ex.seconds > 0)
          Row(children: [
            Text(_t?.isActive == true ? 'Осталось ${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')}' : 'Таймер: ${ex.seconds ~/ 60} мин', style: W.h2),
            const Spacer(),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: W.bg), onPressed: _start, child: Text(_t?.isActive == true ? 'Заново' : 'Старт')),
          ]),
        if (score != null && score! < 70)
          const Text('Совет: веди линию быстрее и одним движением — медленная линия дрожит.', style: W.small),
      ]),
    );
  }
}

class PracticeScreen extends StatefulWidget {
  final String title, task;
  final int seconds, xp;
  const PracticeScreen({super.key, required this.title, required this.task, this.seconds = 0, this.xp = 5});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final c = DrawPadController();
  bool counted = false;

  @override
  void initState() {
    super.initState();
    c.addListener(() {
      if (!counted && c.strokes.length > 10) {
        counted = true;
        Progress.practice(widget.xp);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(widget.task, style: W.h2),
              if (widget.seconds > 0) Text('Постарайся уложиться в ${widget.seconds ~/ 60} мин', style: W.small),
              const SizedBox(height: 8),
              Expanded(child: DrawPad(controller: c)),
              StatefulBuilder(builder: (context, set) => padTools(c, (f) => setState(f))),
              const Text('Для серьёзной работы со слоями и пиксель-артом есть Winter Paint в Winter Hub.', style: W.small),
            ]),
          ),
        ),
      );
}

/// Наброски на время: короткие задания по таймеру одно за другим.
class GestureScreen extends StatefulWidget {
  const GestureScreen({super.key});

  @override
  State<GestureScreen> createState() => _GestureScreenState();
}

class _GestureScreenState extends State<GestureScreen> {
  final c = DrawPadController();
  int seconds = 60;
  int left = 0;
  int n = 0;
  Timer? _t;
  String task = '';
  final rnd = math.Random();

  static const prompts = [
    'человек бежит', 'человек сидит', 'прыжок', 'кот потягивается', 'птица в полёте', 'чашка сбоку', 'рука держит ручку', 'дерево на ветру',
    'человек поднимает тяжесть', 'собака лежит', 'бросок мяча', 'танец', 'взмах мечом', 'человек читает', 'лошадь скачет', 'удар ногой',
  ];

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _next() {
    c.clear();
    setState(() {
      n++;
      left = seconds;
      task = prompts[rnd.nextInt(prompts.length)];
    });
  }

  void _start() {
    n = 0;
    _next();
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) {
        if (n >= 5) {
          _t?.cancel();
          Progress.practice(25);
          toast(context, 'Готово! 5 набросков. Повторяй каждый день');
          setState(() {});
        } else {
          _next();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final running = _t?.isActive == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Наброски на время')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!running) ...[
              const Text('5 быстрых набросков подряд. Не прорисовывай детали — лови движение и общую форму одной линией действия.', style: W.body),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final s in [30, 60, 120]) Chip2('$s сек', selected: seconds == s, onTap: () => setState(() => seconds = s)),
              ]),
              const SizedBox(height: 8),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: _orange, foregroundColor: W.bg), onPressed: _start, child: const Text('Начать')),
            ] else
              Row(children: [
                Expanded(child: Text('$n/5: $task', style: W.h2)),
                Text('$left с', style: W.h1.copyWith(color: left <= 10 ? W.bad : _orange)),
              ]),
            const SizedBox(height: 8),
            Expanded(child: DrawPad(controller: c)),
            StatefulBuilder(builder: (context, set) => padTools(c, (f) => setState(f))),
          ]),
        ),
      ),
    );
  }
}
