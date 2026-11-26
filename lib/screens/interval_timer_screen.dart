import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/screen_on.dart';
import '../i18n/i18n.dart';

/// Отрезок интервальной тренировки.
class IntervalSeg {
  final String kind; // prep / work / rest
  final int seconds;
  final int round;
  const IntervalSeg(this.kind, this.seconds, this.round);
}

enum IntervalMode { tabata, emom, custom }

/// Расписание: подготовка 10 с, потом работа/отдых по кругу (после последнего круга отдыха нет).
List<IntervalSeg> buildIntervals(IntervalMode mode, {int work = 20, int rest = 10, int rounds = 8}) {
  final out = <IntervalSeg>[const IntervalSeg('prep', 10, 0)];
  switch (mode) {
    case IntervalMode.tabata:
      work = 20;
      rest = 10;
      rounds = 8;
    case IntervalMode.emom:
      work = 60;
      rest = 0;
    case IntervalMode.custom:
      break;
  }
  for (var r = 1; r <= rounds; r++) {
    out.add(IntervalSeg('work', work, r));
    if (rest > 0 && r < rounds) out.add(IntervalSeg('rest', rest, r));
  }
  return out;
}

/// Таймер для круговых: Табата, «каждую минуту» (EMOM) и свой интервал.
class IntervalTimerScreen extends StatefulWidget {
  const IntervalTimerScreen({super.key});

  @override
  State<IntervalTimerScreen> createState() => _IntervalTimerScreenState();
}

class _IntervalTimerScreenState extends State<IntervalTimerScreen> {
  IntervalMode mode = IntervalMode.tabata;
  int work = 40, rest = 20, rounds = 6, emomMinutes = 10;

  List<IntervalSeg> segs = const [];
  int index = 0; // текущий отрезок
  int elapsedMs = 0; // прошло в текущем отрезке
  bool running = false, done = false;
  Timer? _timer;
  DateTime? _last;
  int _lastBeepSec = -1;

  final _player = AudioPlayer();
  String? _beepShort, _beepLong;

  @override
  void initState() {
    super.initState();
    _prepareSounds();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _player.dispose();
    ScreenOn.set(false);
    super.dispose();
  }

  /// Сигналы делаем сами: синус 880 Гц (короткий) и 1320 Гц (длинный), WAV во временной папке.
  Future<void> _prepareSounds() async {
    try {
      final dir = await getTemporaryDirectory();
      Future<String> make(String name, double hz, int ms) async {
        final f = File('${dir.path}${Platform.pathSeparator}$name');
        if (!f.existsSync()) await f.writeAsBytes(_wav(hz, ms));
        return f.path;
      }

      _beepShort = await make('winter_beep_short.wav', 880, 140);
      _beepLong = await make('winter_beep_long.wav', 1320, 450);
    } catch (_) {}
  }

  static Uint8List _wav(double hz, int ms) {
    const rate = 22050;
    final n = rate * ms ~/ 1000;
    final b = BytesBuilder();
    void u32(int v) => b.add([v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255]);
    void u16(int v) => b.add([v & 255, (v >> 8) & 255]);
    b.add('RIFF'.codeUnits);
    u32(36 + n * 2);
    b.add('WAVEfmt '.codeUnits);
    u32(16);
    u16(1);
    u16(1);
    u32(rate);
    u32(rate * 2);
    u16(2);
    u16(16);
    b.add('data'.codeUnits);
    u32(n * 2);
    for (var i = 0; i < n; i++) {
      final fade = math.min(1.0, math.min(i, n - i) / (rate * 0.01));
      final v = (math.sin(2 * math.pi * hz * i / rate) * 0.6 * fade * 32767).round();
      u16(v & 0xFFFF);
    }
    return b.toBytes();
  }

  void _beep(bool long) {
    final p = long ? _beepLong : _beepShort;
    if (p != null) {
      _player.play(DeviceFileSource(p)).catchError((_) {});
    } else {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  List<IntervalSeg> _build() => switch (mode) {
        IntervalMode.tabata => buildIntervals(IntervalMode.tabata),
        IntervalMode.emom => buildIntervals(IntervalMode.emom, rounds: emomMinutes),
        IntervalMode.custom => buildIntervals(IntervalMode.custom, work: work, rest: rest, rounds: rounds),
      };

  void _start() {
    if (segs.isEmpty || done) {
      segs = _build();
      index = 0;
      elapsedMs = 0;
      done = false;
    }
    running = true;
    _last = DateTime.now();
    _lastBeepSec = -1;
    ScreenOn.set(true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    setState(() {});
  }

  void _pause() {
    _timer?.cancel();
    running = false;
    ScreenOn.set(false);
    setState(() {});
  }

  void _reset() {
    _timer?.cancel();
    running = false;
    done = false;
    segs = const [];
    index = 0;
    elapsedMs = 0;
    ScreenOn.set(false);
    setState(() {});
  }

  void _tick() {
    final now = DateTime.now();
    elapsedMs += now.difference(_last!).inMilliseconds;
    _last = now;
    var seg = segs[index];
    final left = seg.seconds * 1000 - elapsedMs;
    final leftSec = (left / 1000).ceil();
    if (leftSec <= 3 && leftSec >= 1 && leftSec != _lastBeepSec) {
      _lastBeepSec = leftSec;
      _beep(false);
    }
    if (left <= 0) {
      elapsedMs = -left;
      index++;
      _lastBeepSec = -1;
      HapticFeedback.heavyImpact();
      if (index >= segs.length) {
        _timer?.cancel();
        running = false;
        done = true;
        index = segs.length - 1;
        elapsedMs = segs.last.seconds * 1000;
        ScreenOn.set(false);
        _beep(true);
        Future.delayed(const Duration(milliseconds: 600), () => _beep(true));
      } else {
        seg = segs[index];
        _beep(seg.kind == 'work');
      }
    }
    if (mounted) setState(() {});
  }

  String _mmss(int sec) => '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';

  Widget _stepper(String label, int value, int min, int max, int step, String unit, void Function(int) set) => Row(children: [
        Expanded(child: Text(label, style: Txt.body)),
        IconButton(
          onPressed: value - step >= min ? () => setState(() => set(value - step)) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(width: 64, child: Text('$value $unit', textAlign: TextAlign.center, style: Txt.num(16))),
        IconButton(
          onPressed: value + step <= max ? () => setState(() => set(value + step)) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final active = segs.isNotEmpty;
    final seg = active ? segs[index] : null;
    final left = seg == null ? 0 : ((seg.seconds * 1000 - elapsedMs) / 1000).ceil().clamp(0, 9999);
    final totalLeft = !active
        ? _build().fold<int>(0, (s, x) => s + x.seconds)
        : segs.skip(index + 1).fold<int>(0, (s, x) => s + x.seconds) + left;
    final totalRounds = (active ? segs : _build()).where((s) => s.kind == 'work').length;
    final color = seg == null
        ? AppColors.muted
        : done
            ? AppColors.accent2
            : seg.kind == 'work'
                ? AppColors.accent
                : seg.kind == 'rest'
                    ? const Color(0xFF4FC3F7)
                    : AppColors.muted;
    final phase = done
        ? tr('Готово! 🔥')
        : seg == null
            ? tr('Нажми «Старт»')
            : switch (seg.kind) {
                'prep' => tr('Приготовься'),
                'work' => mode == IntervalMode.emom ? tr('Делай подход, остаток минуты — отдых') : tr('Работа'),
                _ => tr('Отдых'),
              };

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Таймер круговой')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          if (!active)
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final m in IntervalMode.values)
                Pill(
                  switch (m) {
                    IntervalMode.tabata => tr('Табата 20/10'),
                    IntervalMode.emom => tr('Каждую минуту'),
                    IntervalMode.custom => tr('Свой'),
                  },
                  color: m == mode ? AppColors.accent : AppColors.accent2,
                  onTap: () => setState(() => mode = m),
                ),
            ]),
          if (!active) ...[
            const SizedBox(height: 10),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  switch (mode) {
                    IntervalMode.tabata => tr('8 раундов: 20 секунд в полную силу, 10 секунд отдыха. Всего 4 минуты — '
                        'подходит для берпи, прыжков, приседаний, «альпиниста».'),
                    IntervalMode.emom => tr('В начале каждой минуты делай подход (например, 10 берпи или 15 приседаний), '
                        'оставшиеся секунды — отдых. Чем быстрее сделал, тем дольше отдыхаешь.'),
                    IntervalMode.custom => tr('Свои интервалы для круговой: например, 40 секунд работы и 20 секунд отдыха на каждое упражнение.'),
                  },
                  style: Txt.small,
                ),
                if (mode == IntervalMode.emom) ...[
                  const SizedBox(height: 8),
                  _stepper(tr('Минут'), emomMinutes, 3, 40, 1, tr('мин'), (v) => emomMinutes = v),
                ],
                if (mode == IntervalMode.custom) ...[
                  const SizedBox(height: 8),
                  _stepper(tr('Работа'), work, 10, 300, 5, tr('с'), (v) => work = v),
                  _stepper(tr('Отдых'), rest, 0, 300, 5, tr('с'), (v) => rest = v),
                  _stepper(tr('Раундов'), rounds, 1, 50, 1, '', (v) => rounds = v),
                ],
              ]),
            ),
          ],
          const SizedBox(height: 16),
          AppCard(
            child: Column(children: [
              Text(phase, style: Txt.h2.copyWith(color: color), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(seg == null ? _mmss(totalLeft) : _mmss(left), style: Txt.num(72).copyWith(color: color)),
              const SizedBox(height: 4),
              if (seg != null && seg.round > 0)
                Text(trf('Раунд {0} из {1}', [seg.round, totalRounds]), style: Txt.body)
              else
                Text(trf('Раундов: {0}', [totalRounds]), style: Txt.body),
              const SizedBox(height: 4),
              Text(trf('Осталось всего {0}', [_mmss(totalLeft)]), style: Txt.small),
              if (seg != null && !done) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (elapsedMs / (seg.seconds * 1000)).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: color,
                    backgroundColor: AppColors.surface2,
                  ),
                ),
              ],
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: PrimaryButton(
                running ? tr('Пауза') : (active && !done ? tr('Продолжить') : tr('Старт')),
                icon: running ? Icons.pause : Icons.play_arrow,
                onPressed: running ? _pause : _start,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 8),
              Expanded(child: GhostButton(tr('Сбросить'), icon: Icons.restart_alt, onPressed: _reset)),
            ],
          ]),
          const SizedBox(height: 12),
          Text(tr('Пищит за 3 секунды до смены, экран не гаснет. Звук — громкостью мультимедиа.'),
              style: Txt.small, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
