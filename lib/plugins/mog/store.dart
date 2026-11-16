import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../data_dir.dart';

import 'models.dart';

/// Настройки и история. Хранятся в JSON-файлах в папке приложения.
class Store extends ChangeNotifier {
  Store._();
  static final Store I = Store._();

  static const maxHistory = 80;

  String apiKey = '';
  String model = '';
  int tone = 1;
  List<HistoryEntry> history = [];

  Directory? _dir;

  Future<File> _file(String name) async {
    _dir ??= await pluginDataDir('mog');
    if (!await _dir!.exists()) await _dir!.create(recursive: true);
    return File('${_dir!.path}${Platform.pathSeparator}$name');
  }

  Future<Map<String, dynamic>?> _read(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      final d = jsonDecode(await f.readAsString());
      return d is Map ? Map<String, dynamic>.from(d) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _write(String name, Map<String, dynamic> data) async {
    try {
      final f = await _file(name);
      final tmp = File('${f.path}.tmp');
      await tmp.writeAsString(jsonEncode(data), flush: true);
      if (await f.exists()) await f.delete();
      await tmp.rename(f.path);
    } catch (e) {
      debugPrint('save $name failed: $e');
    }
  }

  Future<void> load() async {
    final s = await _read('settings.json');
    if (s != null) {
      apiKey = (s['apiKey'] ?? '').toString();
      model = (s['model'] ?? '').toString();
      tone = ((s['tone'] as num?) ?? 1).clamp(0, 2).toInt();
    }
    final h = await _read('history.json');
    final list = h?['items'];
    if (list is List) {
      history = list.whereType<Map>().map(HistoryEntry.fromJson).toList();
    }
    notifyListeners();
  }

  Future<void> saveSettings({String? apiKey, String? model, int? tone}) async {
    if (apiKey != null) this.apiKey = apiKey.trim();
    if (model != null) this.model = model.trim();
    if (tone != null) this.tone = tone;
    notifyListeners();
    await _write('settings.json', {'apiKey': this.apiKey, 'model': this.model, 'tone': this.tone});
  }

  Future<void> _saveHistory() => _write('history.json', {'items': history.map((e) => e.toJson()).toList()});

  Future<void> addHistory(HistoryEntry e) async {
    history.insert(0, e);
    if (history.length > maxHistory) history = history.sublist(0, maxHistory);
    notifyListeners();
    await _saveHistory();
  }

  Future<void> removeHistory(String id) async {
    history.removeWhere((e) => e.id == id);
    notifyListeners();
    await _saveHistory();
  }

  Future<void> clearHistory() async {
    history = [];
    notifyListeners();
    await _saveHistory();
  }

  /// История одним файлом (без ключа Gemini).
  String exportHistory() => jsonEncode({'app': 'mog-battle', 'version': 1, 'items': history.map((e) => e.toJson()).toList()});

  /// Добавить записи из копии (повторы по id пропускаются). Возвращает число добавленных.
  Future<int> importHistory(String raw) async {
    final Object? j;
    try {
      j = jsonDecode(raw.trim());
    } catch (_) {
      throw const FormatException('Это не файл резервной копии');
    }
    if (j is! Map || j['app'] != 'mog-battle') throw const FormatException('Это не копия Mog Battle');
    final have = {for (final e in history) e.id};
    final add = <HistoryEntry>[];
    for (final m in (j['items'] as List? ?? const []).whereType<Map>()) {
      try {
        final e = HistoryEntry.fromJson(m);
        if (have.add(e.id)) add.add(e);
      } catch (_) {}
    }
    history = [...history, ...add]..sort((a, b) => b.date.compareTo(a.date));
    if (history.length > maxHistory) history = history.sublist(0, maxHistory);
    notifyListeners();
    await _saveHistory();
    return add.length;
  }

  /// Плагин внутри КБЖУ: если свой ключ не задан, берётся ключ Gemini из КБЖУ.
  static String Function()? sharedKey;

  /// Ключ для запросов: свой или общий из КБЖУ.
  String get effectiveKey => apiKey.trim().isNotEmpty ? apiKey.trim() : (sharedKey?.call() ?? '').trim();

  bool get hasKey => effectiveKey.isNotEmpty;
}
