import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../common/ui.dart';
import 'app.dart' show darkTiles, MapAttribution;
import 'run_model.dart';

const _run = Color(0xFFFF9F43);
const _monthsGen = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];

String _when(DateTime d) => '${d.day} ${_monthsGen[d.month - 1]}, ${d.hour}:${d.minute.toString().padLeft(2, '0')}';

bool get _hasGps => Platform.isAndroid || Platform.isIOS;

/// Сохранённые пробежки.
class RunStore extends ChangeNotifier {
  static final I = RunStore._();
  RunStore._();

  final _file = JsonStore('walks_runs.json');
  bool loaded = false;
  List<Run> runs = [];

  Future<void> load() async {
    if (loaded) return;
    final j = await _file.read();
    runs = (j['runs'] as List? ?? const []).map(Run.fromJson).whereType<Run>().toList();
    runs.sort((a, b) => b.start.compareTo(a.start));
    loaded = true;
    notifyListeners();
  }

  Future<void> save() async {
    runs.sort((a, b) => b.start.compareTo(a.start));
    notifyListeners();
    await _file.write({
      'v': 1,
      'runs': [for (final r in runs) r.toJson()],
    });
  }

  Future<void> add(Run r) async {
    runs = [r, ...runs.where((x) => x.id != r.id)];
    await save();
  }

  Future<void> remove(String id) async {
    runs = [for (final r in runs) if (r.id != id) r];
    await save();
  }
}

// ───────────────────────────── Вкладка «Бег» ─────────────────────────────

class RunsTab extends StatefulWidget {
  const RunsTab({super.key});

  @override
  State<RunsTab> createState() => _RunsTabState();
}

class _RunsTabState extends State<RunsTab> {
  final st = RunStore.I;

  @override
  void initState() {
    super.initState();
    st.addListener(_changed);
    st.load();
  }

  @override
  void dispose() {
    st.removeListener(_changed);
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  @override
  Widget build(BuildContext context) {
    final runs = st.runs;
    final week = kmLastDays(runs, DateTime.now());
    final weekN = runs.where((r) => r.start >= DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch).length;
    final rec = records(runs);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
      WCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _big('${week.toStringAsFixed(1).replaceAll('.', ',')} км', 'за 7 дней'),
            _big('$weekN', weekN == 1 ? 'пробежка' : 'пробежек'),
            _big('${runs.length}', 'всего'),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _run, foregroundColor: W.bg, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _hasGps
                  ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RunScreen()))
                  : null,
              icon: const Icon(Icons.directions_run),
              label: const Text('Начать пробежку', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          if (!_hasGps) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Пробежки записываются на телефоне — там есть GPS.', style: W.small)),
        ]),
      ),
      if (runs.isNotEmpty) ...[
        const Section('Рекорды'),
        WCard(
          child: Column(children: [
            if (rec.longest != null) _recRow('🏔', 'Самая длинная', '${kmText(rec.longest!.meters)} км'),
            if (rec.fastestKmSec != null) _recRow('⚡', 'Быстрейший километр', '${paceText(rec.fastestKmSec!.toDouble())} /км'),
            if (rec.best5k != null) _recRow('🏅', 'Лучший темп на 5+ км', '${paceText(rec.best5k!.pace) ?? '—'} /км'),
          ]),
        ),
      ],
      const Section('История'),
      if (runs.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Center(
            child: Text('Пробежек пока нет.\nЗапись идёт и с выключенным экраном — телефон можно убрать в карман.',
                style: W.small, textAlign: TextAlign.center),
          ),
        )
      else
        for (final r in runs)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: WCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RunDetailScreen(run: r))),
              child: Row(children: [
                const Text('🏃', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${kmText(r.meters)} км · ${durText(r.seconds)}', style: W.h2),
                    Text('${_when(r.date)} · темп ${paceText(r.pace) ?? '—'} /км', style: W.small),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: W.muted),
              ]),
            ),
          ),
    ]);
  }

  Widget _big(String v, String label) => Expanded(
        child: Column(children: [
          FittedBox(child: Text(v, style: W.h2.copyWith(fontSize: 22, color: _run))),
          Text(label, style: W.small),
        ]),
      );

  Widget _recRow(String e, String t, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Text(e, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(t, style: W.body)),
          Text(v, style: W.body.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );
}

// ───────────────────────────── Идёт пробежка ─────────────────────────────

enum _RunState { idle, running, paused }

class RunScreen extends StatefulWidget {
  const RunScreen({super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  _RunState state = _RunState.idle;
  final sw = Stopwatch();
  final List<List<RunPoint>> segments = [[]];
  double meters = 0;
  int kmDone = 0;
  int startMs = 0;
  LatLng? me;
  double? accuracy;
  String? error;
  bool follow = true;
  StreamSubscription<Position>? _sub;
  Timer? _tick;
  final map = MapController();
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _listen();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && state == _RunState.running) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  LocationSettings _settings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
        intervalDuration: const Duration(seconds: 1),
        // Уведомление держит GPS, когда экран выключен и телефон в кармане.
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Winter Walks — пробежка',
          notificationText: 'Записываю маршрут. Открой приложение, чтобы закончить.',
          notificationChannelName: 'Пробежка',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3);
  }

  Future<void> _listen() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() => error = 'Включи геолокацию (GPS) в шторке телефона.');
        return;
      }
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
        setState(() => error = 'Нет доступа к местоположению. Разреши его в настройках телефона → Приложения → КБЖУ Трекер.');
        return;
      }
      _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(_onPos, onError: (Object e) {
        if (mounted) setState(() => error = 'GPS: $e');
      });
    } catch (e) {
      if (mounted) setState(() => error = 'GPS не запустился: $e');
    }
  }

  void _onPos(Position pos) {
    final now = DateTime.now().millisecondsSinceEpoch;
    me = LatLng(pos.latitude, pos.longitude);
    accuracy = pos.accuracy;
    error = null;
    if (state == _RunState.running) {
      final seg = segments.last;
      final p = RunPoint(pos.latitude, pos.longitude, now);
      final last = seg.isEmpty ? null : seg.last;
      if (acceptPoint(last, p, pos.accuracy)) {
        if (last != null) meters += segM(last, p);
        seg.add(p);
        if (meters ~/ 1000 > kmDone) {
          kmDone = meters ~/ 1000;
          HapticFeedback.heavyImpact();
        }
      }
    }
    if (follow && _mapReady) {
      try {
        map.move(me!, map.camera.zoom);
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  void _start() {
    HapticFeedback.mediumImpact();
    setState(() {
      state = _RunState.running;
      startMs = DateTime.now().millisecondsSinceEpoch;
      sw.start();
    });
  }

  void _pause() {
    HapticFeedback.mediumImpact();
    setState(() {
      state = _RunState.paused;
      sw.stop();
    });
  }

  void _resume() {
    HapticFeedback.mediumImpact();
    setState(() {
      state = _RunState.running;
      if (segments.last.isNotEmpty) segments.add([]);
      sw.start();
    });
  }

  Future<void> _finish() async {
    final wasRunning = state == _RunState.running;
    if (wasRunning) _pause();
    final ok = await confirmDialog(
      context,
      'Закончить пробежку?',
      '${kmText(meters)} км за ${durText(sw.elapsed.inSeconds)}.',
      ok: 'Закончить',
    );
    if (!ok) {
      if (wasRunning) _resume();
      return;
    }
    await _sub?.cancel();
    _sub = null;
    if (meters < 50) {
      if (mounted) {
        toast(context, 'Слишком короткая — не сохраняю');
        Navigator.pop(context);
      }
      return;
    }
    final segs = [for (final s in segments) if (s.length >= 2) s];
    final run = Run(
      id: '$startMs',
      start: startMs,
      seconds: sw.elapsed.inSeconds,
      meters: meters,
      segments: [for (final s in segs) thin(s)],
      splitSec: splits(segs),
    );
    await RunStore.I.add(run);
    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => RunDetailScreen(run: run, fresh: true)));
  }

  Future<void> _onBack() async {
    if (state == _RunState.idle) {
      Navigator.pop(context);
      return;
    }
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final secs = sw.elapsed.inSeconds;
    final cur = state == _RunState.running ? paceText(recentPace(segments.last)) : null;
    final avg = paceText(paceOf(meters, secs));
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(switch (state) {
            _RunState.idle => 'Пробежка',
            _RunState.running => 'Бежим!',
            _RunState.paused => 'Пауза',
          }),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _onBack),
        ),
        body: Column(children: [
          Expanded(
            flex: 5,
            child: Stack(children: [
              FlutterMap(
                mapController: map,
                options: MapOptions(
                  initialCenter: me ?? const LatLng(50.0647, 19.9450),
                  initialZoom: me == null ? 11 : 16.5,
                  onMapReady: () => _mapReady = true,
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture && follow) setState(() => follow = false);
                  },
                ),
                children: [
                  darkTiles(),
                  PolylineLayer(polylines: [
                    for (final seg in segments)
                      if (seg.length >= 2)
                        Polyline(points: [for (final p in seg) LatLng(p.lat, p.lon)], color: _run, strokeWidth: 5),
                  ]),
                  if (me != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: me!,
                        width: 22,
                        height: 22,
                        child: Container(
                          decoration: BoxDecoration(shape: BoxShape.circle, color: _run, border: Border.all(color: Colors.white, width: 3)),
                        ),
                      ),
                    ]),
                  const MapAttribution(),
                ],
              ),
              if (!follow && me != null)
                Positioned(
                  right: 12,
                  top: 12,
                  child: FloatingActionButton.small(
                    heroTag: 'run-follow',
                    backgroundColor: W.surface,
                    onPressed: () {
                      setState(() => follow = true);
                      try {
                        map.move(me!, 16.5);
                      } catch (_) {}
                    },
                    child: const Icon(Icons.my_location, color: _run),
                  ),
                ),
            ]),
          ),
          Container(
            color: W.surface,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (error != null)
                  Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(error!, style: W.body.copyWith(color: W.bad), textAlign: TextAlign.center))
                else if (me == null)
                  const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('Ищу спутники… Выйди на открытое место.', style: W.small))
                else if (state == _RunState.idle && (accuracy ?? 99) > 25)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text('GPS пока неточный (±${(accuracy ?? 0).round()} м) — подожди пару секунд.', style: W.small),
                  ),
                Text(kmText(meters), style: const TextStyle(fontSize: 54, fontWeight: FontWeight.w900, color: W.text, height: 1)),
                const Text('километров', style: W.small),
                const SizedBox(height: 12),
                Row(children: [
                  _stat(durText(secs), 'время'),
                  _stat(cur ?? '—', 'темп сейчас'),
                  _stat(avg ?? '—', 'средний темп'),
                ]),
                const SizedBox(height: 16),
                _buttons(),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(children: [
          Text(v, style: W.h2.copyWith(fontSize: 22)),
          Text(l, style: W.small),
        ]),
      );

  Widget _buttons() {
    final big = FilledButton.styleFrom(backgroundColor: _run, foregroundColor: W.bg, padding: const EdgeInsets.symmetric(vertical: 16));
    switch (state) {
      case _RunState.idle:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: big,
            onPressed: error == null ? _start : null,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Text('Старт', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
        );
      case _RunState.running:
        return Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: big,
              onPressed: _pause,
              icon: const Icon(Icons.pause_rounded, size: 28),
              label: const Text('Пауза', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
        ]);
      case _RunState.paused:
        return Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _finish,
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Закончить'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              style: big,
              onPressed: _resume,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Дальше'),
            ),
          ),
        ]);
    }
  }
}

// ───────────────────────────── Итог пробежки ─────────────────────────────

class RunDetailScreen extends StatelessWidget {
  final Run run;
  final bool fresh;
  const RunDetailScreen({super.key, required this.run, this.fresh = false});

  @override
  Widget build(BuildContext context) {
    final pts = [
      for (final seg in run.segments)
        for (final p in seg) LatLng(p.lat, p.lon),
    ];
    final slowest = run.splitSec.isEmpty ? 0 : run.splitSec.reduce((a, b) => a > b ? a : b);
    final fastest = run.splitSec.isEmpty ? 0 : run.splitSec.reduce((a, b) => a < b ? a : b);
    return Scaffold(
      appBar: AppBar(
        title: Text(fresh ? 'Готово! 🎉' : _when(run.date)),
        actions: [
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirmDialog(context, 'Удалить пробежку?', '${kmText(run.meters)} км, ${_when(run.date)}.', ok: 'Удалить')) return;
              await RunStore.I.remove(run.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        if (pts.length >= 2)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 260,
              child: FlutterMap(
                options: MapOptions(
                  initialCameraFit: CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(28)),
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag),
                ),
                children: [
                  darkTiles(),
                  PolylineLayer(polylines: [
                    for (final seg in run.segments)
                      if (seg.length >= 2) Polyline(points: [for (final p in seg) LatLng(p.lat, p.lon)], color: _run, strokeWidth: 5),
                  ]),
                  MarkerLayer(markers: [
                    Marker(point: pts.first, width: 16, height: 16, child: _dot(W.good)),
                    Marker(point: pts.last, width: 16, height: 16, child: _dot(W.bad)),
                  ]),
                  const MapAttribution(),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        WCard(
          child: Row(children: [
            _stat('${kmText(run.meters)} км', 'дистанция'),
            _stat(durText(run.seconds), 'время'),
            _stat(paceText(run.pace) ?? '—', 'темп /км'),
          ]),
        ),
        if (run.splitSec.isNotEmpty) ...[
          const Section('По километрам'),
          WCard(
            child: Column(children: [
              for (var i = 0; i < run.splitSec.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    SizedBox(width: 44, child: Text('${i + 1} км', style: W.small)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          // Чем быстрее километр, тем длиннее полоска.
                          value: slowest <= 0 ? 0 : (fastest / run.splitSec[i]).clamp(0.05, 1).toDouble(),
                          minHeight: 8,
                          backgroundColor: W.border,
                          color: run.splitSec[i] == fastest ? W.good : _run,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 52,
                      child: Text(paceText(run.splitSec[i].toDouble()) ?? '—', style: W.body, textAlign: TextAlign.right),
                    ),
                  ]),
                ),
            ]),
          ),
        ],
      ]),
    );
  }

  static Widget _dot(Color c) =>
      Container(decoration: BoxDecoration(shape: BoxShape.circle, color: c, border: Border.all(color: Colors.white, width: 2)));

  Widget _stat(String v, String l) => Expanded(
        child: Column(children: [
          FittedBox(child: Text(v, style: W.h2.copyWith(fontSize: 20, color: _run))),
          Text(l, style: W.small),
        ]),
      );
}
