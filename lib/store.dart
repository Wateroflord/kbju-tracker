import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'calc.dart';
import 'life/life_store.dart';
import 'models.dart';
import 'util.dart';

/// Всё состояние приложения. Сохраняется в JSON-файл в памяти телефона
/// после каждого изменения, поэтому данные не пропадают после закрытия.
class AppStore extends ChangeNotifier {
  static const defaultModel = 'gemini-flash-latest';

  Profile? profile;
  final List<FoodEntry> entries = [];
  final Map<String, double> weights = {};
  final Map<String, int> water = {};
  final Map<String, Targets> dayTargets = {};
  final List<GoalChange> goalHistory = [];
  String apiKey = '';
  String model = defaultModel;

  /// Привычки, шаги, сон, тренировки, уход, напоминания.
  late final LifeStore life = LifeStore(_changed);

  String _docs = '';
  int _idCounter = 0;
  Future<void> _saving = Future.value();

  String get _mainPath => '$_docs/kbju_data.json';
  String get _bakPath => '$_docs/kbju_data.bak.json';
  String get _tmpPath => '$_docs/kbju_data.tmp';

  // ---------- загрузка / сохранение ----------

  Future<void> load() async {
    try {
      _docs = (await getApplicationDocumentsDirectory()).path;
    } catch (e) {
      debugPrint('docs dir error: $e');
      return;
    }
    for (final path in [_mainPath, _bakPath]) {
      try {
        final f = File(path);
        if (!await f.exists()) continue;
        final txt = await f.readAsString();
        _fromJson(Map<String, dynamic>.from(jsonDecode(txt) as Map));
        return;
      } catch (e) {
        debugPrint('load $path failed: $e');
      }
    }
  }

  Map<String, dynamic> _toJson() => {
        'version': 2,
        'profile': profile?.toJson(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'weights': weights,
        'water': water,
        'dayTargets': dayTargets.map((k, v) => MapEntry(k, v.toJson())),
        'goalHistory': goalHistory.map((g) => g.toJson()).toList(),
        'apiKey': apiKey,
        'model': model,
        'life': life.toJson(),
      };

  void _fromJson(Map<String, dynamic> j, {bool keepApi = false}) {
    profile = j['profile'] is Map
        ? Profile.fromJson(Map<String, dynamic>.from(j['profile'] as Map))
        : null;
    entries
      ..clear()
      ..addAll(((j['entries'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => FoodEntry.fromJson(Map<String, dynamic>.from(m))));
    weights
      ..clear()
      ..addAll(((j['weights'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), asDouble(v))));
    water
      ..clear()
      ..addAll(((j['water'] as Map?) ?? const {})
          .map((k, v) => MapEntry(k.toString(), asInt(v))));
    dayTargets
      ..clear()
      ..addAll(((j['dayTargets'] as Map?) ?? const {}).map((k, v) => MapEntry(
          k.toString(),
          Targets.fromJson(Map<String, dynamic>.from(v as Map)))));
    goalHistory
      ..clear()
      ..addAll(((j['goalHistory'] as List?) ?? const [])
          .whereType<Map>()
          .map((m) => GoalChange.fromJson(Map<String, dynamic>.from(m))));
    life.load(j['life']);
    if (!keepApi) {
      apiKey = j['apiKey']?.toString() ?? '';
      final m = j['model']?.toString() ?? '';
      model = m.isEmpty ? defaultModel : m;
    }
  }

  void _persist() {
    if (_docs.isEmpty) return;
    final data = jsonEncode(_toJson());
    _saving = _saving.then((_) async {
      try {
        final tmp = File(_tmpPath);
        await tmp.writeAsString(data, flush: true);
        final main = File(_mainPath);
        if (await main.exists()) await main.copy(_bakPath);
        await tmp.rename(_mainPath);
      } catch (e) {
        debugPrint('save failed: $e');
      }
    });
  }

  void _changed() {
    notifyListeners();
    _persist();
  }

  String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  // ---------- профиль и нормы ----------

  Targets get currentTargets =>
      profile == null ? Targets.zero : computeTargets(profile!);

  Targets targetsFor(String key) => dayTargets[key] ?? currentTargets;

  void _snapshot(String key) {
    if (profile == null) return;
    if (key == todayKey() || !dayTargets.containsKey(key)) {
      dayTargets[key] = currentTargets;
    }
  }

  void saveProfile(Profile p) {
    final old = profile;
    final t = todayKey();
    if (old == null) {
      goalHistory.add(GoalChange(t, null, p.goal));
    } else if (old.goal != p.goal) {
      goalHistory.add(GoalChange(t, old.goal, p.goal));
    }
    if (old == null || (old.weightKg - p.weightKg).abs() > 0.001) {
      weights[t] = p.weightKg;
    }
    profile = p;
    dayTargets[t] = computeTargets(p);
    _changed();
  }

  void setGoal(Goal g) {
    final p = profile;
    if (p == null || p.goal == g) return;
    saveProfile(p.copyWith(goal: g));
  }

  String? get goalSince {
    for (var i = goalHistory.length - 1; i >= 0; i--) {
      if (goalHistory[i].to == profile?.goal) return goalHistory[i].date;
    }
    return null;
  }

  // ---------- вес ----------

  List<MapEntry<String, double>> get weightSeries =>
      weights.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

  void _syncProfileWeight() {
    final p = profile;
    if (p == null || weights.isEmpty) return;
    final latest = weightSeries.last.value;
    if ((p.weightKg - latest).abs() > 0.001) {
      profile = p.copyWith(weightKg: latest);
      dayTargets[todayKey()] = computeTargets(profile!);
    }
  }

  void setWeight(String key, double kg) {
    weights[key] = kg;
    _syncProfileWeight();
    _changed();
  }

  void deleteWeight(String key) {
    weights.remove(key);
    _syncProfileWeight();
    _changed();
  }

  // ---------- еда ----------

  List<FoodEntry> entriesFor(String key) =>
      entries.where((e) => e.date == key).toList()
        ..sort((a, b) => a.time.compareTo(b.time));

  Totals totalsFor(String key) {
    final t = Totals();
    for (final e in entries) {
      if (e.date == key) t.add(e);
    }
    return t;
  }

  /// Итоги по всем дням сразу (для календаря и графиков).
  Map<String, Totals> allTotals() {
    final m = <String, Totals>{};
    for (final e in entries) {
      (m[e.date] ??= Totals()).add(e);
    }
    return m;
  }

  DayStatus statusFor(String key, [Totals? t]) {
    final tot = t ?? totalsFor(key);
    if (tot.count == 0) return DayStatus.none;
    return dayStatus(tot.kcal, targetsFor(key).kcal);
  }

  void addEntries(List<FoodEntry> list) {
    if (list.isEmpty) return;
    entries.addAll(list);
    for (final k in list.map((e) => e.date).toSet()) {
      _snapshot(k);
    }
    _changed();
  }

  void updateEntry(FoodEntry e) {
    final i = entries.indexWhere((x) => x.id == e.id);
    if (i < 0) return;
    entries[i] = e;
    _snapshot(e.date);
    _changed();
  }

  void deleteEntry(String id) {
    final i = entries.indexWhere((x) => x.id == id);
    if (i < 0) return;
    final removed = entries.removeAt(i);
    final photo = removed.photo;
    if (photo != null && !entries.any((x) => x.photo == photo)) {
      _deleteFile(photoFile(photo));
    }
    _changed();
  }

  Future<void> _deleteFile(File? f) async {
    if (f == null) return;
    try {
      await f.delete();
    } catch (_) {}
  }

  Future<String?> savePhoto(Uint8List bytes) async {
    if (_docs.isEmpty) return null;
    try {
      final dir = Directory('$_docs/photos');
      await dir.create(recursive: true);
      final rel = 'photos/${DateTime.now().microsecondsSinceEpoch}.jpg';
      await File('$_docs/$rel').writeAsBytes(bytes, flush: true);
      return rel;
    } catch (e) {
      debugPrint('photo save failed: $e');
      return null;
    }
  }

  File? photoFile(String? rel) {
    if (rel == null || _docs.isEmpty) return null;
    final f = File('$_docs/$rel');
    return f.existsSync() ? f : null;
  }

  // ---------- вода ----------

  int waterFor(String key) => water[key] ?? 0;

  void addWater(String key, int delta) {
    final v = waterFor(key) + delta;
    water[key] = v < 0 ? 0 : v;
    _snapshot(key);
    _changed();
  }

  // ---------- настройки ИИ ----------

  void setAi(String key, String m) {
    apiKey = key.trim();
    model = m.trim().isEmpty ? defaultModel : m.trim();
    _changed();
  }

  // ---------- данные ----------

  String exportJson() => const JsonEncoder.withIndent(' ').convert(_toJson());

  /// Возвращает текст ошибки или null при успехе.
  String? importJson(String txt) {
    try {
      final j = Map<String, dynamic>.from(jsonDecode(txt.trim()) as Map);
      if (!j.containsKey('entries') && !j.containsKey('profile')) {
        return 'Это не похоже на резервную копию приложения';
      }
      _fromJson(j, keepApi: true);
      _changed();
      return null;
    } catch (e) {
      return 'Не удалось прочитать данные: $e';
    }
  }

  void resetAll() {
    profile = null;
    entries.clear();
    weights.clear();
    water.clear();
    dayTargets.clear();
    goalHistory.clear();
    life.reset(silent: true);
    _changed();
    _deletePhotos();
  }

  Future<void> _deletePhotos() async {
    if (_docs.isEmpty) return;
    try {
      final dir = Directory('$_docs/photos');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('photo cleanup failed: $e');
    }
  }
}

/// Даёт доступ к AppStore из любого экрана и перерисовывает экраны при изменениях.
class StoreScope extends InheritedNotifier<AppStore> {
  const StoreScope({super.key, required AppStore store, required super.child})
      : super(notifier: store);

  static AppStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StoreScope>()!.notifier!;

  static AppStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<StoreScope>()!.notifier!;
}
