import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../platform.dart';

import '../common/ui.dart';
import '../common/wav.dart';
import 'chords.dart';
import 'pitch.dart';
import 'sound.dart';

const _accent = Color(0xFFFFB35C);

class GuitarApp extends StatelessWidget {
  const GuitarApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Winter Guitar',
        debugShowCheckedModeBanner: false,
        theme: winterTheme(_accent),
        home: const _Home(),
      );
}

/// Настройки плагина (строй, темп, рекорды тренажёра).
class GuitarStore {
  static final _store = JsonStore('guitar.json');
  static Map<String, dynamic> data = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    data = await _store.read();
    _loaded = true;
  }

  static Future<void> set(String k, Object? v) async {
    data[k] = v;
    await _store.write(data);
  }

  static int get(String k, int def) => (data[k] as num?)?.toInt() ?? def;
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  int tab = 0;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    GuitarStore.load().then((_) => mounted ? setState(() => loaded = true) : null);
  }

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: tab, children: [
          TunerScreen(active: tab == 0),
          MetronomeScreen(active: tab == 1),
          const ChordsScreen(),
          const ChangesTrainer(),
        ]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        backgroundColor: W.surface,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.tune), label: 'Тюнер'),
          NavigationDestination(icon: Icon(Icons.av_timer), label: 'Метроном'),
          NavigationDestination(icon: Icon(Icons.grid_on), label: 'Аккорды'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Тренажёр'),
        ],
      ),
    );
  }
}

// ───────────────────────────── Тюнер ─────────────────────────────

class TunerScreen extends StatefulWidget {
  final bool active;
  const TunerScreen({super.key, required this.active});

  @override
  State<TunerScreen> createState() => _TunerScreenState();
}

class _TunerScreenState extends State<TunerScreen> with WidgetsBindingObserver {
  static const _rate = 44100;
  AudioRecorder? _rec;
  StreamSubscription<Uint8List>? _sub;
  final _player = AudioPlayer();
  final _buf = Float64List(2048); // после прореживания: 22050 Гц
  int _filled = 0, _sinceLast = 0;
  final List<double> _recent = [];
  DateTime _lastHeard = DateTime(2000);
  DateTime? _inTuneSince;

  bool listening = false, needAsk = false;
  String? error;
  double? hz;
  int tuningIndex = 0;
  int? lockedString; // null — автоопределение струны

  Tuning get tuning => tunings[tuningIndex.clamp(0, tunings.length - 1)];

  @override
  void initState() {
    super.initState();
    tuningIndex = GuitarStore.get('tuning', 0);
    WidgetsBinding.instance.addObserver(this);
    if (widget.active) _autoStart();
  }

  @override
  void didUpdateWidget(TunerScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _autoStart();
    if (!widget.active && old.active) _stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _stop();
    if (state == AppLifecycleState.resumed && widget.active) _autoStart();
  }

  /// Сам включаем микрофон, только если доступ уже дали. Спрашивать — только по кнопке,
  /// иначе окно разрешения выскакивало бы при каждом открытии (и снова после «Запретить»).
  Future<void> _autoStart() async {
    if (listening) return;
    if (isAndroid) {
      try {
        if (!await Permission.microphone.isGranted) {
          if (mounted) setState(() => needAsk = true);
          return;
        }
      } catch (_) {}
    }
    await _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    if (listening) return;
    try {
      final rec = _rec ??= AudioRecorder();
      if (!await rec.hasPermission()) {
        if (!mounted) return;
        final forever = isAndroid && await Permission.microphone.isPermanentlyDenied;
        setState(() {
          needAsk = false;
          error = forever
              ? 'Доступ к микрофону запрещён. Включи его: Настройки телефона → Приложения → КБЖУ Трекер → Разрешения → Микрофон.'
              : 'Без микрофона тюнер не слышит гитару. Нажми «Разрешить микрофон» ещё раз.';
        });
        return;
      }
      needAsk = false;
      final stream = await rec.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _rate,
        numChannels: 1,
        echoCancel: false,
        noiseSuppress: false,
        autoGain: false,
      ));
      _sub = stream.listen(_onData, onError: (Object e) => setState(() => error = 'Микрофон: $e'));
      setState(() {
        listening = true;
        error = null;
      });
    } catch (e) {
      setState(() => error = 'Не удалось включить микрофон: $e');
    }
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _rec?.stop();
    } catch (_) {}
    if (mounted) setState(() => listening = false);
  }

  void _onData(Uint8List bytes) {
    final s = pcm16ToFloat(bytes);
    // Прореживание 44,1 → 22,05 кГц (среднее пары — заодно простой фильтр).
    for (var i = 0; i + 1 < s.length; i += 2) {
      final v = (s[i] + s[i + 1]) / 2;
      if (_filled < _buf.length) {
        _buf[_filled++] = v;
      } else {
        _buf.setRange(0, _buf.length - 1, _buf, 1);
        _buf[_buf.length - 1] = v;
      }
      _sinceLast++;
    }
    if (_filled < _buf.length || _sinceLast < 1024) return;
    _sinceLast = 0;
    final f = detectPitch(_buf, _rate ~/ 2, minHz: 60, maxHz: 1000);
    final now = DateTime.now();
    if (f != null) {
      _recent.add(f);
      if (_recent.length > 5) _recent.removeAt(0);
      final sorted = [..._recent]..sort();
      _lastHeard = now;
      setState(() => hz = sorted[sorted.length ~/ 2]);
    } else if (hz != null && now.difference(_lastHeard).inMilliseconds > 900) {
      _recent.clear();
      _inTuneSince = null;
      setState(() => hz = null);
    }
  }

  Future<void> _playString(int i) async {
    final midi = tuning.midi[i];
    try {
      final path = await tempSound('winter_guitar_$midi.wav', () => pluckWav(hzOfMidi(midi)));
      await _player.stop();
      await _player.play(DeviceFileSource(path));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final f = hz;
    final target = f == null ? lockedString : (lockedString ?? nearestString(tuning, f));
    int? midi;
    double? cents;
    if (f != null) {
      midi = target != null ? tuning.midi[target] : midiOf(f).round();
      // Если звучит не та октава (флажолет / другая струна) — показываем ближайшую ноту.
      final c = centsOff(f, midi);
      if (c.abs() > 350) midi = midiOf(f).round();
      cents = centsOff(f, midi).clamp(-50.0, 50.0);
    }
    final inTune = cents != null && cents.abs() <= 5;
    if (inTune) {
      final was = _inTuneSince;
      _inTuneSince ??= DateTime.now();
      if (was == null) HapticFeedback.lightImpact();
    } else {
      _inTuneSince = null;
    }
    final color = cents == null ? W.muted : (inTune ? W.good : (cents.abs() < 15 ? W.warn : W.bad));

    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Row(children: [
        const Expanded(child: Text('Тюнер', style: W.h1)),
        Icon(listening ? Icons.mic : Icons.mic_off, color: listening ? W.good : W.muted),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < tunings.length; i++)
          Chip2(tunings[i].name, selected: tuningIndex == i, onTap: () {
            setState(() {
              tuningIndex = i;
              lockedString = null;
            });
            GuitarStore.set('tuning', i);
          }),
      ]),
      if (needAsk && error == null) ...[
        const SizedBox(height: 12),
        WCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Тюнер слушает гитару через микрофон. Звук никуда не отправляется и не записывается.', style: W.body),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _start, icon: const Icon(Icons.mic), label: const Text('Включить микрофон')),
          ]),
        ),
      ],
      if (error != null) ...[
        const SizedBox(height: 12),
        WCard(
          borderColor: W.bad,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(error!, style: W.body),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton(onPressed: _start, child: const Text('Разрешить микрофон')),
              if (isAndroid) OutlinedButton(onPressed: openAppSettings, child: const Text('Настройки')),
            ]),
          ]),
        ),
      ],
      const SizedBox(height: 18),
      Center(
        child: Text(
          midi == null ? '—' : noteName(midi),
          style: TextStyle(fontSize: 72, fontWeight: FontWeight.w900, color: color, height: 1),
        ),
      ),
      const SizedBox(height: 4),
      Center(
        child: Text(
          f == null
              ? (listening ? 'Дёрни струну' : 'Микрофон выключен')
              : '${f.toStringAsFixed(1)} Гц · ${cents! >= 0 ? '+' : ''}${cents.round()} центов',
          style: W.small,
        ),
      ),
      const SizedBox(height: 14),
      SizedBox(height: 90, child: CustomPaint(painter: _Needle(cents, color), size: const Size(double.infinity, 90))),
      const SizedBox(height: 6),
      Center(
        child: Text(
          cents == null
              ? ' '
              : inTune
                  ? 'В строю ✓'
                  : (cents < 0 ? 'Низко — подтяни колок' : 'Высоко — ослабь колок'),
          style: W.h2.copyWith(color: color),
        ),
      ),
      const SizedBox(height: 20),
      Row(children: [
        for (var i = 0; i < 6; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _StringButton(
                label: noteNames[tuning.midi[i] % 12],
                number: 6 - i,
                selected: target == i,
                locked: lockedString == i,
                onTap: () {
                  setState(() => lockedString = lockedString == i ? null : i);
                  _playString(i);
                },
              ),
            ),
          ),
      ]),
      const SizedBox(height: 10),
      Text(
        lockedString == null
            ? 'Струна определяется сама. Нажми на струну, чтобы услышать, как она должна звучать, и закрепить её.'
            : 'Закреплена ${6 - lockedString!}-я струна. Нажми ещё раз — снова авто.',
        style: W.small,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      const WCard(
        child: Text(
          'Совет: настраивай снизу вверх (с 6-й струны), подтягивая к ноте — не сверху вниз. '
          'Так струна меньше «уходит». В шумном месте поднеси телефон ближе к гитаре.',
          style: W.small,
        ),
      ),
    ]);
  }
}

class _StringButton extends StatelessWidget {
  final String label;
  final int number;
  final bool selected, locked;
  final VoidCallback onTap;
  const _StringButton({required this.label, required this.number, required this.selected, required this.locked, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? W.accent.withValues(alpha: 0.22) : W.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: locked ? W.accent : (selected ? W.accent.withValues(alpha: 0.6) : W.border), width: locked ? 2 : 1),
            ),
            child: Column(children: [
              Text(label, style: W.h2.copyWith(color: selected ? W.accent : W.text)),
              Text('$number', style: W.small),
            ]),
          ),
        ),
      );
}

class _Needle extends CustomPainter {
  final double? cents;
  final Color color;
  _Needle(this.cents, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height - 6);
    final radius = math.min(size.width / 2 - 10, size.height - 12);
    final arc = Paint()
      ..color = W.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const sweep = math.pi * 0.7;
    const start = -math.pi / 2 - sweep / 2;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, arc);
    // Зелёная зона ±5 центов.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2 - sweep * 5 / 100,
      sweep * 10 / 100,
      false,
      Paint()
        ..color = W.good
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6,
    );
    for (var c = -50; c <= 50; c += 10) {
      final a = -math.pi / 2 + sweep * c / 100;
      final o = center + Offset(math.cos(a), math.sin(a)) * radius;
      final i = center + Offset(math.cos(a), math.sin(a)) * (radius - (c == 0 ? 14 : 8));
      canvas.drawLine(i, o, Paint()
        ..color = W.muted
        ..strokeWidth = c == 0 ? 2.5 : 1.2);
    }
    if (cents != null) {
      final a = -math.pi / 2 + sweep * cents! / 100;
      final tip = center + Offset(math.cos(a), math.sin(a)) * (radius - 4);
      canvas.drawLine(center, tip, Paint()
        ..color = color
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round);
    }
    canvas.drawCircle(center, 6, Paint()..color = cents == null ? W.muted : color);
  }

  @override
  bool shouldRepaint(_Needle old) => old.cents != cents || old.color != color;
}

// ───────────────────────────── Метроном ─────────────────────────────

class MetronomeScreen extends StatefulWidget {
  final bool active;
  const MetronomeScreen({super.key, required this.active});

  @override
  State<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends State<MetronomeScreen> {
  final _player = AudioPlayer();
  int bpm = 90, beats = 4;
  bool playing = false, accent = true;
  final _clock = Stopwatch();
  Timer? _ui;
  int beat = -1;
  final List<DateTime> _taps = [];
  Timer? _restart;
  String? _lastPath;

  @override
  void initState() {
    super.initState();
    bpm = GuitarStore.get('bpm', 90).clamp(30, 240);
    beats = GuitarStore.get('beats', 4);
    accent = GuitarStore.data['accent'] != false;
    _player.setReleaseMode(ReleaseMode.loop);
  }

  @override
  void didUpdateWidget(MetronomeScreen old) {
    super.didUpdateWidget(old);
    if (!widget.active && playing) _stopPlay();
  }

  @override
  void dispose() {
    _ui?.cancel();
    _restart?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startPlay() async {
    try {
      // Своё имя файла на каждый темп: плеер не перепутает старый звук с новым.
      final path = await tempSound('winter_metronome_${bpm}_${beats}_${accent ? 1 : 0}.wav', () => metronomeWav(bpm, beats, accent: accent));
      await _player.stop();
      await _player.play(DeviceFileSource(path));
      final old = _lastPath;
      _lastPath = path;
      if (old != null && old != path) File(old).delete().catchError((_) => File(old));
      _clock
        ..reset()
        ..start();
      _ui?.cancel();
      final spb = samplesPerBeat(bpm) / soundRate * 1000; // мс на долю
      _ui = Timer.periodic(const Duration(milliseconds: 20), (_) {
        final b = (_clock.elapsedMilliseconds / spb).floor() % beats;
        if (b != beat && mounted) setState(() => beat = b);
      });
      setState(() => playing = true);
    } catch (e) {
      if (mounted) toast(context, 'Звук не запустился: $e');
    }
  }

  Future<void> _stopPlay() async {
    _ui?.cancel();
    _clock.stop();
    await _player.stop();
    if (mounted) {
      setState(() {
        playing = false;
        beat = -1;
      });
    }
  }

  void _change({int? newBpm, int? newBeats, bool? newAccent}) {
    setState(() {
      if (newBpm != null) bpm = newBpm.clamp(30, 240);
      if (newBeats != null) beats = newBeats;
      if (newAccent != null) accent = newAccent;
    });
    GuitarStore.set('bpm', bpm);
    GuitarStore.set('beats', beats);
    GuitarStore.set('accent', accent);
    if (playing) {
      // Ползунок шлёт много значений подряд — перезапускаем звук, когда палец остановился.
      _restart?.cancel();
      _restart = Timer(const Duration(milliseconds: 350), _startPlay);
    }
  }

  void _tap() {
    final now = DateTime.now();
    if (_taps.isNotEmpty && now.difference(_taps.last).inMilliseconds > 2000) _taps.clear();
    _taps.add(now);
    if (_taps.length > 6) _taps.removeAt(0);
    if (_taps.length >= 3) {
      final ms = _taps.last.difference(_taps.first).inMilliseconds / (_taps.length - 1);
      _change(newBpm: (60000 / ms).round());
    }
    HapticFeedback.selectionClick();
  }

  String get _tempoName => switch (bpm) {
        < 60 => 'Ларго — очень медленно',
        < 76 => 'Адажио — медленно',
        < 108 => 'Андante / модерато — спокойно',
        < 140 => 'Аллегро — быстро',
        _ => 'Престо — очень быстро',
      };

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        const Text('Метроном', style: W.h1),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 0; i < beats; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 60),
              margin: const EdgeInsets.symmetric(horizontal: 6),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: beat == i ? (i == 0 && accent ? W.accent : W.ice) : W.surface2,
                border: Border.all(color: W.border),
              ),
            ),
        ]),
        const SizedBox(height: 22),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton.filledTonal(onPressed: () => _change(newBpm: bpm - 5), icon: const Text('−5')),
          IconButton(onPressed: () => _change(newBpm: bpm - 1), icon: const Icon(Icons.remove)),
          SizedBox(
            width: 120,
            child: Column(children: [
              Text('$bpm', style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: W.text, height: 1)),
              const Text('ударов в минуту', style: W.small),
            ]),
          ),
          IconButton(onPressed: () => _change(newBpm: bpm + 1), icon: const Icon(Icons.add)),
          IconButton.filledTonal(onPressed: () => _change(newBpm: bpm + 5), icon: const Text('+5')),
        ]),
        Slider(value: bpm.toDouble(), min: 30, max: 240, divisions: 210, onChanged: (v) => _change(newBpm: v.round())),
        Center(child: Text(_tempoName, style: W.small)),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (final b in [2, 3, 4, 6]) Chip2('$b/4', selected: beats == b, onTap: () => _change(newBeats: b)),
          Chip2('Акцент на 1', selected: accent, onTap: () => _change(newAccent: !accent)),
        ]),
        const SizedBox(height: 22),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: playing ? _stopPlay : _startPlay,
            icon: Icon(playing ? Icons.stop : Icons.play_arrow),
            label: Text(playing ? 'Стоп' : 'Старт', style: const TextStyle(fontSize: 18)),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: OutlinedButton(onPressed: _tap, child: const Text('Настучать темп (TAP)')),
        ),
        const SizedBox(height: 16),
        const WCard(
          child: Text(
            'Учишь новый кусок — поставь темп пониже, где получается чисто, и поднимай на 5 ударов, '
            'когда сыграешь 3 раза подряд без ошибок.',
            style: W.small,
          ),
        ),
      ]);
}

// ───────────────────────────── Аккорды ─────────────────────────────

class ChordsScreen extends StatelessWidget {
  const ChordsScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        const Text('Аккорды', style: W.h1),
        const SizedBox(height: 4),
        const Text('Слева — 6-я (толстая) струна. Цифра в кружке — палец: 1 указательный, 2 средний, 3 безымянный, 4 мизинец. '
            '× — струну не играть, ○ — открытая.', style: W.small),
        for (final g in chordGroups) ...[
          Section(g.title),
          Text(g.hint, style: W.small),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.72,
            children: [
              for (final c in g.chords)
                WCard(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
                  onTap: () => _open(context, c),
                  child: Column(children: [
                    Text(c.name, style: W.h2.copyWith(color: W.accent)),
                    const SizedBox(height: 4),
                    Expanded(child: FittedBox(child: ChordDiagram(c, width: 90))),
                  ]),
                ),
            ],
          ),
        ],
      ]);

  void _open(BuildContext context, Chord c) => showModalBottomSheet(
        context: context,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(c.name, style: W.h1.copyWith(color: W.accent)),
              const SizedBox(height: 12),
              ChordDiagram(c, width: 200),
              const SizedBox(height: 12),
              Text(
                'Струны (с 6-й): ${c.frets.map((f) => f < 0 ? '×' : '$f').join(' ')}',
                style: W.body,
              ),
            ]),
          ),
        ),
      );
}

// ───────────────────────── Тренажёр смены аккордов ─────────────────────────

/// «Минута смен»: сколько раз за минуту успеешь переставить пальцы между двумя аккордами.
class ChangesTrainer extends StatefulWidget {
  const ChangesTrainer({super.key});

  @override
  State<ChangesTrainer> createState() => _ChangesTrainerState();
}

class _ChangesTrainerState extends State<ChangesTrainer> {
  static const _seconds = 60;
  String a = 'Am', b = 'C';
  int count = 0, left = _seconds;
  bool running = false, finished = false;
  Timer? _t;

  String get _key => 'best_${[a, b]..sort()}';
  int get best => GuitarStore.get(_key, 0);

  @override
  void initState() {
    super.initState();
    a = GuitarStore.data['pairA']?.toString() ?? 'Am';
    b = GuitarStore.data['pairB']?.toString() ?? 'C';
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      count = 0;
      left = _seconds;
      running = true;
      finished = false;
    });
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => left--);
      if (left <= 3 && left > 0) HapticFeedback.selectionClick();
      if (left <= 0) _finish();
    });
  }

  Future<void> _finish() async {
    _t?.cancel();
    HapticFeedback.heavyImpact();
    final record = count > best;
    if (record) await GuitarStore.set(_key, count);
    final hist = List<dynamic>.from(GuitarStore.data['history'] as List? ?? []);
    hist.insert(0, {'a': a, 'b': b, 'n': count, 't': DateTime.now().millisecondsSinceEpoch});
    await GuitarStore.set('history', hist.take(30).toList());
    if (!mounted) return;
    setState(() {
      running = false;
      finished = true;
    });
    if (record && count > 0) toast(context, 'Новый рекорд: $count смен! 🎸');
  }

  Future<void> _pick(bool first) async {
    final name = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final ch in allChords) Chip2(ch.name, selected: (first ? a : b) == ch.name, onTap: () => Navigator.pop(c, ch.name)),
          ]),
        ),
      ),
    );
    if (name == null) return;
    setState(() => first ? a = name : b = name);
    GuitarStore.set(first ? 'pairA' : 'pairB', name);
  }

  @override
  Widget build(BuildContext context) {
    final ca = chordByName(a), cb = chordByName(b);
    final hist = (GuitarStore.data['history'] as List? ?? []).whereType<Map>().take(5).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      const Text('Смена аккордов', style: W.h1),
      const SizedBox(height: 4),
      const Text(
        'Самое полезное упражнение для начинающих: минуту переставляешь пальцы между двумя аккордами '
        '(ударь по струнам один раз на каждый) и жмёшь большую кнопку после каждой смены. Каждый день — новый рекорд.',
        style: W.small,
      ),
      const SizedBox(height: 14),
      Row(children: [
        for (final (i, c) in [(true, ca), (false, cb)])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: WCard(
                onTap: running ? null : () => _pick(i),
                child: Column(children: [
                  Text(c?.name ?? '?', style: W.h2.copyWith(color: W.accent)),
                  const SizedBox(height: 6),
                  if (c != null) ChordDiagram(c, width: 100),
                  if (!running) const Text('сменить', style: W.small),
                ]),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 14),
      Center(child: Text('Рекорд для этой пары: $best', style: W.small)),
      const SizedBox(height: 10),
      if (running)
        SizedBox(
          height: 160,
          child: FilledButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => count++);
            },
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$count', style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900)),
              Text('осталось $left с', style: const TextStyle(fontSize: 16)),
            ]),
          ),
        )
      else ...[
        if (finished)
          Center(child: Text('Результат: $count смен за минуту', style: W.h2)),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: FilledButton.icon(onPressed: _start, icon: const Icon(Icons.play_arrow), label: const Text('Начать минуту')),
        ),
      ],
      if (hist.isNotEmpty) ...[
        const Section('Последние'),
        for (final h in hist)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Text('${h['a']} ↔ ${h['b']}: ${h['n']} смен', style: W.body),
          ),
      ],
    ]);
  }
}
