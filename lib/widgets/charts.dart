import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../util.dart';

class ChartPoint {
  final DateTime x;
  final double y;
  const ChartPoint(this.x, this.y);
}

/// Линейный график (вес).
class LineChart extends StatelessWidget {
  final List<ChartPoint> points;
  final Color color;
  final double? targetY;
  final double height;

  const LineChart({
    super.key,
    required this.points,
    this.color = AppColors.accent,
    this.targetY,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _LinePainter(points, color, targetY)),
      );
}

void _text(Canvas c, String s, Offset at, {Color color = AppColors.muted, double size = 10, bool alignRight = false, bool center = false}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(color: color, fontSize: size, fontFeatures: Txt.tab)),
    textDirection: TextDirection.ltr,
  )..layout();
  var dx = at.dx;
  if (alignRight) dx -= tp.width;
  if (center) dx -= tp.width / 2;
  tp.paint(c, Offset(dx, at.dy - tp.height / 2));
}

void _dashedLine(Canvas c, Offset a, Offset b, Paint p, {double dash = 4, double gap = 4}) {
  final len = (b - a).distance;
  if (len <= 0) return;
  final dir = (b - a) / len;
  var d = 0.0;
  while (d < len) {
    final e = math.min(d + dash, len);
    c.drawLine(a + dir * d, a + dir * e, p);
    d = e + gap;
  }
}

class _LinePainter extends CustomPainter {
  final List<ChartPoint> pts;
  final Color color;
  final double? targetY;
  _LinePainter(this.pts, this.color, this.targetY);

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.isEmpty) return;
    const left = 36.0, bottom = 20.0, top = 8.0, right = 8.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    var minY = pts.map((p) => p.y).reduce(math.min);
    var maxY = pts.map((p) => p.y).reduce(math.max);
    if (targetY != null) {
      minY = math.min(minY, targetY!);
      maxY = math.max(maxY, targetY!);
    }
    final pad = math.max((maxY - minY) * 0.15, 0.5);
    minY -= pad;
    maxY += pad;

    final x0 = pts.first.x;
    final span = math.max(1, daysBetween(x0, pts.last.x));
    double px(DateTime d) =>
        pts.length == 1 ? left + w / 2 : left + w * daysBetween(x0, d) / span;
    double py(double y) => top + h * (1 - (y - minY) / (maxY - minY));

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + h * i / 3;
      _dashedLine(canvas, Offset(left, y), Offset(left + w, y), grid, dash: 3, gap: 4);
      final v = maxY - (maxY - minY) * i / 3;
      _text(canvas, fmt1(v), Offset(left - 6, y), alignRight: true);
    }

    if (targetY != null) {
      final tp = Paint()
        ..color = AppColors.accent2
        ..strokeWidth = 1.5;
      final y = py(targetY!);
      _dashedLine(canvas, Offset(left, y), Offset(left + w, y), tp, dash: 6, gap: 4);
      _text(canvas, 'цель', Offset(left + w - 2, y - 9), color: AppColors.accent2, alignRight: true);
    }

    final offsets = [for (final p in pts) Offset(px(p.x), py(p.y))];

    if (offsets.length > 1) {
      final line = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final o in offsets.skip(1)) {
        line.lineTo(o.dx, o.dy);
      }
      final fill = Path.from(line)
        ..lineTo(offsets.last.dx, top + h)
        ..lineTo(offsets.first.dx, top + h)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
          ).createShader(Rect.fromLTWH(left, top, w, h)),
      );
      canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
    }

    if (offsets.length <= 40) {
      for (final o in offsets) {
        canvas.drawCircle(o, 3.5, Paint()..color = AppColors.bg);
        canvas.drawCircle(
          o,
          3.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = color,
        );
      }
    }

    _text(canvas, fmtShort(pts.first.x), Offset(left, size.height - 8));
    if (pts.length > 1) {
      _text(canvas, fmtShort(pts.last.x), Offset(left + w, size.height - 8), alignRight: true);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.pts != pts || old.color != color || old.targetY != targetY;
}

class BarDatum {
  final DateTime day;
  final double value; // 0 — нет данных
  final double target;
  final Color color;
  const BarDatum(this.day, this.value, this.target, this.color);
}

/// Столбики калорий по дням с отметкой нормы.
class BarChart extends StatelessWidget {
  final List<BarDatum> data;
  final double height;
  const BarChart({super.key, required this.data, this.height = 170});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _BarPainter(data)),
      );
}

class _BarPainter extends CustomPainter {
  final List<BarDatum> data;
  _BarPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    const left = 36.0, bottom = 20.0, top = 8.0, right = 4.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;

    var maxV = 0.0;
    for (final d in data) {
      maxV = math.max(maxV, math.max(d.value, d.target));
    }
    if (maxV <= 0) maxV = 2000;
    maxV *= 1.1;

    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = top + h * i / 3;
      _dashedLine(canvas, Offset(left, y), Offset(left + w, y), grid, dash: 3, gap: 4);
      _text(canvas, fmtInt(maxV - maxV * i / 3), Offset(left - 6, y), alignRight: true);
    }

    final slot = w / data.length;
    final barW = math.max(2.0, math.min(18.0, slot * 0.62));
    for (var i = 0; i < data.length; i++) {
      final d = data[i];
      final cx = left + slot * (i + 0.5);
      if (d.value > 0) {
        final bh = h * d.value / maxV;
        final r = RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barW / 2, top + h - bh, barW, bh),
          topLeft: Radius.circular(math.min(4.0, barW / 2)),
          topRight: Radius.circular(math.min(4.0, barW / 2)),
        );
        canvas.drawRRect(r, Paint()..color = d.color.withValues(alpha: 0.9));
      } else {
        canvas.drawCircle(Offset(cx, top + h - 2), 1.5, Paint()..color = AppColors.border);
      }
      if (d.target > 0) {
        final ty = top + h * (1 - d.target / maxV);
        canvas.drawLine(
          Offset(cx - slot / 2 + 0.5, ty),
          Offset(cx + slot / 2 - 0.5, ty),
          Paint()
            ..color = AppColors.text.withValues(alpha: 0.55)
            ..strokeWidth = 1.5,
        );
      }
    }

    _text(canvas, fmtShort(data.first.day), Offset(left, size.height - 8));
    if (data.length > 1) {
      _text(canvas, fmtShort(data.last.day), Offset(left + w, size.height - 8), alignRight: true);
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => old.data != data;
}
