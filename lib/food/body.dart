import 'dart:math' as math;

import '../models.dart';
import '../store.dart';
import '../util.dart';
import '../i18n/i18n.dart';

String measureTitle(String part) => switch (part) {
      'waist' => tr('Талия'),
      'chest' => tr('Грудь'),
      'hips' => tr('Бёдра'),
      'arm' => tr('Рука (бицепс)'),
      'thigh' => tr('Нога (бедро)'),
      'neck' => tr('Шея'),
      _ => part,
    };

String measureHint(String part) => switch (part) {
      'waist' => tr('на уровне пупка, на выдохе'),
      'chest' => tr('по самой широкой части'),
      'hips' => tr('по самой широкой части ягодиц'),
      'arm' => tr('напряжённый бицепс'),
      'thigh' => tr('под ягодицей'),
      'neck' => tr('под кадыком'),
      _ => '',
    };

/// Процент жира по формуле ВМС США (нужны рост, шея, талия; для женщин ещё бёдра).
double? bodyFatPercent(Profile? p, double? neck, double? waist, double? hips) {
  if (p == null || neck == null || waist == null) return null;
  final h = p.heightCm;
  double v;
  if (p.sex == Sex.male) {
    if (waist - neck <= 0) return null;
    v = 495 / (1.0324 - 0.19077 * _log10(waist - neck) + 0.15456 * _log10(h)) - 450;
  } else {
    if (hips == null || waist + hips - neck <= 0) return null;
    v = 495 / (1.29579 - 0.35004 * _log10(waist + hips - neck) + 0.22100 * _log10(h)) - 450;
  }
  if (!v.isFinite || v < 2 || v > 60) return null;
  return v;
}

double _log10(double x) => math.log(x) / math.ln10;

class WeightForecast {
  final double ratePerWeek; // кг в неделю (минус — худеет)
  final DateTime? eta; // когда будет достигнута цель
  final bool awayFromTarget;
  const WeightForecast(this.ratePerWeek, this.eta, this.awayFromTarget);
}

/// Прогноз по линейному тренду веса за последние 5 недель.
WeightForecast? weightForecast(AppStore store) {
  final now = today();
  final from = dkey(addDays(now, -35));
  final pts = store.weightSeries.where((e) => e.key.compareTo(from) >= 0).toList();
  if (pts.length < 2) return null;
  final x0 = parseKey(pts.first.key);
  final xs = [for (final e in pts) daysBetween(x0, parseKey(e.key)).toDouble()];
  final ys = [for (final e in pts) e.value];
  if (xs.last - xs.first < 6) return null;
  final n = xs.length;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var sxy = 0.0, sxx = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += (xs[i] - mx) * (ys[i] - my);
    sxx += (xs[i] - mx) * (xs[i] - mx);
  }
  if (sxx == 0) return null;
  final slope = sxy / sxx; // кг в день
  final rate = slope * 7;
  final target = store.profile?.targetWeightKg;
  if (target == null) return WeightForecast(rate, null, false);
  final current = my + slope * (daysBetween(x0, now) - mx);
  final diff = target - current;
  if (diff.abs() < 0.3) return WeightForecast(rate, now, false);
  if (slope.abs() < 0.005) return WeightForecast(rate, null, false);
  if (diff.sign != slope.sign) return WeightForecast(rate, null, true);
  final days = (diff / slope).round();
  if (days > 3 * 365) return WeightForecast(rate, null, false);
  return WeightForecast(rate, addDays(now, days), false);
}
