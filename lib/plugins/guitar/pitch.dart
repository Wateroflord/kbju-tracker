import 'dart:math' as math;
import 'dart:typed_data';

/// Определение высоты звука (алгоритм YIN) — чистая логика, проверяется тестами.
///
/// [samples] — моно-сигнал от -1 до 1. Возвращает частоту в Гц или null (тишина / шум).
double? detectPitch(Float64List samples, int sampleRate, {double minHz = 60, double maxHz = 1100, double threshold = 0.15}) {
  final n = samples.length;
  final tauMax = math.min(n ~/ 2, (sampleRate / minHz).ceil());
  final tauMin = math.max(2, (sampleRate / maxHz).floor());
  if (tauMax <= tauMin + 2) return null;
  final w = n - tauMax;
  if (w < 64) return null;

  // Громкость: в тишине ничего не ищем.
  var energy = 0.0;
  for (var i = 0; i < n; i++) {
    energy += samples[i] * samples[i];
  }
  if (math.sqrt(energy / n) < 0.006) return null;

  // Разностная функция и её нормированное среднее (CMNDF).
  final d = Float64List(tauMax + 1);
  for (var tau = 1; tau <= tauMax; tau++) {
    var s = 0.0;
    for (var i = 0; i < w; i++) {
      final x = samples[i] - samples[i + tau];
      s += x * x;
    }
    d[tau] = s;
  }
  final cm = Float64List(tauMax + 1)..[0] = 1;
  var running = 0.0;
  for (var tau = 1; tau <= tauMax; tau++) {
    running += d[tau];
    cm[tau] = running == 0 ? 1 : d[tau] * tau / running;
  }

  // Первый провал ниже порога — это период (так не путаем с октавой ниже).
  var best = -1;
  for (var tau = tauMin; tau <= tauMax; tau++) {
    if (cm[tau] < threshold) {
      while (tau + 1 <= tauMax && cm[tau + 1] < cm[tau]) {
        tau++;
      }
      best = tau;
      break;
    }
  }
  if (best < 0) {
    // Порог не пройден — берём глобальный минимум, если он достаточно чёткий.
    var minV = double.infinity;
    for (var tau = tauMin; tau <= tauMax; tau++) {
      if (cm[tau] < minV) {
        minV = cm[tau];
        best = tau;
      }
    }
    if (minV > 0.35) return null;
  }

  // Уточнение между отсчётами (парабола).
  var t = best.toDouble();
  if (best > 1 && best < tauMax) {
    final a = cm[best - 1], b = cm[best], c = cm[best + 1];
    final den = a + c - 2 * b;
    if (den.abs() > 1e-12) t = best + (a - c) / (2 * den);
  }
  final hz = sampleRate / t;
  if (hz < minHz || hz > maxHz) return null;
  return hz;
}

/// PCM 16 бит (little-endian) → числа от -1 до 1.
Float64List pcm16ToFloat(Uint8List bytes) {
  final bd = ByteData.sublistView(bytes);
  final out = Float64List(bytes.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = bd.getInt16(i * 2, Endian.little) / 32768.0;
  }
  return out;
}

const noteNames = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];

/// Номер ноты MIDI (дробный): A4 = 69.
double midiOf(double hz, {double a4 = 440}) => 69 + 12 * math.log(hz / a4) / math.ln2;

double hzOfMidi(num midi, {double a4 = 440}) => a4 * math.pow(2, (midi - 69) / 12).toDouble();

/// «E2», «A#3».
String noteName(int midi) => '${noteNames[midi % 12]}${midi ~/ 12 - 1}';

/// Отклонение в центах от ноты [midi] (+ — выше, − — ниже).
double centsOff(double hz, int midi, {double a4 = 440}) => (midiOf(hz, a4: a4) - midi) * 100;

/// Строй гитары: ноты струн от толстой (6-й) к тонкой (1-й).
class Tuning {
  final String name;
  final List<int> midi;
  const Tuning(this.name, this.midi);
}

const tunings = [
  Tuning('Стандарт (E A D G B E)', [40, 45, 50, 55, 59, 64]),
  Tuning('Drop D (D A D G B E)', [38, 45, 50, 55, 59, 64]),
  Tuning('Полтона ниже (Eb)', [39, 44, 49, 54, 58, 63]),
  Tuning('Тон ниже (D G C F A D)', [38, 43, 48, 53, 57, 62]),
  Tuning('Drop C (C G C F A D)', [36, 43, 48, 53, 57, 62]),
];

/// Ближайшая струна строя к частоте [hz] (индекс 0 — 6-я струна).
int nearestString(Tuning t, double hz) {
  final m = midiOf(hz);
  var best = 0;
  for (var i = 1; i < t.midi.length; i++) {
    if ((t.midi[i] - m).abs() < (t.midi[best] - m).abs()) best = i;
  }
  return best;
}
