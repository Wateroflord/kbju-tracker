import 'dart:async';

import 'package:flutter/material.dart';

import '../arc/arc_service.dart';
import '../kbju_app.dart';
import '../plugins/common/ui.dart';
import '../plugins/shell.dart';
import '../screens/arc_screen.dart';
import 'games_service.dart';

/// Лобби игр с друзьями: приглашения, идущие партии, история.
/// Общее для шахмат и сапёра — отличается только тем, как создать и открыть партию.
class FriendsLobby extends StatefulWidget {
  final String kind; // chess / mines
  final String title;
  final String about;

  /// Настройки новой партии (уровень, цвет…). null — отмена.
  final Future<Map<String, dynamic>?> Function(BuildContext context) newState;

  /// Экран партии.
  final Widget Function(GameRec g) open;

  /// Строка о партии в списке («твой ход», «Профи»…).
  final String Function(GameRec g, String me) describe;

  const FriendsLobby({
    super.key,
    required this.kind,
    required this.title,
    required this.about,
    required this.newState,
    required this.open,
    required this.describe,
  });

  @override
  State<FriendsLobby> createState() => _FriendsLobbyState();
}

class _FriendsLobbyState extends State<FriendsLobby> {
  final svc = GamesService.I;
  List<GameRec> active = [], history = [];
  String? error;
  bool loading = true, supported = true, busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    ArcService.I.addListener(_arc);
    _load();
    _poll = Timer.periodic(const Duration(seconds: 6), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    ArcService.I.removeListener(_arc);
    super.dispose();
  }

  void _arc() {
    if (mounted) _load();
  }

  Future<void> _load({bool quiet = false}) async {
    if (!svc.connected) {
      if (mounted) setState(() => loading = false);
      return;
    }
    if (!quiet && mounted) setState(() => loading = true);
    try {
      if (!quiet) supported = await svc.serverSupports();
      if (supported) {
        final a = await svc.active(widget.kind);
        final h = quiet ? history : await svc.history(widget.kind);
        active = a;
        history = h;
      }
      error = null;
    } catch (e) {
      if (!quiet) error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _openArc() async {
    await WinterShell.switchTo('kbju');
    for (var i = 0; i < 40 && kbjuNavKey.currentState == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    kbjuNavKey.currentState?.push(MaterialPageRoute(builder: (_) => const ArcScreen()));
  }

  Future<void> _go(GameRec g) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => widget.open(g)));
    _load(quiet: true);
  }

  Future<void> _invite() async {
    List<Friend> friends;
    setState(() => busy = true);
    try {
      friends = await svc.friends();
    } catch (e) {
      if (mounted) toast(context, '$e');
      return;
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!mounted) return;
    final pick = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.7),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(12), children: [
            const Padding(padding: EdgeInsets.fromLTRB(4, 4, 4, 8), child: Text('Кого позвать?', style: W.h2)),
            ListTile(
              leading: Icon(Icons.groups_outlined, color: W.accent),
              title: const Text('Любого друга'),
              subtitle: const Text('Приглашение увидят все — первый, кто примет, играет', style: W.small),
              onTap: () => Navigator.pop(c, ''),
            ),
            for (final f in friends)
              ListTile(
                leading: CircleAvatar(backgroundColor: W.surface2, child: Text(f.name.isEmpty ? '?' : f.name.characters.first.toUpperCase())),
                title: Text(f.name),
                onTap: () => Navigator.pop(c, f.id),
              ),
          ]),
        ),
      ),
    );
    if (pick == null || !mounted) return;
    final state = await widget.newState(context);
    if (state == null || !mounted) return;
    setState(() => busy = true);
    try {
      final g = await svc.create(widget.kind, state, guest: pick.isEmpty ? null : pick);
      if (mounted) await _go(g);
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _accept(GameRec g) async {
    setState(() => busy = true);
    try {
      final j = await svc.join(g.id);
      if (mounted) await _go(j);
    } catch (e) {
      if (mounted) toast(context, '$e');
      _load(quiet: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cancel(GameRec g) async {
    try {
      await svc.delete(g.id);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    _load(quiet: true);
  }

  @override
  Widget build(BuildContext context) {
    final me = svc.me;
    final invitesToMe = active.where((g) => g.open && !g.isHost(me)).toList();
    final myInvites = active.where((g) => g.open && g.isHost(me)).toList();
    final playing = active.where((g) => g.playing && g.mine(me)).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title), actions: [
        if (svc.connected) IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: svc.connected && supported
          ? FloatingActionButton.extended(
              onPressed: busy ? null : _invite,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Позвать друга'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
          Text(widget.about, style: W.small),
          const SizedBox(height: 12),
          if (!svc.connected)
            WCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Нужен вход на сервер друзей', style: W.h2),
                const SizedBox(height: 4),
                const Text('Игры идут через сервер Winter Chat. Войди в Winter Arc в КБЖУ тем же логином и паролем, что в Winter Chat — '
                    'и возвращайся сюда.', style: W.small),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: _openArc, icon: const Icon(Icons.login), label: const Text('Открыть Winter Arc')),
              ]),
            )
          else if (loading && active.isEmpty)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (!supported)
            const WCard(
              child: Text('Сервер Winter Chat пока не умеет игры. Обнови сервер на ноутбуке через Winter Hub — и попробуй снова.', style: W.body),
            )
          else ...[
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: WCard(borderColor: W.bad, child: Text(error!, style: W.body)),
              ),
            Text('Ты: ${svc.myName}', style: W.small),
            if (invitesToMe.isNotEmpty) ...[
              const Section('Тебя зовут'),
              for (final g in invitesToMe)
                _row(
                  g,
                  '${g.hostName} зовёт сыграть',
                  widget.describe(g, me),
                  FilledButton(onPressed: busy ? null : () => _accept(g), child: const Text('Принять')),
                  highlight: true,
                ),
            ],
            if (playing.isNotEmpty) ...[
              const Section('Идут'),
              for (final g in playing)
                _row(g, 'С ${g.opponentName(me)}', widget.describe(g, me), const Icon(Icons.chevron_right, color: W.muted), onTap: () => _go(g)),
            ],
            if (myInvites.isNotEmpty) ...[
              const Section('Ждут ответа'),
              for (final g in myInvites)
                _row(
                  g,
                  g.guest.isEmpty ? 'Любой друг' : g.guestName,
                  widget.describe(g, me),
                  TextButton(onPressed: () => _cancel(g), child: const Text('Отменить')),
                  onTap: () => _go(g),
                ),
            ],
            if (invitesToMe.isEmpty && playing.isEmpty && myInvites.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('Пока партий нет — позови друга кнопкой внизу.', style: W.small, textAlign: TextAlign.center)),
              ),
            if (history.isNotEmpty) ...[
              const Section('Сыграно'),
              for (final g in history.take(10))
                _row(g, 'С ${g.opponentName(me).isEmpty ? '—' : g.opponentName(me)}', _resultText(g, me), null),
            ],
          ],
        ]),
      ),
    );
  }

  String _resultText(GameRec g, String me) {
    if (g.result == 'abandoned' && g.winner.isEmpty) return 'Брошена';
    if (g.winner.isEmpty) return 'Ничья';
    return g.winner == me ? 'Победа 🏆' : 'Поражение';
  }

  Widget _row(GameRec g, String title, String sub, Widget? trailing, {VoidCallback? onTap, bool highlight = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: WCard(
          onTap: onTap,
          borderColor: highlight ? W.accent : null,
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: W.body.copyWith(fontWeight: FontWeight.w700)),
                if (sub.isNotEmpty) Text(sub, style: W.small),
              ]),
            ),
            if (trailing != null) trailing,
          ]),
        ),
      );
}
