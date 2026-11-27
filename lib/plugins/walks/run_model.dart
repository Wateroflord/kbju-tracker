/// Пробежки — чистая логика (проверяется тестами): фильтр GPS, темп, отрезки по километрам, рекорды.
library;

import 'dart:math' as math;

/// Точка маршрута.
class RunPoint {
  final double lat, lon;
  final int t; // мс с начала эпохи
  const RunPoint(this.lat, this.lon, this.t);

  List<num> toJson() => [double.parse(lat.toStringAsFixed(6)), double.parse(lon.toStringAsFixed(6)), t];

  static RunPoint? fromJson(dynamic j) {
    if (j is! List || j.length < 3) return null;
    return RunPoint((j[0] as num).toDouble(), (j[1] as num).toDouble(), (j[2] as num).toInt());
  }
}

double distM(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a1 = lat1 * math.pi / 180, a2 = lat2 * math.pi / 180;
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(a1) * math.cos(a2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * r * math.asin(math.min(1, math.sqrt(h)));
}

double segM(RunPoint a, RunPoint b) => distM(a.lat, a.lon, b.lat, b.lon);

/// Стоит ли принять новую GPS-точку после [last].
/// Отбрасываем неточные (> 25 м), слишком близкие (< 3 м — дрожание на месте)
/// и «телепорты» быстрее 30 км/ч (для бега это ошибка GPS).
bool acceptPoint(RunPoint? last, RunPoint p, double accuracyM) {
  if (accuracyM > 25) return false;
  if (last == null) return true;
  final d = segM(last, p);
  if (d < 3) return false;
  final dt = (p.t - last.t) / 1000;
  if (dt <= 0) return false;
  return d / dt <= 30 / 3.6;
}

/// Темп «5:32» (мин:сек на километр). null — если стоим.
String? paceText(double secPerKm) {
  if (secPerKm.isNaN || secPerKm.isInfinite || secPerKm <= 0 || secPerKm > 60 * 60) return null;
  final s = secPerKm.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

double paceOf(double meters, int seconds) => meters < 10 ? double.nan : seconds / (meters / 1000);

String durText(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String kmText(double m) => (m / 1000).toStringAsFixed(2).replaceAll('.', ',');

/// Время каждого полного километра (сек). Паузы не учитываются — между точками
/// после паузы время не идёт (отрезок начинается заново).
List<int> splits(List<List<RunPoint>> segments) {
  final out = <int>[];
  var acc = 0.0, accT = 0.0;
  for (final seg in segments) {
    for (var i = 1; i < seg.length; i++) {
      var d = segM(seg[i - 1], seg[i]);
      var dt = (seg[i].t - seg[i - 1].t) / 1000;
      while (acc + d >= 1000) {
        final need = 1000 - acc;
        final part = dt * need / d;
        out.add((accT + part).round());
        d -= need;
        dt -= part;
        acc = 0;
        accT = 0;
      }
      acc += d;
      accT += dt;
    }
  }
  return out;
}

double totalM(List<List<RunPoint>> segments) {
  var m = 0.0;
  for (final seg in segments) {
    for (var i = 1; i < seg.length; i++) {
      m += segM(seg[i - 1], seg[i]);
    }
  }
  return m;
}

/// Темп за последние ~[window] метров — «текущий темп».
double recentPace(List<RunPoint> seg, {double window = 200}) {
  if (seg.length < 2) return double.nan;
  var m = 0.0;
  var i = seg.length - 1;
  while (i > 0 && m < window) {
    m += segM(seg[i - 1], seg[i]);
    i--;
  }
  final sec = (seg.last.t - seg[i].t) / 1000;
  return paceOf(m, sec.round());
}

/// Прореживание маршрута для хранения: точки не ближе [minM] метров друг к другу.
List<RunPoint> thin(List<RunPoint> pts, {double minM = 8}) {
  if (pts.length <= 2) return pts;
  final out = [pts.first];
  for (var i = 1; i < pts.length - 1; i++) {
    if (segM(out.last, pts[i]) >= minM) out.add(pts[i]);
  }
  out.add(pts.last);
  return out;
}

/// Сохранённая пробежка.
class Run {
  final String id;
  final int start; // мс
  final int seconds; // время в движении (без пауз)
  final double meters;
  final List<List<RunPoint>> segments; // куски между паузами
  final List<int> splitSec;

  const Run({
    required this.id,
    required this.start,
    required this.seconds,
    required this.meters,
    this.segments = const [],
    this.splitSec = const [],
  });

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(start);
  double get pace => paceOf(meters, seconds);

  Map<String, dynamic> toJson() => {
        'id': id,
        's': start,
        'sec': seconds,
        'm': double.parse(meters.toStringAsFixed(1)),
        'seg': [
          for (final seg in segments) [for (final p in seg) p.toJson()],
        ],
        'sp': splitSec,
      };

  static Run? fromJson(dynamic j) {
    if (j is! Map || j['id'] == null) return null;
    return Run(
      id: '${j['id']}',
      start: (j['s'] as num?)?.toInt() ?? 0,
      seconds: (j['sec'] as num?)?.toInt() ?? 0,
      meters: (j['m'] as num?)?.toDouble() ?? 0,
      segments: [
        for (final seg in (j['seg'] as List? ?? const []))
          if (seg is List) [for (final p in seg) RunPoint.fromJson(p)].whereType<RunPoint>().toList(),
      ],
      splitSec: [for (final x in (j['sp'] as List? ?? const [])) (x as num).toInt()],
    );
  }
}

/// Рекорды: самая длинная, самый быстрый километр, лучший средний темп на 5+ км.
class RunRecords {
  final Run? longest;
  final int? fastestKmSec;
  final Run? best5k;
  const RunRecords({this.longest, this.fastestKmSec, this.best5k});
}

RunRecords records(Iterable<Run> runs) {
  Run? longest, best5;
  int? fast;
  for (final r in runs) {
    if (longest == null || r.meters > longest.meters) longest = r;
    for (final s in r.splitSec) {
      if (s > 0 && (fast == null || s < fast)) fast = s;
    }
    if (r.meters >= 5000 && (best5 == null || r.pace < best5.pace)) best5 = r;
  }
  return RunRecords(longest: longest, fastestKmSec: fast, best5k: best5);
}

/// Километры за последние 7 дней до [now].
double kmLastDays(Iterable<Run> runs, DateTime now, {int days = 7}) {
  final from = now.subtract(Duration(days: days)).millisecondsSinceEpoch;
  return runs.where((r) => r.start >= from).fold<double>(0, (s, r) => s + r.meters) / 1000;
}
