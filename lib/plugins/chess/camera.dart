import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:chess/chess.dart' as ch;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:winter_core/winter_core.dart';

import '../common/ui.dart';
import 'app.dart' show Store;
import 'board.dart' show BoardColors, PieceImage, sanOf;
import 'engine.dart' show Eval, evaluate;
import 'scan.dart';

const _green = Color(0xFF39E07A);

/// Камера: наводишь телефон на настоящую доску → ИИ читает позицию → Stockfish показывает лучший ход
/// зелёной стрелкой прямо поверх камеры.
class CameraHint extends StatefulWidget {
  const CameraHint({super.key});

  @override
  State<CameraHint> createState() => _CameraHintState();
}

class _ScanError implements Exception {
  final String text;
  const _ScanError(this.text);
}

class _CameraHintState extends State<CameraHint> with WidgetsBindingObserver {
  CameraController? _cam;
  bool _camTried = false;
  String? _camError;

  Uint8List? _still; // фото из галереи (на компьютере — единственный вариант)
  Size? _stillSize;

  /// Углы рамки в долях кадра: верх-лево, верх-право, низ-право, низ-лево.
  List<Offset>? _corners;
  int? _drag; // 0..3 — угол, 4 — вся рамка

  Grid? _grid; // позиция как на фото
  int _rot = 0; // поворот сетки, чтобы белые были снизу
  bool? _white; // за кого считали ход
  String? _best, _status, _evalText, _note;
  bool _busy = false, _problem = false;

  bool get _phone => Platform.isAndroid || Platform.isIOS;
  bool get _ready => (_cam?.value.isInitialized ?? false) || _still != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCorners();
    if (_phone) {
      SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
      _initCamera();
    } else {
      _camTried = true;
      _camError = 'На компьютере камера здесь не работает — выбери фото доски.';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _cam;
    _cam = null;
    c?.dispose();
    if (_phone) SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _cam;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      if (c != null && c.value.isInitialized) {
        _cam = null;
        c.dispose();
        if (mounted) setState(() {});
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_cam == null && _camTried && _camError == null && _still == null) _initCamera();
    }
  }

  Future<void> _initCamera() async {
    if (!_phone) return;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) throw CameraException('none', 'Камера не найдена');
      final back = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cams.first);
      final c = CameraController(back, ResolutionPreset.veryHigh, enableAudio: false);
      await c.initialize();
      try {
        await c.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (_) {}
      try {
        await c.setFocusMode(FocusMode.auto);
      } catch (_) {}
      if (!mounted || _still != null) {
        await c.dispose();
        return;
      }
      setState(() {
        _cam = c;
        _camTried = true;
        _camError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _camTried = true;
          _camError = 'Нет доступа к камере. Разреши камеру в настройках телефона — или выбери фото доски.';
        });
      }
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2400, maxHeight: 2400, imageQuality: 92);
      if (x == null) return;
      final r = await compute(orientedJpeg, await x.readAsBytes());
      if (!mounted) return;
      final c = _cam;
      _cam = null;
      await c?.dispose();
      setState(() {
        _still = r['bytes'] as Uint8List;
        _stillSize = Size((r['w'] as int).toDouble(), (r['h'] as int).toDouble());
        _corners = null;
        _clearResult();
      });
    } catch (_) {
      if (mounted) toast(context, 'Не получилось открыть фото');
    }
  }

  void _backToCamera() {
    setState(() {
      _still = null;
      _stillSize = null;
      _corners = null;
      _camError = null;
      _clearResult();
    });
    _loadCorners();
    _initCamera();
  }

  void _loadCorners() {
    final saved = Store.d['camCorners'];
    if (saved is List && saved.length == 8) {
      final v = [for (final x in saved) (x is num ? x.toDouble() : 0.5).clamp(0.0, 1.0).toDouble()];
      _corners = [for (var i = 0; i < 4; i++) Offset(v[i * 2], v[i * 2 + 1])];
    }
  }

  void _clearResult() {
    _grid = null;
    _best = null;
    _white = null;
    _status = null;
    _evalText = null;
    _note = null;
    _problem = false;
  }

  void _say(String text, {bool problem = false}) {
    if (!mounted) return;
    setState(() {
      _status = text;
      _problem = problem;
      if (problem) {
        _best = null;
        _evalText = null;
      }
    });
  }

  // ---------- Снимок → позиция ----------

  Future<Uint8List?> _shot() async {
    final s = _still;
    if (s != null) return s;
    final c = _cam;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) return null;
    final x = await c.takePicture();
    return x.readAsBytes();
  }

  double _viewAspect() {
    final s = _stillSize;
    if (_still != null && s != null) return s.width / s.height;
    final c = _cam;
    if (c == null || !c.value.isInitialized) return 3 / 4;
    return 1 / c.value.aspectRatio; // экран зафиксирован вертикально
  }

  Future<void> _scan(bool white) async {
    if (_busy) return;
    final key = (Store.sharedKey?.call() ?? '').trim();
    if (key.isEmpty) {
      _say('Нужен ключ Gemini: открой КБЖУ → Профиль и вставь ключ (тот же, что для распознавания еды).', problem: true);
      return;
    }
    final corners = _corners;
    if (corners == null) return;
    setState(() {
      _busy = true;
      _status = 'Снимаю доску…';
      _best = null;
      _evalText = null;
      _note = null;
      _problem = false;
    });
    try {
      final raw = await _shot();
      if (raw == null) throw const _ScanError('Камера ещё не готова — подожди секунду и нажми снова.');
      if (mounted) setState(() => _status = 'Смотрю, где стоят фигуры…');
      final prep = await compute(prepareShot, <String, Object>{
        'bytes': raw,
        'corners': [for (final o in corners) ...[o.dx, o.dy]],
        'aspect': _viewAspect(),
      });
      final j = await _ask(key, prep['rect'] as Uint8List, prep['photo'] as Uint8List);
      final g = gridFromJson(j);
      if (g == null) throw const _ScanError('Не вижу шахматную доску. Поставь углы рамки на углы игрового поля и попробуй ещё раз.');
      _grid = g;
      _rot = pickRotation(g, rotationForWhiteSide(j['white_side']));
      final note = '${j['note'] ?? ''}'.trim();
      final conf = j['confidence'] is num ? (j['confidence'] as num).toDouble() : 1.0;
      _note = [
        if (note.isNotEmpty) note,
        if (conf < 0.6) 'ИИ не уверен в позиции — проверь фигуры («Поправить фигуры»).',
      ].join(' ');
      await _analyze(white);
    } on _ScanError catch (e) {
      _say(e.text, problem: true);
    } on GeminiError catch (e) {
      _say(_geminiText(e), problem: true);
    } on CameraException catch (_) {
      _say('Камера не смогла сделать снимок. Попробуй ещё раз.', problem: true);
    } catch (e) {
      _say('Не получилось: $e', problem: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _ask(String key, Uint8List rect, Uint8List photo) async {
    final text = await WinterGemini.generate(
      key: key,
      parts: [
        {'text': scanPrompt},
        {'text': 'Image 1 (straightened board):'},
        WinterGemini.image(rect),
        {'text': 'Image 2 (original photo):'},
        WinterGemini.image(photo),
      ],
      json: true,
      config: const {'temperature': 0.1},
      timeout: const Duration(seconds: 120),
    );
    final j = WinterGemini.jsonObject(text);
    if (j == null) throw const _ScanError('ИИ ответил непонятно. Попробуй ещё раз.');
    return j;
  }

  String _geminiText(GeminiError e) => switch (e.kind) {
        GeminiFail.noKey => 'Нужен ключ Gemini: открой КБЖУ → Профиль и вставь ключ.',
        GeminiFail.badKey => 'Ключ Gemini не подходит. Проверь его в КБЖУ → Профиль.',
        GeminiFail.timeout => 'ИИ слишком долго отвечает. Попробуй ещё раз.',
        GeminiFail.offline => 'Нет интернета — ИИ не может посмотреть на доску.',
        GeminiFail.rateLimit => 'Лимит запросов Gemini. Подожди минуту и попробуй снова.',
        _ => 'ИИ не смог прочитать доску${e.detail.isEmpty ? '' : ' (${e.detail})'}. Попробуй ещё раз.',
      };

  // ---------- Позиция → лучший ход ----------

  Future<void> _analyzeSafe(bool white) async {
    if (_busy || _grid == null) return;
    setState(() => _busy = true);
    try {
      await _analyze(white);
    } catch (e) {
      _say('Не получилось посчитать ход: $e', problem: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _analyze(bool white) async {
    final g = _grid;
    if (g == null) return;
    _white = white;
    final std = rotate(g, _rot);
    final who = white ? 'белых' : 'чёрных';
    final p = positionProblem(std, white);
    if (p != null) {
      _say(p, problem: true);
      return;
    }
    final fen = fenOf(std, white);
    final game = ch.Chess.fromFEN(fen);
    if (game.in_checkmate || game.in_stalemate) {
      _say(game.in_checkmate ? 'У $who мат — ходов нет.' : 'У $who пат — ходов нет, это ничья.');
      return;
    }
    if (mounted) setState(() => _status = 'Stockfish думает…');
    final e = await evaluate(fen, movetime: 1500);
    final best = e.best;
    if (best == null || best.length < 4) {
      _say('Не нашёл ход — проверь позицию («Поправить фигуры»).', problem: true);
      return;
    }
    if (!mounted) return;
    setState(() {
      _best = best;
      _status = 'Лучший ход за $who: ${describeMove(std, best, sanOf(game, best))}';
      _evalText = evalLine(e);
      _problem = false;
    });
  }

  Future<void> _edit() async {
    final g = _grid;
    if (g == null || _busy) return;
    final res = await showModalBottomSheet<Grid>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PositionEditor(std: rotate(g, _rot)),
    );
    if (res == null || !mounted) return;
    setState(() => _grid = rotate(res, (4 - _rot) % 4));
    await _analyzeSafe(_white ?? true);
  }

  void _turn() {
    if (_busy || _grid == null) return;
    setState(() => _rot = (_rot + 1) % 4);
    _analyzeSafe(_white ?? true);
  }

  // ---------- Рамка ----------

  List<Offset> _defaultCorners(Size s) {
    final side = math.min(s.width, s.height) * 0.86;
    final l = (s.width - side) / 2 / s.width, t = (s.height - side) / 2 / s.height;
    final r = 1 - l, b = 1 - t;
    return [Offset(l, t), Offset(r, t), Offset(r, b), Offset(l, b)];
  }

  void _panStart(Offset p, List<Offset> px) {
    var best = -1;
    var bd = 56.0;
    for (var i = 0; i < 4; i++) {
      final d = (px[i] - p).distance;
      if (d < bd) {
        bd = d;
        best = i;
      }
    }
    if (best >= 0) {
      _drag = best;
    } else {
      _drag = (Path()..addPolygon(px, true)).contains(p) ? 4 : null;
    }
  }

  void _panUpdate(Offset delta, Size size) {
    final i = _drag, c = _corners;
    if (i == null || c == null) return;
    final d = Offset(delta.dx / size.width, delta.dy / size.height);
    setState(() {
      if (i == 4) {
        final xs = c.map((o) => o.dx), ys = c.map((o) => o.dy);
        final dx = d.dx.clamp(-xs.reduce(math.min), 1 - xs.reduce(math.max)).toDouble();
        final dy = d.dy.clamp(-ys.reduce(math.min), 1 - ys.reduce(math.max)).toDouble();
        _corners = [for (final o in c) o + Offset(dx, dy)];
      } else {
        final n = c[i] + d;
        _corners = [...c]..[i] = Offset(n.dx.clamp(0.0, 1.0).toDouble(), n.dy.clamp(0.0, 1.0).toDouble());
      }
    });
  }

  void _panEnd() {
    final c = _corners;
    _drag = null;
    if (c == null || _still != null) return;
    Store.d['camCorners'] = [for (final o in c) ...[o.dx, o.dy]];
    Store.save();
  }

  // ---------- Экран ----------

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Камера: лучший ход'),
          actions: [
            if (_still != null && _phone)
              IconButton(icon: const Icon(Icons.videocam_outlined), tooltip: 'Вернуться к камере', onPressed: _busy ? null : _backToCamera),
            IconButton(icon: const Icon(Icons.photo_library_outlined), tooltip: 'Фото доски из галереи', onPressed: _busy ? null : _pickPhoto),
            IconButton(icon: const Icon(Icons.help_outline), tooltip: 'Как пользоваться', onPressed: _help),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(children: [
                Expanded(child: _sideButton(true)),
                const SizedBox(width: 10),
                Expanded(child: _sideButton(false)),
              ]),
            ),
            Expanded(child: LayoutBuilder(builder: (context, box) => Center(child: _viewport(box.biggest)))),
            _panel(),
          ]),
        ),
      );

  Widget _sideButton(bool white) {
    final on = _white == white && _best != null;
    final bg = white ? const Color(0xFFF2F2F2) : const Color(0xFF1B1B1B);
    final fg = white ? const Color(0xFF111111) : const Color(0xFFF2F2F2);
    return SizedBox(
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.45),
          disabledForegroundColor: fg.withValues(alpha: 0.6),
          side: BorderSide(color: on ? _green : const Color(0xFF555555), width: on ? 3 : 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _busy || !_ready ? null : () => _scan(white),
        child: Text(white ? 'Белые' : 'Чёрные', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _viewport(Size avail) {
    final Widget media;
    final double aspect;
    final c = _cam;
    final still = _still, ss = _stillSize;
    if (still != null && ss != null) {
      aspect = ss.width / ss.height;
      media = Image.memory(still, fit: BoxFit.fill, gaplessPlayback: true);
    } else if (c != null && c.value.isInitialized) {
      aspect = 1 / c.value.aspectRatio;
      media = CameraPreview(c);
    } else {
      return _placeholder();
    }
    var w = avail.width, h = w / aspect;
    if (h > avail.height) {
      h = avail.height;
      w = h * aspect;
    }
    final size = Size(w, h);
    final corners = _corners ??= _defaultCorners(size);
    final px = [for (final o in corners) Offset(o.dx * w, o.dy * h)];
    return SizedBox(
      width: w,
      height: h,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: _busy ? null : (d) => _panStart(d.localPosition, px),
        onPanUpdate: _busy ? null : (d) => _panUpdate(d.delta, size),
        onPanEnd: _busy ? null : (_) => _panEnd(),
        child: Stack(fit: StackFit.expand, children: [
          media,
          CustomPaint(painter: BoardOverlay(px, _best, _rot, _busy)),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ]),
      ),
    );
  }

  Widget _placeholder() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(_camError == null ? Icons.photo_camera_outlined : Icons.no_photography_outlined, size: 56, color: W.muted),
          const SizedBox(height: 12),
          Text(_camError ?? 'Включаю камеру…', style: W.body, textAlign: TextAlign.center),
          if (_camError != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _pickPhoto, icon: const Icon(Icons.photo_library_outlined), label: const Text('Выбрать фото доски')),
          ],
        ]),
      );

  Widget _panel() {
    final s = _status ??
        (_ready
            ? 'Растяни рамку за углы точно по углам игрового поля и нажми «Белые» или «Чёрные» — за кого подсказать ход.'
            : 'Камера нужна, чтобы увидеть доску.');
    final TextStyle style = _best != null
        ? W.h2.copyWith(color: _green)
        : _problem
            ? W.body.copyWith(color: W.warn)
            : W.body;
    final note = _note ?? '';
    return Container(
      width: double.infinity,
      color: W.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s, style: style),
        if (_evalText != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_evalText!, style: W.small)),
        if (note.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note, style: W.small.copyWith(color: W.warn))),
        if (_grid != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              _chip(Icons.edit_outlined, 'Поправить фигуры', _busy ? null : _edit),
              _chip(Icons.rotate_right, 'Повернуть доску', _busy ? null : _turn),
              if (_white != null) _chip(Icons.swap_horiz, 'Ход за ${_white! ? 'чёрных' : 'белых'}', _busy ? null : () => _analyzeSafe(!_white!)),
            ]),
          ),
      ]),
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback? onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
      );

  void _help() => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Как пользоваться', style: W.h2),
          content: const SingleChildScrollView(
            child: Text(
              '1. Поставь телефон так, чтобы вся доска была видна (лучше сверху или чуть сбоку).\n'
              '2. Растяни рамку за 4 угла точно по углам игрового поля (без цифр и букв по краям). '
              'Рамку можно двигать целиком, потянув за середину. Положение рамки запоминается.\n'
              '3. Нажми «Белые» или «Чёрные» — за кого показать лучший ход. Зелёная стрелка появится прямо на доске.\n'
              '4. Если ИИ ошибся в фигуре — «Поправить фигуры». Если стрелка не на тех клетках — «Повернуть доску».\n\n'
              'Фигуры читает ИИ Gemini (нужен интернет и ключ из КБЖУ), ход считает Stockfish прямо на телефоне.',
              style: W.body,
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Понятно'))],
        ),
      );
}

/// Рамка доски, сетка 8×8 и зелёная стрелка лучшего хода — с учётом перспективы.
class BoardOverlay extends CustomPainter {
  final List<Offset> corners; // в пикселях: верх-лево, верх-право, низ-право, низ-лево
  final String? best;
  final int rot;
  final bool busy;
  BoardOverlay(this.corners, this.best, this.rot, this.busy);

  @override
  void paint(Canvas canvas, Size size) {
    final h = Homography.fromQuad([for (final c in corners) (c.dx, c.dy)]);
    Offset at(double u, double v) {
      final (x, y) = h.map(u, v);
      return Offset(x, y);
    }

    final quad = Path()..addPolygon(corners, true);
    final outside = Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), quad);
    canvas.drawPath(outside, Paint()..color = const Color(0x66000000));

    final grid = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 1;
    for (var k = 1; k < 8; k++) {
      canvas.drawLine(at(k / 8, 0), at(k / 8, 1), grid);
      canvas.drawLine(at(0, k / 8), at(1, k / 8), grid);
    }
    canvas.drawPath(
      quad,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = busy ? W.warn : W.ice,
    );

    final b = best;
    if (b != null && b.length >= 4) {
      final from = b.substring(0, 2), to = b.substring(2, 4);
      for (final sq in [from, to]) {
        final poly = [for (final (u, v) in squareCornersUv(sq, rot)) at(u, v)];
        canvas.drawPath(Path()..addPolygon(poly, true), Paint()..color = _green.withValues(alpha: 0.38));
      }
      final (fu, fv) = squareCenterUv(from, rot);
      final (tu, tv) = squareCenterUv(to, rot);
      final cell = (at(tu + 1 / 16, tv) - at(tu - 1 / 16, tv)).distance;
      _arrow(canvas, at(fu, fv), at(tu, tv), cell);
    }

    for (final c in corners) {
      canvas.drawCircle(c, 13, Paint()..color = const Color(0xCC0A1020));
      canvas.drawCircle(
        c,
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = W.ice,
      );
    }
  }

  void _arrow(Canvas canvas, Offset a, Offset b, double cell) {
    final d = b - a;
    final len = d.distance;
    if (len < 2) return;
    final dir = d / len;
    final n = Offset(-dir.dy, dir.dx);
    final w = math.max(6.0, cell * 0.2);
    final headLen = math.min(len * 0.6, math.max(18.0, cell * 0.5));
    final headW = math.max(14.0, cell * 0.38);
    final end = b - dir * headLen;
    canvas.drawLine(
      a,
      end,
      Paint()
        ..color = const Color(0x99000000)
        ..strokeWidth = w + 4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      a,
      end,
      Paint()
        ..color = _green
        ..strokeWidth = w
        ..strokeCap = StrokeCap.round,
    );
    final l = end + n * headW, r = end - n * headW;
    final head = Path()
      ..moveTo(b.dx, b.dy)
      ..lineTo(l.dx, l.dy)
      ..lineTo(r.dx, r.dy)
      ..close();
    canvas.drawPath(
      head,
      Paint()
        ..color = const Color(0x99000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(head, Paint()..color = _green);
  }

  @override
  bool shouldRepaint(covariant BoardOverlay old) => true;
}

/// Правка позиции: выбираешь фигуру и нажимаешь на клетки. Белые снизу.
class PositionEditor extends StatefulWidget {
  final Grid std;
  const PositionEditor({super.key, required this.std});

  @override
  State<PositionEditor> createState() => _PositionEditorState();
}

class _PositionEditorState extends State<PositionEditor> {
  late Grid g = copyGrid(widget.std);
  String pen = 'P';

  Widget _piece(String c) => c == '.' ? const SizedBox.shrink() : PieceImage(c == c.toUpperCase() ? 'w' : 'b', c.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final maxBoard = math.min(MediaQuery.of(context).size.width - 32, 420.0);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Поправь позицию', style: W.h2),
          const SizedBox(height: 4),
          const Text('Выбери фигуру внизу и нажимай на клетки (нажми ещё раз — уберёшь). Белые — снизу.', style: W.small, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          SizedBox(
            width: maxBoard,
            height: maxBoard,
            child: Column(children: [
              for (var i = 0; i < 8; i++)
                Expanded(
                  child: Row(children: [
                    for (var j = 0; j < 8; j++)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => g[i][j] = g[i][j] == pen ? '.' : pen),
                          child: Container(
                            color: (i + j).isEven ? BoardColors.light : BoardColors.dark,
                            padding: const EdgeInsets.all(2),
                            child: Stack(fit: StackFit.expand, children: [
                              _piece(g[i][j]),
                              if (j == 0)
                                Positioned(left: 1, top: 0, child: Text('${8 - i}', style: const TextStyle(fontSize: 9, color: Color(0xFF233247)))),
                              if (i == 7)
                                Positioned(right: 1, bottom: 0, child: Text('abcdefgh'[j], style: const TextStyle(fontSize: 9, color: Color(0xFF233247)))),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
            for (final c in [...'KQRBNP'.split(''), ...'kqrbnp'.split(''), '.'])
              InkWell(
                onTap: () => setState(() => pen = c),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: W.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: pen == c ? _green : W.border, width: pen == c ? 2.5 : 1),
                  ),
                  child: c == '.' ? const Icon(Icons.backspace_outlined, color: W.muted, size: 20) : _piece(c),
                ),
              ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, g), child: const Text('Готово'))),
          ]),
        ]),
      ),
    );
  }
}

// ---------- Подписи ----------

const _pieceNames = {'k': 'король', 'q': 'ферзь', 'r': 'ладья', 'b': 'слон', 'n': 'конь', 'p': 'пешка'};

/// SAN по-русски: Nf3 → Кf3, Qxd8+ → Фxd8+.
String ruSan(String san) {
  if (san.startsWith('O-O')) return san;
  const m = {'K': 'Кр', 'Q': 'Ф', 'R': 'Л', 'B': 'С', 'N': 'К'};
  return san.split('').map((c) => m[c] ?? c).join();
}

/// «Кf3 (конь g1 → f3)».
String describeMove(Grid std, String uci, String? san) {
  final from = uci.substring(0, 2), to = uci.substring(2, 4);
  final (i, j) = squareToStd(from);
  final piece = _pieceNames[std[i][j].toLowerCase()] ?? 'фигура';
  if (san != null && san.startsWith('O-O-O')) return 'длинная рокировка (король $from → $to)';
  if (san != null && san.startsWith('O-O')) return 'короткая рокировка (король $from → $to)';
  final s = san == null ? '' : '${ruSan(san)} ';
  return '$s($piece $from → $to)';
}

String _movesWord(int n) {
  final a = n % 100, b = n % 10;
  if (a >= 11 && a <= 14) return 'ходов';
  if (b == 1) return 'ход';
  if (b >= 2 && b <= 4) return 'хода';
  return 'ходов';
}

/// Оценка позиции простыми словами (с точки зрения того, кто ходит).
String evalLine(Eval e) {
  final m = e.mate;
  if (m != null && m != 0) {
    return m > 0 ? 'Мат в $m ${_movesWord(m)}!' : 'Соперник ставит мат в ${-m} ${_movesWord(-m)} — защищайся.';
  }
  final v = (e.cp.abs() / 100).toStringAsFixed(1);
  if (e.cp > 150) return 'Позиция лучше у тебя (+$v)';
  if (e.cp < -150) return 'Позиция хуже у тебя (−$v)';
  return 'Примерно равно (${e.cp >= 0 ? '+' : '−'}$v)';
}

// ---------- Обработка фото (в отдельном потоке) ----------

/// Фото из галереи → JPEG без поворота по EXIF (чтобы рамка совпадала с картинкой).
Map<String, Object> orientedJpeg(Uint8List raw) {
  final d = img.decodeImage(raw);
  if (d == null) throw Exception('bad image');
  var im = img.bakeOrientation(d);
  if (math.max(im.width, im.height) > 2000) {
    im = im.width >= im.height ? img.copyResize(im, width: 2000) : img.copyResize(im, height: 2000);
  }
  return {'bytes': Uint8List.fromList(img.encodeJpg(im, quality: 90)), 'w': im.width, 'h': im.height};
}

/// Снимок + углы рамки → «выпрямленная» доска сверху (для ИИ) и уменьшенное исходное фото.
/// [a]: bytes — JPEG, corners — 8 чисел (доли кадра), aspect — ширина/высота того, что видно на экране.
Map<String, Object> prepareShot(Map<String, Object> a) {
  final raw = a['bytes'] as Uint8List;
  final c = [for (final x in a['corners'] as List) (x as num).toDouble()];
  final pa = (a['aspect'] as num).toDouble();
  final d = img.decodeImage(raw);
  if (d == null) throw Exception('bad image');
  var im = img.bakeOrientation(d);
  if (math.max(im.width, im.height) > 2000) {
    im = im.width >= im.height ? img.copyResize(im, width: 2000) : img.copyResize(im, height: 2000);
  }
  final w = im.width.toDouble(), h = im.height.toDouble();
  // На экране может быть видна только середина снимка (другое соотношение сторон) — учитываем.
  var ox = 0.0, oy = 0.0, vw = w, vh = h;
  final ia = w / h;
  if ((ia - pa).abs() > 0.02) {
    if (ia > pa) {
      vw = h * pa;
      ox = (w - vw) / 2;
    } else {
      vh = w / pa;
      oy = (h - vh) / 2;
    }
  }
  final hom = Homography.fromQuad([for (var i = 0; i < 4; i++) (ox + c[i * 2] * vw, oy + c[i * 2 + 1] * vh)]);
  final rect = rectify(im, hom, 768);
  final small = math.max(im.width, im.height) > 1024
      ? (im.width >= im.height ? img.copyResize(im, width: 1024) : img.copyResize(im, height: 1024))
      : im;
  return {
    'rect': Uint8List.fromList(img.encodeJpg(rect, quality: 88)),
    'photo': Uint8List.fromList(img.encodeJpg(small, quality: 82)),
  };
}

/// Перспективное выпрямление: доска → квадрат [size]×[size] с полями (сверху больше — там торчат высокие фигуры).
img.Image rectify(img.Image src, Homography hom, int size) {
  const top = 0.10, side = 0.05, bottom = 0.05;
  final out = img.Image(width: size, height: size);
  final sw = src.width, sh = src.height;
  for (var y = 0; y < size; y++) {
    final v = -top + (y + 0.5) / size * (1 + top + bottom);
    for (var x = 0; x < size; x++) {
      final u = -side + (x + 0.5) / size * (1 + 2 * side);
      final (fx, fy) = hom.map(u, v);
      final sx = fx.round(), sy = fy.round();
      if (sx < 0 || sy < 0 || sx >= sw || sy >= sh) {
        out.setPixelRgb(x, y, 0, 0, 0);
      } else {
        final p = src.getPixel(sx, sy);
        out.setPixelRgb(x, y, p.r, p.g, p.b);
      }
    }
  }
  return out;
}
