import 'package:flutter/material.dart';

import '../life/content.dart';
import '../life/eval.dart';
import '../life/models.dart';
import '../store.dart';
import '../theme.dart';
import 'common.dart';
import '../i18n/i18n.dart';

/// Строка привычки: иконка, название, прогресс/серия, отметка справа.
class HabitRow extends StatelessWidget {
  final Habit habit;
  final DateTime date;
  const HabitRow({super.key, required this.habit, required this.date});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final auto = store.habitAutoDone(habit, date);
    final manual = store.life.manualDone(habit, date);
    final done = auto || manual;
    final progress = store.habitProgress(habit, date);
    final streak = store.habitStreak(habit);
    final unit = switch (habit.period) {
      HabitPeriod.daily => tr('дн.'),
      HabitPeriod.weekly => tr('нед.'),
      HabitPeriod.monthly => tr('мес.'),
    };
    final sub = [
      if (progress != null) progress,
      if (streak > 1) trf('серия {0} {1}', [streak, unit]),
    ].join(' · ');

    return InkWell(
      onTap: () {
        if (auto && !manual) {
          showToast(context, tr('Отмечено автоматически'));
          return;
        }
        store.life.toggleHabit(habit, date);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: done ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(habitIcon(habit.icon), size: 18, color: done ? AppColors.accent : AppColors.muted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(habit.title),
                    style: Txt.body.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: done ? AppColors.text : AppColors.accent2,
                    ),
                  ),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: Txt.small.copyWith(fontSize: 11.5)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            CheckMark(done: done, auto: auto),
          ],
        ),
      ),
    );
  }
}

/// Круглая отметка: пустая / красная с галочкой.
class CheckMark extends StatelessWidget {
  final bool done;
  final bool auto;
  const CheckMark({super.key, required this.done, this.auto = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done ? AppColors.accent : Colors.transparent,
        border: Border.all(color: done ? AppColors.accent : AppColors.border, width: 2),
      ),
      child: done
          ? Icon(auto ? Icons.bolt : Icons.check, size: 15, color: Colors.white)
          : null,
    );
  }
}
