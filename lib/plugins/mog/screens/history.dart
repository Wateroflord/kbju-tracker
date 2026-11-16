import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'rate.dart' show fmtDate;
import 'result.dart';
import '../../common/backup_io.dart';

enum _Filter { all, battles, looks, style, synergy }

extension on _Filter {
  String get title => switch (this) {
        _Filter.all => 'Все',
        _Filter.battles => 'Батлы',
        _Filter.looks => 'Внешность',
        _Filter.style => 'Стиль',
        _Filter.synergy => 'Синергия',
      };
  Kind? get kind => switch (this) {
        _Filter.looks => Kind.looks,
        _Filter.style => Kind.style,
        _Filter.synergy => Kind.synergy,
        _ => null,
      };
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Filter _f = _Filter.all;

  bool _match(HistoryEntry e) => switch (_f) {
        _Filter.all => true,
        _Filter.battles => e.battle,
        _ => !e.battle && e.kind == _f.kind,
      };

  Future<void> _backup(BuildContext context) async {
    final m = ScaffoldMessenger.of(context);
    try {
      final path = await BackupIO.save('mog-battle-${BackupIO.stamp()}.json', Store.I.exportHistory());
      if (path != null) m.showSnackBar(const SnackBar(content: Text('История сохранена')));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('Не удалось сохранить: $e')));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final m = ScaffoldMessenger.of(context);
    try {
      final text = await BackupIO.open();
      if (text == null) return;
      final n = await Store.I.importHistory(text);
      m.showSnackBar(SnackBar(content: Text(n == 0 ? 'Новых записей нет' : 'Восстановлено записей: $n')));
    } on FormatException catch (e) {
      m.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('Не удалось восстановить: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('История'), actions: [
        PopupMenuButton<String>(
          tooltip: 'Резервная копия',
          onSelected: (v) => v == 'save' ? _backup(context) : _restore(context),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'save', child: Text('Сохранить историю в файл')),
            PopupMenuItem(value: 'restore', child: Text('Восстановить из файла')),
          ],
        ),
      ]),
      body: StoreBuilder(builder: (context, s) {
        final items = s.history.where(_match).toList();
        final progress = _f.kind == null ? <HistoryEntry>[] : items.reversed.toList();
        return Column(children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.title),
                      selected: _f == f,
                      onSelected: (_) => setState(() => _f = f),
                      selectedColor: C.gold.withValues(alpha: 0.2),
                      labelStyle: TextStyle(color: _f == f ? C.gold : C.muted, fontWeight: FontWeight.w600),
                      side: const BorderSide(color: C.border),
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('Здесь появятся твои оценки и батлы.',
                          textAlign: TextAlign.center, style: TextStyle(color: C.muted)),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      Narrow(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          if (progress.length >= 2) ...[
                            _ProgressCard(progress),
                            const SizedBox(height: 14),
                          ],
                          for (final e in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Dismissible(
                                key: ValueKey(e.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  decoration: BoxDecoration(
                                    color: C.bad.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, color: C.bad),
                                ),
                                onDismissed: (_) => Store.I.removeHistory(e.id),
                                child: _HistoryTile(e),
                              ),
                            ),
                          const Text('Смахни запись влево, чтобы удалить.',
                              textAlign: TextAlign.center, style: TextStyle(color: C.muted, fontSize: 12)),
                        ]),
                      ),
                    ],
                  ),
          ),
        ]);
      }),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry e;
  const _HistoryTile(this.e);

  @override
  Widget build(BuildContext context) {
    final Widget trailing;
    final String title;
    if (e.battle) {
      final r = e.duel;
      final name = e.opponent.isEmpty ? 'соперник' : e.opponent;
      title = 'Батл · ${e.kind.title}';
      final (res, col) = switch (r.winner) {
        'a' => ('Победа', C.a),
        'b' => ('Поражение', C.b),
        _ => ('Ничья', C.gold),
      };
      trailing = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${fmtScore(r.aScore)} : ${fmtScore(r.bScore)}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        Text(res, style: TextStyle(color: col, fontWeight: FontWeight.w700, fontSize: 12.5)),
        Text('vs $name', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: C.muted, fontSize: 11.5)),
      ]);
    } else {
      final r = e.solo;
      title = e.kind.title;
      trailing = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(fmtScore(r.overall),
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: scoreColor(r.overall))),
        Text(tierName(r.overall), style: const TextStyle(color: C.muted, fontSize: 12)),
      ]);
    }
    return Material(
      color: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: C.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultPage(entry: e))),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            PhotoBox(b64: e.thumbA, width: 48, height: 60, radius: 10, border: e.battle ? C.a : null),
            if (e.battle) ...[
              const SizedBox(width: 6),
              PhotoBox(b64: e.thumbB, width: 48, height: 60, radius: 10, border: C.b),
            ],
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(e.battle ? Icons.local_fire_department_rounded : e.kind.icon, size: 16, color: C.gold),
                  const SizedBox(width: 6),
                  Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 3),
                Text(fmtDate(e.date), style: const TextStyle(color: C.muted, fontSize: 12.5)),
              ]),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 110), child: trailing),
          ]),
        ),
      ),
    );
  }
}

/// График прогресса по одиночным оценкам выбранного типа.
class _ProgressCard extends StatelessWidget {
  final List<HistoryEntry> items; // от старых к новым
  const _ProgressCard(this.items);

  @override
  Widget build(BuildContext context) {
    final scores = items.map((e) => e.solo.overall).toList();
    final diff = scores.last - scores.first;
    final sign = diff > 0 ? '+' : '';
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.show_chart_rounded, color: C.gold, size: 20),
          const SizedBox(width: 8),
          const Expanded(child: Text('Прогресс', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          Text('$sign${diff.toStringAsFixed(1)}',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: diff > 0
                      ? C.good
                      : diff < 0
                          ? C.bad
                          : C.muted)),
        ]),
        const SizedBox(height: 12),
        SizedBox(height: 120, width: double.infinity, child: CustomPaint(painter: _ChartPainter(scores))),
      ]),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<double> v;
  _ChartPainter(this.v);

  @override
  void paint(Canvas canvas, Size size) {
    double lo = v.reduce((a, b) => a < b ? a : b) - 1, hi = v.reduce((a, b) => a > b ? a : b) + 1;
    if (lo < 0) lo = 0;
    if (hi > 10) hi = 10;
    if (hi - lo < 2) hi = (lo + 2).clamp(0, 10).toDouble();
    double y(double s) => size.height - (s - lo) / (hi - lo) * size.height;
    double x(int i) => v.length == 1 ? size.width / 2 : i / (v.length - 1) * size.width;

    final grid = Paint()
      ..color = C.border
      ..strokeWidth = 1;
    for (var s = lo.ceilToDouble(); s <= hi; s += 1) {
      canvas.drawLine(Offset(0, y(s)), Offset(size.width, y(s)), grid);
    }

    final path = Path()..moveTo(x(0), y(v[0]));
    for (var i = 1; i < v.length; i++) {
      path.lineTo(x(i), y(v[i]));
    }
    final fill = Path.from(path)
      ..lineTo(x(v.length - 1), size.height)
      ..lineTo(x(0), size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [C.gold.withValues(alpha: 0.25), C.gold.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = C.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < v.length; i++) {
      canvas.drawCircle(Offset(x(i), y(v[i])), 4, Paint()..color = scoreColor(v[i]));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.v != v;
}
