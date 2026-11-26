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

  /// Плагины, которые один раз включились сами (Winter Language вместо вкладки «Учёба»).
  final Set<String> autoEnabled = {};

  /// Плагины, которые пользователь уже видел в списке. Появились новые после обновления — предложим включить.
  final Set<String> known = {};

  /// Плагины, добавленные после первого выбора (у старых пользователей их ещё нет в known).
  static const _addedLater = {'guitar', 'shifts', 'focus'};

  /// Новые плагины, о которых пользователь ещё не знает.
  List<WinterPlugin> get fresh => [
        for (final p in winterPlugins)
          if (!p.core && !known.contains(p.id) && !enabled.contains(p.id)) p,
      ];

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
        autoEnabled
          ..clear()
          ..addAll([for (final e in (j['auto'] as List? ?? const [])) '$e']);
        final k = j['known'];
        known
          ..clear()
          ..addAll(k is List
              ? [for (final e in k) '$e']
              : [for (final p in winterPlugins) if (!_addedLater.contains(p.id)) p.id]);
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
      await _file?.writeAsString(
          jsonEncode({
            'enabled': enabled.toList(),
            'asked': asked,
            'active': active,
            'auto': autoEnabled.toList(),
            'known': known.toList(),
          }));
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

  /// Включить плагин сам один раз. Если пользователь потом его выключит — больше не включаем.
  Future<void> enableOnce(String id) async {
    if (pluginById(id) == null || autoEnabled.contains(id)) return;
    autoEnabled.add(id);
    enabled.add(id);
    notifyListeners();
    await _save();
  }

  /// Первый выбор плагинов сделан.
  Future<void> finishWelcome(Set<String> ids) async {
    enabled
      ..clear()
      ..addAll(ids);
    asked = true;
    known.addAll(winterPlugins.map((p) => p.id));
    notifyListeners();
    await _save();
  }

  /// После обновления: какие из новых плагинов включить.
  Future<void> finishNew(Set<String> ids) async {
    enabled.addAll(ids);
    known.addAll(winterPlugins.map((p) => p.id));
    notifyListeners();
    await _save();
  }
}
