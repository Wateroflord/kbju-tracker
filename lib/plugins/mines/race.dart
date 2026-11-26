import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../games/games_service.dart';
import '../../games/lobby.dart';
import '../common/ui.dart';
import 'app.dart' show MineCellView, Stats, fmtTime;
import 'game.dart';

Level _level(GameRec g) => levels.firstWhere((l) => l.id == g.state['level'], orElse: () => levels.first);

/// Лобби гонки в сапёр.
class RaceLobby extends StatelessWidget {
  const RaceLobby({super.key});

  @override
  Widget build(BuildContext context) => FriendsLobby(
        kind: 'mines',
        title: 'Гонка с другом',
        about: 'У вас одинаковое поле. Кто первым откроет все клетки — победил. Подорвался — ждёшь, '
            'справится ли друг. Если оба подорвались — выигрывает тот, кто открыл больше.',
        newState: (context) => showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          builder: (c) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Какое поле?', style: W.h2),
                const SizedBox(height: 12),
                for (final l in levels)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(c, {'level': l.id, 'seed': math.Random().nextInt(1 << 30), 'gen': 1}),
                      child: Text('${l.name} — ${l.w}×${l.h}, ${l.mines} мин'),
                    ),
                  ),
              ]),
            ),
          ),
        ),
        open: (g) => RaceScreen(game: g),
        describe: (g, me) {
          final l = _level(g);
          if (g.open) return '${l.name}, ${l.w}×${l.h}';
          final mine = g.myState(me);
          return '${l.name} · ${mine['won'] != null ? 'ты прошёл, ждём друга' : mine['lost'] == true ? 'ты подорвался, ждём друга' : 'идёт'}';
        },
      );
}

class RaceScreen extends StatefulWidget {
  final GameRec game;
  const RaceScreen({super.key, required this.game});

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen> {
  final svc = GamesService.I;
  late GameRec g = widget.game;
  late final Level level = _level(g);
  late Board board = Board(level.w, level.h, level.mines, noGuess: true, seed: (g.state['seed'] as num?)?.toInt() ?? 1);
  Timer? _poll, _tick;
  int? countdown; // 3-2-1 перед стартом
  bool started = false, finished = false, flagMode = false, shownResult = false;
  int _sentOpen = -1;
  DateTime _lastSent = DateTime(2000);
  String? error;

  String get me => svc.me;
  String get opponent => g.opponentName(me).isEmpty ? 'друг' : g.opponentName(me);
  int get myMs => board.time.inMilliseconds;

  @override
  void initState() {
    super.initState();
    // Уже начатую раньше гонку продолжить нельзя (поле в памяти пропало) — засчитываем как проигрыш.
    final mine = g.myState(me);
    if (g.playing && (mine['started'] == true || mine.isNotEmpty)) {
      finished = true;
      if (mine['won'] == null && mine['lost'] != true) _send({...mine, 'lost': true, 'open': mine['open'] ?? 0});
    }
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (started && !finished) {
        _checkSlow();
        if (DateTime.now().difference(_lastSent).inSeconds >= 3 && board.opened != _sentOpen) _progress();
      }
      setState(() {});
    });
    if (g.playing && !finished) _countdown();
    if (g.done) {
      finished = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showResult());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final next = await svc.get(g.id);
      if (!mounted) return;
      final becamePlaying = g.open && next.playing;
      setState(() {
        g = next;
        error = null;
      });
      if (becamePlaying && !finished) _countdown();
      if (g.done) _showResult();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void _countdown() {
    if (countdown != null || started) return;
    setState(() => countdown = 3);
    HapticFeedback.selectionClick();
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (countdown! > 1) {
        HapticFeedback.selectionClick();
        setState(() => countdown = countdown! - 1);
      } else {
        t.cancel();
        HapticFeedback.heavyImpact();
        // Одинаковое начало у обоих: открываем центр поля.
        board.reveal((level.h ~/ 2) * level.w + level.w ~/ 2);
        setState(() {
          countdown = null;
          started = true;
        });
        _progress(extra: {'started': true});
      }
    });
  }

  Future<void> _send(Map<String, dynamic> state) async {
    _lastSent = DateTime.now();
    try {
      final next = await svc.myProgress(g, state);
      if (mounted) setState(() => g = next);
      if (g.done) _showResult();
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  void _progress({Map<String, dynamic> extra = const {}}) {
    _sentOpen = board.opened;
    _send({'started': true, 'open': board.opened, ...extra});
  }

  /// Друг уже прошёл быстрее, чем я успею, — гонка для меня окончена.
  void _checkSlow() {
    final their = g.theirState(me);
    final t = (their['won'] as num?)?.toInt();
    if (t != null && myMs > t && board.state == GameState.playing) {
      finished = true;
      HapticFeedback.mediumImpact();
      _send({'started': true, 'open': board.opened, 'lost': true, 'slow': true});
    }
  }

  void _after() {
    if (board.state == GameState.won) {
      finished = true;
      HapticFeedback.heavyImpact();
      Stats.record(level.id, true, board.elapsed.inMilliseconds, counts: false);
      _send({'started': true, 'open': board.opened, 'won': board.elapsed.inMilliseconds});
    } else if (board.state == GameState.lost) {
      finished = true;
      HapticFeedback.heavyImpact();
      _send({'started': true, 'open': board.opened, 'lost': true});
    }
  }

  void _tap(int i) {
    if (!started || finished) return;
    final changed = flagMode && !board.cells[i].open ? board.toggleFlag(i) : board.reveal(i);
    if (changed) {
      setState(() {});
      _after();
    }
  }

  void _flag(int i) {
    if (!started || finished) return;
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

  Future<void> _showResult() async {
    if (shownResult || !mounted) return;
    shownResult = true;
    final win = g.winner == me;
    final draw = g.winner.isEmpty;
    final their = g.theirState(me);
    final mine = g.myState(me);
    String line(Map<String, dynamic> s) => s['won'] != null
        ? 'прошёл за ${fmtTime((s['won'] as num).toInt())}'
        : 'открыл ${s['open'] ?? 0} из ${board.safeCells}${s['slow'] == true ? '' : ' 💥'}';
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(draw ? 'Ничья 🤝' : (win ? 'Победа! 🏆' : 'Победил $opponent'), style: W.h2),
        content: Text('Ты: ${line(mine)}\n$opponent: ${line(their)}', style: W.body),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
  }

  Future<bool> _confirmLeave() async {
    if (!started || finished || g.done) return true;
    final ok = await confirmDialog(context, 'Сдаться?', 'Если выйти сейчас, гонка будет проиграна.', ok: 'Сдаться');
    if (ok) {
      finished = true;
      await _send({'started': true, 'open': board.opened, 'lost': true});
    }
    return ok;
  }

  Widget _bar(String name, Map<String, dynamic> s, {bool live = false}) {
    final open = live ? board.opened : ((s['open'] as num?)?.toInt() ?? 0);
    final p = (open / board.safeCells).clamp(0.0, 1.0);
    final won = live ? board.state == GameState.won : s['won'] != null;
    final lost = live ? board.state == GameState.lost : s['lost'] == true;
    final tail = won
        ? '🏁 ${fmtTime(live ? board.elapsed.inMilliseconds : (s['won'] as num).toInt())}'
        : lost
            ? (s['slow'] == true ? '⏱' : '💥')
            : '${(p * 100).round()}%';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        SizedBox(width: 90, child: Text(name, style: W.small, overflow: TextOverflow.ellipsis)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: p, minHeight: 8, color: lost ? W.bad : (won ? W.good : W.accent), backgroundColor: W.surface2),
          ),
        ),
        SizedBox(width: 74, child: Text(tail, style: W.small, textAlign: TextAlign.right)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final b = board;
    return PopScope(
      canPop: !started || finished || g.done,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(g.open ? 'Гонка: ждём друга' : 'Гонка с $opponent')),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Column(children: [
                _bar('Ты', g.myState(me), live: started),
                if (!g.open) _bar(opponent, g.theirState(me)),
                Row(children: [
                  Text('🚩 ${b.minesLeft}', style: W.body),
                  const Spacer(),
                  Text('${level.name} · ${level.w}×${level.h}', style: W.small),
                  const Spacer(),
                  Text('⏱ ${fmtTime(b.time.inMilliseconds).split('.').first}', style: W.body),
                ]),
                if (error != null) Text(error!, style: W.small.copyWith(color: W.bad)),
              ]),
            ),
            Expanded(
              child: g.open
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            g.isHost(me)
                                ? 'Ждём, пока ${g.guest.isEmpty ? 'кто-нибудь из друзей' : opponent} примет приглашение. Как только примет — отсчёт 3-2-1 и старт.'
                                : 'Приглашение',
                            style: W.body,
                            textAlign: TextAlign.center,
                          ),
                        ]),
                      ),
                    )
                  : Stack(children: [
                      LayoutBuilder(builder: (context, box) {
                        final fit = ((box.maxWidth - 16) / b.w).clamp(0.0, (box.maxHeight - 16) / b.h);
                        final cell = Stats.bigCells ? fit.clamp(34.0, 64.0) : fit.clamp(18.0, 56.0);
                        final boardW = cell * b.w, boardH = cell * b.h;
                        return InteractiveViewer(
                          constrained: false,
                          minScale: 0.5,
                          maxScale: 3,
                          boundaryMargin: const EdgeInsets.all(200),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: ((box.maxWidth - boardW) / 2).clamp(8.0, double.infinity),
                              vertical: ((box.maxHeight - boardH) / 2).clamp(8.0, double.infinity),
                            ),
                            child: SizedBox(
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
                                  child: MineCellView(
                                    cell: b.cells[i],
                                    size: cell,
                                    exploded: b.exploded == i,
                                    hinted: false,
                                    lost: b.state == GameState.lost,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      if (countdown != null)
                        Positioned.fill(
                          child: ColoredBox(
                            color: const Color(0x99000000),
                            child: Center(child: Text('$countdown', style: const TextStyle(fontSize: 96, fontWeight: FontWeight.w900, color: W.text))),
                          ),
                        ),
                      if (finished && !g.done)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 8,
                          child: WCard(
                            child: Text(
                              board.state == GameState.won ? 'Ты прошёл! Ждём, успеет ли $opponent быстрее…' : 'Для тебя гонка окончена — ждём $opponent…',
                              style: W.body,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ]),
            ),
            if (!g.open)
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
      ),
    );
  }
}
