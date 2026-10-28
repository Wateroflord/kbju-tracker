import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../life/notifications.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../i18n/i18n.dart';

String fmtHm(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return '$h:${two(m)}';
}

String fmtClock(DateTime t) => '${two(t.hour)}:${two(t.minute)}';

/// Фаза голодания (примерно, для мотивации).
String fastPhase(double h) {
  if (h < 4) return tr('Еда переваривается');
  if (h < 12) return tr('Сахар в крови снижается');
  if (h < 16) return tr('Запасы гликогена уменьшаются');
  if (h < 24) return tr('Организм активнее использует жир');
  return tr('Долгое голодание — не увлекайся без врача');
}

/// Мини-карточка для вкладки «Питание».
class FastingMiniCard extends StatefulWidget {
  const FastingMiniCard({super.key});

  @override
  State<FastingMiniCard> createState() => _FastingMiniCardState();
}

class _FastingMiniCardState extends State<FastingMiniCard> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = StoreScope.of(context).food;
    final on = f.fasting;
    final el = on ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(f.fastStart)) : Duration.zero;
    final ratio = on ? el.inMinutes / (f.fastGoalH * 60) : 0.0;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FastingScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 18, color: on ? AppColors.accent : AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(tr('Голодание'), style: Txt.section, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(on ? fmtHm(el) : '${f.fastGoalH}:${24 - f.fastGoalH}',
              style: Txt.num(20, color: on ? AppColors.accent : AppColors.text)),
          const SizedBox(height: 2),
          Text(on ? trf('из {0} ч', [f.fastGoalH]) : tr('не запущено'), style: Txt.small),
          const SizedBox(height: 8),
          ProgressLine(ratio: ratio, color: AppColors.accent, overIsBad: false, height: 4),
        ],
      ),
    );
  }
}

class FastingScreen extends StatefulWidget {
  const FastingScreen({super.key});

  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _start(AppStore store, {bool pickTime = false}) async {
    int? at;
    if (pickTime) {
      final now = DateTime.now();
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: (now.hour + 22) % 24, minute: 0),
        helpText: tr('Когда был последний приём пищи?'),
      );
      if (t == null) return;
      var d = DateTime(now.year, now.month, now.day, t.hour, t.minute);
      if (d.isAfter(now)) d = d.subtract(const Duration(days: 1));
      at = d.millisecondsSinceEpoch;
    }
    store.food.startFast(at: at);
    await NotificationService.instance.requestPermission();
    await NotificationService.instance.syncFasting(store);
  }

  Future<void> _stop(AppStore store) async {
    final e = store.food.stopFast();
    await NotificationService.instance.syncFasting(store);
    if (!mounted) return;
    if (e == null) {
      showToast(context, tr('Голодание меньше 30 минут не сохраняется'));
    } else {
      showToast(context, e.reached ? trf('Отлично! {0} ч без еды', [fmt1(e.hours)]) : trf('Записано: {0} ч', [fmt1(e.hours)]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final f = store.food;
    final on = f.fasting;
    final start = DateTime.fromMillisecondsSinceEpoch(f.fastStart);
    final el = on ? DateTime.now().difference(start) : Duration.zero;
    final hours = el.inSeconds / 3600;
    final ratio = hours / f.fastGoalH;
    final end = start.add(Duration(hours: f.fastGoalH));
    final history = [...f.fasts]..sort((a, b) => b.start.compareTo(a.start));
    final reached = f.fasts.where((x) => x.reached).length;
    final avg = f.fasts.isEmpty ? 0.0 : f.fasts.map((x) => x.hours).reduce((a, b) => a + b) / f.fasts.length;
    final longest = f.fasts.isEmpty ? 0.0 : f.fasts.map((x) => x.hours).reduce(math.max);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Интервальное голодание')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          AppCard(
            child: Column(
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CustomPaint(
                    painter: RingPainter(progress: ratio, color: AppColors.accent, stroke: 14),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(on ? tr('ПРОШЛО') : tr('ЦЕЛЬ'), style: Txt.label),
                          const SizedBox(height: 4),
                          Text(
                            on
                                ? '${fmtHm(el)}:${two(el.inSeconds % 60)}'
                                : trf('{0} ч', [f.fastGoalH]),
                            style: Txt.num(34),
                          ),
                          const SizedBox(height: 4),
                          Text(on ? trf('из {0} ч · {1}%', [f.fastGoalH, (ratio * 100).round()]) : trf('окно еды {0} ч', [24 - f.fastGoalH]),
                              style: Txt.small),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (on) ...[
                  Text(fastPhase(hours), style: Txt.body.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(
                    trf('Начало {0} · окончание {1}{2}', [
                      fmtClock(start),
                      fmtClock(end),
                      sameDay(end, DateTime.now()) ? '' : tr(' (завтра)'),
                    ]),
                    style: Txt.small,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      GhostButton(tr('Отменить'), icon: Icons.close, color: AppColors.muted, onPressed: () async {
                        final ok = await confirm(context, tr('Отменить голодание?'), tr('Запись не сохранится.'), ok: tr('Отменить'));
                        if (ok) {
                          f.cancelFast();
                          await NotificationService.instance.syncFasting(store);
                        }
                      }),
                      const SizedBox(width: 10),
                      Expanded(child: PrimaryButton(tr('Завершить — поел'), icon: Icons.restaurant, onPressed: () => _stop(store))),
                    ],
                  ),
                ] else ...[
                  PrimaryButton(tr('Начать сейчас'), icon: Icons.play_arrow, onPressed: () => _start(store)),
                  const SizedBox(height: 8),
                  GhostButton(tr('Я уже не ем с …'), icon: Icons.schedule, onPressed: () => _start(store, pickTime: true)),
                ],
              ],
            ),
          ),
          SectionLabel(tr('Схема')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in const [12, 14, 16, 18, 20, 23])
                Pill(
                  '$h:${24 - h}',
                  color: h == f.fastGoalH ? AppColors.accent : AppColors.accent2,
                  onTap: () async {
                    f.setFastGoal(h);
                    await NotificationService.instance.syncFasting(store);
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tr('Первое число — часы без еды, второе — окно, когда можно есть. Начни с 12:12 или 14:10, потом переходи на 16:8. Калории и белок всё равно важнее, чем время.'),
            style: Txt.small,
          ),
          SectionLabel(tr('Статистика')),
          Row(
            children: [
              Expanded(child: StatTile(label: tr('Всего'), value: '${f.fasts.length}', sub: trf('цель — {0}', [reached]))),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: tr('В среднем'), value: fmt1(avg), sub: tr('часов'))),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: tr('Рекорд'), value: fmt1(longest), sub: tr('часов'), color: AppColors.accent)),
            ],
          ),
          if (history.isNotEmpty) SectionLabel(tr('История')),
          for (final e in history.take(20))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                child: Row(
                  children: [
                    Icon(e.reached ? Icons.check_circle : Icons.timelapse, size: 18, color: e.reached ? AppColors.good : AppColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${fmtDate(DateTime.fromMillisecondsSinceEpoch(e.start))}, ${fmtClock(DateTime.fromMillisecondsSinceEpoch(e.start))} → ${fmtClock(DateTime.fromMillisecondsSinceEpoch(e.end))}',
                        style: Txt.small.copyWith(color: AppColors.text),
                      ),
                    ),
                    Text(trf('{0} ч', [fmt1(e.hours)]), style: Txt.num(14)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
                      onPressed: () => f.deleteFast(e.start),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.surface2,
            child: Text(
              tr('Голодание не подходит при беременности и кормлении, диабете, проблемах с ЖКТ и расстройствах пищевого поведения. Если есть сомнения — сначала посоветуйся с врачом. Плохо себя чувствуешь — просто поешь.'),
              style: Txt.small,
            ),
          ),
        ],
      ),
    );
  }
}
