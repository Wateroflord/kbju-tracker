import 'package:flutter/material.dart';

import '../food/body.dart';
import '../food/food_models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/sheets.dart';
import '../i18n/i18n.dart';

/// Карточка замеров для вкладки «Прогресс».
class MeasuresCard extends StatelessWidget {
  const MeasuresCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final f = store.food;
    final has = f.measures.isNotEmpty;
    final waist = f.measureSeries('waist');
    final fat = bodyFatPercent(store.profile, f.latestMeasure('neck'), f.latestMeasure('waist'), f.latestMeasure('hips'));
    double? waistChange;
    if (waist.length >= 2) waistChange = waist.last.value - waist.first.value;

    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MeasuresScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.straighten, color: AppColors.accent2, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(tr('Замеры тела'), style: Txt.h2)),
              GhostButton(tr('Записать'), icon: Icons.add, onPressed: () => showMeasureSheet(context)),
            ],
          ),
          const SizedBox(height: 12),
          if (!has)
            Text(
              tr('Талия, грудь, бёдра, руки. На сушке вес может стоять, а талия уменьшаться — замеры это покажут. Меряй раз в 1–2 недели утром.'),
              style: Txt.small,
            )
          else
            Row(
              children: [
                Expanded(
                  child: StatTile(
                    label: tr('Талия'),
                    value: waist.isEmpty ? '—' : fmt1(waist.last.value),
                    sub: waistChange == null
                        ? tr('см')
                        : trf('{0}{1} см с начала', [waistChange > 0 ? '+' : waistChange < 0 ? '−' : '', fmt1(waistChange.abs())]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: tr('Жир (оценка)'),
                    value: fat == null ? '—' : '${fmt1(fat)}%',
                    sub: fat == null ? tr('нужны шея и талия') : tr('формула ВМС США'),
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(label: tr('Записей'), value: '${f.measures.length}', sub: tr('замеров')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

Future<void> showMeasureSheet(BuildContext context) =>
    showAppSheet<void>(context, const _MeasureForm());

class _MeasureForm extends StatefulWidget {
  const _MeasureForm();

  @override
  State<_MeasureForm> createState() => _MeasureFormState();
}

class _MeasureFormState extends State<_MeasureForm> {
  final ctrls = {for (final p in measureParts) p: TextEditingController()};
  DateTime date = today();

  @override
  void initState() {
    super.initState();
    _fill();
  }

  void _fill() {
    final cur = StoreScope.read(context).food.measures[dkey(date)];
    for (final p in measureParts) {
      ctrls[p]!.text = cur?[p] == null ? '' : fmt1(cur![p]!);
    }
  }

  @override
  void dispose() {
    for (final c in ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final vals = <String, double>{};
    for (final p in measureParts) {
      final v = parseNum(ctrls[p]!.text);
      if (v != null && v >= 10 && v <= 250) vals[p] = v;
    }
    if (vals.isEmpty) {
      showToast(context, tr('Введи хотя бы один замер в сантиметрах'));
      return;
    }
    StoreScope.read(context).food.setMeasures(dkey(date), vals);
    Navigator.pop(context);
    showToast(context, tr('Замеры сохранены'));
  }

  @override
  Widget build(BuildContext context) {
    final f = StoreScope.read(context).food;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Row(
            children: [
              Expanded(child: Text(tr('Замеры, см'), style: Txt.h2)),
              GhostButton(
                sameDay(date, today()) ? tr('Сегодня') : fmtDate(date),
                icon: Icons.event,
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: today(),
                  );
                  if (d != null) {
                    setState(() {
                      date = dayOnly(d);
                      _fill();
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr('Мерь утром, сантиметровой лентой, не затягивая. Можно заполнить не все поля.'), style: Txt.small),
          const SizedBox(height: 12),
          for (final p in measureParts) ...[
            TextField(
              controller: ctrls[p],
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: Txt.num(15, weight: FontWeight.w600),
              decoration: fieldDeco(
                measureTitle(p),
                suffix: tr('см'),
                hint: f.latestMeasure(p) == null
                    ? measureHint(p)
                    : trf('было {0} · {1}', [fmt1(f.latestMeasure(p)!), measureHint(p)]),
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 6),
          PrimaryButton(tr('Сохранить'), icon: Icons.check, onPressed: _save),
        ],
      ),
    );
  }
}

class MeasuresScreen extends StatefulWidget {
  const MeasuresScreen({super.key});

  @override
  State<MeasuresScreen> createState() => _MeasuresScreenState();
}

class _MeasuresScreenState extends State<MeasuresScreen> {
  String part = 'waist';

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final f = store.food;
    final series = f.measureSeries(part);
    final days = f.measures.keys.toList()..sort((a, b) => b.compareTo(a));
    final fat = bodyFatPercent(store.profile, f.latestMeasure('neck'), f.latestMeasure('waist'), f.latestMeasure('hips'));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Замеры тела')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => showMeasureSheet(context),
        icon: const Icon(Icons.add),
        label: Text(tr('Записать'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in measureParts)
                Pill(measureTitle(p),
                    color: p == part ? AppColors.accent : AppColors.accent2, onTap: () => setState(() => part = p)),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(series.isEmpty ? '—' : fmt1(series.last.value), style: Txt.num(30)),
                    Text(tr(' см'), style: Txt.small),
                    const Spacer(),
                    if (series.length >= 2)
                      Pill(
                        trf('{0}{1} см', [
                          series.last.value - series.first.value > 0 ? '+' : (series.last.value - series.first.value < 0 ? '−' : ''),
                          fmt1((series.last.value - series.first.value).abs()),
                        ]),
                        color: AppColors.accent2,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (series.length >= 2)
                  LineChart(points: [for (final e in series) ChartPoint(parseKey(e.key), e.value)], color: AppColors.accent)
                else
                  Text(tr('Нужно хотя бы два замера, чтобы увидеть график.'), style: Txt.small),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.percent, color: AppColors.accent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fat == null
                        ? tr('Процент жира посчитается, когда будут замеры шеи и талии (для женщин — ещё бёдер).')
                        : trf('Процент жира примерно {0}%. Это оценка по формуле ВМС США: погрешность 3–4%, важнее следить за изменением.',
                            [fmt1(fat)]),
                    style: Txt.small,
                  ),
                ),
              ],
            ),
          ),
          SectionLabel(tr('История')),
          if (days.isEmpty) Text(tr('Пока нет записей.'), style: Txt.small),
          for (final d in days)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fmtDate(parseKey(d), year: true), style: Txt.body.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(
                            [
                              for (final p in measureParts)
                                if (f.measures[d]![p] != null) '${measureTitle(p)} ${fmt1(f.measures[d]![p]!)}',
                            ].join(' · '),
                            style: Txt.small,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
                      onPressed: () async {
                        final ok = await confirm(context, tr('Удалить замеры?'), fmtDate(parseKey(d), year: true), ok: tr('Удалить'));
                        if (ok) f.deleteMeasures(d);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
