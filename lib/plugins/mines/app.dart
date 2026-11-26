import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'race.dart';
import '../common/ui.dart';

class MinesApp extends StatelessWidget {
  const MinesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Сапёр',
        debugShowCheckedModeBanner: false,
        theme: winterTheme(const Color(0xFF7FD8FF)),
        home: const MenuScreen(),
      );
}

/// Рекорды и статистика.
class Stats {
  static final _store = JsonStore('mines_stats.json');
  static Map<String, dynamic> data = {};

  static Future<void> load() async => data = await _store.read();

  static int? best(String id) => (data['best_$id'] as num?)?.toInt();
  static int played(String id) => (data['played_$id'] as num?)?.toInt() ?? 0;
  static int won(String id) => (data['won_$id'] as num?)?.toInt() ?? 0;
  static bool get noGuess => data['noGuess'] == true;
  static bool get bigCells => data['bigCells'] == true;

  static Future<bool> record(String id, bool win, int ms, {bool counts = true}) async {
    data['played_$id'] = played(id) + 1;
    var isBest = false;
    if (win) {
      data['won_$id'] = won(id) + 1;
      final b = best(id);
      if (counts && (b == null || ms < b)) {
        data['best_$id'] = ms;
        isBest = true;
      }
    }
    await _store.write(data);
    return isBest;
  }

  static Future<void> set(String k, Object v) async {
    data[k] = v;
    await _store.write(data);
  }
}

String fmtTime(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}.${((ms % 1000) ~/ 100)}';
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    Stats.load().then((_) => setState(() => loaded = true));
  }

  Future<void> _play(Level l) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(level: l)));
    setState(() {});
  }

  Future<void> _custom() async {
    var w = (Stats.data['cw'] as num?)?.toInt() ?? 12;
    var h = (Stats.data['ch'] as num?)?.toInt() ?? 12;
    var m = (Stats.data['cm'] as num?)?.toInt() ?? 25;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          m = m.clamp(1, w * h - 9);
          Widget row(String name, int v, int min, int max, void Function(int) f) => Row(children: [
                SizedBox(width: 70, child: Text(name, style: W.body)),
                Expanded(child: Slider(value: v.toDouble(), min: min.toDouble(), max: max.toDouble(), onChanged: (x) => set(() => f(x.round())))),
                SizedBox(width: 36, child: Text('$v', textAlign: TextAlign.right, style: W.body)),
              ]);
          return AlertDialog(
            title: const Text('Своё поле', style: W.h2),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              row('Ширина', w, 5, 40, (x) => w = x),
              row('Высота', h, 5, 40, (x) => h = x),
              row('Мины', m, 1, w * h - 9, (x) => m = x),
              Text('Плотность мин: ${(m * 100 / (w * h)).round()}%', style: W.small),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Играть')),
            ],
          );
        },
      ),
    );
    if (ok != true) return;
    await Stats.set('cw', w);
    await Stats.set('ch', h);
    await Stats.set('cm', m);
    await _play(Level('custom', 'Своё поле', w, h, m));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: W.surface2,
                      border: Border.all(color: W.accent.withValues(alpha: 0.5)),
                    ),
                    child: const _MineIcon(size: 30),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Сапёр', style: W.h1),
                      Text('Открой все клетки без мин', style: W.small),
                    ]),
                  ),
                ]),
                const Section('Сложность'),
                for (final l in levels)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: WCard(
                      onTap: () => _play(l),
                      child: Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(l.name, style: W.h2),
                            Text('${l.w}×${l.h}, мин: ${l.mines}', style: W.small),
                          ]),
                        ),
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(Stats.best(l.id) == null ? '—' : fmtTime(Stats.best(l.id)!), style: W.h2.copyWith(color: W.accent)),
                          Text('побед ${Stats.won(l.id)} из ${Stats.played(l.id)}', style: W.small),
                        ]),
                      ]),
                    ),
                  ),
                WCard(
                  onTap: _custom,
                  child: const Row(children: [
                    Icon(Icons.tune, color: W.ice),
                    SizedBox(width: 12),
                    Expanded(child: Text('Своё поле: размер и число мин', style: W.body)),
                    Icon(Icons.chevron_right, color: W.muted),
                  ]),
                ),
                const SizedBox(height: 8),
                WCard(
                  borderColor: W.accent.withValues(alpha: 0.5),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RaceLobby())).then((_) => setState(() {})),
                  child: Row(children: [
                    Icon(Icons.sports_score, color: W.accent),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Гонка с другом', style: W.h2),
                        Text('Одинаковое поле — кто быстрее. Через сервер Winter Chat', style: W.small),
                      ]),
                    ),
                    const Icon(Icons.chevron_right, color: W.muted),
                  ]),
                ),
                const Section('Настройки'),
                WCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Без угадывания', style: W.body),
                      subtitle: const Text('Поле всегда можно решить логикой — не придётся рисковать 50 на 50', style: W.small),
                      value: Stats.noGuess,
                      onChanged: (v) => Stats.set('noGuess', v).then((_) => setState(() {})),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Крупные клетки', style: W.body),
                      subtitle: const Text('Удобнее на телефоне, большое поле листается пальцем', style: W.small),
                      value: Stats.bigCells,
                      onChanged: (v) => Stats.set('bigCells', v).then((_) => setState(() {})),
                    ),
                  ]),
                ),
                const Section('Как играть'),
                const WCard(
                  child: Text(
                    '• Нажатие — открыть клетку. Первая клетка всегда безопасна.\n'
                    '• Цифра — сколько мин в восьми соседних клетках.\n'
                    '• Флажок: долгое нажатие, правая кнопка мыши или режим «флажок» внизу.\n'
                    '• Нажми на цифру, вокруг которой уже стоят все флажки, — откроются остальные соседи.\n'
                    '• Подсказка покажет безопасную клетку, но рекорд за такую игру не засчитается.',
                    style: W.body,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  final Level level;
  const GameScreen({super.key, required this.level});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Board board;
  Timer? _timer;
  bool flagMode = false;
  bool usedHint = false;
  int? hinted;
  final viewer = TransformationController();

  @override
  void initState() {
    super.initState();
    _new();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (board.state == GameState.playing && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _new() {
    board = Board(widget.level.w, widget.level.h, widget.level.mines, noGuess: Stats.noGuess);
    usedHint = false;
    hinted = null;
    setState(() {});
  }

  Future<void> _after() async {
    if (board.state == GameState.won || board.state == GameState.lost) {
      final win = board.state == GameState.won;
      if (win) HapticFeedback.mediumImpact();
      final best = await Stats.record(widget.level.id == 'custom' ? 'custom' : widget.level.id, win, board.elapsed.inMilliseconds,
          counts: !usedHint && widget.level.id != 'custom');
      if (!mounted) return;
      setState(() {});
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(win ? (best ? 'Новый рекорд!' : 'Победа!') : 'Мина!', style: W.h2),
          content: Text(
            win
                ? 'Время: ${fmtTime(board.elapsed.inMilliseconds)}${usedHint ? '\n(с подсказкой — рекорд не засчитан)' : ''}'
                : 'Не повезло. Попробуй ещё раз — первая клетка всегда безопасна.',
            style: W.body,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Посмотреть поле')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _new();
              },
              child: const Text('Ещё раз'),
            ),
          ],
        ),
      );
    }
  }

  void _tap(int i) {
    hinted = null;
    final changed = flagMode && !board.cells[i].open ? board.toggleFlag(i) : board.reveal(i);
    if (changed) {
      setState(() {});
      _after();
    }
  }

  void _flag(int i) {
    hinted = null;
    if (board.cells[i].open) {
      if (board.chord(i)) {
        setState(() {});
        _after();
      }
      return;
    }
    if (board.toggleFlag(i)) {
      HapticFeedback.selectionClick();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = board;
    final face = switch (b.state) {
      GameState.won => '😎',
      GameState.lost => '😵',
      _ => '🙂',
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.level.name),
        actions: [
          IconButton(
            tooltip: 'Подсказка',
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: b.state != GameState.playing
                ? null
                : () {
                    final h = b.hint();
                    if (h == null) {
                      toast(context, 'Сначала открой клетку');
                      return;
                    }
                    usedHint = true;
                    setState(() => hinted = h);
                  },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(children: [
              _counter(Icons.flag, '${b.minesLeft}'),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _new,
                child: Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: W.surface2, border: Border.all(color: W.border)),
                  child: Text(face, style: const TextStyle(fontSize: 24)),
                ),
              ),
              const Spacer(),
              _counter(Icons.timer_outlined, fmtTime(b.time.inMilliseconds).split('.').first),
            ]),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, box) {
              final fit = ((box.maxWidth - 16) / b.w).clamp(0.0, (box.maxHeight - 16) / b.h);
              final cell = Stats.bigCells ? fit.clamp(34.0, 64.0) : fit.clamp(18.0, 56.0);
              final boardW = cell * b.w, boardH = cell * b.h;
              final grid = SizedBox(
                width: boardW,
                height: boardH,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: b.w),
                  itemCount: b.w * b.h,
                  itemBuilder: (_, i) => GestureDetector(
                    onTap: () => _tap(i),
                    onLongPress: () => _flag(i),
                    onSecondaryTap: () => _flag(i),
                    child: MineCellView(cell: b.cells[i], size: cell, exploded: b.exploded == i, hinted: hinted == i, lost: b.state == GameState.lost),
                  ),
                ),
              );
              return InteractiveViewer(
                transformationController: viewer,
                constrained: false,
                minScale: 0.5,
                maxScale: 3,
                boundaryMargin: const EdgeInsets.all(200),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: ((box.maxWidth - boardW) / 2).clamp(8.0, double.infinity),
                    vertical: ((box.maxHeight - boardH) / 2).clamp(8.0, double.infinity),
                  ),
                  child: grid,
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, icon: Icon(Icons.touch_app_outlined), label: Text('Открывать')),
                ButtonSegment(value: true, icon: Icon(Icons.flag_outlined), label: Text('Флажок')),
              ],
              selected: {flagMode},
              onSelectionChanged: (s) => setState(() => flagMode = s.first),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _counter(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: W.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: W.border)),
        child: Row(children: [
          Icon(icon, size: 18, color: W.accent),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: W.text, fontFeatures: [FontFeature.tabularFigures()])),
        ]),
      );
}

const _numColors = [
  Colors.transparent,
  Color(0xFF7FD8FF),
  Color(0xFF5EE6A8),
  Color(0xFFFF6B8A),
  Color(0xFFB79CFF),
  Color(0xFFFFA25E),
  Color(0xFF4FE3E3),
  Color(0xFFEAF2FF),
  Color(0xFF8A9BB8),
];

class MineCellView extends StatelessWidget {
  final Cell cell;
  final double size;
  final bool exploded, hinted, lost;
  const MineCellView({super.key, required this.cell, required this.size, required this.exploded, required this.hinted, required this.lost});

  @override
  Widget build(BuildContext context) {
    final c = cell;
    Widget? child;
    BoxDecoration deco;
    if (!c.open) {
      deco = BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hinted ? [const Color(0xFF2E6B4F), const Color(0xFF1B4A36)] : [const Color(0xFF2B4472), const Color(0xFF1A2C4E)],
        ),
        border: Border.all(color: hinted ? W.good : const Color(0xFF3A5A8F), width: hinted ? 2 : 1),
      );
      if (c.flag) {
        final wrong = lost && !c.mine;
        child = Icon(wrong ? Icons.close : Icons.flag, size: size * 0.55, color: wrong ? W.bad : W.warn);
      }
    } else {
      deco = BoxDecoration(
        color: exploded ? W.bad.withValues(alpha: 0.6) : const Color(0xFF0E172B),
        borderRadius: BorderRadius.circular(size * 0.1),
        border: Border.all(color: const Color(0xFF1A2742)),
      );
      if (c.mine) {
        child = _MineIcon(size: size * 0.6);
      } else if (c.n > 0) {
        child = Text('${c.n}', style: TextStyle(fontSize: size * 0.55, fontWeight: FontWeight.w800, color: _numColors[c.n]));
      }
    }
    return Container(
      margin: EdgeInsets.all(size * 0.04),
      alignment: Alignment.center,
      decoration: deco,
      child: child,
    );
  }
}

/// Мина — ледяной шарик с шипами.
class _MineIcon extends StatelessWidget {
  final double size;
  const _MineIcon({required this.size});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _MinePainter());
}

class _MinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width * 0.3;
    final p = Paint()
      ..color = const Color(0xFFEAF2FF)
      ..strokeWidth = s.width * 0.09
      ..strokeCap = StrokeCap.round;
    for (var k = 0; k < 4; k++) {
      final a = k * 3.14159 / 4;
      final d = Offset(r * 1.55 * cosA(a), r * 1.55 * sinA(a));
      canvas.drawLine(c - d, c + d, p);
    }
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF0A1020));
    canvas.drawCircle(c, r, Paint()
      ..color = const Color(0xFF7FD8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s.width * 0.08);
    canvas.drawCircle(c - Offset(r * 0.35, r * 0.35), r * 0.22, Paint()..color = const Color(0xFFEAF2FF));
  }

  double cosA(double a) => _cos[(a * 4 / 3.14159).round() % 8];
  double sinA(double a) => _cos[((a * 4 / 3.14159).round() + 6) % 8];
  static const _cos = [1.0, 0.7071, 0.0, -0.7071, -1.0, -0.7071, 0.0, 0.7071];

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
