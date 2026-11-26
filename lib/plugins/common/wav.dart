import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// Звуки плагинов генерируются в коде — без файлов в APK.

/// PCM 16 бит моно → WAV.
Uint8List pcmToWav(Int16List pcm, int rate) {
  final data = pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes);
  final b = BytesBuilder();
  void u32(int v) => b.add([v & 255, (v >> 8) & 255, (v >> 16) & 255, (v >> 24) & 255]);
  void u16(int v) => b.add([v & 255, (v >> 8) & 255]);
  b.add('RIFF'.codeUnits);
  u32(36 + data.length);
  b.add('WAVEfmt '.codeUnits);
  u32(16);
  u16(1); // PCM
  u16(1); // моно
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  b.add('data'.codeUnits);
  u32(data.length);
  b.add(data);
  return b.toBytes();
}

/// Мягкий сигнал из нескольких нот (колокольчик): [notes] — частоты по очереди.
Uint8List chimeWav(List<double> notes, {int rate = 22050, int noteMs = 260}) {
  final per = rate * noteMs ~/ 1000;
  final tail = rate ~/ 2;
  final pcm = Int16List(per * notes.length + tail);
  for (var n = 0; n < notes.length; n++) {
    final hz = notes[n];
    for (var k = 0; k < per + tail && n * per + k < pcm.length; k++) {
      final env = math.exp(-k / (rate * 0.18)) * math.min(1.0, k / (rate * 0.004));
      final v = (math.sin(2 * math.pi * hz * k / rate) + 0.3 * math.sin(4 * math.pi * hz * k / rate)) * env * 0.45;
      final i = n * per + k;
      pcm[i] = (pcm[i] + v * 32767).round().clamp(-32768, 32767);
    }
  }
  return pcmToWav(pcm, rate);
}

/// Записать звук во временный файл (один раз на имя) и вернуть путь.
Future<String> tempSound(String name, Uint8List Function() make, {bool rewrite = false}) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}${Platform.pathSeparator}$name');
  if (rewrite || !f.existsSync()) await f.writeAsBytes(make(), flush: true);
  return f.path;
}
