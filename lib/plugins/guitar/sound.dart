import 'dart:math' as math;
import 'dart:typed_data';

import '../common/wav.dart';

/// Звуки гитарного плагина генерируются в коде (без файлов в APK).

const soundRate = 22050;

/// Отсчётов на одну долю — целое число, чтобы темп не «плыл».
int samplesPerBeat(int bpm, {int rate = soundRate}) => (rate * 60 / bpm).round();

/// Метроном: несколько тактов подряд в одном WAV, который играет по кругу.
/// Длинный файл (≥ [minSeconds]) — чтобы стык при повторе случался редко.
Uint8List metronomeWav(int bpm, int beats, {int rate = soundRate, double minSeconds = 24, bool accent = true}) {
  final spb = samplesPerBeat(bpm, rate: rate);
  final bar = spb * beats;
  final bars = math.max(1, (minSeconds * rate / bar).ceil());
  final pcm = Int16List(bar * bars);
  final clickLen = math.min(spb, (rate * 0.035).round());
  for (var i = 0; i < beats * bars; i++) {
    final first = accent && i % beats == 0;
    final hz = first ? 1760.0 : 1100.0;
    final amp = first ? 0.9 : 0.6;
    final at = i * spb;
    for (var k = 0; k < clickLen; k++) {
      final env = math.exp(-k / (rate * 0.008));
      pcm[at + k] = (math.sin(2 * math.pi * hz * k / rate) * env * amp * 32767).round();
    }
  }
  return pcmToWav(pcm, rate);
}

/// Звук гитарной струны (Карплус — Стронг) для настройки на слух.
Uint8List pluckWav(double hz, {int rate = soundRate, double seconds = 2.5, int seed = 7}) {
  final n = (rate * seconds).round();
  final period = math.max(2, (rate / hz).round());
  final rnd = math.Random(seed);
  final buf = Float64List(period);
  for (var i = 0; i < period; i++) {
    buf[i] = rnd.nextDouble() * 2 - 1;
  }
  final pcm = Int16List(n);
  var idx = 0;
  for (var i = 0; i < n; i++) {
    final next = (idx + 1) % period;
    final v = buf[idx];
    buf[idx] = 0.4985 * (v + buf[next]);
    final fade = i > n - rate * 0.1 ? (n - i) / (rate * 0.1) : 1.0;
    pcm[i] = (v * 0.7 * fade * 32767).round().clamp(-32768, 32767);
    idx = next;
  }
  return pcmToWav(pcm, rate);
}
