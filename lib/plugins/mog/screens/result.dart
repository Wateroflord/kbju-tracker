import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ai.dart';
import '../models.dart';
import '../photo.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Что нужно оценить.
class Job {
  final Kind kind;
  final Photo a;
  final Photo? b;
  final String opponent;
  const Job({required this.kind, required this.a, this.b, this.opponent = ''});
  bool get battle => b != null;
}

/// Экран результата: либо запускает оценку ([job]), либо показывает запись из истории ([entry]).
class ResultPage extends StatefulWidget {
  final Job? job;
  final HistoryEntry? entry;
  const ResultPage({super.key, this.job, this.entry});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  HistoryEntry? _entry;
  String? _error;
  bool _refused = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    if (_entry == null && widget.job != null) _run();
  }

  Future<void> _run() async {
    final job = widget.job!;
    final s = Store.I;
    setState(() {
      _error = null;
      _refused = false;
    });
    try {
      final Map<String, dynamic> result;
      if (job.battle) {
        final r = await Ai.rateBattle(
          apiKey: s.effectiveKey,
          model: s.model,
          kind: job.kind,
          tone: s.tone,
          photoA: job.a.full,
          photoB: job.b!.full,
        );
        result = r.toJson();
      } else {
        final r = await Ai.rateSolo(apiKey: s.effectiveKey, model: s.model, kind: job.kind, tone: s.tone, photo: job.a.full);
        result = r.toJson();
      }
      final e = HistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        kind: job.kind,
        battle: job.battle,
        thumbA: job.a.thumbB64,
        thumbB: job.b?.thumbB64,
        opponent: job.opponent.trim(),
        result: result,
      );
      await s.addHistory(e);
      if (mounted) setState(() => _entry = e);
    } on AiRefused catch (e) {
      if (mounted) {
        setState(() {
          _error = e.reason;
          _refused = true;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _entry;
    final kind = e?.kind ?? widget.job!.kind;
    final battle = e?.battle ?? widget.job!.battle;
    return Scaffold(
      appBar: AppBar(
        title: Text(battle ? 'Мог-батл · ${kind.title}' : 'Оценка · ${kind.title}'),
        actions: [
          if (e != null)
            IconButton(
              tooltip: 'Скопировать результат',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: shareText(e)));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Результат скопирован')));
              },
            ),
        ],
      ),
      body: e != null
          ? (e.battle ? BattleView(e) : SoloView(e))
          : _error != null
              ? _ErrorView(message: _error!, refused: _refused, onRetry: _refused ? null : _run)
              : _Loading(job: widget.job!),
    );
  }
}

// ---------------- Загрузка ----------------

class _Loading extends StatefulWidget {
  final Job job;
  const _Loading({required this.job});
  @override
  State<_Loading> createState() => _LoadingState();
}

class _LoadingState extends State<_Loading> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  Timer? _t;
  int _i = 0;

  List<String> get _lines => switch (widget.job.kind) {
        Kind.looks => [
            'Разглядываю черты лица…',
            'Оцениваю кожу и волосы…',
            'Проверяю пропорции и гармонию…',
            'Смотрю на подачу и ракурс…',
            'Подбираю советы…',
          ],
        Kind.style => [
            'Разбираю образ по вещам…',
            'Проверяю сочетание цветов…',
            'Смотрю посадку и силуэт…',
            'Оцениваю обувь и аксессуары…',
            'Подбираю советы…',
          ],
        Kind.synergy => [
            'Определяю цветотип…',
            'Сравниваю одежду с чертами лица…',
            'Проверяю, как вещи сидят по фигуре…',
            'Считаю синергию…',
            'Подбираю советы…',
          ],
      };

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 2300), (_) {
      if (mounted) setState(() => _i = (_i + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.job;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) {
              final s = 1 + _pulse.value * 0.04;
              return Transform.scale(
                scale: s,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  PhotoBox(bytes: j.a.thumb, width: 120, height: 150, border: C.a.withValues(alpha: 0.4 + _pulse.value * 0.6)),
                  if (j.b != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('VS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.gold)),
                    ),
                    PhotoBox(bytes: j.b!.thumb, width: 120, height: 150, border: C.b.withValues(alpha: 0.4 + _pulse.value * 0.6)),
                  ],
                ]),
              );
            },
          ),
          const SizedBox(height: 32),
          const SizedBox(width: 200, child: LinearProgressIndicator(minHeight: 4)),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(_lines[_i], key: ValueKey(_i), style: const TextStyle(fontSize: 16, color: C.muted)),
          ),
          const SizedBox(height: 8),
          const Text('Обычно 10–30 секунд', style: TextStyle(fontSize: 12.5, color: C.muted)),
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final bool refused;
  final VoidCallback? onRetry;
  const _ErrorView({required this.message, required this.refused, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Narrow(
          max: 480,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(refused ? Icons.do_not_disturb_alt_rounded : Icons.error_outline_rounded, size: 56, color: C.warn),
              const SizedBox(height: 16),
              Text(refused ? 'Это фото не получится оценить' : 'Что-то пошло не так',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: C.muted, height: 1.4)),
              const SizedBox(height: 24),
              if (onRetry != null)
                FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Попробовать ещё раз')),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Назад')),
            ]),
          ),
        ),
      );
}

// ---------------- Соло ----------------

class SoloView extends StatelessWidget {
  final HistoryEntry e;
  const SoloView(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final r = e.solo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Narrow(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Panel(
              child: Row(children: [
                PhotoBox(b64: e.thumbA, width: 120, height: 156),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(children: [
                    ScoreRing(score: r.overall, size: 124),
                    const SizedBox(height: 10),
                    Text(tierName(r.overall),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: scoreColor(r.overall))),
                    if (r.potential != null && r.potential! > r.overall) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: C.good.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text('Потенциал: ${fmtScore(r.potential)} ↑',
                            style: const TextStyle(color: C.good, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ]),
                ),
              ]),
            ),
            if (r.summary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Panel(child: Text(r.summary, style: const TextStyle(fontSize: 15, height: 1.45))),
            ],
            if (r.subScores.isNotEmpty) ...[
              const SectionTitle('Три оценки', icon: Icons.auto_awesome),
              Row(children: [
                for (final s in r.subScores) ...[
                  Expanded(
                    child: Panel(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                      child: Column(children: [
                        ScoreRing(score: s.score ?? 0, size: 72),
                        const SizedBox(height: 8),
                        Text(s.name,
                            textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    ),
                  ),
                  if (s != r.subScores.last) const SizedBox(width: 8),
                ],
              ]),
              const SizedBox(height: 10),
              for (final s in r.subScores)
                if (s.comment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: '${s.name}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: s.comment, style: const TextStyle(color: Color(0xFFDCD6E4))),
                    ]), style: const TextStyle(fontSize: 14, height: 1.4)),
                  ),
            ],
            const SectionTitle('Разбор по категориям', icon: Icons.analytics_outlined),
            Panel(
              child: Column(children: [
                for (final c in r.categories) ...[
                  _CategoryRow(c),
                  if (c != r.categories.last) const Divider(height: 26, color: C.border),
                ],
              ]),
            ),
            if (r.strengths.isNotEmpty) ...[
              const SectionTitle('Сильные стороны', icon: Icons.thumb_up_alt_outlined, color: C.good),
              Panel(child: Bullets(r.strengths, icon: Icons.check_circle_rounded, color: C.good)),
            ],
            if (r.weaknesses.isNotEmpty) ...[
              const SectionTitle('Что тянет вниз', icon: Icons.trending_down_rounded, color: C.warn),
              Panel(child: Bullets(r.weaknesses, icon: Icons.arrow_circle_down_rounded, color: C.warn)),
            ],
            if (r.tips.isNotEmpty) ...[
              const SectionTitle('Как стать лучше', icon: Icons.rocket_launch_outlined),
              for (var i = 0; i < r.tips.length; i++) TipCard(r.tips[i], i + 1),
            ],
            if (r.photoNote.isNotEmpty) ...[
              const SectionTitle('Про само фото', icon: Icons.photo_camera_outlined, color: C.muted),
              Panel(child: Text(r.photoNote, style: const TextStyle(color: C.muted, height: 1.4))),
            ],
          ]),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category c;
  const _CategoryRow(this.c);

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
          Text(c.score == null ? 'не видно' : fmtScore(c.score),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: c.score == null ? 13 : 16,
                color: scoreColor(c.score),
              )),
        ]),
        const SizedBox(height: 8),
        ScoreBar(score: c.score),
        if (c.comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(c.comment, style: const TextStyle(color: Color(0xFFCFC8D9), fontSize: 14, height: 1.4)),
        ],
      ]);
}

// ---------------- Батл ----------------

class BattleView extends StatelessWidget {
  final HistoryEntry e;
  const BattleView(this.e, {super.key});

  @override
  Widget build(BuildContext context) {
    final r = e.duel;
    final bName = e.opponent.isEmpty ? 'Соперник' : e.opponent;
    final aWins = r.categories.where((c) => c.winner == 'a').length;
    final bWins = r.categories.where((c) => c.winner == 'b').length;
    final (headline, hColor) = switch (r.winner) {
      'a' => ('Ты могаешь!', C.a),
      'b' => ('$bName могает тебя', C.b),
      _ => ('Ничья', C.gold),
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Narrow(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Panel(
              child: Column(children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _Fighter(name: 'Ты', b64: e.thumbA, score: r.aScore, color: C.a, winner: r.winner == 'a')),
                  const Padding(
                    padding: EdgeInsets.only(top: 70, left: 6, right: 6),
                    child: Text('VS', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: C.gold)),
                  ),
                  Expanded(
                    child: _Fighter(name: bName, b64: e.thumbB, score: r.bScore, color: C.b, winner: r.winner == 'b'),
                  ),
                ]),
                const SizedBox(height: 16),
                Text(headline,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: hColor)),
                const SizedBox(height: 4),
                Text('Категории: $aWins : $bWins',
                    style: const TextStyle(color: C.muted, fontWeight: FontWeight.w600)),
                if (r.verdict.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(r.verdict, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.45)),
                ],
              ]),
            ),
            if (r.aSummary.isNotEmpty || r.bSummary.isNotEmpty) ...[
              const SizedBox(height: 12),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (r.aSummary.isNotEmpty) _who('Ты', C.a, r.aSummary),
                  if (r.aSummary.isNotEmpty && r.bSummary.isNotEmpty) const SizedBox(height: 10),
                  if (r.bSummary.isNotEmpty) _who(bName, C.b, r.bSummary),
                ]),
              ),
            ],
            const SectionTitle('Кто где сильнее', icon: Icons.compare_arrows_rounded),
            Panel(
              child: Column(children: [
                for (final c in r.categories) ...[
                  _DuelRow(c),
                  if (c != r.categories.last) const Divider(height: 28, color: C.border),
                ],
              ]),
            ),
            if (r.aEdges.isNotEmpty) ...[
              const SectionTitle('Где ты лучше', icon: Icons.emoji_events_outlined, color: C.a),
              Panel(child: Bullets(r.aEdges, icon: Icons.check_circle_rounded, color: C.a)),
            ],
            if (r.bEdges.isNotEmpty) ...[
              SectionTitle('Где $bName лучше', icon: Icons.emoji_events_outlined, color: C.b),
              Panel(child: Bullets(r.bEdges, icon: Icons.check_circle_rounded, color: C.b)),
            ],
            if (r.tips.isNotEmpty) ...[
              SectionTitle(r.winner == 'a' ? 'Как оторваться ещё сильнее' : 'Как забрать реванш',
                  icon: Icons.rocket_launch_outlined),
              for (var i = 0; i < r.tips.length; i++) TipCard(r.tips[i], i + 1),
            ],
            if (r.photoNote.isNotEmpty) ...[
              const SectionTitle('Про сами фото', icon: Icons.photo_camera_outlined, color: C.muted),
              Panel(child: Text(r.photoNote, style: const TextStyle(color: C.muted, height: 1.4))),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _who(String name, Color color, String text) => Text.rich(
        TextSpan(children: [
          TextSpan(text: '$name: ', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
          TextSpan(text: text),
        ]),
        style: const TextStyle(fontSize: 14.5, height: 1.4),
      );
}

class _Fighter extends StatelessWidget {
  final String name;
  final String? b64;
  final double score;
  final Color color;
  final bool winner;
  const _Fighter({required this.name, required this.b64, required this.score, required this.color, required this.winner});

  @override
  Widget build(BuildContext context) => Column(children: [
        Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: [
          AspectRatio(aspectRatio: 0.78, child: PhotoBox(b64: b64, border: winner ? color : C.border)),
          if (winner)
            Positioned(
              top: -14,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle),
                child: const Icon(Icons.workspace_premium_rounded, size: 20, color: Color(0xFF1A1206)),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 15)),
        const SizedBox(height: 2),
        Text(fmtScore(score), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: scoreColor(score))),
      ]);
}

class _DuelRow extends StatelessWidget {
  final DuelCategory c;
  const _DuelRow(this.c);

  @override
  Widget build(BuildContext context) {
    final aw = c.winner == 'a', bw = c.winner == 'b';
    TextStyle numStyle(bool win, Color col) => TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: win ? 17 : 15,
          color: win ? col : C.muted,
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        SizedBox(width: 40, child: Text(c.a == null ? '—' : fmtScore(c.a), style: numStyle(aw, C.a))),
        Expanded(
          child: Text(c.name,
              textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
        ),
        SizedBox(
          width: 40,
          child: Text(c.b == null ? '—' : fmtScore(c.b), textAlign: TextAlign.right, style: numStyle(bw, C.b)),
        ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: ScoreBar(score: c.a, color: aw ? C.a : C.a.withValues(alpha: 0.45), reverse: true)),
        Container(
          width: 22,
          alignment: Alignment.center,
          child: Icon(
            aw
                ? Icons.chevron_left_rounded
                : bw
                    ? Icons.chevron_right_rounded
                    : Icons.drag_handle_rounded,
            size: 18,
            color: aw
                ? C.a
                : bw
                    ? C.b
                    : C.gold,
          ),
        ),
        Expanded(child: ScoreBar(score: c.b, color: bw ? C.b : C.b.withValues(alpha: 0.45))),
      ]),
      if (c.comment.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(c.comment, style: const TextStyle(color: Color(0xFFCFC8D9), fontSize: 14, height: 1.4)),
      ],
    ]);
  }
}

// ---------------- Текст для копирования ----------------

String shareText(HistoryEntry e) {
  final b = StringBuffer();
  if (e.battle) {
    final r = e.duel;
    final bName = e.opponent.isEmpty ? 'Соперник' : e.opponent;
    b.writeln('Mog Battle · ${e.kind.title}');
    b.writeln('Ты ${fmtScore(r.aScore)} : ${fmtScore(r.bScore)} $bName');
    if (r.verdict.isNotEmpty) b.writeln(r.verdict);
    b.writeln();
    for (final c in r.categories) {
      b.writeln('${c.name}: ${fmtScore(c.a)} vs ${fmtScore(c.b)}${c.comment.isNotEmpty ? ' — ${c.comment}' : ''}');
    }
    if (r.tips.isNotEmpty) {
      b.writeln();
      b.writeln('Советы:');
      for (final t in r.tips) {
        b.writeln('• ${t.title}: ${t.text}');
      }
    }
  } else {
    final r = e.solo;
    b.writeln('Mog Battle · ${e.kind.title}: ${fmtScore(r.overall)}/10 (${tierName(r.overall)})');
    if (r.potential != null) b.writeln('Потенциал: ${fmtScore(r.potential)}');
    if (r.summary.isNotEmpty) b.writeln(r.summary);
    b.writeln();
    for (final c in [...r.subScores, ...r.categories]) {
      b.writeln('${c.name}: ${fmtScore(c.score)}${c.comment.isNotEmpty ? ' — ${c.comment}' : ''}');
    }
    if (r.tips.isNotEmpty) {
      b.writeln();
      b.writeln('Как стать лучше:');
      for (final t in r.tips) {
        b.writeln('• ${t.title}: ${t.text}');
      }
    }
  }
  return b.toString().trim();
}
