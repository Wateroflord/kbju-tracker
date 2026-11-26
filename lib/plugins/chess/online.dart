import 'dart:async';

import 'package:chess/chess.dart' as ch;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../games/games_service.dart';
import '../../games/lobby.dart';
import '../common/ui.dart';
import 'app.dart' show Store;
import 'board.dart';

/// Лобби шахмат с друзьями.
class OnlineChessLobby extends StatelessWidget {
  const OnlineChessLobby({super.key});

  @override
  Widget build(BuildContext context) => FriendsLobby(
        kind: 'chess',
        title: 'С другом по сети',
        about: 'Партия идёт через сервер Winter Chat: ходи, когда удобно — можно закрыть приложение и вернуться. '
            'Новый ход друга появится сам.',
        newState: _newState,
        open: (g) => OnlineChessScreen(game: g),
        describe: (g, me) {
          final moves = (g.state['moves'] as List?)?.length ?? 0;
          if (g.open) return g.isHost(me) ? 'Ждём, пока друг примет' : 'Ты будешь за ${_myColor(g, me) == ch.Color.WHITE ? 'белых' : 'чёрных'}';
          final myTurn = _turnOf(moves) == _myColor(g, me);
          return '${moves ~/ 2 + 1}-й ход · ${myTurn ? 'твой ход ♟' : 'ход друга'}';
        },
      );

  static Future<Map<String, dynamic>?> _newState(BuildContext context) => showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        builder: (c) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Чем играешь?', style: W.h2),
              const SizedBox(height: 12),
              for (final (label, white) in [('Белыми — хожу первым', true), ('Чёрными', false), ('Случайно', null)])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(c, {
                      'hostWhite': white ?? DateTime.now().microsecond.isEven,
                      'moves': <String>[],
                    }),
                    child: Text(label),
                  ),
                ),
            ]),
          ),
        ),
      );
}

ch.Color _turnOf(int moves) => moves.isEven ? ch.Color.WHITE : ch.Color.BLACK;

ch.Color _myColor(GameRec g, String me) {
  final hostWhite = g.state['hostWhite'] != false;
  return (g.isHost(me) == hostWhite) ? ch.Color.WHITE : ch.Color.BLACK;
}

class OnlineChessScreen extends StatefulWidget {
  final GameRec game;
  const OnlineChessScreen({super.key, required this.game});

  @override
  State<OnlineChessScreen> createState() => _OnlineChessScreenState();
}

class _OnlineChessScreenState extends State<OnlineChessScreen> with WidgetsBindingObserver {
  final svc = GamesService.I;
  late GameRec g = widget.game;
  ch.Chess board = ch.Chess();
  List<String> moves = [];
  bool sending = false, saved = false;
  String? error;
  Timer? _poll;

  String get me => svc.me;
  ch.Color get myColor => _myColor(g, me);
  bool get myTurn => g.playing && board.turn == myColor;
  String get opponent => g.opponentName(me).isEmpty ? 'друг' : g.opponentName(me);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _apply(g);
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  void _apply(GameRec next) {
    final wasMyTurn = myTurn;
    final list = [for (final m in (next.state['moves'] as List? ?? const [])) '$m'];
    final b = ch.Chess();
    for (final m in list) {
      if (!playUci(b, m)) break;
    }
    final oldSeq = g.seq;
    g = next;
    moves = list;
    board = b;
    if (next.seq != oldSeq && !wasMyTurn && myTurn) HapticFeedback.mediumImpact();
    if (g.done) _save();
  }

  Future<void> _refresh() async {
    if (sending || g.done) return;
    try {
      final next = await svc.get(g.id);
      if (!mounted) return;
      if (next.seq != g.seq || next.status != g.status) setState(() => _apply(next));
      if (error != null) setState(() => error = null);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  Future<void> _send(Map<String, dynamic> body) async {
    setState(() => sending = true);
    try {
      final next = await svc.update(g, body);
      if (mounted) setState(() => _apply(next));
    } on GamesError catch (e) {
      if (mounted) toast(context, e.message);
      sending = false;
      await _refresh();
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Map<String, dynamic> _state(List<String> m, {bool keepOffer = false}) => {
        'hostWhite': g.state['hostWhite'] != false,
        'moves': m,
        if (keepOffer && g.state['drawOffer'] != null) 'drawOffer': g.state['drawOffer'],
      };

  void _onMove(String uci) {
    if (!myTurn || sending) return;
    final b = ch.Chess();
    for (final m in moves) {
      playUci(b, m);
    }
    if (!playUci(b, uci)) return;
    final next = [...moves, uci];
    // Сразу показываем ход, сервер подтвердит.
    setState(() {
      board = b;
      moves = next;
    });
    final body = <String, dynamic>{'state': _state(next)};
    if (b.in_checkmate) {
      body.addAll({'status': 'done', 'winner': me, 'result': 'checkmate'});
    } else if (b.in_stalemate) {
      body.addAll({'status': 'done', 'winner': '', 'result': 'stalemate'});
    } else if (b.insufficient_material || b.in_threefold_repetition || b.in_draw) {
      body.addAll({'status': 'done', 'winner': '', 'result': 'draw'});
    }
    _send(body);
  }

  Future<void> _resign() async {
    if (!await confirmDialog(context, 'Сдаться?', 'Победа достанется $opponent.', ok: 'Сдаться')) return;
    final other = g.isHost(me) ? g.guest : g.host;
    await _send({'state': _state(moves), 'status': 'done', 'winner': other, 'result': 'resign'});
  }

  Future<void> _offerDraw() => _send({'state': {..._state(moves), 'drawOffer': me}});

  Future<void> _answerDraw(bool accept) => accept
      ? _send({'state': _state(moves), 'status': 'done', 'winner': '', 'result': 'agreed'})
      : _send({'state': _state(moves)});

  void _save() {
    if (saved || moves.isEmpty) return;
    saved = true;
    final w = g.winner;
    final score = w.isEmpty ? '1/2-1/2' : ((w == g.host) == (g.state['hostWhite'] != false) ? '1-0' : '0-1');
    final b = ch.Chess();
    final sans = <String>[];
    for (final m in moves) {
      sans.add(sanOf(b, m) ?? m);
      playUci(b, m);
    }
    Store.addGame({
      'date': DateTime.now().toIso8601String(),
      'mode': 'friend',
      'level': opponent,
      'player': myColor == ch.Color.WHITE ? 'w' : 'b',
      'moves': moves,
      'sans': sans,
      'result': score,
      'text': _resultText(),
    });
  }

  String _resultText() {
    final w = g.winner;
    final how = switch (g.result) {
      'checkmate' => 'мат',
      'resign' => 'сдался',
      'stalemate' => 'пат',
      'agreed' => 'по согласию',
      'abandoned' => 'партия брошена',
      _ => '',
    };
    if (w.isEmpty) return 'Ничья${how.isEmpty ? '' : ' ($how)'}';
    final iWon = w == me;
    if (g.result == 'resign') return iWon ? 'Победа: $opponent сдался' : 'Ты сдался';
    return iWon ? 'Победа${how.isEmpty ? '' : ': $how'} 🏆' : 'Поражение${how.isEmpty ? '' : ': $how'}';
  }

  @override
  Widget build(BuildContext context) {
    final offer = g.state['drawOffer']?.toString();
    final theyOffer = g.playing && offer != null && offer != me;
    final iOffer = g.playing && offer == me;
    final last = moves.isEmpty ? null : moves.last;
    final status = g.open
        ? (g.isHost(me) ? 'Ждём, пока ${g.guest.isEmpty ? 'кто-нибудь из друзей' : opponent} примет приглашение…' : 'Приглашение')
        : g.done
            ? _resultText()
            : sending
                ? 'Отправляю ход…'
                : myTurn
                    ? (board.in_check ? 'Твой ход — тебе шах!' : 'Твой ход')
                    : 'Ход $opponent…';

    return Scaffold(
      appBar: AppBar(title: Text(g.open ? 'Шахматы с другом' : 'Против: $opponent')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
              WCard(
                borderColor: myTurn ? W.accent : (g.done ? (g.winner == me ? W.good : W.border) : null),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  if (g.playing && !myTurn && !sending)
                    const Padding(padding: EdgeInsets.only(right: 10), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
                  Expanded(child: Text(status, style: W.h2)),
                  Text(myColor == ch.Color.WHITE ? '⚪ ты белые' : '⚫ ты чёрные', style: W.small),
                ]),
              ),
              if (error != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(error!, style: W.small.copyWith(color: W.bad))),
              const SizedBox(height: 10),
              AspectRatio(
                aspectRatio: 1,
                child: ChessBoard(
                  game: board,
                  flipped: myColor == ch.Color.BLACK,
                  lastMove: last,
                  canMove: (side) => side == myColor && myTurn && !sending,
                  onMove: _onMove,
                ),
              ),
              const SizedBox(height: 10),
              if (theyOffer)
                WCard(
                  borderColor: W.warn,
                  child: Row(children: [
                    Expanded(child: Text('$opponent предлагает ничью', style: W.body)),
                    TextButton(onPressed: sending ? null : () => _answerDraw(false), child: const Text('Нет')),
                    FilledButton(onPressed: sending ? null : () => _answerDraw(true), child: const Text('Принять')),
                  ]),
                ),
              if (g.playing)
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: sending || iOffer || moves.length < 2 ? null : _offerDraw,
                      icon: const Icon(Icons.handshake_outlined),
                      label: Text(iOffer ? 'Ничья предложена' : 'Ничья?'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: sending ? null : _resign,
                      icon: const Icon(Icons.flag_outlined),
                      label: const Text('Сдаться'),
                    ),
                  ),
                ]),
              if (g.done)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Партия сохранена в «Мои партии» — там можно посмотреть разбор от Stockfish.', style: W.small, textAlign: TextAlign.center),
                ),
              if (moves.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(_movesText(), style: W.small),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  String _movesText() {
    final b = ch.Chess();
    final parts = <String>[];
    for (var i = 0; i < moves.length; i++) {
      final san = sanOf(b, moves[i]) ?? moves[i];
      playUci(b, moves[i]);
      parts.add(i.isEven ? '${i ~/ 2 + 1}. $san' : san);
    }
    return parts.join('  ');
  }
}
