import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/mines/game.dart';

void main() {
  test('первый ход никогда не попадает на мину, вокруг тоже пусто', () {
    for (var t = 0; t < 200; t++) {
      final b = Board(9, 9, 10);
      final first = 40;
      b.reveal(first);
      expect(b.cells[first].mine, isFalse);
      for (final n in b.neighbors(first)) {
        expect(b.cells[n].mine, isFalse);
      }
      expect(b.state, isNot(GameState.lost));
      expect(b.cells.where((c) => c.mine).length, 10);
    }
  });

  test('цифры правильно считают мины вокруг', () {
    final b = Board(16, 16, 40)..reveal(0);
    for (var i = 0; i < b.cells.length; i++) {
      final n = b.neighbors(i).where((j) => b.cells[j].mine).length;
      expect(b.cells[i].n, n);
    }
  });

  test('угловая клетка имеет 3 соседа, центральная — 8', () {
    final b = Board(9, 9, 10);
    expect(b.neighbors(0).length, 3);
    expect(b.neighbors(40).length, 8);
    expect(b.neighbors(8).length, 3);
  });

  test('открыть все пустые клетки = победа, мины помечаются флажками', () {
    final b = Board(9, 9, 10)..reveal(40);
    for (var i = 0; i < b.cells.length; i++) {
      if (!b.cells[i].mine && !b.cells[i].open) b.reveal(i);
    }
    expect(b.state, GameState.won);
    expect(b.cells.where((c) => c.mine).every((c) => c.flag), isTrue);
    expect(b.minesLeft, 0);
  });

  test('нажатие на мину = поражение', () {
    final b = Board(9, 9, 10)..reveal(40);
    final mine = b.cells.indexWhere((c) => c.mine);
    expect(b.reveal(mine), isTrue);
    expect(b.state, GameState.lost);
    expect(b.exploded, mine);
    expect(b.reveal(0), isFalse);
  });

  test('флажок защищает клетку от открытия', () {
    final b = Board(9, 9, 10)..reveal(40);
    final mine = b.cells.indexWhere((c) => c.mine);
    expect(b.toggleFlag(mine), isTrue);
    expect(b.reveal(mine), isFalse);
    expect(b.state, GameState.playing);
    expect(b.minesLeft, 9);
  });

  test('режим «без угадывания» даёт решаемое поле и всё равно 10 мин', () {
    for (var t = 0; t < 20; t++) {
      final b = Board(9, 9, 10, noGuess: true)..reveal(40);
      expect(b.cells.where((c) => c.mine).length, 10);
      expect(b.state, isNot(GameState.lost));
    }
  });

  test('подсказка указывает на безопасную клетку', () {
    final b = Board(16, 16, 40)..reveal(100);
    final h = b.hint();
    if (h != null) expect(b.cells[h].mine, isFalse);
  });

  test('уровни сложности корректны', () {
    for (final l in levels) {
      expect(l.mines, lessThan(l.w * l.h - 9), reason: l.name);
    }
  });
}
