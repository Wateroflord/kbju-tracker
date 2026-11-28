import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/chess/camera.dart';
import 'package:kbju_tracker/plugins/chess/engine.dart' show Eval;
import 'package:kbju_tracker/plugins/chess/scan.dart';

Grid _start() => gridFromJson({
      'rows': ['rnbqkbnr', 'pppppppp', '8', '8', '8', '8', 'PPPPPPPP', 'RNBQKBNR'],
    })!;

Grid _ccw(Grid g) => List.generate(8, (i) => List.generate(8, (j) => g[j][7 - i]));

void main() {
  test('строки ответа ИИ: буквы, точки, цифры FEN, списки', () {
    expect(parseRow('rnbqkbnr'), 'rnbqkbnr'.split(''));
    expect(parseRow('3p4').join(), '...p....');
    expect(parseRow('..P').join(), '..P.....');
    expect(parseRow(['K', '', null, 'q']).join(), 'K..q....');
    expect(parseRow('PPPPPPPPPP').length, 8);
  });

  test('ответ ИИ без доски и с FEN', () {
    expect(gridFromJson({'board': false}), isNull);
    final g = gridFromJson({'fen': 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1'})!;
    expect(g[4].join(), '....P...');
  });

  test('начальная позиция → FEN с рокировками', () {
    expect(fenOf(_start(), true), 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    expect(positionProblem(_start(), true), isNull);
  });

  test('повороты: белые справа/слева/сверху находятся сами', () {
    final s = _start();
    final right = _ccw(s); // белые справа
    expect(rotationForWhiteSide('right'), 1);
    expect(rotate(right, 1), s);
    expect(guessRotation(right), 1);
    expect(guessRotation(rotate(s, 2)), 2);
    expect(guessRotation(rotate(s, 1)), 3);
    expect(guessRotation(s), 0);
    // ИИ ошибся со стороной — пешки на крайних горизонталях, берём догадку
    expect(pickRotation(right, 0), 1);
    expect(pickRotation(s, 0), 0);
  });

  test('клетка стандартной сетки ↔ клетка на фото', () {
    final s = _start();
    for (var r = 0; r < 4; r++) {
      final photo = rotate(s, (4 - r) % 4);
      expect(rotate(photo, r), s);
      for (var i = 0; i < 8; i++) {
        for (var j = 0; j < 8; j++) {
          final (a, b) = stdToGrid(i, j, r);
          expect(photo[a][b], s[i][j]);
        }
      }
    }
    expect(squareToStd('e2'), (6, 4));
    expect(squareCenterUv('a8', 0), (1 / 16, 1 / 16));
    expect(squareCenterUv('a1', 2), (15 / 16, 1 / 16));
  });

  test('проблемы позиции', () {
    final noKing = gridFromJson({'rows': ['8', '8', '8', '8', '8', '8', '8', '4K3']})!;
    expect(positionProblem(noKing, true), contains('королей'));
    // чёрным шах, а ход за белых — так не бывает
    final check = gridFromJson({'rows': ['4k3', '8', '8', '8', '8', '8', '8', '4RK2']})!;
    expect(positionProblem(check, true), contains('шах'));
    expect(positionProblem(check, false), isNull);
    final pawn = gridFromJson({'rows': ['P3k3', '8', '8', '8', '8', '8', '8', '4K3']})!;
    expect(positionProblem(pawn, true), contains('Пешка'));
  });

  test('перспектива: углы рамки и середина', () {
    final h = Homography.fromQuad([(10.0, 20.0), (300.0, 30.0), (330.0, 400.0), (0.0, 380.0)]);
    void near((double, double) a, (double, double) b) {
      expect(a.$1, closeTo(b.$1, 1e-6));
      expect(a.$2, closeTo(b.$2, 1e-6));
    }

    near(h.map(0, 0), (10, 20));
    near(h.map(1, 0), (300, 30));
    near(h.map(1, 1), (330, 400));
    near(h.map(0, 1), (0, 380));
    final sq = Homography.fromQuad([(0.0, 0.0), (8.0, 0.0), (8.0, 8.0), (0.0, 8.0)]);
    near(sq.map(0.5, 0.25), (4, 2));
  });

  test('подписи хода и оценки', () {
    expect(ruSan('Nf3'), 'Кf3');
    expect(ruSan('Qxd8+'), 'Фxd8+');
    expect(ruSan('O-O'), 'O-O');
    expect(describeMove(_start(), 'g1f3', 'Nf3'), 'Кf3 (конь g1 → f3)');
    expect(evalLine(const Eval(0, 2, null)), 'Мат в 2 хода!');
    expect(evalLine(const Eval(30, null, null)), startsWith('Примерно равно'));
    expect(evalLine(const Eval(-400, null, null)), startsWith('Позиция хуже'));
  });
}
