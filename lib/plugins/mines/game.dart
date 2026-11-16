import 'dart:math' as math;

/// Уровень сложности.
class Level {
  final String id, name;
  final int w, h, mines;
  const Level(this.id, this.name, this.w, this.h, this.mines);
}

const levels = [
  Level('easy', 'Новичок', 9, 9, 10),
  Level('mid', 'Любитель', 16, 16, 40),
  Level('hard', 'Профи', 30, 16, 99),
];

enum GameState { ready, playing, won, lost }

class Cell {
  bool mine = false;
  bool open = false;
  bool flag = false;
  int n = 0; // мин вокруг
}

/// Поле сапёра.
class Board {
  final int w, h, mines;
  final bool noGuess;
  late List<Cell> cells;
  GameState state = GameState.ready;
  int? exploded;
  DateTime? started;
  Duration elapsed = Duration.zero;
  final math.Random _rnd = math.Random();

  Board(this.w, this.h, this.mines, {this.noGuess = false}) {
    cells = List.generate(w * h, (_) => Cell());
  }

  Cell at(int x, int y) => cells[y * w + x];
  int idx(int x, int y) => y * w + x;

  Iterable<int> neighbors(int i) sync* {
    final x = i % w, y = i ~/ w;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx, ny = y + dy;
        if (nx >= 0 && ny >= 0 && nx < w && ny < h) yield ny * w + nx;
      }
    }
  }

  int get flags => cells.where((c) => c.flag).length;
  int get minesLeft => mines - flags;

  /// Расставить мины так, чтобы первая клетка и её соседи были пустыми.
  void _place(int first) {
    final safe = {first, ...neighbors(first)};
    final spots = [for (var i = 0; i < w * h; i++) if (!safe.contains(i)) i];
    // Если поле слишком маленькое — оставляем безопасной только саму клетку.
    if (spots.length < mines) {
      spots
        ..clear()
        ..addAll([for (var i = 0; i < w * h; i++) if (i != first) i]);
    }
    for (final c in cells) {
      c.mine = false;
      c.n = 0;
    }
    spots.shuffle(_rnd);
    for (final i in spots.take(mines)) {
      cells[i].mine = true;
    }
    for (var i = 0; i < cells.length; i++) {
      cells[i].n = neighbors(i).where((j) => cells[j].mine).length;
    }
  }

  /// Можно ли решить поле одной логикой, начиная с клетки [first].
  bool _solvable(int first) {
    final open = List<bool>.filled(w * h, false);
    final mine = List<bool>.filled(w * h, false);
    void reveal(int i) {
      final stack = [i];
      while (stack.isNotEmpty) {
        final c = stack.removeLast();
        if (open[c]) continue;
        open[c] = true;
        if (cells[c].n == 0) {
          for (final n in neighbors(c)) {
            if (!open[n]) stack.add(n);
          }
        }
      }
    }

    reveal(first);
    var progress = true;
    while (progress) {
      progress = false;
      final frontier = <int>[];
      for (var i = 0; i < cells.length; i++) {
        if (!open[i] || cells[i].n == 0) continue;
        final unknown = neighbors(i).where((j) => !open[j] && !mine[j]).toList();
        if (unknown.isEmpty) continue;
        frontier.add(i);
        final left = cells[i].n - neighbors(i).where((j) => mine[j]).length;
        if (left == 0) {
          for (final j in unknown) {
            reveal(j);
          }
          progress = true;
        } else if (left == unknown.length) {
          for (final j in unknown) {
            mine[j] = true;
          }
          progress = true;
        }
      }
      if (progress) continue;
      // Правило подмножеств: если соседи A ⊂ соседи B.
      for (final a in frontier) {
        final ua = neighbors(a).where((j) => !open[j] && !mine[j]).toSet();
        final la = cells[a].n - neighbors(a).where((j) => mine[j]).length;
        for (final b in frontier) {
          if (a == b) continue;
          final ub = neighbors(b).where((j) => !open[j] && !mine[j]).toSet();
          if (ua.isEmpty || !ub.containsAll(ua) || ub.length == ua.length) continue;
          final lb = cells[b].n - neighbors(b).where((j) => mine[j]).length;
          final rest = ub.difference(ua);
          if (lb - la == 0) {
            for (final j in rest) {
              reveal(j);
            }
            progress = true;
          } else if (lb - la == rest.length) {
            for (final j in rest) {
              mine[j] = true;
            }
            progress = true;
          }
          if (progress) break;
        }
        if (progress) break;
      }
    }
    for (var i = 0; i < cells.length; i++) {
      if (!cells[i].mine && !open[i]) return false;
    }
    return true;
  }

  void _start(int first) {
    if (noGuess) {
      for (var t = 0; t < 400; t++) {
        _place(first);
        if (_solvable(first)) break;
      }
    } else {
      _place(first);
    }
    state = GameState.playing;
    started = DateTime.now();
  }

  Duration get time => state == GameState.playing && started != null ? DateTime.now().difference(started!) : elapsed;

  void _end(GameState s) {
    state = s;
    elapsed = started == null ? Duration.zero : DateTime.now().difference(started!);
  }

  /// Открыть клетку. true — что-то изменилось.
  bool reveal(int i) {
    if (state == GameState.won || state == GameState.lost) return false;
    if (state == GameState.ready) _start(i);
    final c = cells[i];
    if (c.flag) return false;
    if (c.open) return chord(i);
    if (c.mine) {
      c.open = true;
      exploded = i;
      for (final m in cells) {
        if (m.mine) m.open = true;
      }
      _end(GameState.lost);
      return true;
    }
    final stack = [i];
    while (stack.isNotEmpty) {
      final k = stack.removeLast();
      final cell = cells[k];
      if (cell.open || cell.flag) continue;
      cell.open = true;
      if (cell.n == 0) stack.addAll(neighbors(k).where((j) => !cells[j].open));
    }
    _checkWin();
    return true;
  }

  /// Нажатие на открытую цифру: если флажков вокруг столько же — открыть остальных соседей.
  bool chord(int i) {
    final c = cells[i];
    if (!c.open || c.n == 0) return false;
    final nb = neighbors(i).toList();
    if (nb.where((j) => cells[j].flag).length != c.n) return false;
    var changed = false;
    for (final j in nb) {
      if (!cells[j].open && !cells[j].flag) {
        changed = reveal(j) || changed;
        if (state == GameState.lost) break;
      }
    }
    return changed;
  }

  bool toggleFlag(int i) {
    if (state == GameState.won || state == GameState.lost) return false;
    final c = cells[i];
    if (c.open) return false;
    c.flag = !c.flag;
    return true;
  }

  void _checkWin() {
    if (cells.every((c) => c.mine || c.open)) {
      for (final c in cells) {
        if (c.mine) c.flag = true;
      }
      _end(GameState.won);
    }
  }

  /// Подсказка: безопасная закрытая клетка рядом с открытыми (если есть).
  int? hint() {
    if (state != GameState.playing) return null;
    final edge = <int>[];
    for (var i = 0; i < cells.length; i++) {
      final c = cells[i];
      if (c.open || c.flag || c.mine) continue;
      if (neighbors(i).any((j) => cells[j].open)) edge.add(i);
    }
    if (edge.isEmpty) return null;
    return edge[_rnd.nextInt(edge.length)];
  }
}
