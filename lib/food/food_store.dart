import '../util.dart';
import 'food_models.dart';

/// Дополнительные данные питания. Сохраняются в общем JSON под ключом `food`.
class FoodStore {
  final void Function() _notify;
  FoodStore(this._notify);

  final List<FavFood> favorites = [];
  final Map<String, BarcodeProduct> products = {}; // штрихкод -> товар

  // Замеры тела: день -> часть тела -> см
  final Map<String, Map<String, double>> measures = {};

  // Интервальное голодание
  int fastStart = 0; // ms, 0 — не голодаю
  int fastGoalH = 16;
  final List<FastEntry> fasts = [];

  // Расходы на еду
  final List<Expense> expenses = [];
  double budgetPln = 0; // 0 — без бюджета
  double usdRate = 3.6; // злотых за доллар

  // Недельные разборы ИИ: понедельник недели -> текст
  final Map<String, String> reports = {};

  int _id = 0;
  String newId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_id++}';

  void reset({bool silent = false}) {
    favorites.clear();
    products.clear();
    measures.clear();
    fastStart = 0;
    fastGoalH = 16;
    fasts.clear();
    expenses.clear();
    budgetPln = 0;
    usdRate = 3.6;
    reports.clear();
    if (!silent) _notify();
  }

  Map<String, dynamic> toJson() => {
        'favorites': favorites.map((f) => f.toJson()).toList(),
        'products': products.map((k, v) => MapEntry(k, v.toJson())),
        'measures': measures,
        'fastStart': fastStart,
        'fastGoalH': fastGoalH,
        'fasts': fasts.map((f) => f.toJson()).toList(),
        'expenses': expenses.map((e) => e.toJson()).toList(),
        'budgetPln': budgetPln,
        'usdRate': usdRate,
        'reports': reports,
      };

  static List<Map<String, dynamic>> maps(dynamic v) =>
      ((v as List?) ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

  void load(dynamic raw) {
    reset(silent: true);
    if (raw is! Map) return;
    final j = Map<String, dynamic>.from(raw);
    favorites.addAll(maps(j['favorites']).map(FavFood.fromJson).where((f) => f.name.isNotEmpty));
    final pr = j['products'];
    if (pr is Map) {
      pr.forEach((k, v) {
        if (v is Map) products[k.toString()] = BarcodeProduct.fromJson(Map<String, dynamic>.from(v));
      });
    }
    final ms = j['measures'];
    if (ms is Map) {
      ms.forEach((k, v) {
        if (v is Map) {
          final m = <String, double>{};
          v.forEach((p, x) {
            final d = asDouble(x);
            if (d > 0) m[p.toString()] = d;
          });
          if (m.isNotEmpty) measures[k.toString()] = m;
        }
      });
    }
    fastStart = asInt(j['fastStart']);
    fastGoalH = asInt(j['fastGoalH'], 16).clamp(10, 72).toInt();
    fasts.addAll(maps(j['fasts']).map(FastEntry.fromJson).where((f) => f.end > f.start));
    expenses.addAll(maps(j['expenses']).map(Expense.fromJson).where((e) => e.amount > 0));
    budgetPln = asDouble(j['budgetPln']);
    usdRate = asDouble(j['usdRate'], 3.6);
    if (usdRate <= 0.5 || usdRate > 20) usdRate = 3.6;
    final rp = j['reports'];
    if (rp is Map) rp.forEach((k, v) => reports[k.toString()] = v.toString());
  }

  // ---------- замеры ----------

  List<MapEntry<String, double>> measureSeries(String part) {
    final out = <MapEntry<String, double>>[];
    for (final e in measures.entries) {
      final v = e.value[part];
      if (v != null) out.add(MapEntry(e.key, v));
    }
    out.sort((a, b) => a.key.compareTo(b.key));
    return out;
  }

  double? latestMeasure(String part) {
    final s = measureSeries(part);
    return s.isEmpty ? null : s.last.value;
  }

  void setMeasures(String day, Map<String, double> values) {
    final m = {for (final e in values.entries) if (e.value > 0) e.key: e.value};
    if (m.isEmpty) {
      measures.remove(day);
    } else {
      measures[day] = m;
    }
    _notify();
  }

  void deleteMeasures(String day) {
    measures.remove(day);
    _notify();
  }

  // ---------- голодание ----------

  bool get fasting => fastStart > 0;

  void startFast({int? at}) {
    fastStart = at ?? DateTime.now().millisecondsSinceEpoch;
    _notify();
  }

  /// Завершить. Возвращает запись (или null, если голодание было слишком коротким).
  FastEntry? stopFast() {
    if (fastStart == 0) return null;
    final e = FastEntry(fastStart, DateTime.now().millisecondsSinceEpoch, fastGoalH);
    fastStart = 0;
    if (e.hours >= 0.5) fasts.add(e);
    _notify();
    return e.hours >= 0.5 ? e : null;
  }

  void cancelFast() {
    fastStart = 0;
    _notify();
  }

  void setFastGoal(int h) {
    fastGoalH = h.clamp(10, 72).toInt();
    _notify();
  }

  void deleteFast(int start) {
    fasts.removeWhere((f) => f.start == start);
    _notify();
  }

  // ---------- расходы ----------

  double toPln(Expense e) => e.currency == 'USD' ? e.amount * usdRate : e.amount;

  List<Expense> expensesOfMonth(int year, int month) {
    final p = '$year-${two(month)}';
    return expenses.where((e) => e.date.startsWith(p)).toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  void saveExpense(Expense e) {
    final i = expenses.indexWhere((x) => x.id == e.id);
    if (i < 0) {
      expenses.add(e);
    } else {
      expenses[i] = e;
    }
    _notify();
  }

  void deleteExpense(String id) {
    expenses.removeWhere((e) => e.id == id);
    _notify();
  }

  void setBudget(double pln, double rate) {
    budgetPln = pln < 0 ? 0 : pln;
    if (rate > 0.5 && rate < 20) usdRate = rate;
    _notify();
  }

  // ---------- отчёты ----------

  void saveReport(String week, String text) {
    reports[week] = text;
    _notify();
  }

  // ---------- избранное ----------

  bool isFavorite(String name) {
    final n = name.trim().toLowerCase();
    return n.isNotEmpty && favorites.any((f) => f.norm == n);
  }

  /// Добавить в избранное или убрать, если уже есть. Возвращает true, если добавлено.
  bool toggleFavorite(FavFood f) {
    final n = f.norm;
    if (n.isEmpty) return false;
    final before = favorites.length;
    favorites.removeWhere((x) => x.norm == n);
    final added = favorites.length == before;
    if (added) favorites.insert(0, f);
    _notify();
    return added;
  }

  void removeFavorite(String id) {
    favorites.removeWhere((f) => f.id == id);
    _notify();
  }

  // ---------- штрихкоды ----------

  void saveProduct(BarcodeProduct p) {
    products[p.code] = p;
    _notify();
  }
}
