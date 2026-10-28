import 'package:flutter/material.dart';

import '../life/models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/sheets.dart';

/// Создание и редактирование своей программы тренировок.
class ProgramEditorScreen extends StatefulWidget {
  final Program? program;
  const ProgramEditorScreen({super.key, this.program});

  @override
  State<ProgramEditorScreen> createState() => _ProgramEditorScreenState();
}

class _DayDraft {
  final String id;
  final TextEditingController title;
  final List<PlanExercise> exercises;
  _DayDraft(this.id, String t, this.exercises) : title = TextEditingController(text: t);
}

class _ProgramEditorScreenState extends State<ProgramEditorScreen> {
  late final TextEditingController name = TextEditingController(text: widget.program?.title ?? '');
  late List<int> weekdays = [...(widget.program?.weekdays ?? const [1, 3, 5])];
  late final List<_DayDraft> days = widget.program == null
      ? [_DayDraft('D1', 'Тренировка 1', [])]
      : [for (final d in widget.program!.days) _DayDraft(d.id, d.title, [...d.exercises])];

  @override
  void dispose() {
    name.dispose();
    for (final d in days) {
      d.title.dispose();
    }
    super.dispose();
  }

  void _save() {
    final store = StoreScope.read(context);
    final title = name.text.trim();
    if (title.isEmpty) {
      showToast(context, 'Введи название программы');
      return;
    }
    final valid = days.where((d) => d.exercises.isNotEmpty).toList();
    if (valid.isEmpty) {
      showToast(context, 'Добавь хотя бы одно упражнение');
      return;
    }
    final p = Program(
      id: widget.program?.id ?? store.life.newId('p'),
      title: title,
      desc: 'Своя программа',
      days: [
        for (var i = 0; i < valid.length; i++)
          WorkoutDay(
            id: valid[i].id,
            title: valid[i].title.text.trim().isEmpty ? 'Тренировка ${i + 1}' : valid[i].title.text.trim(),
            exercises: valid[i].exercises,
          ),
      ],
      weekdays: [...weekdays]..sort(),
      custom: true,
    );
    store.life.saveProgram(p);
    store.life.setActiveProgram(p.id);
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final p = widget.program;
    if (p == null) return;
    final ok = await confirm(context, 'Удалить программу?', p.title, ok: 'Удалить');
    if (!ok || !mounted) return;
    StoreScope.read(context).life.deleteProgram(p.id);
    Navigator.pop(context);
  }

  Future<void> _pickExercise(_DayDraft day) async {
    final exId = await showAppSheet<String>(context, const _ExercisePicker());
    if (exId == null || !mounted) return;
    final ex = StoreScope.read(context).life.exerciseById(exId);
    final pe = await _editScheme(PlanExercise(exId, 3, ex.timed ? 30 : 8, ex.timed ? 60 : 12), ex);
    if (pe != null) setState(() => day.exercises.add(pe));
  }

  Future<PlanExercise?> _editScheme(PlanExercise pe, Exercise ex) async {
    final sets = TextEditingController(text: '${pe.sets}');
    final min = TextEditingController(text: pe.toFailure ? '' : '${pe.repMin}');
    final max = TextEditingController(text: pe.toFailure ? '' : '${pe.repMax}');
    var failure = pe.toFailure;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(ex.name, style: Txt.h2),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NumField(sets, 'Подходов'),
              const SizedBox(height: 8),
              if (!failure)
                Row(
                  children: [
                    Expanded(child: NumField(min, ex.timed ? 'От, сек' : 'Повторов от')),
                    const SizedBox(width: 8),
                    Expanded(child: NumField(max, ex.timed ? 'До, сек' : 'до')),
                  ],
                ),
              if (!ex.timed)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: failure,
                  activeColor: AppColors.accent,
                  title: const Text('До отказа минус 1–2', style: Txt.body),
                  onChanged: (v) => setD(() => failure = v ?? false),
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
              child: const Text('Готово', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    final s = (parseNum(sets.text) ?? 3).round().clamp(1, 10).toInt();
    var a = (parseNum(min.text) ?? 8).round().clamp(1, 600).toInt();
    var b = (parseNum(max.text) ?? a).round().clamp(1, 600).toInt();
    if (b < a) b = a;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sets.dispose();
      min.dispose();
      max.dispose();
    });
    if (ok != true) return null;
    return failure ? PlanExercise(pe.exId, s, 0, 0) : PlanExercise(pe.exId, s, a, b);
  }

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(widget.program == null ? 'Новая программа' : 'Программа', actions: [
        if (widget.program != null)
          IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline, color: AppColors.muted)),
      ]),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: PrimaryButton('Сохранить', icon: Icons.check, onPressed: _save),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.sentences,
            style: Txt.body,
            decoration: fieldDeco('Название программы', hint: 'например: Верх / Низ'),
          ),
          const SectionLabel('Дни недели'),
          Row(
            children: [
              for (var d = 1; d <= 7; d++) ...[
                if (d > 1) const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      if (!weekdays.remove(d)) weekdays.add(d);
                    }),
                    child: Container(
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: weekdays.contains(d) ? AppColors.accent : AppColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: weekdays.contains(d) ? AppColors.accent : AppColors.border),
                      ),
                      child: Text(weekdaysShort[d - 1],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: weekdays.contains(d) ? Colors.white : AppColors.muted,
                          )),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          const Text('Дни программы чередуются по кругу: 1, 2, 1, 2…', style: Txt.small),
          for (var i = 0; i < days.length; i++) ...[
            SectionLabel('День ${i + 1}', trailing: days.length > 1
                ? GestureDetector(
                    onTap: () => setState(() {
                      final d = days.removeAt(i);
                      WidgetsBinding.instance.addPostFrameCallback((_) => d.title.dispose());
                    }),
                    child: const Text('Удалить день', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  )
                : null),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: days[i].title,
                    style: Txt.body,
                    decoration: fieldDeco('Название дня'),
                  ),
                  const SizedBox(height: 8),
                  for (var j = 0; j < days[i].exercises.length; j++)
                    Row(
                      children: [
                        Expanded(
                          child: Text(life.exerciseById(days[i].exercises[j].exId).name,
                              style: Txt.body.copyWith(fontSize: 13.5)),
                        ),
                        TextButton(
                          onPressed: () async {
                            final pe = days[i].exercises[j];
                            final res = await _editScheme(pe, life.exerciseById(pe.exId));
                            if (res != null) setState(() => days[i].exercises[j] = res);
                          },
                          child: Text(days[i].exercises[j].scheme, style: const TextStyle(color: AppColors.accent2)),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() => days[i].exercises.removeAt(j)),
                          icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  GhostButton('Добавить упражнение', icon: Icons.add, onPressed: () => _pickExercise(days[i])),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (days.length < 4)
            GhostButton('Добавить день', icon: Icons.add, onPressed: () => setState(() {
              days.add(_DayDraft('D${DateTime.now().millisecondsSinceEpoch}', 'Тренировка ${days.length + 1}', []));
            })),
        ],
      ),
    );
  }
}

/// Выбор упражнения из списка или создание нового.
class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker();

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String q = '';

  Future<void> _create() async {
    final name = TextEditingController();
    final tech = TextEditingController();
    var bodyweight = false;
    var timed = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Новое упражнение', style: Txt.h2),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  style: Txt.body,
                  decoration: fieldDeco('Название'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tech,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  style: Txt.body,
                  decoration: fieldDeco('Техника (необязательно)'),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: bodyweight,
                  activeColor: AppColors.accent,
                  title: const Text('Без веса (свой вес)', style: Txt.body),
                  onChanged: (v) => setD(() => bodyweight = v ?? false),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: timed,
                  activeColor: AppColors.accent,
                  title: const Text('На время (секунды)', style: Txt.body),
                  onChanged: (v) => setD(() => timed = v ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена', style: TextStyle(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Создать', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    final t = tech.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      tech.dispose();
    });
    if (ok != true || n.isEmpty || !mounted) return;
    final life = StoreScope.read(context).life;
    final ex = Exercise(id: life.newId('ex'), name: n, technique: t, bodyweight: bodyweight || timed, timed: timed, custom: true);
    life.addExercise(ex);
    Navigator.pop(context, ex.id);
  }

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final list = life.allExercises.where((e) => q.isEmpty || e.name.toLowerCase().contains(q.toLowerCase())).toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          const SheetHandle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              style: Txt.body,
              decoration: fieldDeco('Поиск упражнения'),
              onChanged: (v) => setState(() => q = v),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              children: [
                ListTile(
                  leading: const Icon(Icons.add, color: AppColors.accent),
                  title: const Text('Создать своё упражнение', style: TextStyle(color: AppColors.accent)),
                  onTap: _create,
                ),
                for (final e in list)
                  ListTile(
                    title: Text(e.name, style: Txt.body),
                    subtitle: Text(
                      e.timed ? 'на время' : (e.bodyweight ? 'свой вес' : 'с весом'),
                      style: Txt.small,
                    ),
                    trailing: e.custom
                        ? IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.muted),
                            onPressed: () => life.deleteExercise(e.id),
                          )
                        : null,
                    onTap: () => Navigator.pop(context, e.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
