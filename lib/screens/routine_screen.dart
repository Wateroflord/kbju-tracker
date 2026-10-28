import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../learn/tts.dart';
import '../life/routines.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/screen_on.dart';
import '../i18n/i18n.dart';

IconData routineIcon(String k) => switch (k) {
      'stretch' => Icons.self_improvement,
      'morning' => Icons.wb_sunny_outlined,
      'back' => Icons.accessibility_new,
      _ => Icons.local_fire_department_outlined,
    };

String fmtMinSec(int sec) => '${sec ~/ 60}:${two(sec % 60)}';

/// Список разминок и растяжек.
class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final todayDone = life.routinesDone[todayKey()] ?? const [];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Разминка и растяжка')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            tr('Таймер сам переключает упражнения и называет их вслух. Разминка — перед тренировкой, растяжка — после.'),
            style: Txt.small,
          ),
          const SizedBox(height: 12),
          for (final r in routines)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RoutinePlayer(routine: r))),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(routineIcon(r.icon), color: AppColors.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(r.title), style: Txt.body.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(tr(r.desc), style: Txt.small),
                          const SizedBox(height: 4),
                          Text(
                            trf('{0} мин · {1} упражнений', [(r.totalSeconds / 60).round(), r.steps.length]),
                            style: Txt.small.copyWith(color: AppColors.accent2),
                          ),
                        ],
                      ),
                    ),
                    if (todayDone.contains(r.id)) const Icon(Icons.check_circle, color: AppColors.good, size: 20),
                    const Icon(Icons.play_arrow, color: AppColors.accent),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          Text(trf('Всего выполнено комплексов: {0}', [life.routinesTotal]), style: Txt.small),
        ],
      ),
    );
  }
}

/// Пошаговый таймер комплекса.
class RoutinePlayer extends StatefulWidget {
  final Routine routine;
  const RoutinePlayer({super.key, required this.routine});

  @override
  State<RoutinePlayer> createState() => _RoutinePlayerState();
}

class _RoutinePlayerState extends State<RoutinePlayer> {
  int step = 0;
  bool prep = true; // пауза «приготовься» перед упражнением
  late int left = 5;
  bool paused = false;
  bool finished = false;
  bool voice = true;
  Timer? _t;

  List<RoutineStep> get steps => widget.routine.steps;

  @override
  void initState() {
    super.initState();
    ScreenOn.set(true);
    _announce();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _t?.cancel();
    ScreenOn.set(false);
    Tts.stop();
    super.dispose();
  }

  void _say(String text) {
    if (voice) Tts.speak(text, appLang.code);
  }

  void _announce() {
    final s = steps[step];
    _say(prep ? trf('Приготовься: {0}', [tr(s.name)]) : tr(s.name));
  }

  void _tick() {
    if (paused || finished || !mounted) return;
    setState(() => left--);
    if (left > 0 && left <= 3) HapticFeedback.selectionClick();
    if (left > 0) return;
    if (prep) {
      HapticFeedback.heavyImpact();
      setState(() {
        prep = false;
        left = steps[step].seconds;
      });
      _say(tr('Начали'));
    } else {
      _next();
    }
  }

  void _next() {
    if (step >= steps.length - 1) {
      _finish();
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      step++;
      prep = true;
      left = routinePause;
    });
    _announce();
  }

  void _prev() {
    setState(() {
      if (!prep && left < steps[step].seconds - 2) {
        left = steps[step].seconds;
      } else if (step > 0) {
        step--;
        prep = false;
        left = steps[step].seconds;
      }
    });
  }

  void _finish() {
    HapticFeedback.heavyImpact();
    setState(() => finished = true);
    StoreScope.read(context).life.markRoutine(widget.routine.id);
    _say(tr('Готово! Отличная работа.'));
    ScreenOn.set(false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.routine;
    if (finished) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: subAppBar(tr(r.title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppColors.good, size: 72),
                const SizedBox(height: 16),
                Text(tr('Готово!'), style: Txt.h1),
                const SizedBox(height: 8),
                Text(trf('{0} — {1} мин', [tr(r.title), (r.totalSeconds / 60).round()]), style: Txt.small),
                const SizedBox(height: 24),
                PrimaryButton(tr('Закрыть'), icon: Icons.check, onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
        ),
      );
    }
    final s = steps[step];
    final total = prep ? routinePause : s.seconds;
    final ratio = 1 - left / (total == 0 ? 1 : total);
    final next = step + 1 < steps.length ? steps[step + 1] : null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr(r.title), actions: [
        IconButton(
          tooltip: tr('Голос'),
          icon: Icon(voice ? Icons.volume_up_outlined : Icons.volume_off_outlined),
          onPressed: () => setState(() {
            voice = !voice;
            if (!voice) Tts.stop();
          }),
        ),
      ]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            children: [
              ProgressLine(ratio: (step + (prep ? 0 : ratio)) / steps.length, color: AppColors.accent2, overIsBad: false, height: 4),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(trf('Упражнение {0} из {1}', [step + 1, steps.length]), style: Txt.small),
              ),
              const Spacer(),
              Text(prep ? tr('ПРИГОТОВЬСЯ') : tr('ВЫПОЛНЯЙ'), style: Txt.label.copyWith(color: prep ? AppColors.fat : AppColors.accent)),
              const SizedBox(height: 10),
              Text(tr(s.name), textAlign: TextAlign.center, style: Txt.h1.copyWith(fontSize: 24)),
              if (s.hint.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(tr(s.hint), textAlign: TextAlign.center, style: Txt.small.copyWith(fontSize: 14)),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: RingPainter(progress: ratio, color: prep ? AppColors.fat : AppColors.accent, stroke: 12),
                  child: Center(child: Text(fmtMinSec(left), style: Txt.num(44))),
                ),
              ),
              const Spacer(),
              if (next != null)
                Text(trf('Дальше: {0}', [tr(next.name)]), style: Txt.small, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SquareIconButton(Icons.skip_previous, tooltip: tr('Назад'), onTap: _prev),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () => setState(() => paused = !paused),
                      child: Icon(paused ? Icons.play_arrow : Icons.pause, size: 34, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SquareIconButton(Icons.skip_next, tooltip: tr('Дальше'), onTap: _next),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
