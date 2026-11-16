import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'data_dir.dart';
import 'registry.dart';

/// Какие плагины включены и какой открыт сейчас. Хранится в plugins/host/host.json.
class PluginHost extends ChangeNotifier {
  PluginHost._();
  static final PluginHost I = PluginHost._();

  /// Включённые плагины (КБЖУ включён всегда).
  final Set<String> enabled = {};

  /// Пользователь уже выбрал плагины в первый раз.
  bool asked = false;

  /// Открытый сейчас плагин.
  String active = 'kbju';

  /// Плагины, которые уже подготовлены (init выполнен).
  final Set<String> _ready = {'kbju'};

  /// Плагин, который сейчас готовится (показываем загрузку).
  String? preparing;
  String? error;

  File? _file;

  List<WinterPlugin> get visible => [
        for (final p in winterPlugins)
          if (p.core || enabled.contains(p.id)) p,
      ];

  bool isOn(String id) => pluginById(id)?.core == true || enabled.contains(id);
  bool isReady(String id) => _ready.contains(id);

  Future<void> load() async {
    try {
      _file = File('${(await pluginDataDir('host')).path}${Platform.pathSeparator}host.json');
      if (await _file!.exists()) {
        final j = jsonDecode(await _file!.readAsString()) as Map;
        enabled
          ..clear()
          ..addAll([for (final e in (j['enabled'] as List? ?? const [])) '$e'].where((id) => pluginById(id) != null));
        asked = j['asked'] == true;
        final last = '${j['active'] ?? 'kbju'}';
        if (isOn(last)) active = last;
      }
    } catch (e) {
      debugPrint('plugins: $e');
    }
    // Последний открытый плагин подготовить сразу.
    if (active != 'kbju') await _prepare(active);
  }

  Future<void> _save() async {
    try {
      await _file?.writeAsString(jsonEncode({'enabled': enabled.toList(), 'asked': asked, 'active': active}));
    } catch (_) {}
  }

  Future<bool> _prepare(String id) async {
    if (_ready.contains(id)) return true;
    final p = pluginById(id);
    if (p == null) return false;
    preparing = id;
    error = null;
    notifyListeners();
    try {
      await p.init?.call();
      _ready.add(id);
      return true;
    } catch (e) {
      error = '$e';
      debugPrint('plugin $id init: $e');
      return false;
    } finally {
      preparing = null;
      notifyListeners();
    }
  }

  /// Открыть плагин (если выключен — включается).
  Future<void> open(String id) async {
    if (pluginById(id) == null) return;
    if (!isOn(id)) enabled.add(id);
    final ok = await _prepare(id);
    if (!ok) {
      active = 'kbju';
    } else {
      active = id;
    }
    notifyListeners();
    await _save();
  }

  Future<void> setEnabled(String id, bool on) async {
    if (pluginById(id)?.core == true) return;
    if (on) {
      enabled.add(id);
    } else {
      enabled.remove(id);
      if (active == id) active = 'kbju';
    }
    notifyListeners();
    await _save();
  }

  /// Первый выбор плагинов сделан.
  Future<void> finishWelcome(Set<String> ids) async {
    enabled
      ..clear()
      ..addAll(ids);
    asked = true;
    notifyListeners();
    await _save();
  }
}
