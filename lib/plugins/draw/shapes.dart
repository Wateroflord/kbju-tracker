import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Фигура-подсказка в координатах 0..1 (по ширине и высоте холста).
abstract class G {
  const G();
  Path path(Size s);

  /// Точки вдоль контура (для оценки обводки).
  List<Offset> samples(Size s, {double step = 4}) {
    final out = <Offset>[];
    for (final m in path(s).computeMetrics()) {
      for (var d = 0.0; d <= m.length; d += step) {
        final t = m.getTangentForOffset(d);
        if (t != null) out.add(t.position);
      }
    }
    return out;
  }
}

class Line extends G {
  final double x1, y1, x2, y2;
  const Line(this.x1, this.y1, this.x2, this.y2);
  @override
  Path path(Size s) => Path()
    ..moveTo(x1 * s.width, y1 * s.height)
    ..lineTo(x2 * s.width, y2 * s.height);
}

class Circle extends G {
  final double cx, cy, r; // r — доля от меньшей стороны
  const Circle(this.cx, this.cy, this.r);
  @override
  Path path(Size s) => Path()..addOval(Rect.fromCircle(center: Offset(cx * s.width, cy * s.height), radius: r * s.shortestSide));
}

class Ellipse extends G {
  final double cx, cy, rx, ry, angle; // rx, ry — доли от меньшей стороны; angle в градусах
  const Ellipse(this.cx, this.cy, this.rx, this.ry, [this.angle = 0]);
  @override
  Path path(Size s) {
    final m = s.shortestSide;
    final p = Path()..addOval(Rect.fromCenter(center: Offset.zero, width: rx * 2 * m, height: ry * 2 * m));
    final t = Matrix4.identity()
      ..translate(cx * s.width, cy * s.height)
      ..rotateZ(angle * math.pi / 180);
    return p.transform(t.storage);
  }
}

class Poly extends G {
  final List<double> xy; // x1,y1,x2,y2…
  final bool closed;
  const Poly(this.xy, {this.closed = false});
  @override
  Path path(Size s) {
    final p = Path()..moveTo(xy[0] * s.width, xy[1] * s.height);
    for (var i = 2; i + 1 < xy.length; i += 2) {
      p.lineTo(xy[i] * s.width, xy[i + 1] * s.height);
    }
    if (closed) p.close();
    return p;
  }
}

class Curve extends G {
  final List<double> xy; // старт, затем тройки контрольных точек (кубические кривые)
  const Curve(this.xy);
  @override
  Path path(Size s) {
    Offset o(int i) => Offset(xy[i] * s.width, xy[i + 1] * s.height);
    final p = Path()..moveTo(o(0).dx, o(0).dy);
    for (var i = 2; i + 5 < xy.length + 1; i += 6) {
      final a = o(i), b = o(i + 2), c = o(i + 4);
      p.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
    }
    return p;
  }
}

/// Особые иллюстрации (не для обводки): светотень, цветовой круг, шкала тона.
class Special extends G {
  final String kind;
  const Special(this.kind);
  @override
  Path path(Size s) => Path();
  @override
  List<Offset> samples(Size s, {double step = 4}) => const [];
}

/// Рисует иллюстрацию урока.
class GuidePainter extends CustomPainter {
  final List<G> shapes;
  final Color color;
  final double width;
  final bool dashed;
  const GuidePainter(this.shapes, {this.color = const Color(0xFF2B3550), this.width = 3, this.dashed = false});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final g in shapes) {
      if (g is Special) {
        _special(canvas, s, g.kind);
        continue;
      }
      final path = g.path(s);
      if (!dashed) {
        canvas.drawPath(path, p);
      } else {
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d < m.length; d += 14) {
            canvas.drawPath(m.extractPath(d, math.min(d + 8, m.length)), p);
          }
        }
      }
    }
  }

  void _special(Canvas c, Size s, String kind) {
    final m = s.shortestSide;
    final center = s.center(Offset.zero);
    switch (kind) {
      case 'sphere':
        final r = m * 0.3;
        final rect = Rect.fromCircle(center: center, radius: r);
        // Падающая тень
        c.drawOval(Rect.fromCenter(center: center + Offset(r * 0.5, r * 0.95), width: r * 2.2, height: r * 0.5), Paint()..color = const Color(0x55000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
        c.drawCircle(center, r, Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.45),
            radius: 1.1,
            colors: const [Color(0xFFFFFFFF), Color(0xFFBFC6D2), Color(0xFF59606E), Color(0xFF2A2F3A), Color(0xFF4A5160)],
            stops: const [0, 0.25, 0.65, 0.85, 1],
          ).createShader(rect));
        _label(c, center + Offset(-r * 0.55, -r * 0.6), 'блик');
        _label(c, center + Offset(-r * 0.2, r * 0.05), 'свет');
        _label(c, center + Offset(r * 0.25, r * 0.45), 'собств. тень');
        _label(c, center + Offset(r * 0.6, r * 0.78), 'рефлекс');
        _label(c, center + Offset(r * 0.9, r * 1.15), 'падающая тень');
      case 'cube':
        final a = m * 0.22;
        final top = Path()
          ..moveTo(center.dx, center.dy - a * 1.2)
          ..lineTo(center.dx + a, center.dy - a * 0.6)
          ..lineTo(center.dx, center.dy)
          ..lineTo(center.dx - a, center.dy - a * 0.6)
          ..close();
        final left = Path()
          ..moveTo(center.dx - a, center.dy - a * 0.6)
          ..lineTo(center.dx, center.dy)
          ..lineTo(center.dx, center.dy + a * 1.2)
          ..lineTo(center.dx - a, center.dy + a * 0.6)
          ..close();
        final right = Path()
          ..moveTo(center.dx + a, center.dy - a * 0.6)
          ..lineTo(center.dx, center.dy)
          ..lineTo(center.dx, center.dy + a * 1.2)
          ..lineTo(center.dx + a, center.dy + a * 0.6)
          ..close();
        c.drawPath(top, Paint()..color = const Color(0xFFE8ECF2));
        c.drawPath(left, Paint()..color = const Color(0xFFA9B2C1));
        c.drawPath(right, Paint()..color = const Color(0xFF5B6475));
        _label(c, center + Offset(-a * 0.2, -a * 0.75), 'свет');
        _label(c, center + Offset(-a * 0.85, a * 0.3), 'полутон');
        _label(c, center + Offset(a * 0.15, a * 0.3), 'тень');
      case 'wheel':
        final r = m * 0.36;
        for (var i = 0; i < 12; i++) {
          final hue = i * 30.0;
          final path = Path()
            ..moveTo(center.dx, center.dy)
            ..arcTo(Rect.fromCircle(center: center, radius: r), (hue - 90 - 15) * math.pi / 180, 30 * math.pi / 180, false)
            ..close();
          c.drawPath(path, Paint()..color = HSVColor.fromAHSV(1, hue, 0.85, 0.95).toColor());
        }
        c.drawCircle(center, r * 0.35, Paint()..color = const Color(0xFFF5F7FA));
        _label(c, center + Offset(r * 0.7, -r * 0.9), 'тёплые');
        _label(c, center + Offset(-r * 1.1, r * 0.9), 'холодные');
      case 'values':
        final w = s.width * 0.8 / 7;
        for (var i = 0; i < 7; i++) {
          final v = 1 - i / 6;
          c.drawRect(Rect.fromLTWH(s.width * 0.1 + i * w, center.dy - w / 2, w, w), Paint()..color = HSVColor.fromAHSV(1, 0, 0, v).toColor());
        }
        _label(c, Offset(s.width * 0.1, center.dy + w * 0.7), 'светлое');
        _label(c, Offset(s.width * 0.75, center.dy + w * 0.7), 'тёмное');
      case 'hatch':
        final p = Paint()
          ..color = const Color(0xFF2B3550)
          ..strokeWidth = 1.6;
        for (var k = 0; k < 4; k++) {
          final x0 = s.width * (0.08 + k * 0.22), w = s.width * 0.18;
          final r = Rect.fromLTWH(x0, s.height * 0.3, w, s.height * 0.4);
          c.save();
          c.clipRect(r);
          for (var layer = 0; layer <= k; layer++) {
            final ang = [45, -45, 0, 90][layer] * math.pi / 180;
            final d = Offset(math.cos(ang), math.sin(ang)) * 400;
            for (var t = -400.0; t < 400; t += 7) {
              final n = Offset(-math.sin(ang), math.cos(ang)) * t;
              c.drawLine(r.center + n - d, r.center + n + d, p);
            }
          }
          c.restore();
          c.drawRect(r, Paint()
            ..style = PaintingStyle.stroke
            ..color = const Color(0x552B3550));
        }
      case 'pixel_jaggy':
        final cell = m / 16;
        final o = Offset(s.width / 2 - cell * 7, s.height / 2 - cell * 3);
        final good = [(0, 0), (1, 0), (2, 1), (3, 1), (4, 2), (5, 2), (6, 3), (7, 3)];
        final bad = [(0, 0), (1, 0), (2, 0), (3, 1), (4, 2), (5, 2), (6, 2), (7, 3)];
        for (final (x, y) in good) {
          c.drawRect(Rect.fromLTWH(o.dx + x * cell, o.dy + y * cell, cell, cell), Paint()..color = const Color(0xFF2B3550));
        }
        for (final (x, y) in bad) {
          c.drawRect(Rect.fromLTWH(o.dx + (x + 0) * cell, o.dy + (y + 5) * cell, cell, cell), Paint()..color = const Color(0xFFC0392B));
        }
        _label(c, o + Offset(cell * 9, cell * 1), 'ровно: 2-2-2-2');
        _label(c, o + Offset(cell * 9, cell * 6), 'зубцы: 3-1-3-1');
    }
  }

  void _label(Canvas c, Offset at, String text) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: const TextStyle(fontSize: 11, color: Color(0xFF1B2335), fontWeight: FontWeight.w600)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at);
  }

  @override
  bool shouldRepaint(covariant GuidePainter old) => true;
}
