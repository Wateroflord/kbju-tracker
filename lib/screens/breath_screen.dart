import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../learn/tts.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/screen_on.dart';
import '../i18n/i18n.dart';

enum BreathPhase { inhale, hold, exhale, holdOut }

class BreathTechnique {
  final String id;
  final String title;
  final String desc;
  final List<(BreathPhase, int)> pattern;
  const BreathTechnique(this.id, this.title, this.desc, this.pattern);

  int get cycleSeconds => pattern.fold(0, (s, p) => s + p.$2);
}

const breathTechniques = [
  BreathTechnique('box', 'Квадратное дыхание 4-4-4-4', 'Успокаивает и помогает сосредоточиться. Подходит перед работой или экзаменом.', [
    (BreathPhase.inhale, 4),
    (BreathPhase.hold, 4),
    (BreathPhase.exhale, 4),
    (BreathPhase.holdOut, 4),
  ]),
  BreathTechnique('478', 'Дыхание 4-7-8', 'Длинный выдох расслабляет. Хорошо делать в кровати перед сном.', [
    (BreathPhase.inhale, 4),
    (BreathPhase.hold, 7),
    (BreathPhase.exhale, 8),
  ]),
  BreathTechnique('coherent', 'Ровное дыхание 5-5', 'Около 6 вдохов в минуту — снижает стресс. Можно делать в любое время.', [
    (BreathPhase.inhale, 5),
    (BreathPhase.exhale, 5),
  ]),
  BreathTechnique('sigh', 'Двойной вдох и долгий выдох', 'Самый быстрый способ снять напряжение: 1–2 минуты.', [
    (BreathPhase.inhale, 2),
    (BreathPhase.inhale, 1),
    (BreathPhase.exhale, 6),
  ]),
];

String phaseTitle(BreathPhase p) => switch (p) {
      BreathPhase.inhale => tr('Вдох'),
      BreathPhase.hold => tr('Задержка'),
      BreathPhase.exhale => tr('Выдох'),
      BreathPhase.holdOut => tr('Пауза'),
    };

/// Дыхание и медитация.
class BreathScreen extends StatefulWidget {
  const BreathScreen({super.key});

  @override
  State<BreathScreen> createState() => _BreathScreenState();
}

class _BreathScreenState extends State<BreathScreen> {
  int minutes = 3;

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final todayMin = life.mindSecondsOn(todayKey()) ~/ 60;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Дыхание и медитация')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(
            children: [
              Expanded(child: StatTile(label: tr('Сегодня'), value: '$todayMin', sub: tr('минут'), color: AppColors.accent)),
              const SizedBox(width: 8),
              Expanded(child: StatTile(label: tr('Всего'), value: '${life.mindTotalMinutes}', sub: tr('минут'))),
            ],
          ),
          SectionLabel(tr('Длительность')),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in const [1, 3, 5, 10, 15, 20])
                Pill(trf('{0} мин', [m]),
                    color: m == minutes ? AppColors.accent : AppColors.accent2, onTap: () => setState(() => minutes = m)),
            ],
          ),
          SectionLabel(tr('Дыхательные техники')),
          for (final t in breathTechniques)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => BreathPlayer(technique: t, minutes: minutes)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.air, color: AppColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(t.title), style: Txt.body.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(tr(t.desc), style: Txt.small),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_arrow, color: AppColors.accent),
                  ],
                ),
              ),
            ),
          SectionLabel(tr('Медитация')),
          AppCard(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MeditationPlayer(minutes: minutes))),
            child: Row(
              children: [
                const Icon(Icons.self_improvement, color: AppColors.accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(trf('Тихий таймер · {0} мин', [minutes]), style: Txt.body.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(tr('Сядь удобно и следи за дыханием. Мысли уводят — мягко возвращайся. Вибрация в конце.'),
                          style: Txt.small),
                    ],
                  ),
                ),
                const Icon(Icons.play_arrow, color: AppColors.accent),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('Если кружится голова — вернись к обычному дыханию. Даже 3 минуты в день заметно снижают стресс.'),
            style: Txt.small,
          ),
        ],
      ),
    );
  }
}

/// Анимированный круг дыхания.
class BreathPlayer extends StatefulWidget {
  final BreathTechnique technique;
  final int minutes;
  const BreathPlayer({super.key, required this.technique, required this.minutes});

  @override
  State<BreathPlayer> createState() => _BreathPlayerState();
}

class _BreathPlayerState extends State<BreathPlayer> with SingleTickerProviderStateMixin {
  late final AnimationController anim = AnimationController(vsync: this, value: 0.35);
  int phase = 0;
  int phaseLeft = 0;
  int elapsed = 0;
  bool paused = false;
  bool done = false;
  bool voice = false;
  Timer? _t;
  late final AppStore _store;

  List<(BreathPhase, int)> get pattern => widget.technique.pattern;
  int get total => widget.minutes * 60;

  @override
  void initState() {
    super.initState();
    _store = StoreScope.read(context);
    ScreenOn.set(true);
    _startPhase(0);
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _t?.cancel();
    anim.dispose();
    _save();
    ScreenOn.set(false);
    Tts.stop();
    super.dispose();
  }

  int _saved = 0;
  void _save() {
    final d = elapsed - _saved;
    if (d > 0) {
      _saved = elapsed;
      _store.life.addMindSeconds(d);
    }
  }

  void _startPhase(int i) {
    phase = i;
    final (p, sec) = pattern[i];
    phaseLeft = sec;
    final target = switch (p) {
      BreathPhase.inhale => (i > 0 && pattern[i - 1].$1 == BreathPhase.inhale) ? 1.0 : 0.85,
      BreathPhase.exhale => 0.35,
      _ => anim.value,
    };
    anim.animateTo(target, duration: Duration(seconds: sec), curve: Curves.easeInOut);
    HapticFeedback.lightImpact();
    if (voice) Tts.speak(phaseTitle(p), appLang.code);
  }

  void _tick() {
    if (paused || done || !mounted) return;
    setState(() {
      elapsed++;
      phaseLeft--;
    });
    if (elapsed >= total && phase == pattern.length - 1 && phaseLeft <= 0 || elapsed >= total + 20) {
      _finish();
      return;
    }
    if (phaseLeft <= 0) _startPhase((phase + 1) % pattern.length);
  }

  void _finish() {
    HapticFeedback.heavyImpact();
    _save();
    setState(() => done = true);
    anim.animateTo(0.6, duration: const Duration(seconds: 1));
    ScreenOn.set(false);
  }

  void _togglePause() {
    setState(() => paused = !paused);
    if (paused) {
      anim.stop();
    } else {
      _startPhase(phase);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (p, _) = pattern[phase];
    final left = (total - elapsed).clamp(0, total);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr(widget.technique.title), actions: [
        IconButton(
          tooltip: tr('Голос'),
          icon: Icon(voice ? Icons.volume_up_outlined : Icons.volume_off_outlined),
          onPressed: () => setState(() => voice = !voice),
        ),
      ]),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ProgressLine(ratio: elapsed / total, color: AppColors.accent2, overIsBad: false, height: 4),
              const SizedBox(height: 6),
              Align(alignment: Alignment.centerRight, child: Text(_mmss(left), style: Txt.num(14, color: AppColors.muted))),
              const Spacer(),
              SizedBox(
                width: 280,
                height: 280,
                child: AnimatedBuilder(
                  animation: anim,
                  builder: (_, __) => Center(
                    child: Container(
                      width: 280 * anim.value,
                      height: 280 * anim.value,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.15),
                        border: Border.all(color: AppColors.accent, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: done
                          ? const Icon(Icons.check, color: AppColors.good, size: 48)
                          : Text('$phaseLeft', style: Txt.num(40)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(done ? tr('Готово!') : (paused ? tr('Пауза') : phaseTitle(p)), style: Txt.h1),
              const SizedBox(height: 6),
              Text(
                done
                    ? trf('{0} мин спокойного дыхания', [widget.minutes])
                    : (p == BreathPhase.inhale ? tr('через нос') : (p == BreathPhase.exhale ? tr('медленно, через рот') : '')),
                style: Txt.small,
              ),
              const Spacer(),
              if (done)
                PrimaryButton(tr('Закрыть'), icon: Icons.check, onPressed: () => Navigator.pop(context))
              else
                SizedBox(
                  width: 72,
                  height: 72,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent, shape: const CircleBorder(), padding: EdgeInsets.zero),
                    onPressed: _togglePause,
                    child: Icon(paused ? Icons.play_arrow : Icons.pause, size: 34, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _mmss(int sec) => '${sec ~/ 60}:${two(sec % 60)}';

/// Тихий таймер медитации.
class MeditationPlayer extends StatefulWidget {
  final int minutes;
  const MeditationPlayer({super.key, required this.minutes});

  @override
  State<MeditationPlayer> createState() => _MeditationPlayerState();
}

class _MeditationPlayerState extends State<MeditationPlayer> {
  int elapsed = 0;
  bool paused = false;
  bool done = false;
  Timer? _t;
  int _saved = 0;
  late final AppStore _store;

  int get total => widget.minutes * 60;

  static const _hints = [
    'Сядь удобно, спина прямая, плечи расслаблены.',
    'Закрой глаза. Почувствуй, как воздух входит и выходит.',
    'Считай выдохи от 1 до 10, потом начинай сначала.',
    'Мысли уводят — это нормально. Просто вернись к дыханию.',
    'Заметь, где в теле напряжение, и отпусти его на выдохе.',
  ];

  @override
  void initState() {
    super.initState();
    _store = StoreScope.read(context);
    ScreenOn.set(true);
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (paused || done || !mounted) return;
      setState(() => elapsed++);
      if (elapsed % 60 == 0 && elapsed < total) HapticFeedback.selectionClick();
      if (elapsed >= total) _finish();
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _save();
    ScreenOn.set(false);
    super.dispose();
  }

  void _save() {
    final d = elapsed - _saved;
    if (d > 0) {
      _saved = elapsed;
      _store.life.addMindSeconds(d);
    }
  }

  void _finish() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 400), HapticFeedback.heavyImpact);
    _save();
    setState(() => done = true);
    ScreenOn.set(false);
  }

  @override
  Widget build(BuildContext context) {
    final left = (total - elapsed).clamp(0, total);
    final hint = _hints[(elapsed ~/ 45) % _hints.length];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Медитация')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              SizedBox(
                width: 240,
                height: 240,
                child: CustomPaint(
                  painter: RingPainter(progress: elapsed / total, color: AppColors.accent2, stroke: 6),
                  child: Center(
                    child: done
                        ? const Icon(Icons.check, color: AppColors.good, size: 56)
                        : Text(_mmss(left), style: Txt.num(44, weight: FontWeight.w300)),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: Text(
                  done ? trf('{0} мин тишины. Хорошая работа.', [widget.minutes]) : tr(hint),
                  key: ValueKey(done ? 'done' : hint),
                  textAlign: TextAlign.center,
                  style: Txt.body.copyWith(color: AppColors.accent2, height: 1.4),
                ),
              ),
              const Spacer(),
              if (done)
                PrimaryButton(tr('Закрыть'), icon: Icons.check, onPressed: () => Navigator.pop(context))
              else
                GhostButton(paused ? tr('Продолжить') : tr('Пауза'),
                    icon: paused ? Icons.play_arrow : Icons.pause, onPressed: () => setState(() => paused = !paused)),
            ],
          ),
        ),
      ),
    );
  }
}
