import 'package:flutter/material.dart';

import '../common/ui.dart';

/// Аппликатура аккорда. [frets] — от 6-й (толстой) струны к 1-й: -1 — не играть, 0 — открытая.
/// [fingers] — каким пальцем (1 — указательный … 4 — мизинец), 0 — без пальца.
class Chord {
  final String name;
  final List<int> frets;
  final List<int> fingers;

  /// Баррэ: лад и с какой струны (индекс 0 = 6-я). null — без баррэ.
  final int? barreFret, barreFrom;
  const Chord(this.name, this.frets, this.fingers, {this.barreFret, this.barreFrom});

  int get maxFret => frets.fold(0, (m, f) => f > m ? f : m);

  /// С какого лада рисовать схему (1 — от порожка).
  int get baseFret {
    if (maxFret <= 5) return 1;
    return frets.where((f) => f > 0).reduce((a, b) => a < b ? a : b);
  }
}

class ChordGroup {
  final String title, hint;
  final List<Chord> chords;
  const ChordGroup(this.title, this.hint, this.chords);
}

const chordGroups = [
  ChordGroup('Основные', 'С них начинают все: на этих 8 аккордах держится большинство песен.', [
    Chord('C', [-1, 3, 2, 0, 1, 0], [0, 3, 2, 0, 1, 0]),
    Chord('D', [-1, -1, 0, 2, 3, 2], [0, 0, 0, 1, 3, 2]),
    Chord('E', [0, 2, 2, 1, 0, 0], [0, 2, 3, 1, 0, 0]),
    Chord('G', [3, 2, 0, 0, 0, 3], [2, 1, 0, 0, 0, 3]),
    Chord('A', [-1, 0, 2, 2, 2, 0], [0, 0, 1, 2, 3, 0]),
    Chord('Am', [-1, 0, 2, 2, 1, 0], [0, 0, 2, 3, 1, 0]),
    Chord('Dm', [-1, -1, 0, 2, 3, 1], [0, 0, 0, 2, 3, 1]),
    Chord('Em', [0, 2, 2, 0, 0, 0], [0, 2, 3, 0, 0, 0]),
  ]),
  ChordGroup('Септаккорды', 'Звучат «блюзово» и тянут к следующему аккорду.', [
    Chord('A7', [-1, 0, 2, 0, 2, 0], [0, 0, 1, 0, 2, 0]),
    Chord('B7', [-1, 2, 1, 2, 0, 2], [0, 2, 1, 3, 0, 4]),
    Chord('C7', [-1, 3, 2, 3, 1, 0], [0, 3, 2, 4, 1, 0]),
    Chord('D7', [-1, -1, 0, 2, 1, 2], [0, 0, 0, 2, 1, 3]),
    Chord('E7', [0, 2, 0, 1, 0, 0], [0, 2, 0, 1, 0, 0]),
    Chord('G7', [3, 2, 0, 0, 0, 1], [3, 2, 0, 0, 0, 1]),
    Chord('Am7', [-1, 0, 2, 0, 1, 0], [0, 0, 2, 0, 1, 0]),
    Chord('Em7', [0, 2, 0, 0, 0, 0], [0, 2, 0, 0, 0, 0]),
    Chord('Dm7', [-1, -1, 0, 2, 1, 1], [0, 0, 0, 2, 1, 1]),
  ]),
  ChordGroup('Баррэ', 'Указательный палец зажимает все струны на одном ладу. Сначала тяжело — это нормально.', [
    Chord('F', [1, 3, 3, 2, 1, 1], [1, 3, 4, 2, 1, 1], barreFret: 1, barreFrom: 0),
    Chord('Fm', [1, 3, 3, 1, 1, 1], [1, 3, 4, 1, 1, 1], barreFret: 1, barreFrom: 0),
    Chord('F#m', [2, 4, 4, 2, 2, 2], [1, 3, 4, 1, 1, 1], barreFret: 2, barreFrom: 0),
    Chord('Gm', [3, 5, 5, 3, 3, 3], [1, 3, 4, 1, 1, 1], barreFret: 3, barreFrom: 0),
    Chord('Bb', [-1, 1, 3, 3, 3, 1], [0, 1, 3, 3, 3, 1], barreFret: 1, barreFrom: 1),
    Chord('B', [-1, 2, 4, 4, 4, 2], [0, 1, 3, 3, 3, 1], barreFret: 2, barreFrom: 1),
    Chord('Bm', [-1, 2, 4, 4, 3, 2], [0, 1, 3, 4, 2, 1], barreFret: 2, barreFrom: 1),
    Chord('Cm', [-1, 3, 5, 5, 4, 3], [0, 1, 3, 4, 2, 1], barreFret: 3, barreFrom: 1),
  ]),
  ChordGroup('Красивые', 'Sus, add9 и maj7 — простые и звучат «дороже» обычных.', [
    Chord('Cmaj7', [-1, 3, 2, 0, 0, 0], [0, 3, 2, 0, 0, 0]),
    Chord('Fmaj7', [-1, -1, 3, 2, 1, 0], [0, 0, 3, 2, 1, 0]),
    Chord('Amaj7', [-1, 0, 2, 1, 2, 0], [0, 0, 2, 1, 3, 0]),
    Chord('Cadd9', [-1, 3, 2, 0, 3, 3], [0, 2, 1, 0, 3, 4]),
    Chord('Dsus2', [-1, -1, 0, 2, 3, 0], [0, 0, 0, 1, 3, 0]),
    Chord('Dsus4', [-1, -1, 0, 2, 3, 3], [0, 0, 0, 1, 3, 4]),
    Chord('Asus2', [-1, 0, 2, 2, 0, 0], [0, 0, 1, 2, 0, 0]),
    Chord('Asus4', [-1, 0, 2, 2, 3, 0], [0, 0, 1, 2, 3, 0]),
    Chord('Esus4', [0, 2, 2, 2, 0, 0], [0, 2, 3, 4, 0, 0]),
  ]),
  ChordGroup('Квинты (пауэр-аккорды)', 'Две-три струны, для рока и металла. Лишние струны глуши ладонью.', [
    Chord('E5', [0, 2, 2, -1, -1, -1], [0, 1, 2, 0, 0, 0]),
    Chord('A5', [-1, 0, 2, 2, -1, -1], [0, 0, 1, 2, 0, 0]),
    Chord('G5', [3, 5, 5, -1, -1, -1], [1, 3, 4, 0, 0, 0]),
    Chord('C5', [-1, 3, 5, 5, -1, -1], [0, 1, 3, 4, 0, 0]),
    Chord('D5', [-1, 5, 7, 7, -1, -1], [0, 1, 3, 4, 0, 0]),
  ]),
];

/// Все аккорды одним списком (для тренажёра).
List<Chord> get allChords => [for (final g in chordGroups) ...g.chords];

Chord? chordByName(String name) {
  for (final c in allChords) {
    if (c.name == name) return c;
  }
  return null;
}

/// Схема аккорда: 6 струн, 5 ладов, точки с номерами пальцев.
class ChordDiagram extends StatelessWidget {
  final Chord chord;
  final double width;
  const ChordDiagram(this.chord, {super.key, this.width = 120});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size(width, width * 1.25), painter: _ChordPainter(chord, W.accent));
}

class _ChordPainter extends CustomPainter {
  final Chord c;
  final Color accent;
  _ChordPainter(this.c, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    const frets = 5;
    final left = size.width * 0.16, right = size.width * 0.92;
    final top = size.height * 0.16, bottom = size.height * 0.96;
    final sx = (right - left) / 5, fy = (bottom - top) / frets;
    final line = Paint()
      ..color = W.muted
      ..strokeWidth = 1.2;
    final base = c.baseFret;

    for (var s = 0; s < 6; s++) {
      canvas.drawLine(Offset(left + s * sx, top), Offset(left + s * sx, bottom), line);
    }
    for (var f = 0; f <= frets; f++) {
      canvas.drawLine(Offset(left, top + f * fy), Offset(right, top + f * fy), line);
    }
    if (base == 1) {
      canvas.drawRect(Rect.fromLTRB(left - 1, top - 4, right + 1, top), Paint()..color = W.text);
    } else {
      _text(canvas, '$base', Offset(left - sx * 0.55, top + fy * 0.5), size.width * 0.1, W.muted);
    }

    // Над грифом: × — не играть, ○ — открытая.
    for (var s = 0; s < 6; s++) {
      final f = c.frets[s];
      final o = Offset(left + s * sx, top - size.height * 0.075);
      if (f < 0) {
        _text(canvas, '×', o, size.width * 0.11, W.bad);
      } else if (f == 0) {
        canvas.drawCircle(o, sx * 0.22, Paint()
          ..color = W.text
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4);
      }
    }

    final dot = Paint()..color = accent;
    final r = sx * 0.36;
    if (c.barreFret != null) {
      final y = top + (c.barreFret! - base + 0.5) * fy;
      final from = c.barreFrom ?? 0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTRB(left + from * sx - r, y - r, right + r, y + r), Radius.circular(r)),
        dot,
      );
    }
    for (var s = 0; s < 6; s++) {
      final f = c.frets[s];
      if (f <= 0) continue;
      final o = Offset(left + s * sx, top + (f - base + 0.5) * fy);
      final onBarre = c.barreFret == f && s >= (c.barreFrom ?? 0) && c.fingers[s] == 1;
      if (!onBarre) canvas.drawCircle(o, r, dot);
      if (c.fingers[s] > 0 && !onBarre) _text(canvas, '${c.fingers[s]}', o, r * 1.2, W.bg);
    }
    if (c.barreFret != null) {
      _text(canvas, '1', Offset(left + (c.barreFrom ?? 0) * sx, top + (c.barreFret! - base + 0.5) * fy), r * 1.2, W.bg);
    }
  }

  void _text(Canvas canvas, String s, Offset center, double fontSize, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: color, fontSize: fontSize, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_ChordPainter old) => old.c != c || old.accent != accent;
}
