import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../common/ui.dart';

/// Что камера увидела на одном кадре.
class PoseSample {
  /// Угол в локте (градусы). null — рук не видно.
  final double? elbowAngle;
  const PoseSample(this.elbowAngle);
  bool get visible => elbowAngle != null;
}

/// Подсчёт работает только на телефоне: ML Kit есть на Android/iOS, на Windows его нет.
bool get poseSupported => Platform.isAndroid || Platform.isIOS;

/// Превью камеры + распознавание позы. На каждый обработанный кадр вызывает [onSample].
class PoseCamera extends StatefulWidget {
  final void Function(PoseSample s) onSample;
  const PoseCamera({super.key, required this.onSample});

  @override
  State<PoseCamera> createState() => _PoseCameraState();
}

class _PoseCameraState extends State<PoseCamera> {
  CameraController? _cam;
  List<CameraDescription> _cams = [];
  int _camIndex = 0;
  final _detector = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  bool _busy = false; // предыдущий кадр ещё обрабатывается
  String? _error;

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) {
        setState(() => _error = 'Камера не найдена');
        return;
      }
      // По умолчанию фронтальная: видно экран во время отжиманий.
      final front = _cams.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _camIndex = front >= 0 ? front : 0;
      await _start();
    } catch (e) {
      if (mounted) setState(() => _error = 'Нет доступа к камере');
    }
  }

  Future<void> _start() async {
    final old = _cam;
    _cam = null;
    if (mounted) setState(() {});
    await _stop(old);
    final c = CameraController(
      _cams[_camIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    try {
      await c.initialize();
      await c.startImageStream(_onImage);
      if (!mounted) {
        await _stop(c);
        return;
      }
      setState(() {
        _cam = c;
        _error = null;
      });
    } on CameraException {
      await _stop(c);
      if (mounted) setState(() => _error = 'Нет доступа к камере. Разреши камеру в настройках телефона.');
    }
  }

  Future<void> _stop(CameraController? c) async {
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
    } catch (_) {}
    try {
      await c.dispose();
    } catch (_) {}
  }

  Future<void> _switchCamera() async {
    if (_cams.length < 2) return;
    _camIndex = (_camIndex + 1) % _cams.length;
    await _start();
  }

  Future<void> _onImage(CameraImage image) async {
    if (_busy) return; // пропускаем кадр, если не успеваем
    final c = _cam;
    if (c == null) return;
    _busy = true;
    try {
      final input = _toInputImage(image, c);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      if (!mounted) return;
      widget.onSample(PoseSample(poses.isEmpty ? null : elbowAngle(poses.first)));
    } catch (_) {
      // кадр не распознался — просто ждём следующий
    } finally {
      _busy = false;
    }
  }

  /// Кадр камеры → картинка для ML Kit (код из примера google_mlkit).
  InputImage? _toInputImage(CameraImage image, CameraController c) {
    final camera = c.description;
    final sensor = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      var comp = _orientations[c.value.deviceOrientation];
      if (comp == null) return null;
      comp = camera.lensDirection == CameraLensDirection.front ? (sensor + comp) % 360 : (sensor - comp + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(comp);
    }
    if (rotation == null) return null;
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    final c = _cam;
    _cam = null;
    _stop(c);
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: W.body, textAlign: TextAlign.center),
        ),
      );
    }
    final c = _cam;
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(child: CameraPreview(c)),
        if (_cams.length > 1)
          Positioned(
            right: 12,
            bottom: 12,
            child: IconButton.filledTonal(
              tooltip: 'Другая камера',
              onPressed: _switchCamera,
              icon: const Icon(Icons.cameraswitch_rounded),
            ),
          ),
      ],
    );
  }
}

/// Угол в локте по точкам «плечо — локоть — кисть».
/// Берём ту руку, которую камера видит увереннее. null — руки не видно.
double? elbowAngle(Pose pose) {
  double? side(PoseLandmarkType s, PoseLandmarkType e, PoseLandmarkType w, List<double> conf) {
    final ps = pose.landmarks[s], pe = pose.landmarks[e], pw = pose.landmarks[w];
    if (ps == null || pe == null || pw == null) return null;
    final c = math.min(ps.likelihood, math.min(pe.likelihood, pw.likelihood));
    if (c < 0.5) return null;
    conf.add(c);
    final ax = ps.x - pe.x, ay = ps.y - pe.y;
    final bx = pw.x - pe.x, by = pw.y - pe.y;
    final la = math.sqrt(ax * ax + ay * ay), lb = math.sqrt(bx * bx + by * by);
    if (la == 0 || lb == 0) return null;
    final cos = ((ax * bx + ay * by) / (la * lb)).clamp(-1.0, 1.0);
    return math.acos(cos) * 180 / math.pi;
  }

  final lc = <double>[], rc = <double>[];
  final l = side(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, lc);
  final r = side(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rc);
  if (l == null) return r;
  if (r == null) return l;
  return lc.first >= rc.first ? l : r;
}
