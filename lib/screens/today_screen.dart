import 'package:flutter/material.dart';

import '../life/content.dart';
import '../life/eval.dart';
import '../life/models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/habit_row.dart';
import '../widgets/nav.dart';
import '../widgets/quick_inputs.dart';
import '../life/steps_service.dart';
import 'habits_screen.dart';
import 'sleep_screen.dart';
import 'steps_screen.dart';

/// Главный экран: кольца дня, тренировка, привычки, совет дня.
class TodayScreen extends StatelessWidget {
  /// Переключение вкладки нижнего меню (0 — Сегодня, 1 — Питание, 2 — Тренировки, 3 — Уход, 4 — Прогресс).
  final ValueChanged<int> onOpenTab;
  final VoidCallback? onOpenSteps;
  final VoidCallback? onOpenSleep;

  const TodayScreen({super.key, required this.onOpenTab, this.onOpenSteps, this.onOpenSleep});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = today();
    final key = dkey(now);
    final life = store.life;
    final t = store.targetsFor(key);
    final tot = store.totalsFor(key);
    final steps = life.stepsFor(key);
    final water = store.waterFor(key);
    final sleep = life.sleepFor(key);
    final streak = store.dayStreak();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            TabHeader('Сегодня', subtitle: '${weekdaysFull[now.weekday - 1]}, ${fmtDate(now)}'),
            const SizedBox(height: 14),
            AppCard(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: MiniRing(
                      ratio: t.kcal > 0 ? tot.kcal / t.kcal : 0,
                      value: fmtInt(tot.kcal),
                      label: 'из ${fmtInt(t.kcal)} ккал',
                      color: AppColors.accent,
                      onTap: () => onOpenTab(1),
                    ),
                  ),
                  Expanded(
                    child: MiniRing(
                      ratio: steps / life.stepGoal,
                      value: fmtInt(steps),
                      label: 'шагов',
                      color: AppColors.good,
                      onTap: onOpenSteps ??
                          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StepsScreen())),
                    ),
                  ),
                  Expanded(
                    child: MiniRing(
                      ratio: t.waterMl > 0 ? water / t.waterMl : 0,
                      value: fmt1(water / 1000),
                      label: 'л воды',
                      color: AppColors.water,
                      onTap: () => showWaterSheet(context, now),
                    ),
                  ),
                  Expanded(
                    child: MiniRing(
                      ratio: sleep == null ? 0 : sleep.hours / life.sleepGoal,
                      value: sleep == null ? '—' : fmt1(sleep.hours),
                      label: 'ч сна',
                      color: AppColors.carbs,
                      onTap: onOpenSleep ??
                          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SleepScreen())),
                    ),
                  ),
                ],
              ),
            ),
            if (life.stepSource == 'manual' && !life.stepsPromptHidden) ...[
              const SizedBox(height: 12),
              const _StepsPrompt(),
            ],
            const SizedBox(height: 12),
            _WorkoutCard(onOpen: () => onOpenTab(2)),
            SectionLabel(
              'Привычки на сегодня',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (streak > 0) ...[
                    Pill('$streak дн. подряд', icon: Icons.local_fire_department_outlined),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HabitsScreen()),
                    ),
                    child: const Text('Все',
                        style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ),
            _HabitsCard(period: HabitPeriod.daily, date: now),
            const SizedBox(height: 10),
            _PeriodSummary(period: HabitPeriod.weekly, date: now),
            const SizedBox(height: 8),
            _PeriodSummary(period: HabitPeriod.monthly, date: now),
            const SectionLabel('Совет дня'),
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, color: AppColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tipOfDay(now), style: Txt.body)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _WorkoutCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final life = store.life;
    final now = today();
    final todays = life.sessionsOn(dkey(now));
    final doneToday = todays.any((s) => s.finished);
    final active = life.activeSession;
    final trainingDay = life.isTrainingDay(now);
    final next = life.nextDay();

    String title;
    String sub;
    IconData icon;
    Color color;
    if (active != null) {
      title = '${active.title} идёт';
      sub = 'Нажми, чтобы продолжить';
      icon = Icons.timer_outlined;
      color = AppColors.accent;
    } else if (doneToday) {
      final s = todays.lastWhere((s) => s.finished);
      title = '${s.title} — сделано';
      sub = '${s.doneSets} подходов${s.volume > 0 ? ' · ${fmtInt(s.volume)} кг объём' : ''}';
      icon = Icons.check_circle_outline;
      color = AppColors.good;
    } else if (trainingDay) {
      title = 'Сегодня: ${next.title}';
      sub = '${life.activeProgram.title} · ${next.exercises.length} упражнений';
      icon = Icons.fitness_center;
      color = AppColors.accent;
    } else {
      title = 'День отдыха';
      sub = 'Следующая: ${next.title} · ${life.activeProgram.title}';
      icon = Icons.self_improvement;
      color = AppColors.muted;
    }

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(sub, style: Txt.small, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class _HabitsCard extends StatelessWidget {
  final HabitPeriod period;
  final DateTime date;
  const _HabitsCard({required this.period, required this.date});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.life.habitsOf(period);
    if (list.isEmpty) {
      return const AppCard(child: Text('Нет включённых привычек. Включи их в разделе «Все».', style: Txt.small));
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < list.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 58, color: AppColors.border),
            HabitRow(habit: list[i], date: date),
          ],
        ],
      ),
    );
  }
}

/// Свернутый блок недельных/месячных привычек: «На этой неделе 2 / 5».
class _PeriodSummary extends StatefulWidget {
  final HabitPeriod period;
  final DateTime date;
  const _PeriodSummary({required this.period, required this.date});

  @override
  State<_PeriodSummary> createState() => _PeriodSummaryState();
}

class _PeriodSummaryState extends State<_PeriodSummary> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.life.habitsOf(widget.period);
    if (list.isEmpty) return const SizedBox.shrink();
    final done = list.where((h) => store.habitDoneOn(h, widget.date)).length;
    final title = widget.period == HabitPeriod.weekly ? 'На этой неделе' : 'В этом месяце';
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => open = !open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(widget.period == HabitPeriod.weekly ? Icons.date_range_outlined : Icons.calendar_month_outlined,
                      color: AppColors.muted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: Txt.body.copyWith(fontWeight: FontWeight.w600))),
                  Text('$done / ${list.length}',
                      style: Txt.num(14, color: done == list.length ? AppColors.good : AppColors.text)),
                  const SizedBox(width: 6),
                  Icon(open ? Icons.expand_less : Icons.expand_more, color: AppColors.muted),
                ],
              ),
            ),
          ),
          if (open) ...[
            const Divider(height: 1, color: AppColors.border),
            for (var i = 0; i < list.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 58, color: AppColors.border),
              HabitRow(habit: list[i], date: widget.date),
            ],
          ],
        ],
      ),
    );
  }
}


/// Предложение включить автоматический подсчёт шагов.
class _StepsPrompt extends StatefulWidget {
  const _StepsPrompt();

  @override
  State<_StepsPrompt> createState() => _StepsPromptState();
}

class _StepsPromptState extends State<_StepsPrompt> {
  bool busy = false;

  Future<void> _enable() async {
    final ok = await confirm(
      context,
      'Автоподсчёт шагов',
      'Шагомер будет считать шаги сам, когда ты ходишь с телефоном, даже если приложение закрыто. '
          'Android попросит доступ к «Физической активности» и к уведомлениям — в шторке будет '
          'тихое уведомление с шагами за сегодня.',
      ok: 'Включить',
    );
    if (!ok || !mounted) return;
    setState(() => busy = true);
    final err = await StepsService.instance.connectSensor();
    if (!mounted) return;
    setState(() => busy = false);
    showToast(context, err ?? 'Шагомер включён — просто ходи с телефоном');
  }

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    return AppCard(
      borderColor: AppColors.good.withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_walk, color: AppColors.good, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text('Включить автоподсчёт шагов?', style: Txt.section),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Шаги будут считаться сами, пока телефон с тобой — вводить вручную не нужно.', style: Txt.small),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: PrimaryButton('Включить', icon: Icons.check, loading: busy, onPressed: _enable)),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  life.stepsPromptHidden = true;
                  life.touch();
                },
                child: const Text('Не сейчас', style: TextStyle(color: AppColors.muted)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
