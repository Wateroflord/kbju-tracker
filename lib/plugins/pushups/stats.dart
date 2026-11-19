import 'dart:convert';
import 'dart:io';

import '../data_dir.dart';

/// Один подход (тренировка или бой).
class PushSet {
  final DateTime at;
  final int reps;
  final int ms; // длительность подхода
  final int rejected; // незасчитанные повторы

  const PushSet(this.at, this.reps, this.ms, this.rejected);

  Map<String, dynamic> toJson() => {'at': at.toIso8601String(), 'reps': reps, 'ms': ms, 'rej': rejected};

  static PushSet? fromJson(Map j) {
    final at = DateTime.tryParse('${j['at']}');
    if (at == null) return null;
    return PushSet(at, (j['reps'] as num?)?.toInt() ?? 0, (j['ms'] as num?)?.toInt() ?? 0, (j['rej'] as num?)?.toInt() ?? 0);
  }
}

/// Личная статистика Push-Up Arena. Хранится в папке плагина: plugins/pushups/stats.json.
class PushStats {
  PushStats._();
  static final PushStats I = PushStats._();

  static const _maxHistory = 200;

  int best = 0; // рекорд за один подход
  int total = 0; // всего отжиманий за всё время
  int sets = 0; // сколько подходов сделано
  List<PushSet> history = []; // последние подходы, новые в начале

  Future<File> _file() async => File('${(await pluginDataDir('pushups')).path}${Platform.pathSeparator}stats.json');

  Future<void> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return;
      final j = jsonDecode(await f.readAsString()) as Map;
      best = (j['best'] as num?)?.toInt() ?? 0;
      total = (j['total'] as num?)?.toInt() ?? 0;
      sets = (j['sets'] as num?)?.toInt() ?? 0;
      history = [
        for (final e in (j['history'] as List? ?? const []))
          if (e is Map) PushSet.fromJson(e),
      ].whereType<PushSet>().toList();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final f = await _file();
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(
          jsonEncode({'best': best, 'total': total, 'sets': sets, 'history': [for (final s in history) s.toJson()]}),
          flush: true);
      await tmp.rename(f.path);
    } catch (_) {}
  }

  /// Записать подход. Возвращает true, если это новый рекорд.
  Future<bool> addSet(PushSet s) async {
    if (s.reps <= 0) return false;
    final record = s.reps > best;
    if (record) best = s.reps;
    total += s.reps;
    sets++;
    history.insert(0, s);
    if (history.length > _maxHistory) history = history.sublist(0, _maxHistory);
    await _save();
    return record;
  }

  /// Отжиманий за сегодня.
  int get today {
    final n = DateTime.now();
    var sum = 0;
    for (final s in history) {
      if (s.at.year == n.year && s.at.month == n.month && s.at.day == n.day) sum += s.reps;
    }
    return sum;
  }
}
