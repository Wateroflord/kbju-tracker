import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:chess/chess.dart' as ch;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Оценка позиции с точки зрения стороны, которая ходит. mate: ходов до мата (минус — мат нам).
class Eval {
  final int cp;
  final int? mate;
  final String? best;
  const Eval(this.cp, this.mate, this.best);

  /// Оценка в «пешках×100», маты сводятся к большим числам.
  int get score => mate == null ? cp : (mate! > 0 ? 10000 - mate! * 10 : -10000 - mate! * 10);
}

/// Уровни бота.
class BotLevel {
  final String name;
  final int elo; // примерно, для подписи
  final int skill; // Skill Level Stockfish 0–20; -1 — встроенный простой бот
  final int movetime;
  final int dartDepth;
  final double random;
  const BotLevel(this.name, this.elo, this.skill, this.movetime, {this.dartDepth = 2, this.random = 0});
}

const botLevels = [
  BotLevel('Новичок', 400, -1, 0, dartDepth: 1, random: 0.45),
  BotLevel('Ученик', 700, -1, 0, dartDepth: 2, random: 0.15),
  BotLevel('Любитель', 1000, 0, 80),
  BotLevel('Клубный', 1300, 4, 150),
  BotLevel('Сильный', 1600, 8, 250),
  BotLevel('Кандидат', 1900, 12, 400),
  BotLevel('Мастер', 2300, 16, 700),
  BotLevel('Stockfish', 3000, 20, 1500),
];

/// Откуда телефон скачивает нейросети Stockfish (их туда выкладывает сборка, tools/stockfish.sh).
const stockfishNetsUrl = 'https://github.com/Wateroflord/kbju-tracker/releases/download/stockfish-nets/';

/// Движок Stockfish (UCI) — отдельная программа рядом с приложением.
///
/// На телефоне программа маленькая (без встроенной нейросети), а сама нейросеть (~100 МБ)
/// скачивается один раз при первом открытии шахмат — так обновления КБЖУ не тянут её каждый раз.
class Stockfish {
  Stockfish._();
  static final Stockfish instance = Stockfish._();

  Process? _p;
  final _lines = StreamController<String>.broadcast();
  Future<void> _lock = Future.value();
  bool? _available;
  String? error;

  /// Нейросети, которых не хватает движку (имена файлов nn-….nnue). Пусто — всё на месте.
  List<String> missingNets = const [];
  bool get needsNets => missingNets.isNotEmpty;

  bool get running => _p != null;

  /// Папка с нейросетями (не попадает в резервную копию Android — там только файл данных КБЖУ).
  static Future<Directory> netDir() async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}stockfish');
    await d.create(recursive: true);
    return d;
  }

  static Future<String?> _path() async {
    try {
      if (Platform.isWindows) {
        final p = '${File(Platform.resolvedExecutable).parent.path}\\stockfish.exe';
        return File(p).existsSync() ? p : null;
      }
      if (Platform.isAndroid) {
        final dir = await const MethodChannel('winterchess/engine').invokeMethod<String>('libDir');
        final p = '$dir/libstockfish.so';
        return dir != null && File(p).existsSync() ? p : null;
      }
    } catch (_) {}
    return null;
  }

  /// Запустить движок (если ещё не запущен). false — Stockfish недоступен, будет встроенный бот.
  Future<bool> start() async {
    if (_p != null) return true;
    if (_available == false) return false;
    final path = await _path();
    if (path == null) {
      _available = false;
      error = 'Stockfish не найден';
      return false;
    }
    try {
      final dir = await netDir();
      // Рабочая папка = папка нейросетей: движок сам находит в ней файлы с нужными именами.
      final p = await Process.start(path, [], workingDirectory: dir.path);
      _p = p;
      p.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_lines.add);
      p.stderr.drain<void>();
      p.exitCode.then((_) {
        if (identical(_p, p)) _p = null;
      });
      // Какие нейросети нужны движку: «option name EvalFile… default nn-….nnue».
      final nets = <String, String>{};
      final sub = _lines.stream.listen((l) {
        final m = RegExp(r'^option name (EvalFile\w*) type string default (nn-[0-9a-f]+\.nnue)').firstMatch(l);
        if (m != null) nets[m.group(1)!] = m.group(2)!;
      });
      _send('uci');
      await _wait((l) => l == 'uciok', const Duration(seconds: 8));
      await sub.cancel();
      final threads = math.max(1, math.min(4, Platform.numberOfProcessors - 1));
      _send('setoption name Threads value $threads');
      _send('setoption name Hash value 64');
      final missing = <String>[];
      for (final e in nets.entries) {
        final f = File('${dir.path}${Platform.pathSeparator}${e.value}');
        if (f.existsSync()) {
          _send('setoption name ${e.key} value ${f.path}');
        } else {
          missing.add(e.value);
        }
      }
      _send('isready');
      await _wait((l) => l == 'readyok', const Duration(seconds: 8));
      // Файлов нет — проверяем, не встроена ли нейросеть в сам движок (Windows, старые сборки).
      if (missing.isNotEmpty && !await _probe(p)) {
        missingNets = missing;
        error = 'Нужно скачать нейросеть Stockfish';
        stop();
        _available = false;
        return false;
      }
      missingNets = const [];
      _available = true;
      return true;
    } catch (e) {
      error = '$e';
      _p?.kill();
      _p = null;
      _available = false;
      return false;
    }
  }

  void _send(String cmd) => _p?.stdin.writeln(cmd);

  /// Может ли движок посчитать ход (без нейросети он пишет ошибку и закрывается).
  Future<bool> _probe(Process p) async {
    try {
      _send('position startpos');
      _send('go depth 1');
      return await Future.any([
        _lines.stream.firstWhere((l) => l.startsWith('bestmove')).then((_) => true),
        p.exitCode.then((_) => false),
      ]).timeout(const Duration(seconds: 10));
    } catch (_) {
      return false;
    }
  }

  /// Скачать недостающие нейросети (один раз). [progress] — 0…1.
  /// Каждый файл проверяется: имя nn-XXXXXXXXXXXX.nnue — это начало его SHA-256.
  Future<void> downloadNets(void Function(double) progress, {bool Function()? cancelled}) async {
    final dir = await netDir();
    final names = List<String>.from(missingNets);
    final client = http.Client();
    try {
      // Размеры — чтобы прогресс шёл по всем файлам сразу.
      final sizes = <String, int>{};
      for (final n in names) {
        try {
          final r = await client.head(Uri.parse('$stockfishNetsUrl$n')).timeout(const Duration(seconds: 20));
          sizes[n] = int.tryParse(r.headers['content-length'] ?? '') ?? 0;
        } catch (_) {
          sizes[n] = 0;
        }
      }
      final total = sizes.values.fold<int>(0, (a, b) => a + b);
      var done = 0;
      for (final n in names) {
        final res = await client.send(http.Request('GET', Uri.parse('$stockfishNetsUrl$n'))).timeout(const Duration(seconds: 30));
        if (res.statusCode != 200) throw 'Сервер ответил ${res.statusCode}';
        final part = File('${dir.path}${Platform.pathSeparator}$n.part');
        final sink = part.openWrite();
        final chunks = _DigestSink();
        final hasher = sha256.startChunkedConversion(chunks);
        try {
          await for (final c in res.stream.timeout(const Duration(seconds: 30))) {
            if (cancelled?.call() ?? false) throw 'Отменено';
            sink.add(c);
            hasher.add(c);
            done += c.length;
            if (total > 0) progress((done / total).clamp(0.0, 1.0));
          }
        } finally {
          await sink.close();
        }
        hasher.close();
        final want = RegExp(r'^nn-([0-9a-f]+)\.nnue$').firstMatch(n)?.group(1) ?? '';
        if (want.isEmpty || !chunks.value.toString().startsWith(want)) {
          await part.delete();
          throw 'Файл скачался с ошибкой — попробуй ещё раз';
        }
        await part.rename('${dir.path}${Platform.pathSeparator}$n');
      }
      missingNets = const [];
      _available = null; // следующий start() запустит движок с нейросетью
    } on TimeoutException {
      throw 'Связь пропала — попробуй ещё раз';
    } on SocketException {
      throw 'Нет интернета';
    } finally {
      client.close();
      try {
        for (final f in dir.listSync().whereType<File>().where((f) => f.path.endsWith('.part'))) {
          f.deleteSync();
        }
      } catch (_) {}
    }
  }

  Future<String> _wait(bool Function(String) test, Duration timeout) =>
      _lines.stream.firstWhere(test).timeout(timeout);

  Future<T> _locked<T>(Future<T> Function() f) {
    final c = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        c.complete(await f());
      } catch (e) {
        c.completeError(e);
      }
    });
    return c.future;
  }

  Future<String?> bestMove(String fen, {int skill = 20, int movetime = 500}) => _locked(() async {
        if (!await start()) return null;
        _send('setoption name Skill Level value $skill');
        _send('position fen $fen');
        _send('go movetime $movetime');
        final line = await _wait((l) => l.startsWith('bestmove'), Duration(milliseconds: movetime + 15000));
        final m = line.split(' ');
        return m.length > 1 && m[1] != '(none)' ? m[1] : null;
      });

  Future<Eval?> evaluate(String fen, {int movetime = 300}) => _locked(() async {
        if (!await start()) return null;
        _send('setoption name Skill Level value 20');
        _send('position fen $fen');
        int cp = 0;
        int? mate;
        String? best;
        final sub = _lines.stream.listen((l) {
          if (!l.startsWith('info') || !l.contains(' score ')) return;
          final t = l.split(' ');
          final i = t.indexOf('score');
          if (i >= 0 && i + 2 < t.length) {
            if (t[i + 1] == 'cp') {
              cp = int.tryParse(t[i + 2]) ?? cp;
              mate = null;
            } else if (t[i + 1] == 'mate') {
              mate = int.tryParse(t[i + 2]);
            }
          }
          final pv = t.indexOf('pv');
          if (pv >= 0 && pv + 1 < t.length) best = t[pv + 1];
        });
        _send('go movetime $movetime');
        final line = await _wait((l) => l.startsWith('bestmove'), Duration(milliseconds: movetime + 15000));
        await sub.cancel();
        final b = line.split(' ');
        if (b.length > 1 && b[1] != '(none)') best = b[1];
        return Eval(cp, mate, best);
      });

  void stop() {
    _p?.kill();
    _p = null;
  }
}

class _DigestSink implements Sink<Digest> {
  Digest? _v;
  Digest get value => _v!;
  @override
  void add(Digest data) => _v = data;
  @override
  void close() {}
}

// ---------------- Встроенный простой бот (если Stockfish недоступен) ----------------

const _val = {'p': 100, 'n': 320, 'b': 330, 'r': 500, 'q': 900, 'k': 0};

int _evalBoard(ch.Chess c) {
  if (c.in_checkmate) return -100000;
  if (c.in_draw) return 0;
  var s = 0;
  for (var r = 0; r < 8; r++) {
    for (var f = 0; f < 8; f++) {
      final sq = '${'abcdefgh'[f]}${r + 1}';
      final p = c.get(sq);
      if (p == null) continue;
      var v = _val[p.type.name]!;
      // Центр и продвижение пешек.
      final center = 3.5 - ((f - 3.5).abs() + (r - 3.5).abs()) / 2;
      if (p.type.name == 'n' || p.type.name == 'b') v += (center * 8).round();
      if (p.type.name == 'p') v += (p.color == ch.Color.WHITE ? r : 7 - r) * 6 + (center * 3).round();
      s += p.color == c.turn ? v : -v;
    }
  }
  return s;
}

int _search(ch.Chess c, int depth, int alpha, int beta) {
  if (depth == 0 || c.game_over) return _evalBoard(c);
  final moves = c.generate_moves();
  moves.sort((a, b) => (b.captured != null ? 1 : 0).compareTo(a.captured != null ? 1 : 0));
  for (final m in moves) {
    c.make_move(m);
    final v = -_search(c, depth - 1, -beta, -alpha);
    c.undo_move();
    if (v > alpha) alpha = v;
    if (alpha >= beta) break;
  }
  return alpha;
}

String _uci(ch.Move m) => '${m.fromAlgebraic}${m.toAlgebraic}${m.promotion?.name ?? ''}';

/// Лучший ход простым перебором (в отдельном потоке).
String? _dartBest(Map<String, dynamic> a) {
  final c = ch.Chess.fromFEN(a['fen'] as String);
  final depth = a['depth'] as int;
  final rnd = math.Random();
  final moves = c.generate_moves();
  if (moves.isEmpty) return null;
  if (rnd.nextDouble() < (a['random'] as double)) return _uci(moves[rnd.nextInt(moves.length)]);
  ch.Move? best;
  var bestV = -1 << 30;
  moves.shuffle(rnd);
  for (final m in moves) {
    c.make_move(m);
    final v = -_search(c, depth - 1, -1 << 30, 1 << 30);
    c.undo_move();
    if (v > bestV) {
      bestV = v;
      best = m;
    }
  }
  return best == null ? null : _uci(best);
}

int _dartEval(String fen) {
  final c = ch.Chess.fromFEN(fen);
  return _search(c, 2, -1 << 30, 1 << 30);
}

/// Ход бота на выбранном уровне.
Future<String?> botMove(String fen, BotLevel l) async {
  if (l.skill >= 0) {
    final m = await Stockfish.instance.bestMove(fen, skill: l.skill, movetime: l.movetime);
    if (m != null) return m;
  }
  return compute(_dartBest, {'fen': fen, 'depth': l.skill >= 0 ? 3 : l.dartDepth, 'random': l.random});
}

/// Оценка для разбора и подсказок.
Future<Eval> evaluate(String fen, {int movetime = 300}) async {
  final e = await Stockfish.instance.evaluate(fen, movetime: movetime);
  if (e != null) return e;
  final best = await compute(_dartBest, {'fen': fen, 'depth': 2, 'random': 0.0});
  final v = await compute(_dartEval, fen);
  return Eval(v, null, best);
}
