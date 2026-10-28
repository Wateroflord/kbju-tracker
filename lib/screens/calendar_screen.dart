import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import 'day_view.dart';
import '../i18n/i18n.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime selected = today();

  void _shift(int n) => setState(() => month = DateTime(month.year, month.month + n, 1));

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.allTotals();
    final now = today();

    final offset = month.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + days + 6) ~/ 7) * 7;

    // Статистика месяца
    var logged = 0, good = 0;
    double sum = 0;
    for (var d = 1; d <= days; d++) {
      final k = dkey(DateTime(month.year, month.month, d));
      final t = all[k];
      if (t == null || t.count == 0) continue;
      logged++;
      sum += t.kcal;
      if (store.statusFor(k, t) == DayStatus.good) good++;
    }

    final canNext = DateTime(month.year, month.month + 1, 1).isBefore(addDays(now, 1));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Календарь')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
          children: [
            AppCard(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left)),
                      Expanded(
                        child: Text(
                          '${monthsNom[month.month - 1]} ${month.year}',
                          textAlign: TextAlign.center,
                          style: Txt.h2,
                        ),
                      ),
                      IconButton(
                        onPressed: canNext ? () => _shift(1) : null,
                        icon: Icon(Icons.chevron_right, color: canNext ? AppColors.text : AppColors.border),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      for (final w in weekdaysShort)
                        Expanded(child: Center(child: Text(w, style: Txt.label.copyWith(fontSize: 10)))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cells,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                      childAspectRatio: 0.9,
                    ),
                    itemBuilder: (_, i) {
                      final dayNum = i - offset + 1;
                      if (dayNum < 1 || dayNum > days) return const SizedBox.shrink();
                      final d = DateTime(month.year, month.month, dayNum);
                      final k = dkey(d);
                      final status = store.statusFor(k, all[k] ?? Totals());
                      return _DayCell(
                        day: dayNum,
                        status: status,
                        isToday: sameDay(d, now),
                        isSelected: sameDay(d, selected),
                        isFuture: d.isAfter(now),
                        onTap: () => setState(() => selected = d),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _Legend(AppColors.good, tr('в норме')),
                      SizedBox(width: 14),
                      _Legend(AppColors.under, tr('недобор')),
                      SizedBox(width: 14),
                      _Legend(AppColors.over, tr('перебор')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StatTile(label: tr('Дней с записями'), value: '$logged')),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: tr('В норме'),
                    value: '$good',
                    sub: logged > 0 ? trf('{0}% дней', [(good * 100 / logged).round()]) : null,
                    color: AppColors.good,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: StatTile(
                    label: tr('Сред. ккал'),
                    value: logged > 0 ? fmtInt(sum / logged) : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _selectedCard(store, all),
          ],
        ),
      ),
    );
  }

  Widget _selectedCard(AppStore store, Map<String, Totals> all) {
    final k = dkey(selected);
    final t = all[k] ?? Totals();
    final tg = store.targetsFor(k);
    final status = store.statusFor(k, t);
    final w = store.weights[k];
    final water = store.waterFor(k);
    final isFuture = selected.isAfter(today());

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${weekdaysFull[selected.weekday - 1]}, ${fmtDate(selected)}',
                  style: Txt.h2,
                ),
              ),
              if (status != DayStatus.none)
                Pill(
                  switch (status) {
                    DayStatus.good => tr('в норме'),
                    DayStatus.under => tr('недобор'),
                    DayStatus.over => tr('перебор'),
                    DayStatus.none => '',
                  },
                  color: AppColors.status(status),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (t.count == 0)
            Text(tr('Нет записей о еде за этот день.'), style: Txt.small)
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtInt(t.kcal), style: Txt.num(26)),
                Text(trf('  / {0} ккал', [fmtInt(tg.kcal)]), style: Txt.small),
              ],
            ),
            const SizedBox(height: 10),
            ProgressLine(ratio: tg.kcal > 0 ? t.kcal / tg.kcal : 0, color: AppColors.accent),
            const SizedBox(height: 14),
            Row(
              children: [
                _mini(tr('Белки'), t.protein, tg.protein, AppColors.protein),
                _mini(tr('Жиры'), t.fat, tg.fat, AppColors.fat),
                _mini(tr('Углеводы'), t.carbs, tg.carbs, AppColors.carbs),
              ],
            ),
          ],
          if (water > 0 || w != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (water > 0) Pill(trf('Вода {0} мл', [fmtInt(water)]), color: AppColors.water, icon: Icons.water_drop_outlined),
                if (w != null) Pill(trf('Вес {0} кг', [fmt1(w)]), color: AppColors.accent2, icon: Icons.monitor_weight_outlined),
              ],
            ),
          ],
          if (!isFuture) ...[
            const SizedBox(height: 16),
            PrimaryButton(
              t.count == 0 ? tr('Добавить еду за этот день') : tr('Открыть день'),
              icon: t.count == 0 ? Icons.add : Icons.open_in_new,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => DayScreen(date: selected)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _mini(String label, double v, int target, Color c) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Dot(c, size: 6), const SizedBox(width: 6), Text(label, style: Txt.small)]),
            const SizedBox(height: 4),
            Text.rich(TextSpan(children: [
              TextSpan(text: '${v.round()}', style: Txt.num(15)),
              TextSpan(text: trf(' / {0} г', [target]), style: Txt.small),
            ])),
          ],
        ),
      );
}

class _DayCell extends StatelessWidget {
  final int day;
  final DayStatus status;
  final bool isToday, isSelected, isFuture;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.status,
    required this.isToday,
    required this.isSelected,
    required this.isFuture,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sc = AppColors.status(status);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surface2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? AppColors.accent
                : isToday
                    ? AppColors.muted
                    : Colors.transparent,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: Txt.num(14,
                  weight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: isFuture ? AppColors.border : AppColors.text),
            ),
            const SizedBox(height: 5),
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: status == DayStatus.none ? Colors.transparent : sc,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend(this.color, this.text);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Dot(color, size: 7), const SizedBox(width: 6), Text(text, style: Txt.small)],
      );
}
