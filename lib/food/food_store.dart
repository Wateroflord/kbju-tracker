import 'food_models.dart';

/// Дополнительные данные питания. Сохраняются в общем JSON под ключом `food`.
class FoodStore {
  final void Function() _notify;
  FoodStore(this._notify);

  final List<FavFood> favorites = [];
  final Map<String, BarcodeProduct> products = {}; // штрихкод -> товар

  int _id = 0;
  String newId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_id++}';

  void reset({bool silent = false}) {
    favorites.clear();
    products.clear();
    if (!silent) _notify();
  }

  Map<String, dynamic> toJson() => {
        'favorites': favorites.map((f) => f.toJson()).toList(),
        'products': products.map((k, v) => MapEntry(k, v.toJson())),
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
