import '../../../learn/srs.dart';
import '../../../util.dart';

/// Прогресс изучения языков. Поля и формат JSON такие же, как были в КБЖУ Трекере
/// (ключ `life` в его резервной копии), поэтому прогресс переносится без потерь.
class LifeStore {
  final void Function() _notify;
  LifeStore(this._notify);

  static const langs = ['en', 'pl', 'de'];

  String learnLang = 'en';
  int learnGoalMin = 45;
  final Map<String, Map<String, CardState>> learnCards = {};
  final Map<String, Map<String, int>> learnSeconds = {};
  final Map<String, String> learnGoalText = {};

  /// Любое изменение: сохранить и перерисовать экран.
  void touch() => _notify();

  void reset() {
    learnLang = 'en';
    learnGoalMin = 45;
    learnCards.clear();
    learnSeconds.clear();
    learnGoalText.clear();
  }

  Map<String, dynamic> toJson() => {
        'learnLang': learnLang,
        'learnGoalMin': learnGoalMin,
        'learnCards': learnCards.map((l, m) => MapEntry(l, m.map((k, v) => MapEntry(k, v.toJson())))),
        'learnSeconds': learnSeconds,
        'learnGoalText': learnGoalText,
      };

  /// Есть ли в JSON хоть что-то про учёбу.
  static bool hasLearnData(Map j) => j.containsKey('learnCards') || j.containsKey('learnSeconds') || j.containsKey('learnLang');

  void fromJson(Map j) {
    reset();
    final ll = j['learnLang']?.toString() ?? 'en';
    learnLang = langs.contains(ll) ? ll : 'en';
    learnGoalMin = asInt(j['learnGoalMin'], 45).clamp(5, 180).toInt();
    final lc = j['learnCards'];
    if (lc is Map) {
      lc.forEach((l, m) {
        if (m is! Map) return;
        learnCards[l.toString()] = {
          for (final e in m.entries)
            if (e.value is Map) e.key.toString(): CardState.fromJson(Map<String, dynamic>.from(e.value as Map)),
        };
      });
    }
    final ls = j['learnSeconds'];
    if (ls is Map) {
      ls.forEach((l, m) {
        if (m is Map) learnSeconds[l.toString()] = m.map((k, v) => MapEntry(k.toString(), asInt(v)));
      });
    }
    final lg = j['learnGoalText'];
    if (lg is Map) lg.forEach((k, v) => learnGoalText[k.toString()] = v.toString());
  }

  /// Слить прогресс из другого источника (например, из КБЖУ):
  /// по каждому слову берём карточку, где больше ответов; минуты по дням — максимум из двух.
  void mergeFrom(LifeStore o) {
    final wasEmpty = seenTotal() == 0;
    o.learnCards.forEach((lang, cards) {
      final mine = learnCards.putIfAbsent(lang, () => {});
      cards.forEach((id, c) {
        final m = mine[id];
        if (m == null || (c.right + c.wrong) > (m.right + m.wrong)) mine[id] = c;
      });
    });
    o.learnSeconds.forEach((lang, days) {
      final mine = learnSeconds.putIfAbsent(lang, () => {});
      days.forEach((d, s) {
        if (s > (mine[d] ?? 0)) mine[d] = s;
      });
    });
    o.learnGoalText.forEach((l, t) {
      if ((learnGoalText[l] ?? '').isEmpty && t.isNotEmpty) learnGoalText[l] = t;
    });
    if (wasEmpty) learnLang = o.learnLang;
    learnGoalMin = o.learnGoalMin;
  }

  int seenTotal() => learnCards.values.fold(0, (a, m) => a + m.length);
}
