import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/sheets.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  int range = 30; // 0 — всё время
  bool showHistory = false;

  DateTime _from(AppStore store) {
    final now = today();
    if (range > 0) return addDays(now, -(range - 1));
    var first = now;
    for (final e in store.entries) {
      final d = parseKey(e.date);
      if (d.isBefore(first)) first = d;
    }
    for (final k in store.weights.keys) {
      final d = parseKey(k);
      if (d.isBefore(first)) first = d;
    }
    return first;
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final from = _from(store);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
          children: [
            const TabHeader('Прогресс'),
            const SizedBox(height: 14),
            Segmented<int>(
              values: const [7, 30, 90, 0],
              label: (v) => v == 0 ? 'Всё' : '$v дн.',
              selected: range,
              onChanged: (v) => setState(() => range = v),
            ),
            const SizedBox(height: 12),
            _weightCard(store, from),
            const SizedBox(height: 12),
            _complianceCard(store, from),
            const SizedBox(height: 12),
            _goalCard(store),
          ],
        ),
      ),
    );
  }

  // ---------- Вес ----------

  Widget _weightCard(AppStore store, DateTime from) {
    final series = store.weightSeries;
    final fromKey = dkey(from);
    final inRange = series.where((e) => e.key.compareTo(fromKey) >= 0).toList();
    final p = store.profile;
    final current = series.isNotEmpty ? series.last.value : (p?.weightKg ?? 0.0);
    final goal = p?.goal ?? Goal.maintain;
    final target = p?.targetWeightKg;

    double? change;
    if (inRange.length >= 2) change = inRange.last.value - inRange.first.value;

    Color changeColor = AppColors.muted;
    if (change != null && change.abs() >= 0.05) {
      final good = switch (goal) {
        Goal.cut => change < 0,
        Goal.bulk => change > 0,
        Goal.maintain => change.abs() < 1,
      };
      changeColor = good ? AppColors.good : AppColors.over;
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.monitor_weight_outlined, color: AppColors.accent2, size: 20),
              const SizedBox(width: 8),
              const Text('Вес', style: Txt.h2),
              const Spacer(),
              GhostButton('Записать', icon: Icons.add, onPressed: () => _addWeight(store)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmt1(current), style: Txt.num(32)),
              const Text(' кг', style: Txt.small),
              const SizedBox(width: 12),
              if (change != null)
                Pill('${change > 0 ? '+' : change < 0 ? '−' : ''}${fmt1(change.abs())} кг', color: changeColor),
            ],
          ),
          if (target != null && series.isNotEmpty) ...[
            const SizedBox(height: 14),
            _targetProgress(series.first.value, current, target),
          ],
          const SizedBox(height: 16),
          if (inRange.length >= 2)
            LineChart(
              points: [for (final e in inRange) ChartPoint(parseKey(e.key), e.value)],
              color: AppColors.accent2,
              targetY: target,
            )
          else
            Container(
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Записывай вес хотя бы раз в неделю —\nздесь появится график',
                textAlign: TextAlign.center,
                style: Txt.small,
              ),
            ),
          if (series.isNotEmpty) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => showHistory = !showHistory),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(showHistory ? 'Скрыть историю' : 'История взвешиваний',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                    Icon(showHistory ? Icons.expand_less : Icons.expand_more, color: AppColors.accent, size: 18),
                  ],
                ),
              ),
            ),
            if (showHistory)
              for (final e in series.reversed.take(30))
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Text(fmtDate(parseKey(e.key), year: true), style: Txt.small),
                      const Spacer(),
                      Text('${fmt1(e.value)} кг', style: Txt.num(14)),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
                        onPressed: () async {
                          final ok = await confirm(context, 'Удалить запись веса?',
                              '${fmtDate(parseKey(e.key))}: ${fmt1(e.value)} кг', ok: 'Удалить');
                          if (ok) store.deleteWeight(e.key);
                        },
                      ),
                    ],
                  ),
                ),
          ],
        ],
      ),
    );
  }

  Widget _targetProgress(double start, double current, double target) {
    final total = (target - start).abs();
    final done = total < 0.05
        ? 1.0
        : ((target > start ? current - start : start - current) / total).clamp(0.0, 1.0);
    final left = (target - current).abs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Цель ${fmt1(target)} кг', style: Txt.small),
            const Spacer(),
            Text(left < 0.05 ? 'Цель достигнута!' : 'осталось ${fmt1(left)} кг',
                style: Txt.small.copyWith(color: left < 0.05 ? AppColors.good : AppColors.text)),
          ],
        ),
        const SizedBox(height: 8),
        ProgressLine(ratio: done, color: AppColors.accent2, overIsBad: false),
      ],
    );
  }

  Future<void> _addWeight(AppStore store) async {
    final ctrl = TextEditingController(text: fmt1(store.profile?.weightKg ?? 70));
    var date = today();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Записать вес', style: Txt.h2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NumField(ctrl, 'Вес', suffix: 'кг'),
              const SizedBox(height: 10),
              GhostButton(
                sameDay(date, today()) ? 'Сегодня' : fmtDate(date, year: true),
                icon: Icons.event,
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: today(),
                  );
                  if (d != null) setD(() => date = dayOnly(d));
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена', style: TextStyle(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сохранить',
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    final v = parseNum(ctrl.text);
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (saved != true) return;
    if (v == null || v < 25 || v > 350) {
      if (mounted) showToast(context, 'Введи вес от 25 до 350 кг');
      return;
    }
    store.setWeight(dkey(date), v);
    if (mounted) showToast(context, 'Вес записан, нормы обновлены');
  }

  // ---------- Соблюдение норм ----------

  Widget _complianceCard(AppStore store, DateTime from) {
    final now = today();
    final all = store.allTotals();
    final totalDays = daysBetween(from, now) + 1;
    final chartDays = math.min(totalDays, 90);
    final chartFrom = addDays(now, -(chartDays - 1));

    final bars = <BarDatum>[];
    for (var i = 0; i < chartDays; i++) {
      final d = addDays(chartFrom, i);
      final k = dkey(d);
      final t = all[k];
      final tg = store.targetsFor(k).kcal.toDouble();
      final st = store.statusFor(k, t ?? Totals());
      bars.add(BarDatum(d, t?.kcal ?? 0, tg, AppColors.status(st)));
    }

    var logged = 0, good = 0;
    double sk = 0, sp = 0, sf = 0, sc = 0;
    double tk = 0, tp = 0, tf = 0, tc = 0;
    for (var i = 0; i < totalDays; i++) {
      final k = dkey(addDays(from, i));
      final t = all[k];
      if (t == null || t.count == 0) continue;
      final tg = store.targetsFor(k);
      logged++;
      sk += t.kcal;
      sp += t.protein;
      sf += t.fat;
      sc += t.carbs;
      tk += tg.kcal;
      tp += tg.protein;
      tf += tg.fat;
      tc += tg.carbs;
      if (store.statusFor(k, t) == DayStatus.good) good++;
    }

    // Серия дней подряд в норме
    var streak = 0;
    var d = now;
    if ((all[dkey(d)]?.count ?? 0) == 0) d = addDays(d, -1);
    while (true) {
      final k = dkey(d);
      if (store.statusFor(k, all[k] ?? Totals()) != DayStatus.good) break;
      streak++;
      d = addDays(d, -1);
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.insights, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text('Соблюдение норм', style: Txt.h2),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            chartDays < totalDays
                ? 'Калории по дням (последние $chartDays дн.). Белая черта — норма'
                : 'Калории по дням. Белая черта — норма',
            style: Txt.small,
          ),
          const SizedBox(height: 14),
          BarChart(data: bars),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: StatTile(label: 'Дней с записями', value: '$logged', sub: 'из $totalDays')),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'В норме ±10%',
                  value: logged > 0 ? '${(good * 100 / logged).round()}%' : '—',
                  sub: '$good дн.',
                  color: AppColors.good,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: 'Серия',
                  value: '$streak',
                  sub: 'дн. подряд',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          if (logged > 0) ...[
            const SizedBox(height: 16),
            const Text('СРЕДНЕЕ ЗА ДЕНЬ', style: Txt.label),
            const SizedBox(height: 12),
            MacroBar(label: 'Калории', value: sk / logged, target: (tk / logged).round(), color: AppColors.accent, unit: 'ккал'),
            const SizedBox(height: 12),
            MacroBar(label: 'Белки', value: sp / logged, target: (tp / logged).round(), color: AppColors.protein),
            const SizedBox(height: 12),
            MacroBar(label: 'Жиры', value: sf / logged, target: (tf / logged).round(), color: AppColors.fat),
            const SizedBox(height: 12),
            MacroBar(label: 'Углеводы', value: sc / logged, target: (tc / logged).round(), color: AppColors.carbs),
          ],
        ],
      ),
    );
  }

  // ---------- Программа ----------

  Widget _goalCard(AppStore store) {
    final goal = store.profile?.goal ?? Goal.maintain;
    final since = store.goalSince;
    final t = store.currentTargets;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(goal.icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Программа', style: Txt.h2)),
              GhostButton('Изменить', icon: Icons.swap_horiz, onPressed: () => showGoalSheet(context)),
            ],
          ),
          const SizedBox(height: 12),
          Text(goal.title, style: Txt.num(22, color: AppColors.accent)),
          const SizedBox(height: 4),
          Text(
            since != null ? 'с ${fmtDate(parseKey(since), year: true)} · ${goal.desc}' : goal.desc,
            style: Txt.small,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill('${fmtInt(t.kcal)} ккал'),
              Pill('Б ${t.protein} г', color: AppColors.protein),
              Pill('Ж ${t.fat} г', color: AppColors.fat),
              Pill('У ${t.carbs} г', color: AppColors.carbs),
            ],
          ),
          if (store.goalHistory.length > 1) ...[
            const SizedBox(height: 16),
            const Text('ИСТОРИЯ ИЗМЕНЕНИЙ', style: Txt.label),
            const SizedBox(height: 8),
            for (final g in store.goalHistory.reversed.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Dot(AppColors.accent2, size: 6),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        g.from == null ? 'Старт: ${g.to.title}' : '${g.from!.title} → ${g.to.title}',
                        style: Txt.body.copyWith(fontSize: 13),
                      ),
                    ),
                    Text(fmtDate(parseKey(g.date), year: true), style: Txt.small),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
