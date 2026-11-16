import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

/// Ограничивает ширину контента на больших экранах (ПК).
class Narrow extends StatelessWidget {
  final Widget child;
  final double max;
  const Narrow({super.key, required this.child, this.max = 760});
  @override
  Widget build(BuildContext context) =>
      Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: max), child: child));
}

/// Кольцо с оценкой.
class ScoreRing extends StatelessWidget {
  final double score;
  final double size;
  final Color? color;
  final String? caption;
  const ScoreRing({super.key, required this.score, this.size = 120, this.color, this.caption});

  @override
  Widget build(BuildContext context) {
    final c = color ?? scoreColor(score);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(v / 10, c),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                v.toStringAsFixed(1),
                style: TextStyle(fontSize: size * 0.28, fontWeight: FontWeight.w900, color: c, height: 1),
              ),
              if (caption != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(caption!, style: TextStyle(fontSize: size * 0.1, color: C.muted)),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  final Color color;
  _RingPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.075;
    final rect = Offset(w / 2, w / 2) & Size(size.width - w, size.height - w);
    final bg = Paint()
      ..color = C.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = w;
    canvas.drawArc(rect, 0, math.pi * 2, false, bg);
    final fg = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: [color.withValues(alpha: 0.55), color],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = w;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * t.clamp(0.0, 1.0).toDouble(), false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t || old.color != color;
}

/// Горизонтальная полоска оценки 0–10.
class ScoreBar extends StatelessWidget {
  final double? score;
  final Color? color;
  final double height;
  final bool reverse;
  const ScoreBar({super.key, required this.score, this.color, this.height = 8, this.reverse = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? scoreColor(score);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: C.surface2,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (score ?? 0) / 10),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => FractionallySizedBox(
            alignment: reverse ? Alignment.centerRight : Alignment.centerLeft,
            widthFactor: v.clamp(0.0, 1.0).toDouble(),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(height),
                gradient: LinearGradient(
                  begin: reverse ? Alignment.centerRight : Alignment.centerLeft,
                  end: reverse ? Alignment.centerLeft : Alignment.centerRight,
                  colors: [c.withValues(alpha: 0.6), c],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  const SectionTitle(this.text, {super.key, this.icon, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Row(children: [
          if (icon != null) ...[Icon(icon, size: 20, color: color ?? C.gold), const SizedBox(width: 8)],
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color ?? C.text, letterSpacing: 0.2)),
          ),
        ]),
      );
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.borderColor});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor ?? C.border),
        ),
        child: child,
      );
}

/// Список пунктов с маркером.
class Bullets extends StatelessWidget {
  final List<String> items;
  final IconData icon;
  final Color color;
  const Bullets(this.items, {super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final s in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: Icon(icon, size: 16, color: color)),
                const SizedBox(width: 10),
                Expanded(child: Text(s, style: const TextStyle(fontSize: 14.5, height: 1.35))),
              ]),
            ),
        ],
      );
}

/// Карточка совета.
class TipCard extends StatelessWidget {
  final Tip tip;
  final int index;
  const TipCard(this.tip, this.index, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (tip.impact) {
      'high' => ('сильный эффект', C.good),
      'low' => ('мелочь', C.muted),
      _ => ('заметный эффект', C.mid),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: C.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text('$index', style: const TextStyle(fontWeight: FontWeight.w900, color: C.gold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(tip.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Text(tip.text, style: const TextStyle(fontSize: 14.5, height: 1.4, color: Color(0xFFDCD6E4))),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Картинка из байтов или base64 со скруглением.
class PhotoBox extends StatelessWidget {
  final Uint8List? bytes;
  final String? b64;
  final double? width;
  final double? height;
  final double radius;
  final Color? border;
  const PhotoBox({super.key, this.bytes, this.b64, this.width, this.height, this.radius = 16, this.border});

  @override
  Widget build(BuildContext context) {
    Uint8List? data = bytes;
    if (data == null && b64 != null && b64!.isNotEmpty) {
      try {
        data = base64Decode(b64!);
      } catch (_) {}
    }
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: C.surface2,
        borderRadius: BorderRadius.circular(radius),
        border: border != null ? Border.all(color: border!, width: 2) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: data == null
          ? const Icon(Icons.person_outline, color: C.muted)
          : Image.memory(data, fit: BoxFit.cover, gaplessPlayback: true),
    );
  }
}

/// Переключатель «Внешность / Стиль / Синергия».
class KindPicker extends StatelessWidget {
  final Kind value;
  final ValueChanged<Kind> onChanged;
  const KindPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<Kind>(
            showSelectedIcon: false,
            segments: [
              for (final k in Kind.values)
                ButtonSegment(
                  value: k,
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(k.title, maxLines: 1, softWrap: false),
                  ),
                ),
            ],
            selected: {value},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
          const SizedBox(height: 10),
          Text(value.about, style: const TextStyle(color: C.muted, fontSize: 13.5, height: 1.35)),
        ],
      );
}

