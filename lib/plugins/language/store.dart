import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import '../data_dir.dart';

import '../../i18n/i18n.dart';
import 'life/life_store.dart';

/// Всё состояние приложения. Сохраняется в один JSON-файл с копией .bak.
class AppStore extends ChangeNotifier {
  AppStore() {
    life = LifeStore(_changed);
  }

  late final LifeStore life;

  /// Язык интерфейса (на нём же показывается перевод слов).
  AppLang uiLang = AppLang.ru;

  /// Пользователь уже видел предложение перенести прогресс из КБЖУ.
  bool importOffered = false;

  String _docs = '';
  Timer? _debounce;
  Future<void> _saving = Future.value();

  String get _mainPath => '$_docs/winter_language.json';
  String get _bakPath => '$_docs/winter_language.bak';

  static const marker = 'winter-language';

  /// Плагин внутри КБЖУ: язык интерфейса общий с КБЖУ. Супер-приложение
  /// подставляет сюда смену языка в КБЖУ и данные учёбы из КБЖУ (для переноса прогресса).
  static void Function(AppLang)? onUiLang;
  static Map<String, dynamic>? Function()? kbjuLife;

  Future<void> load() async {
    uiLang = appLang; // язык КБЖУ
    try {
      _docs = (await pluginDataDir('language')).path;
      await Directory(_docs).create(recursive: true);
    } catch (_) {
      return;
    }
    for (final p in [_mainPath, _bakPath]) {
      try {
        final f = File(p);
        if (!await f.exists()) continue;
        _fromJson(Map<String, dynamic>.from(jsonDecode(await f.readAsString()) as Map));
        break;
      } catch (e) {
        debugPrint('load $p failed: $e');
      }
    }
    uiLang = appLang; // язык интерфейса задаёт КБЖУ
  }

  Map<String, dynamic> _toJson() => {
        'app': marker,
        'version': 1,
        'uiLang': uiLang.code,
        'importOffered': importOffered,
        'life': life.toJson(),
      };

  void _fromJson(Map<String, dynamic> j) {
    if (j['uiLang'] != null) uiLang = langFromCode(j['uiLang']?.toString());
    importOffered = j['importOffered'] == true;
    final l = j['life'];
    if (l is Map) life.fromJson(l);
  }

  void _changed() {
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _persist);
  }

  void _persist() {
    if (_docs.isEmpty) return;
    final data = const JsonEncoder.withIndent(' ').convert(_toJson());
    _saving = _saving.then((_) async {
      try {
        final main = File(_mainPath);
        if (await main.exists()) await main.copy(_bakPath);
        final tmp = File('$_docs/winter_language.tmp');
        await tmp.writeAsString(data, flush: true);
        await tmp.rename(_mainPath);
      } catch (e) {
        debugPrint('save failed: $e');
      }
    });
  }

  /// Сохранить немедленно (при сворачивании приложения).
  Future<void> flush() async {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      _persist();
    }
    await _saving;
  }

  void setUiLang(AppLang l) {
    uiLang = l;
    appLang = l;
    onUiLang?.call(l);
    _changed();
  }

  void markImportOffered() {
    importOffered = true;
    _changed();
  }

  String exportJson() => const JsonEncoder.withIndent(' ').convert(_toJson());

  /// Восстановить из своей копии или перенести прогресс из КБЖУ Трекера
  /// (подходит и полная копия КБЖУ, и файл «прогресс для Winter Language»).
  /// Возвращает null при успехе, иначе текст ошибки.
  String? importJson(String txt) {
    final Map j;
    try {
      j = jsonDecode(txt.trim()) as Map;
    } catch (_) {
      return tr('Это не файл резервной копии');
    }
    final Map? learn = j['life'] is Map && LifeStore.hasLearnData(j['life'] as Map)
        ? j['life'] as Map
        : (LifeStore.hasLearnData(j) ? j : null);
    if (learn == null) return tr('В файле нет прогресса изучения языков');
    final incoming = LifeStore(() {})..fromJson(learn);
    if (j['app'] == marker) {
      // своя копия — заменяем целиком
      life.fromJson(learn);
      if (j['uiLang'] != null) setUiLang(langFromCode(j['uiLang']?.toString()));
    } else {
      // из КБЖУ — сливаем, чтобы не потерять то, что уже выучено здесь
      life.mergeFrom(incoming);
    }
    importOffered = true;
    _changed();
    return null;
  }
}

class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child}) : super(notifier: store);

  static AppStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static AppStore read(BuildContext context) => context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
