import 'package:flutter/material.dart';

import '../life/care_content.dart';
import '../life/content.dart';
import '../life/models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/habit_row.dart';
import '../widgets/nav.dart';
import 'shopping_screen.dart';

/// Вкладка «Уход»: рутины на сегодня, темы с советами, список покупок.
class CareScreen extends StatelessWidget {
  const CareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final life = store.life;
    final now = DateTime.now();
    final routineHabits = life.habits
        .where((h) => h.enabled && const ['care_am', 'care_pm', 'teeth'].contains(h.id))
        .toList();
    final toBuy = life.shopping.where((s) => !s.bought).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            const TabHeader('Уход', subtitle: 'Кожа, волосы, тело, стиль'),
            if (routineHabits.isNotEmpty) ...[
              const SectionLabel('Рутина на сегодня'),
              AppCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < routineHabits.length; i++) ...[
                      if (i > 0) const Divider(height: 1, indent: 58, color: AppColors.border),
                      HabitRow(habit: routineHabits[i], date: now),
                    ],
                  ],
                ),
              ),
            ],
            const SectionLabel('Разделы'),
            for (final t in careTopics)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CareTopicScreen(topic: t))),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      _iconBox(t.icon),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title, style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(_topicSub(t, life.skinType, life.hairConcern), style: Txt.small),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShoppingScreen())),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  _iconBox(Icons.shopping_bag_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Список покупок', style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(toBuy == 0 ? 'Всё куплено' : 'Осталось купить: $toBuy', style: Txt.small),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _topicSub(CareTopic t, String skin, String hair) {
    if (t.id == 'skin' && skin.isNotEmpty) {
      return 'Твой тип: ${skinQuiz.firstWhere((q) => q.id == skin, orElse: () => skinQuiz.last).title.toLowerCase()}';
    }
    if (t.id == 'hair' && hair.isNotEmpty) {
      return 'Тебе: ${hairQuiz.firstWhere((q) => q.id == hair, orElse: () => hairQuiz[4]).title.toLowerCase()}';
    }
    return t.subtitle;
  }

  static Widget _iconBox(IconData icon) => Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.accent, size: 20),
      );
}

class CareTopicScreen extends StatelessWidget {
  final CareTopic topic;
  const CareTopicScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final life = store.life;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(topic.title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(child: Text(topic.lead, style: Txt.body)),
          if (topic.id == 'skin')
            _Quiz(
              title: 'Какая у тебя кожа?',
              options: skinQuiz,
              selected: life.skinType,
              onSelect: life.setSkinType,
            ),
          if (topic.id == 'hair')
            _Quiz(
              title: 'Что замечаешь?',
              options: hairQuiz,
              selected: life.hairConcern,
              onSelect: life.setHairConcern,
            ),
          for (final s in topic.sections) ...[
            SectionLabel(s.title),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final b in s.bullets)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 7),
                            child: Dot(AppColors.accent, size: 5),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(b, style: Txt.body)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (topic.routines.isNotEmpty) ...[
            const SectionLabel('Добавить в привычки'),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [for (final r in topic.routines) _RoutineRow(routine: r)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  final CareRoutine routine;
  const _RoutineRow({required this.routine});

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    Habit? existing;
    for (final h in life.habits) {
      if (h.title.toLowerCase() == routine.title.toLowerCase()) existing = h;
    }
    final on = existing != null && existing.enabled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          Icon(habitIcon(routine.icon), size: 20, color: on ? AppColors.accent : AppColors.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(routine.title, style: Txt.body.copyWith(fontSize: 13.5)),
                Text(periodTitle(routine.period), style: Txt.small.copyWith(fontSize: 11)),
              ],
            ),
          ),
          if (on)
            const Pill('в привычках', color: AppColors.good, icon: Icons.check)
          else
            TextButton(
              onPressed: () {
                final ex = existing;
                if (ex != null) {
                  life.setHabitEnabled(ex.id, true);
                } else {
                  life.addHabit(routine.title, routine.period, routine.icon);
                }
                showToast(context, 'Добавлено в привычки');
              },
              child: const Text('Добавить', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _Quiz extends StatelessWidget {
  final String title;
  final List<QuizOption> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _Quiz({required this.title, required this.options, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    QuizOption? sel;
    for (final o in options) {
      if (o.id == selected) sel = o;
    }
    final chosen = sel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in options)
              GestureDetector(
                onTap: () => onSelect(o.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: o.id == selected ? AppColors.accent : AppColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: o.id == selected ? AppColors.accent : AppColors.border),
                  ),
                  child: Text(o.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: o.id == selected ? Colors.white : AppColors.text,
                      )),
                ),
              ),
          ],
        ),
        if (chosen != null) ...[
          const SizedBox(height: 10),
          AppCard(
            borderColor: AppColors.accent.withValues(alpha: 0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(child: Text(chosen.title, style: Txt.section)),
                  ],
                ),
                const SizedBox(height: 8),
                for (final a in chosen.advice)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text('• $a', style: Txt.body),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
