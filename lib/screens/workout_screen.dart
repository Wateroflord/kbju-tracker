import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../life/models.dart';
import '../life/training.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';

/// Экран идущей тренировки: подходы, вес, повторы, таймер отдыха.
class WorkoutScreen extends StatefulWidget {
  final String sessionId;
  const WorkoutScreen({super.key, required this.sessionId});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  Timer? _tick;
  int restLeft = 0; // секунд
  int restTotal = 0;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {
      if (restLeft > 0) {
        restLeft--;
        if (restLeft == 0) _restDone();
      }
    });
  }

  Future<void> _restDone() async {
    SystemSound.play(SystemSoundType.alert);
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.vibrate();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
  }

  void _startRest() {
    final s = StoreScope.read(context).life.restSeconds;
    setState(() {
      restTotal = s;
      restLeft = s;
    });
  }

  Session? _session(AppStore store) {
    for (final s in store.life.sessions) {
      if (s.id == widget.sessionId) return s;
    }
    return null;
  }

  void _updateSet(AppStore store, Session s, int exIdx, int setIdx, SetLog v) {
    final exs = [...s.exercises];
    final sets = [...exs[exIdx].sets];
    sets[setIdx] = v;
    exs[exIdx] = SessionExercise(exs[exIdx].exId, sets);
    store.life.updateSession(s.copyWith(exercises: exs));
  }

  void _addSet(AppStore store, Session s, int exIdx) {
    final exs = [...s.exercises];
    final sets = [...exs[exIdx].sets];
    final last = sets.isNotEmpty ? sets.last : const SetLog();
    sets.add(SetLog(weight: last.weight, reps: last.reps));
    exs[exIdx] = SessionExercise(exs[exIdx].exId, sets);
    store.life.updateSession(s.copyWith(exercises: exs));
  }

  void _removeSet(AppStore store, Session s, int exIdx) {
    final exs = [...s.exercises];
    final sets = [...exs[exIdx].sets];
    if (sets.length <= 1) return;
    sets.removeLast();
    exs[exIdx] = SessionExercise(exs[exIdx].exId, sets);
    store.life.updateSession(s.copyWith(exercises: exs));
  }

  Future<void> _finish(AppStore store, Session s) async {
    if (s.doneSets == 0) {
      final ok = await confirm(context, 'Нет выполненных подходов',
          'Отметь подходы галочкой. Удалить эту тренировку?', ok: 'Удалить');
      if (!ok || !mounted) return;
      store.life.deleteSession(s.id);
      Navigator.pop(context);
      return;
    }
    // Рекорды до завершения — чтобы найти новые.
    final before = {for (final e in s.exercises) e.exId: store.life.recordOf(e.exId)?.value ?? 0};
    store.life.finishSession(s.id);
    final records = <String>[];
    for (final e in s.exercises) {
      final r = store.life.recordOf(e.exId);
      if (r != null && r.value > (before[e.exId] ?? 0) && (before[e.exId] ?? 0) > 0) {
        final ex = store.life.exerciseById(e.exId);
        final useW = !ex.bodyweight && !ex.timed;
        records.add('${ex.name}: ${useW ? '${fmt1(r.value)} кг' : '${r.value.round()}${ex.timed ? ' с' : ' повт.'}'}');
      }
    }
    final mins = ((DateTime.now().millisecondsSinceEpoch - s.startedAt) / 60000).round();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Тренировка завершена', style: Txt.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${s.doneSets} подходов · $mins мин'
                '${s.volume > 0 ? ' · ${fmtInt(s.volume)} кг объём' : ''}', style: Txt.body),
            if (records.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Новые рекорды', style: Txt.section),
              const SizedBox(height: 6),
              for (final r in records)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.emoji_events_outlined, size: 16, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Expanded(child: Text(r, style: Txt.small.copyWith(color: AppColors.text))),
                  ]),
                ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Готово', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _cancel(AppStore store, Session s) async {
    final ok = await confirm(context, 'Отменить тренировку?', 'Записанные подходы будут удалены.', ok: 'Отменить');
    if (!ok || !mounted) return;
    store.life.deleteSession(s.id);
    Navigator.pop(context);
  }

  void _showTechnique(Exercise ex) {
    showAppSheet(
      context,
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Text(ex.name, style: Txt.h2),
            const SizedBox(height: 12),
            if (ex.technique.isNotEmpty) ...[
              const Text('Техника', style: Txt.section),
              const SizedBox(height: 4),
              Text(ex.technique, style: Txt.body),
              const SizedBox(height: 12),
            ],
            if (ex.easier.isNotEmpty) ...[
              const Text('Если тяжело', style: Txt.section),
              const SizedBox(height: 4),
              Text(ex.easier, style: Txt.body),
              const SizedBox(height: 12),
            ],
            AppCard(
              borderColor: AppColors.over.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(12),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_outlined, color: AppColors.over, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Острая боль в суставе — остановись и замени упражнение.', style: Txt.small),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final s = _session(store);
    if (s == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(backgroundColor: AppColors.bg),
        body: const Center(child: Text('Тренировка не найдена', style: Txt.small)),
      );
    }
    final elapsed = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - s.startedAt);
    final total = s.exercises.fold<int>(0, (a, e) => a + e.sets.length);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.title, style: Txt.h2),
            Text('${_fmtDur(elapsed)} · ${s.doneSets}/$total подходов', style: Txt.small),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Отменить',
            onPressed: () => _cancel(store, s),
            icon: const Icon(Icons.delete_outline, color: AppColors.muted),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (restLeft > 0) _restBar(),
              PrimaryButton('Завершить тренировку', icon: Icons.flag_outlined, onPressed: () => _finish(store, s)),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          for (var i = 0; i < s.exercises.length; i++) _exerciseCard(store, s, i),
        ],
      ),
    );
  }

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final sec = d.inSeconds % 60;
    return h > 0 ? '$h:${two(m)}:${two(sec)}' : '${two(m)}:${two(sec)}';
  }

  Widget _restBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        borderColor: AppColors.accent.withValues(alpha: 0.5),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                const Text('Отдых', style: Txt.section),
                const SizedBox(width: 10),
                Text(_fmtDur(Duration(seconds: restLeft)), style: Txt.num(20, color: AppColors.accent)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    restLeft += 30;
                    restTotal += 30;
                  }),
                  child: const Text('+30 с', style: TextStyle(color: AppColors.text)),
                ),
                TextButton(
                  onPressed: () => setState(() => restLeft = 0),
                  child: const Text('Пропустить', style: TextStyle(color: AppColors.muted)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ProgressLine(ratio: restTotal > 0 ? 1 - restLeft / restTotal : 0, color: AppColors.accent, height: 4, overIsBad: false),
          ],
        ),
      ),
    );
  }

  Widget _exerciseCard(AppStore store, Session s, int exIdx) {
    final se = s.exercises[exIdx];
    final ex = store.life.exerciseById(se.exId);
    final pe = store.life.planFor(s, se.exId);
    final hint = store.life.progressionHint(pe, exceptSessionId: s.id);
    final allDone = se.sets.isNotEmpty && se.sets.every((x) => x.done);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        borderColor: allDone ? AppColors.good.withValues(alpha: 0.5) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name, style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('План: ${pe.scheme}${ex.timed ? ' с' : ''}', style: Txt.small),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Техника',
                  onPressed: () => _showTechnique(ex),
                  icon: const Icon(Icons.info_outline, color: AppColors.muted, size: 20),
                ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.trending_up, size: 15, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Expanded(child: Text(hint, style: Txt.small.copyWith(color: AppColors.accent2))),
                ],
              ),
            ],
            const SizedBox(height: 8),
            for (var i = 0; i < se.sets.length; i++)
              _SetRow(
                key: ValueKey('${s.id}_${exIdx}_$i'),
                index: i,
                set: se.sets[i],
                showWeight: !ex.bodyweight && !ex.timed,
                timed: ex.timed,
                onChanged: (v) => _updateSet(store, s, exIdx, i, v),
                onDone: (v) {
                  _updateSet(store, s, exIdx, i, v);
                  if (v.done) _startRest();
                },
              ),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _addSet(store, s, exIdx),
                  icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
                  label: const Text('Подход', style: TextStyle(color: AppColors.accent, fontSize: 13)),
                ),
                if (se.sets.length > 1)
                  TextButton.icon(
                    onPressed: () => _removeSet(store, s, exIdx),
                    icon: const Icon(Icons.remove, size: 16, color: AppColors.muted),
                    label: const Text('Убрать', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  final int index;
  final SetLog set;
  final bool showWeight;
  final bool timed;
  final ValueChanged<SetLog> onChanged;
  final ValueChanged<SetLog> onDone;

  const _SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.showWeight,
    required this.timed,
    required this.onChanged,
    required this.onDone,
  });

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController w =
      TextEditingController(text: widget.set.weight > 0 ? fmt1(widget.set.weight) : '');
  late final TextEditingController r =
      TextEditingController(text: widget.set.reps > 0 ? '${widget.set.reps}' : '');

  @override
  void dispose() {
    w.dispose();
    r.dispose();
    super.dispose();
  }

  SetLog _current({bool? done}) => SetLog(
        weight: parseNum(w.text) ?? 0,
        reps: (parseNum(r.text) ?? 0).round(),
        done: done ?? widget.set.done,
      );

  @override
  Widget build(BuildContext context) {
    final done = widget.set.done;
    InputDecoration deco(String suffix) => InputDecoration(
          isDense: true,
          filled: true,
          fillColor: done ? AppColors.good.withValues(alpha: 0.08) : AppColors.surface2,
          suffixText: suffix,
          suffixStyle: const TextStyle(color: AppColors.muted, fontSize: 12),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.accent)),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text('${widget.index + 1}', style: Txt.num(14, color: AppColors.muted)),
          ),
          if (widget.showWeight) ...[
            Expanded(
              child: TextField(
                controller: w,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: Txt.num(14, weight: FontWeight.w600),
                decoration: deco('кг'),
                onChanged: (_) => widget.onChanged(_current()),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: r,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: Txt.num(14, weight: FontWeight.w600),
              decoration: deco(widget.timed ? 'сек' : 'повт.'),
              onChanged: (_) => widget.onChanged(_current()),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () {
              FocusScope.of(context).unfocus();
              widget.onDone(_current(done: !done));
            },
            icon: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: done ? AppColors.good : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: done ? AppColors.good : AppColors.border, width: 2),
              ),
              child: done ? const Icon(Icons.check, size: 18, color: Colors.black) : null,
            ),
          ),
        ],
      ),
    );
  }
}
