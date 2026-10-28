import 'package:flutter/material.dart';

import '../life/content.dart';
import '../life/eval.dart';
import '../life/models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../i18n/i18n.dart';

/// Все привычки: статистика, календарь выполнения, включение/выключение, свои привычки.
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Привычки')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => _addHabit(context),
        icon: const Icon(Icons.add),
        label: Text(tr('Своя привычка'), style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Row(
            children: [
              Expanded(child: StatTile(label: tr('Серия'), value: '${store.dayStreak()}', sub: tr('дней ≥ 80%'), color: AppColors.accent)),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: tr('За 7 дней'), value: '${store.dailyCompletionPercent(7)}%', sub: tr('выполнено'))),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: tr('За 30 дней'), value: '${store.dailyCompletionPercent(30)}%', sub: tr('выполнено'))),
            ],
          ),
          const SizedBox(height: 12),
          _monthGrid(store),
          for (final p in HabitPeriod.values) ...[
            SectionLabel(periodTitle(p)),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final h in store.life.habits.where((h) => h.period == p)) _manageRow(store, h),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            tr('Автоматические привычки отмечаются сами: шаги, еда, вода, сон, тренировки, взвешивание, язык, настроение и дыхание. Остальные отмечай вручную на экране «Сегодня». Новые привычки можно включить переключателем.'),
            style: Txt.small,
          ),
        ],
      ),
    );
  }

  Widget _manageRow(AppStore store, Habit h) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      child: Row(
        children: [
          Icon(habitIcon(h.icon), size: 20, color: h.enabled ? AppColors.accent : AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(h.title), style: Txt.body.copyWith(fontSize: 13.5, color: h.enabled ? AppColors.text : AppColors.muted)),
                if (h.auto != HabitAuto.none)
                  Text(tr('автоматически'), style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          if (!h.builtin)
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.muted),
              onPressed: () async {
                final ok = await confirm(context, tr('Удалить привычку?'), tr(h.title), ok: tr('Удалить'));
                if (ok) store.life.deleteHabit(h.id);
              },
            ),
          Switch(value: h.enabled, onChanged: (v) => store.life.setHabitEnabled(h.id, v)),
        ],
      ),
    );
  }

  Widget _monthGrid(AppStore store) {
    final now = today();
    final offset = month.weekday - 1;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + days + 6) ~/ 7) * 7;
    final canNext = DateTime(month.year, month.month + 1, 1).isBefore(addDays(now, 1));
    return AppCard(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => month = DateTime(month.year, month.month - 1, 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text('${monthsNom[month.month - 1]} ${month.year}',
                    textAlign: TextAlign.center, style: Txt.section),
              ),
              IconButton(
                onPressed: canNext ? () => setState(() => month = DateTime(month.year, month.month + 1, 1)) : null,
                icon: Icon(Icons.chevron_right, color: canNext ? AppColors.text : AppColors.border),
              ),
            ],
          ),
          Row(
            children: [
              for (final w in weekdaysShort)
                Expanded(child: Center(child: Text(w, style: Txt.label.copyWith(fontSize: 10)))),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (_, i) {
              final dn = i - offset + 1;
              if (dn < 1 || dn > days) return const SizedBox.shrink();
              final d = DateTime(month.year, month.month, dn);
              final future = d.isAfter(now);
              final r = future ? null : store.dailyRatio(d);
              final c = (r == null || r == 0)
                  ? AppColors.surface2
                  : AppColors.accent.withValues(alpha: 0.2 + 0.8 * r);
              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c,
                  borderRadius: BorderRadius.circular(6),
                  border: sameDay(d, now) ? Border.all(color: AppColors.text, width: 1) : null,
                ),
                child: Text(
                  '$dn',
                  style: Txt.num(12,
                      weight: FontWeight.w600,
                      color: future ? AppColors.border : (r != null && r >= 0.6 ? Colors.white : AppColors.accent2)),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Text(tr('Чем ярче день, тем больше привычек выполнено'), style: Txt.small),
        ],
      ),
    );
  }

  Future<void> _addHabit(BuildContext context) async {
    final ctrl = TextEditingController();
    var period = HabitPeriod.daily;
    var icon = customHabitIcons.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(tr('Новая привычка'), style: Txt.h2),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: Txt.body,
                  decoration: fieldDeco(tr('Название'), hint: tr('например: 10 минут растяжки')),
                ),
                const SizedBox(height: 12),
                Segmented<HabitPeriod>(
                  values: HabitPeriod.values,
                  label: (p) => switch (p) {
                    HabitPeriod.daily => tr('День'),
                    HabitPeriod.weekly => tr('Неделя'),
                    HabitPeriod.monthly => tr('Месяц'),
                  },
                  selected: period,
                  onChanged: (p) => setD(() => period = p),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final k in customHabitIcons)
                      GestureDetector(
                        onTap: () => setD(() => icon = k),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: icon == k ? AppColors.accent.withValues(alpha: 0.16) : AppColors.surface2,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: icon == k ? AppColors.accent : AppColors.border),
                          ),
                          child: Icon(habitIcon(k), size: 18, color: icon == k ? AppColors.accent : AppColors.muted),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Отмена'), style: TextStyle(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Добавить'), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    final title = ctrl.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (ok == true && title.trim().isNotEmpty && mounted) {
      StoreScope.read(this.context).life.addHabit(title, period, icon);
    }
  }
}
