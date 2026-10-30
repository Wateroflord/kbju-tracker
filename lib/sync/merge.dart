import 'dart:convert';

/// Слияние данных двух устройств (телефон и ПК) с учётом общего состояния после прошлой синхронизации.
///
/// [base] — данные после прошлой синхронизации (у обоих устройств одинаковые), null — первая синхронизация.
/// [a] и [b] — данные устройств сейчас. Если что-то менялось на обоих — побеждает [aNewer] (кто менялся позже).
/// Записи в списках с полем id сливаются по одной: добавленные на любом устройстве сохраняются,
/// удалённые на одном устройстве (были в [base]) удаляются и на другом.
dynamic merge3(dynamic base, dynamic a, dynamic b, {required bool aNewer}) {
  if (_eq(a, b)) return a;
  if (base != null) {
    if (_eq(a, base)) return b;
    if (_eq(b, base)) return a;
  }
  if (a is Map && b is Map) {
    final bm = base is Map ? base : const {};
    final out = <String, dynamic>{};
    final keys = <String>{...a.keys.map((k) => '$k'), ...b.keys.map((k) => '$k')};
    for (final k in keys) {
      final inA = a.containsKey(k), inB = b.containsKey(k), inBase = bm.containsKey(k);
      if (inA && inB) {
        out[k] = merge3(bm[k], a[k], b[k], aNewer: aNewer);
      } else if (inA) {
        // Нет у b: если было в базе и a не менял — значит b удалил.
        if (inBase && _eq(a[k], bm[k])) continue;
        out[k] = a[k];
      } else if (inB) {
        if (inBase && _eq(b[k], bm[k])) continue;
        out[k] = b[k];
      }
    }
    return out;
  }
  if (a is List && b is List && _hasIds(a) && _hasIds(b)) {
    final baseList = base is List && _hasIds(base) ? base : const [];
    final baseById = {for (final x in baseList) _id(x): x};
    final aById = {for (final x in a) _id(x): x};
    final bById = {for (final x in b) _id(x): x};
    final order = <String>[...aById.keys, ...bById.keys.where((k) => !aById.containsKey(k))];
    final out = <dynamic>[];
    for (final id in order) {
      final inA = aById.containsKey(id), inB = bById.containsKey(id), inBase = baseById.containsKey(id);
      if (inA && inB) {
        out.add(merge3(baseById[id], aById[id], bById[id], aNewer: aNewer));
      } else if (inA) {
        if (inBase && _eq(aById[id], baseById[id])) continue; // удалено на b
        out.add(aById[id]);
      } else {
        if (inBase && _eq(bById[id], baseById[id])) continue; // удалено на a
        out.add(bById[id]);
      }
    }
    return out;
  }
  if (a is List && b is List && a.every((x) => x is Map) && b.every((x) => x is Map) && base == null) {
    // Первая синхронизация: объединяем записи без повторов.
    final seen = <String>{};
    return [
      for (final x in [...a, ...b])
        if (seen.add(jsonEncode(x))) x,
    ];
  }
  return aNewer ? a : b;
}

bool _hasIds(List l) => l.isNotEmpty && l.every((x) => x is Map && x['id'] != null);
String _id(dynamic x) => '${(x as Map)['id']}';
bool _eq(dynamic x, dynamic y) => jsonEncode(x) == jsonEncode(y);

/// Поля, которые у каждого устройства свои (датчик шагов телефона и т. п.).
const deviceLocalPaths = [
  ['life', 'stepSensorLast'],
  ['life', 'stepSensorDay'],
  ['life', 'stepSource'],
  ['life', 'stepsPromptHidden'],
  ['modifiedAt'],
];

/// Вернуть в [merged] значения полей устройства из [local].
Map<String, dynamic> keepLocal(Map<String, dynamic> merged, Map<String, dynamic> local) {
  final out = jsonDecode(jsonEncode(merged)) as Map<String, dynamic>;
  for (final path in deviceLocalPaths) {
    dynamic src = local;
    Map? dst = out;
    for (var i = 0; i < path.length - 1; i++) {
      src = src is Map ? src[path[i]] : null;
      final next = dst?[path[i]];
      dst = next is Map ? next : null;
    }
    final k = path.last;
    if (dst == null) continue;
    if (src is Map && src.containsKey(k)) {
      dst[k] = src[k];
    } else {
      dst.remove(k);
    }
  }
  return out;
}

/// Короткий отпечаток данных (чтобы понять, одинаковая ли «база» у двух устройств).
String fingerprint(Object? data) {
  final s = jsonEncode(data);
  var h = 0x811c9dc5;
  for (final c in utf8.encode(s)) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return '${h.toRadixString(16)}-${s.length}';
}
