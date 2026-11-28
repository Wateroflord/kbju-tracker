import 'package:chess/chess.dart' as ch;

/// Распознавание доски по фото: всё, что не зависит от камеры и ИИ.
///
/// Grid — 8 строк по 8 клеток так, как доска видна на снимке (строка 0 — верх фото).
/// Заглавные KQRBNP — белые, строчные — чёрные, '.' — пусто.
/// «Стандартная» сетка — белые снизу: строка 0 = 8-я горизонталь, столбец 0 = вертикаль a.
typedef Grid = List<List<String>>;

const pieceChars = 'KQRBNPkqrbnp';
const _emptyChars = {'.', '-', '_', '0', '·', '*', ' '};

Grid emptyGrid() => List.generate(8, (_) => List.filled(8, '.'));

Grid copyGrid(Grid g) => [for (final r in g) [...r]];

/// Строка ответа ИИ → 8 клеток. Понимает «rnbqkbnr», «..p.....», FEN-цифры «3p4».
List<String> parseRow(Object? row) {
  final out = <String>[];
  if (row is List) {
    for (final e in row) {
      if (out.length >= 8) break;
      final s = '${e ?? ''}'.trim();
      out.add(s.length == 1 && pieceChars.contains(s) ? s : '.');
    }
  } else {
    for (final c in '${row ?? ''}'.split('')) {
      if (out.length >= 8) break;
      if (pieceChars.contains(c)) {
        out.add(c);
      } else if (_emptyChars.contains(c)) {
        if (c != ' ') out.add('.');
      } else {
        final n = int.tryParse(c);
        if (n != null && n >= 1 && n <= 8) {
          for (var i = 0; i < n && out.length < 8; i++) {
            out.add('.');
          }
        }
      }
    }
  }
  while (out.length < 8) {
    out.add('.');
  }
  return out;
}

/// Ответ ИИ ({"rows": [...]} или {"fen": "..."}) → сетка как на фото. null — доски нет.
Grid? gridFromJson(Map<String, dynamic> j) {
  if (j['board'] == false) return null;
  Object? rows = j['rows'];
  if (rows is! List || rows.isEmpty) {
    final fen = '${j['fen'] ?? ''}'.trim();
    if (fen.isEmpty) return null;
    rows = fen.split(' ').first.split('/');
  }
  final list = rows;
  final g = <List<String>>[];
  for (var i = 0; i < 8; i++) {
    g.add(parseRow(i < list.length ? list[i] : ''));
  }
  return g;
}

/// Сторона фото, где стоят белые → сколько раз повернуть сетку по часовой, чтобы белые оказались снизу.
int? rotationForWhiteSide(Object? side) => switch ('${side ?? ''}'.toLowerCase().trim()) {
      'bottom' => 0,
      'right' => 1,
      'top' => 2,
      'left' => 3,
      _ => null,
    };

/// Поворот на 90° по часовой.
Grid rotateCw(Grid g) => List.generate(8, (i) => List.generate(8, (j) => g[7 - j][i]));

/// Сетка с фото → стандартная (белые снизу) при повороте [r] (0..3, по часовой).
Grid rotate(Grid g, int r) {
  var x = g;
  for (var k = 0; k < r % 4; k++) {
    x = rotateCw(x);
  }
  return x;
}

/// Клетка стандартной сетки (строка, столбец) → клетка сетки с фото.
(int, int) stdToGrid(int i, int j, int r) {
  var a = i, b = j;
  for (var k = 0; k < r % 4; k++) {
    final t = a;
    a = 7 - b;
    b = t;
  }
  return (a, b);
}

/// «e4» → клетка стандартной сетки (строка 0 = 8-я горизонталь).
(int, int) squareToStd(String sq) => (8 - int.parse(sq[1]), 'abcdefgh'.indexOf(sq[0]));

/// Если ИИ не понял, где белые, — угадываем по фигурам: белые обычно ближе к своему краю,
/// пешек на крайних горизонталях не бывает.
int guessRotation(Grid g) {
  var best = 0;
  var bestScore = -(1 << 30);
  for (final r in const [0, 2, 1, 3]) {
    final s = rotate(g, r);
    var score = 0;
    for (var i = 0; i < 8; i++) {
      for (var j = 0; j < 8; j++) {
        final c = s[i][j];
        if (c == '.') continue;
        final white = c == c.toUpperCase();
        final pawn = c == 'P' || c == 'p';
        final w = pawn ? 2 : 1;
        score += (white ? i : 7 - i) * w;
        if (pawn && (i == 0 || i == 7)) score -= 60;
        if (c == 'K' && i == 7) score += 6;
        if (c == 'k' && i == 0) score += 6;
      }
    }
    if (score > bestScore) {
      bestScore = score;
      best = r;
    }
  }
  return best;
}

bool _pawnOnEdge(Grid std) => [...std[0], ...std[7]].any((c) => c == 'P' || c == 'p');

/// Поворот: подсказка ИИ ([hinted]), но если с ней пешки оказываются на крайних горизонталях,
/// а с нашей догадкой — нет, верим догадке.
int pickRotation(Grid g, int? hinted) {
  final guess = guessRotation(g);
  if (hinted == null) return guess;
  if (_pawnOnEdge(rotate(g, hinted)) && !_pawnOnEdge(rotate(g, guess))) return guess;
  return hinted;
}

String placement(Grid std) => std.map((row) {
      final b = StringBuffer();
      var n = 0;
      for (final c in row) {
        if (c == '.') {
          n++;
        } else {
          if (n > 0) b.write(n);
          n = 0;
          b.write(c);
        }
      }
      if (n > 0) b.write(n);
      return b.toString();
    }).join('/');

/// Рокировки — если король и ладья стоят на своих местах.
String castling(Grid std) {
  var c = '';
  if (std[7][4] == 'K') {
    if (std[7][7] == 'R') c += 'K';
    if (std[7][0] == 'R') c += 'Q';
  }
  if (std[0][4] == 'k') {
    if (std[0][7] == 'r') c += 'k';
    if (std[0][0] == 'r') c += 'q';
  }
  return c.isEmpty ? '-' : c;
}

String fenOf(Grid std, bool whiteToMove) => '${placement(std)} ${whiteToMove ? 'w' : 'b'} ${castling(std)} - 0 1';

int _count(Grid g, String c) => g.fold(0, (s, r) => s + r.where((x) => x == c).length);

/// Что не так с позицией (по-русски) или null, если по ней можно считать ход.
String? positionProblem(Grid std, bool whiteToMove) {
  final wk = _count(std, 'K'), bk = _count(std, 'k');
  if (wk != 1 || bk != 1) {
    return 'Вижу королей: белых $wk, чёрных $bk — а нужно по одному. Поправь фигуры или переснимай.';
  }
  if (_pawnOnEdge(std)) {
    return 'Пешка на крайней горизонтали — так не бывает. Поверни доску ↻ или поправь фигуры.';
  }
  var white = 0, black = 0;
  for (final r in std) {
    for (final c in r) {
      if (c == '.') continue;
      if (c == c.toUpperCase()) {
        white++;
      } else {
        black++;
      }
    }
  }
  if (white > 16 || black > 16 || _count(std, 'P') > 8 || _count(std, 'p') > 8) {
    return 'Слишком много фигур — похоже, ИИ ошибся. Поправь фигуры или переснимай.';
  }
  try {
    final other = ch.Chess.fromFEN(fenOf(std, !whiteToMove));
    if (other.in_check) {
      final o = whiteToMove ? 'чёрным' : 'белым';
      return 'Сейчас шах $o, значит ход не за этой стороной. Выбери другую кнопку или поправь фигуры.';
    }
  } catch (_) {
    return 'Позиция не читается. Поправь фигуры или переснимай.';
  }
  return null;
}

/// Перспектива: единичный квадрат (u, v ∈ 0..1) → четырёхугольник p0 (верх-лево), p1 (верх-право),
/// p2 (низ-право), p3 (низ-лево). Точки — пары (x, y).
class Homography {
  final double a, b, c, d, e, f, g, h;
  const Homography._(this.a, this.b, this.c, this.d, this.e, this.f, this.g, this.h);

  factory Homography.fromQuad(List<(double, double)> p) {
    final (x0, y0) = p[0];
    final (x1, y1) = p[1];
    final (x2, y2) = p[2];
    final (x3, y3) = p[3];
    final sx = x0 - x1 + x2 - x3, sy = y0 - y1 + y2 - y3;
    final dx1 = x1 - x2, dx2 = x3 - x2, dy1 = y1 - y2, dy2 = y3 - y2;
    final den = dx1 * dy2 - dx2 * dy1;
    var g = 0.0, h = 0.0;
    if (den.abs() > 1e-12) {
      g = (sx * dy2 - dx2 * sy) / den;
      h = (dx1 * sy - sx * dy1) / den;
    }
    return Homography._(x1 - x0 + g * x1, x3 - x0 + h * x3, x0, y1 - y0 + g * y1, y3 - y0 + h * y3, y0, g, h);
  }

  (double, double) map(double u, double v) {
    var w = g * u + h * v + 1;
    if (w.abs() < 1e-9) w = 1e-9;
    return ((a * u + b * v + c) / w, (d * u + e * v + f) / w);
  }
}

/// Центр клетки [sq] на фото (0..1 внутри рамки) при повороте [r].
(double, double) squareCenterUv(String sq, int r) {
  final (i, j) = squareToStd(sq);
  final (gi, gj) = stdToGrid(i, j, r);
  return ((gj + 0.5) / 8, (gi + 0.5) / 8);
}

/// Углы клетки [sq] (в долях рамки) при повороте [r]: верх-лево, верх-право, низ-право, низ-лево — как на фото.
List<(double, double)> squareCornersUv(String sq, int r) {
  final (i, j) = squareToStd(sq);
  final (gi, gj) = stdToGrid(i, j, r);
  final u0 = gj / 8, v0 = gi / 8, u1 = (gj + 1) / 8, v1 = (gi + 1) / 8;
  return [(u0, v0), (u1, v0), (u1, v1), (u0, v1)];
}

/// Подсказка для ИИ: как читать фото доски.
const scanPrompt = '''
You read chess positions from photos of real (physical) chessboards or boards on a screen.
Image 1: the board straightened to a top-down view; the 8x8 playing area roughly fills the image, with a small margin.
Image 2: the original photo from the same camera. Use it to recognise piece shapes and colours.
Pieces are tall, so in image 1 they may lean into the square above; a piece belongs to the square its base stands on.

Answer with JSON only:
{"board": true, "rows": ["........", "........", "........", "........", "........", "........", "........", "........"], "white_side": "bottom", "confidence": 0.9, "note": ""}

rows: exactly 8 strings, first string = the top row of squares in image 1, each string = 8 squares from left to right.
Use K Q R B N P for WHITE (light-coloured) pieces, k q r b n p for BLACK (dark-coloured) pieces, "." for an empty square.
white_side: which edge of image 1 is White's home side (ranks 1-2): "bottom", "top", "left", "right" or "unknown".
Decide it from the coordinate letters/numbers printed on the board if visible, otherwise from where the white king and most white pawns stand.
confidence: 0..1, how sure you are about the whole position.
note: short note in Russian if something is unclear (for example a square is hidden by a hand), else "".
If there is no chessboard in image 1, answer {"board": false}.
Double-check before answering: every row has exactly 8 squares, each side has exactly one king, pawns are never on the first or last rank.
''';
