import '../i18n/i18n.dart';
import '../life/life_store.dart';
import '../util.dart';
import 'srs.dart';
import 'words.dart';

/// Изучение языков: прогресс по словам, время занятий (цель — 20 часов).
extension LearnLogic on LifeStore {
  Map<String, CardState> cardsOf(String lang) => learnCards.putIfAbsent(lang, () => {});

  /// Язык, на котором показываем перевод: язык интерфейса,
  /// а если он совпадает с изучаемым — русский.
  String nativeFor(String lang) => appLang.code == lang ? 'ru' : appLang.code;

  CardState? cardOf(String lang, W w) => cardsOf(lang)[w.id];

  /// Слова, которые пора повторить (уже изученные хотя бы раз).
  List<W> dueWords(String lang) {
    final cards = cardsOf(lang);
    final t = todayKey();
    final list = words.where((w) {
      final c = cards[w.id];
      return c != null && c.due.compareTo(t) <= 0;
    }).toList();
    list.sort((a, b) => cards[a.id]!.box.compareTo(cards[b.id]!.box));
    return list;
  }

  /// Новые слова по порядку тем (сначала самые полезные).
  List<W> newWords(String lang, int n, {String? topic}) {
    final cards = cardsOf(lang);
    final out = <W>[];
    for (final tp in topics) {
      if (topic != null && tp.id != topic) continue;
      for (final w in wordsOf(tp.id)) {
        if (!cards.containsKey(w.id)) out.add(w);
        if (out.length >= n) return out;
      }
    }
    return out;
  }

  int seenCount(String lang) => cardsOf(lang).length;

  int knownCount(String lang) => cardsOf(lang).values.where((c) => c.known).length;

  (int known, int seen, int total) topicProgress(String lang, String topic) {
    final cards = cardsOf(lang);
    final list = wordsOf(topic);
    var k = 0, s = 0;
    for (final w in list) {
      final c = cards[w.id];
      if (c == null) continue;
      s++;
      if (c.known) k++;
    }
    return (k, s, list.length);
  }

  void recordAnswer(String lang, W w, bool ok) {
    final cards = cardsOf(lang);
    final c = cards[w.id];
    cards[w.id] = c == null ? CardState.first(ok) : c.answer(ok);
    touch();
  }

  void addLearnSeconds(String lang, int sec) {
    if (sec <= 0) return;
    final m = learnSeconds.putIfAbsent(lang, () => {});
    final k = todayKey();
    m[k] = (m[k] ?? 0) + sec;
    touch();
  }

  int secondsOn(String day) {
    var s = 0;
    for (final m in learnSeconds.values) {
      s += m[day] ?? 0;
    }
    return s;
  }

  int totalSeconds(String lang) => (learnSeconds[lang] ?? const {}).values.fold(0, (a, b) => a + b);

  int minutesToday() => secondsOn(todayKey()) ~/ 60;

  void setLearnLang(String lang) {
    learnLang = lang;
    touch();
  }

  void setLearnGoal(int minutes) {
    learnGoalMin = minutes.clamp(5, 180).toInt();
    touch();
  }

  void setLearnGoalText(String lang, String text) {
    learnGoalText[lang] = text.trim();
    touch();
  }

  /// Дней подряд с занятиями (хотя бы 1 минута).
  int learnStreak() {
    var d = today();
    if (secondsOn(dkey(d)) < 60) d = addDays(d, -1);
    var n = 0;
    while (n < 3650 && secondsOn(dkey(d)) >= 60) {
      n++;
      d = addDays(d, -1);
    }
    return n;
  }
}
