import 'package:flutter/material.dart';

import '../life/models.dart';
import '../life/training.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/sheets.dart';
import 'program_editor.dart';
import 'workout_screen.dart';

class TrainingScreen extends StatelessWidget {
  const TrainingScreen({super.key});

  static void openWorkout(BuildContext context, String sessionId) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkoutScreen(sessionId: sessionId)));
  }

  static void start(BuildContext context, Program p, WorkoutDay d) {
    final store = StoreScope.read(context);
    final active = store.life.activeSession;
    if (active != null) {
      openWorkout(context, active.id);
      return;
    }
    final s = store.life.startSession(p, d);
    openWorkout(context, s.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final life = store.life;
    final program = life.activeProgram;
    final next = life.nextDay();
    final active = life.activeSession;
    final finished = life.sessions.where((s) => s.finished).toList().reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            TabHeader('Тренировки', subtitle: '${life.sessionsLast7()} за последние 7 дней'),
            const SizedBox(height: 14),
            if (active != null) ...[
              AppCard(
                onTap: () => openWorkout(context, active.id),
                borderColor: AppColors.accent,
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${active.title} идёт', style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                          Text('${active.doneSets} подходов сделано · нажми, чтобы продолжить', style: Txt.small),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _NextCard(program: program, next: next),
            SectionLabel('Программа', trailing: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgramEditorScreen())),
              child: const Text('+ Своя программа',
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
            )),
            for (final p in life.programs)
              OptionTile(
                icon: p.custom ? Icons.edit_note : Icons.fitness_center,
                title: p.title,
                desc: '${p.days.map((d) => d.title).join(' / ')} · ${_weekdaysText(life.weekdaysOf(p))}',
                selected: p.id == life.activeProgramId,
                onTap: () => life.setActiveProgram(p.id),
              ),
            _WeekdayPicker(program: program),
            if (program.custom)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ProgramEditorScreen(program: program)),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.accent),
                  label: const Text('Изменить программу', style: TextStyle(color: AppColors.accent)),
                ),
              ),
            SectionLabel('Рекорды', trailing: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecordsScreen())),
              child: const Text('Все', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
            )),
            _RecordsPreview(),
            const SectionLabel('История'),
            if (finished.isEmpty)
              const AppCard(child: Text('Здесь появятся завершённые тренировки.', style: Txt.small))
            else
              for (final s in finished.take(15))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: s.id)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.title, style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                '${fmtDate(parseKey(s.date), year: true)} · ${s.doneSets} подходов'
                                '${s.volume > 0 ? ' · ${fmtInt(s.volume)} кг' : ''}',
                                style: Txt.small,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

String _weekdaysText(List<int> days) =>
    days.isEmpty ? 'дни не выбраны' : days.map((d) => weekdaysShort[d - 1]).join(', ');

class _NextCard extends StatelessWidget {
  final Program program;
  final WorkoutDay next;
  const _NextCard({required this.program, required this.next});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final life = store.life;
    final isDay = life.isTrainingDay(DateTime.now());
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isDay ? 'Сегодня по плану' : 'Следующая тренировка', style: Txt.label),
                    const SizedBox(height: 4),
                    Text(next.title, style: Txt.h2),
                  ],
                ),
              ),
              if (program.days.length > 1)
                PopupMenuButton<WorkoutDay>(
                  tooltip: 'Другой день',
                  color: AppColors.surface2,
                  icon: const Icon(Icons.swap_horiz, color: AppColors.muted),
                  onSelected: (d) => TrainingScreen.start(context, program, d),
                  itemBuilder: (_) => [
                    for (final d in program.days)
                      PopupMenuItem(value: d, child: Text('Начать: ${d.title}', style: Txt.body)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          for (final pe in next.exercises)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Dot(AppColors.accent, size: 5),
                  const SizedBox(width: 10),
                  Expanded(child: Text(life.exerciseById(pe.exId).name, style: Txt.body.copyWith(fontSize: 13.5))),
                  Text(
                    '${pe.scheme}${life.exerciseById(pe.exId).timed ? ' с' : ''}',
                    style: Txt.num(12.5, color: AppColors.accent2, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          PrimaryButton(
            life.activeSession != null ? 'Продолжить тренировку' : 'Начать тренировку',
            icon: Icons.play_arrow,
            onPressed: next.exercises.isEmpty ? null : () => TrainingScreen.start(context, program, next),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text('Отдых между подходами: ${life.restSeconds} с', style: Txt.small)),
              TextButton(
                onPressed: () => _pickRest(context),
                child: const Text('Изменить', style: TextStyle(color: AppColors.accent, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _pickRest(BuildContext context) {
    showAppSheet(context, Builder(builder: (ctx) {
      final life = StoreScope.of(ctx).life;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            const Text('Отдых между подходами', style: Txt.h2),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in const [60, 90, 120, 150, 180, 240])
                  ChoiceChip(
                    label: Text('$v с'),
                    selected: life.restSeconds == v,
                    selectedColor: AppColors.accent,
                    backgroundColor: AppColors.surface2,
                    labelStyle: TextStyle(color: life.restSeconds == v ? Colors.white : AppColors.text),
                    onSelected: (_) => life.setRestSeconds(v),
                  ),
              ],
            ),
          ],
        ),
      );
    }));
  }
}

class _WeekdayPicker extends StatelessWidget {
  final Program program;
  const _WeekdayPicker({required this.program});

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final days = life.weekdaysOf(program);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          for (var d = 1; d <= 7; d++) ...[
            if (d > 1) const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  final next = [...days];
                  if (!next.remove(d)) next.add(d);
                  life.setWeekdays(program, next);
                },
                child: Container(
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: days.contains(d) ? AppColors.accent : AppColors.surface2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: days.contains(d) ? AppColors.accent : AppColors.border),
                  ),
                  child: Text(
                    weekdaysShort[d - 1],
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: days.contains(d) ? Colors.white : AppColors.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordsPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final ids = life.trainedExerciseIds();
    if (ids.isEmpty) {
      return const AppCard(child: Text('Рекорды появятся после первой тренировки.', style: Txt.small));
    }
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (final id in ids.take(5)) _RecordRow(exId: id),
        ],
      ),
    );
  }
}

class _RecordRow extends StatelessWidget {
  final String exId;
  const _RecordRow({required this.exId});

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final ex = life.exerciseById(exId);
    final r = life.recordOf(exId);
    final useW = !ex.bodyweight && !ex.timed;
    final value = r == null
        ? '—'
        : useW
            ? '${fmt1(r.value)} кг × ${r.reps}'
            : '${r.value.round()} ${ex.timed ? 'с' : 'повт.'}';
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExerciseStatsScreen(exId: exId))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined, size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(ex.name, style: Txt.body.copyWith(fontSize: 13.5))),
            Text(value, style: Txt.num(13.5)),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final ids = life.trainedExerciseIds();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar('Рекорды'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (ids.isEmpty)
            const AppCard(child: Text('Пока нет завершённых тренировок.', style: Txt.small))
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(children: [for (final id in ids) _RecordRow(exId: id)]),
            ),
        ],
      ),
    );
  }
}

/// График рабочего веса (или повторов) по упражнению.
class ExerciseStatsScreen extends StatelessWidget {
  final String exId;
  const ExerciseStatsScreen({super.key, required this.exId});

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final ex = life.exerciseById(exId);
    final hist = life.historyOf(exId);
    final useW = !ex.bodyweight && !ex.timed;
    final unit = useW ? 'кг' : (ex.timed ? 'с' : 'повт.');
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(ex.name),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(useW ? 'Рабочий вес' : (ex.timed ? 'Лучшее время' : 'Лучшие повторы'), style: Txt.section),
                const SizedBox(height: 12),
                if (hist.length >= 2)
                  LineChart(
                    points: [for (final e in hist) ChartPoint(parseKey(e.key), e.value)],
                    color: AppColors.accent,
                  )
                else
                  const Text('График появится после двух тренировок с этим упражнением.', style: Txt.small),
              ],
            ),
          ),
          const SectionLabel('По датам'),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final e in hist.reversed)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    child: Row(
                      children: [
                        Expanded(child: Text(fmtDate(parseKey(e.key), year: true), style: Txt.small)),
                        Text('${useW ? fmt1(e.value) : e.value.round()} $unit', style: Txt.num(14)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (ex.technique.isNotEmpty) ...[
            const SectionLabel('Техника'),
            AppCard(child: Text(ex.technique, style: Txt.body)),
          ],
        ],
      ),
    );
  }
}

/// Просмотр завершённой тренировки.
class SessionDetailScreen extends StatelessWidget {
  final String sessionId;
  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    Session? s;
    for (final x in life.sessions) {
      if (x.id == sessionId) s = x;
    }
    final session = s;
    if (session == null) {
      return Scaffold(backgroundColor: AppColors.bg, appBar: subAppBar('Тренировка'));
    }
    final mins = session.finished ? ((session.finishedAt - session.startedAt) / 60000).round() : 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(session.title, actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.muted),
          onPressed: () async {
            final ok = await confirm(context, 'Удалить тренировку?', session.title, ok: 'Удалить');
            if (!ok || !context.mounted) return;
            life.deleteSession(session.id);
            Navigator.pop(context);
          },
        ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Row(
            children: [
              Expanded(child: StatTile(label: 'Дата', value: fmtShort(parseKey(session.date)))),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'Время', value: '$mins мин')),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: 'Объём', value: fmtInt(session.volume), sub: 'кг')),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in session.exercises)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(life.exerciseById(e.exId).name, style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final set in e.sets)
                          Pill(
                            set.weight > 0 ? '${fmt1(set.weight)} × ${set.reps}' : '${set.reps}',
                            color: set.done ? AppColors.good : AppColors.muted,
                          ),
                      ],
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
