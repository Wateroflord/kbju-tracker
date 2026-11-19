import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../learn/tts.dart';
import '../common/ui.dart';
import 'counter.dart';
import 'pose_camera.dart';
import 'stats.dart';
import 'style.dart';

enum _Phase { calibrate, countdown, active }

/// Тренировка «до отказа»: считаем отжимания, пока не остановишься.
/// Подход заканчивается, если 10 секунд нет новых отжиманий, 10 секунд тебя нет в кадре, или по кнопке «Стоп».
class TrainingScreen extends StatefulWidget {
  const TrainingScreen({super.key});

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  static const _readyHoldMs = 1000; // сколько держать прямые руки перед стартом
  static const _pauseAfterMs = 3000; // пропал из кадра — пауза
  static const _endAfterMs = 10000; // пропал из кадра или нет повторов — конец подхода

  final _counter = RepCounter();
  final _clock = Stopwatch();
  Timer? _tick;
  _Phase _phase = _Phase.calibrate;
  int _countdown = 3;
  double? _smooth; // сглаженный угол
  int _lastSeenMs = 0;
  int? _straightSinceMs;
  int _activeStartMs = 0;
  bool _finished = false;
  int _hintUntilMs = 0;

  @override
  void initState() {
    super.initState();
    _clock.start();
    WakelockPlus.enable().catchError((_) {});
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) => _onTick());
  }

  @override
  void dispose() {
    _tick?.cancel();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  int get _now => _clock.elapsedMilliseconds;
  bool get _outOfFrame => _now - _lastSeenMs > _pauseAfterMs;

  void _onSample(PoseSample s) {
    if (_finished) return;
    final now = _now;
    final a = s.elbowAngle;
    if (a == null) {
      if (_phase == _Phase.calibrate) _straightSinceMs = null;
      setState(() {});
      return;
    }
    _lastSeenMs = now;
    _smooth = _smooth == null ? a : _smooth! * 0.5 + a * 0.5;
    final angle = _smooth!;

    switch (_phase) {
      case _Phase.calibrate:
        if (angle >= RepCounter.upAngle) {
          _straightSinceMs ??= now;
          if (now - _straightSinceMs! >= _readyHoldMs) _startCountdown();
        } else {
          _straightSinceMs = null;
        }
      case _Phase.countdown:
        break;
      case _Phase.active:
        final before = _counter.hint;
        if (_counter.update(angle, now)) {
          _onRep(_counter.reps);
        } else if (_counter.hint != before && _counter.hint != RepHint.none) {
          _hintUntilMs = now + 1500;
          HapticFeedback.heavyImpact();
        }
    }
    setState(() {});
  }

  void _startCountdown() {
    _phase = _Phase.countdown;
    _countdown = 3;
    Tts.speak('3', 'ru');
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _finished) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown > 0) {
        Tts.speak('$_countdown', 'ru');
      } else {
        t.cancel();
        Tts.speak('Старт', 'ru');
        HapticFeedback.heavyImpact();
        setState(() {
          _phase = _Phase.active;
          _counter.reset();
          _counter.ready = true; // руки уже прямые
          _activeStartMs = _now;
        });
      }
    });
  }

  void _onRep(int n) {
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    Tts.speak('$n', 'ru');
  }

  void _onTick() {
    if (_finished || _phase != _Phase.active) {
      if (mounted) setState(() {});
      return;
    }
    final now = _now;
    final last = _counter.lastRepMs ?? _activeStartMs;
    if (now - _lastSeenMs > _endAfterMs || now - last > _endAfterMs) {
      _finish();
      return;
    }
    setState(() {});
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _tick?.cancel();
    final reps = _phase == _Phase.active ? _counter.reps : 0;
    final ms = _phase == _Phase.active ? (_counter.lastRepMs ?? _now) - _activeStartMs : 0;
    final set = PushSet(DateTime.now(), reps, ms < 0 ? 0 : ms, _counter.rejected);
    final record = await PushStats.I.addSet(set);
    if (!mounted) return;
    Tts.speak(reps > 0 ? 'Готово. $reps' : 'Подход не засчитан', 'ru');
    await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ResultScreen(set: set, record: record)));
  }

  /// Секунд до автоматического конца подхода (показываем, когда меньше 5).
  int? get _autoEndIn {
    if (_phase != _Phase.active) return null;
    final now = _now;
    final last = _counter.lastRepMs ?? _activeStartMs;
    final left = _endAfterMs - (_outOfFrame ? now - _lastSeenMs : now - last);
    return left < 5000 ? (left / 1000).ceil().clamp(0, 5) : null;
  }

  @override
  Widget build(BuildContext context) {
    final hint = _now < _hintUntilMs ? hintText(_counter.hint) : '';
    final endIn = _autoEndIn;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PoseCamera(onSample: _onSample),
          // затемнение, чтобы цифры читались
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Color(0x00000000), Color(0x00000000), Color(0xCC000000)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    const Spacer(),
                    if (_smooth != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Text('угол ${_smooth!.round()}°', style: W.small),
                      ),
                  ],
                ),
                const Spacer(),
                ..._center(hint, endIn),
                const Spacer(),
                if (_phase == _Phase.active)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Arena.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                        onPressed: _finish,
                        child: const Text('Стоп', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _center(String hint, int? endIn) {
    switch (_phase) {
      case _Phase.calibrate:
        final holding = _straightSinceMs != null;
        return [
          const Icon(Icons.accessibility_new_rounded, size: 56, color: Arena.ice),
          const SizedBox(height: 12),
          Text(
            holding ? 'Держи…' : 'Встань в упор лёжа\nбоком к камере',
            style: Arena.title(26),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _now - _lastSeenMs > 1000 ? 'Камера тебя не видит — отойди подальше, чтобы были видны плечи и руки' : 'Выпрями руки — счёт начнётся сам',
            style: W.small,
            textAlign: TextAlign.center,
          ),
        ];
      case _Phase.countdown:
        return [Text(_countdown > 0 ? '$_countdown' : 'СТАРТ!', style: Arena.title(96))];
      case _Phase.active:
        return [
          Text('${_counter.reps}', style: Arena.title(120)),
          SizedBox(
            height: 40,
            child: Text(hint, style: Arena.title(28).copyWith(color: Arena.red)),
          ),
          if (_outOfFrame)
            Text('Вернись в кадр!', style: Arena.title(24).copyWith(color: W.warn))
          else if (_counter.rejected > 0)
            Text('не засчитано: ${_counter.rejected}', style: W.small),
          if (endIn != null) ...[
            const SizedBox(height: 8),
            Text('Конец подхода через $endIn…', style: W.body),
          ],
        ];
    }
  }
}

/// Итог подхода.
class ResultScreen extends StatelessWidget {
  final PushSet set;
  final bool record;
  const ResultScreen({super.key, required this.set, required this.record});

  @override
  Widget build(BuildContext context) {
    final s = PushStats.I;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              if (record) ...[
                Text('НОВЫЙ РЕКОРД!', style: Arena.title(30).copyWith(color: W.warn)),
                const SizedBox(height: 8),
              ],
              Text(set.reps > 0 ? 'ПОДХОД ЗАВЕРШЁН' : 'НЕ ЗАСЧИТАНО', style: Arena.title(26)),
              const SizedBox(height: 16),
              Text('${set.reps}', style: Arena.title(120)),
              Text('отжиманий', style: W.h2),
              const SizedBox(height: 24),
              WCard(
                child: Column(
                  children: [
                    _row('Время', fmtDuration(set.ms)),
                    _row('Не засчитано', '${set.rejected}'),
                    _row('Рекорд', '${s.best}'),
                    _row('Сегодня всего', '${s.today}'),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Arena.red, padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const TrainingScreen())),
                  child: const Text('Ещё подход', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('В меню')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [Text(k, style: W.body), const Spacer(), Text(v, style: W.h2)]),
      );
}
