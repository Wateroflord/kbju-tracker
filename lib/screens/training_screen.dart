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
import 'ai_program_screen.dart';
import 'program_editor.dart';
import 'routine_screen.dart';
import 'strength_screen.dart';
import 'workout_screen.dart';
import '../i18n/i18n.dart';

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
            TabHeader(tr('Тренировки'), subtitle: trf('{0} за последние 7 дней', [life.sessionsLast7()])),
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
                          Text(trf('{0} идёт', [tr(active.title)]), style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                          Text(trf('{0} подходов сделано · нажми, чтобы продолжить', [active.doneSets]), style: Txt.small),
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
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _ToolTile(Icons.auto_awesome, tr('Программа от ИИ'), () => const AiProgramScreen())),
                const SizedBox(width: 8),
                Expanded(child: _ToolTile(Icons.self_improvement, tr('Разминка и растяжка'), () => const RoutinesScreen())),
                const SizedBox(width: 8),
                Expanded(child: _ToolTile(Icons.calculate_outlined, tr('Сила и 1ПМ'), () => const OneRmScreen())),
              ],
            ),
            ),
            SectionLabel(tr('Программа'), trailing: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProgramEditorScreen())),
              child: Text(tr('+ Своя программа'),
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
            )),
            for (final p in life.programs)
              OptionTile(
                icon: p.custom ? Icons.edit_note : Icons.fitness_center,
                title: tr(p.title),
                desc: '${p.days.map((d) => tr(d.title)).join(' / ')} · ${_weekdaysText(life.weekdaysOf(p))}',
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
                  label: Text(tr('Изменить программу'), style: TextStyle(color: AppColors.accent)),
                ),
              ),
            SectionLabel(tr('Рекорды'), trailing: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecordsScreen())),
              child: Text(tr('Все'), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
            )),
            _RecordsPreview(),
            SectionLabel(tr('История')),
            if (finished.isEmpty)
              AppCard(child: Text(tr('Здесь появятся завершённые тренировки.'), style: Txt.small))
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
                              Text(tr(s.title), style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(
                                trf('{0} · {1} подходов{2}', [fmtDate(parseKey(s.date), year: true), s.doneSets, s.volume > 0 ? trf(' · {0} кг', [fmtInt(s.volume)]) : '']),
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

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget Function() page;
  const _ToolTile(this.icon, this.text, this.page);

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page())),
        child: Column(
          children: [
            Icon(icon, color: AppColors.accent, size: 22),
            const SizedBox(height: 6),
            Text(text,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: Txt.small.copyWith(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 12, height: 1.2)),
          ],
        ),
      );
}

String _weekdaysText(List<int> days) =>
    days.isEmpty ? tr('дни не выбраны') : days.map((d) => weekdaysShort[d - 1]).join(', ');

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
                    Text(isDay ? tr('Сегодня по плану') : tr('Следующая тренировка'), style: Txt.label),
                    const SizedBox(height: 4),
                    Text(tr(next.title), style: Txt.h2),
                  ],
                ),
              ),
              if (program.days.length > 1)
                PopupMenuButton<WorkoutDay>(
                  tooltip: tr('Другой день'),
                  color: AppColors.surface2,
                  icon: const Icon(Icons.swap_horiz, color: AppColors.muted),
                  onSelected: (d) => TrainingScreen.start(context, program, d),
                  itemBuilder: (_) => [
                    for (final d in program.days)
                      PopupMenuItem(value: d, child: Text(trf('Начать: {0}', [tr(d.title)]), style: Txt.body)),
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
                  Expanded(child: Text(tr(life.exerciseById(pe.exId).name), style: Txt.body.copyWith(fontSize: 13.5))),
                  Text(
                    '${pe.scheme}${life.exerciseById(pe.exId).timed ? tr(' с') : ''}',
                    style: Txt.num(12.5, color: AppColors.accent2, weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          PrimaryButton(
            life.activeSession != null ? tr('Продолжить тренировку') : tr('Начать тренировку'),
            icon: Icons.play_arrow,
            onPressed: next.exercises.isEmpty ? null : () => TrainingScreen.start(context, program, next),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(trf('Отдых между подходами: {0} с', [life.restSeconds]), style: Txt.small)),
              TextButton(
                onPressed: () => _pickRest(context),
                child: Text(tr('Изменить'), style: TextStyle(color: AppColors.accent, fontSize: 13)),
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
            Text(tr('Отдых между подходами'), style: Txt.h2),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in const [60, 90, 120, 150, 180, 240])
                  ChoiceChip(
                    label: Text(trf('{0} с', [v])),
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
      return AppCard(child: Text(tr('Рекорды появятся после первой тренировки.'), style: Txt.small));
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
            ? trf('{0} кг × {1}', [fmt1(r.value), r.reps])
            : '${r.value.round()} ${ex.timed ? tr('с') : tr('повт.')}';
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExerciseStatsScreen(exId: exId))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_outlined, size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(tr(ex.name), style: Txt.body.copyWith(fontSize: 13.5))),
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
      appBar: subAppBar(tr('Рекорды')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (ids.isEmpty)
            AppCard(child: Text(tr('Пока нет завершённых тренировок.'), style: Txt.small))
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
    final unit = useW ? tr('кг') : (ex.timed ? tr('с') : tr('повт.'));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr(ex.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(useW ? tr('Рабочий вес') : (ex.timed ? tr('Лучшее время') : tr('Лучшие повторы')), style: Txt.section),
                const SizedBox(height: 12),
                if (hist.length >= 2)
                  LineChart(
                    points: [for (final e in hist) ChartPoint(parseKey(e.key), e.value)],
                    color: AppColors.accent,
                  )
                else
                  Text(tr('График появится после двух тренировок с этим упражнением.'), style: Txt.small),
              ],
            ),
          ),
          if (useW && life.e1rmHistory(exId).isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(tr('Сила (расчётный 1ПМ)'), style: Txt.section)),
                      Text(trf('{0} кг', [fmt1(life.e1rmHistory(exId).last.value)]), style: Txt.num(16, color: AppColors.accent)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(trf('Рекорд {0} кг. Учитывает и вес, и повторы.', [fmt1(life.bestE1rm(exId))]), style: Txt.small),
                  if (life.e1rmHistory(exId).length >= 2) ...[
                    const SizedBox(height: 12),
                    LineChart(
                      points: [for (final e in life.e1rmHistory(exId)) ChartPoint(parseKey(e.key), e.value)],
                      color: AppColors.accent2,
                      height: 150,
                    ),
                  ],
                ],
              ),
            ),
          ],
          SectionLabel(tr('По датам')),
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
          if (tr(ex.technique).isNotEmpty) ...[
            SectionLabel(tr('Техника')),
            AppCard(child: Text(tr(ex.technique), style: Txt.body)),
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
      return Scaffold(backgroundColor: AppColors.bg, appBar: subAppBar(tr('Тренировка')));
    }
    final mins = session.finished ? ((session.finishedAt - session.startedAt) / 60000).round() : 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr(session.title), actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.muted),
          onPressed: () async {
            final ok = await confirm(context, tr('Удалить тренировку?'), tr(session.title), ok: tr('Удалить'));
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
              Expanded(child: StatTile(label: tr('Дата'), value: fmtShort(parseKey(session.date)))),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: tr('Время'), value: trf('{0} мин', [mins]))),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: tr('Объём'), value: fmtInt(session.volume), sub: tr('кг'))),
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
                    Text(tr(life.exerciseById(e.exId).name), style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
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
