import '../util.dart';

/// Состояние карточки слова (интервальное повторение по системе Лейтнера).
/// box 0 — ещё не запомнено, 1…6 — интервал растёт: 1, 2, 4, 8, 16, 30 дней.
class CardState {
  final int box;
  final String due; // ключ дня, когда повторить
  final int right;
  final int wrong;

  const CardState({this.box = 0, required this.due, this.right = 0, this.wrong = 0});

  static const boxDays = [0, 1, 2, 4, 8, 16, 30];

  bool get known => box >= 3;

  CardState answer(bool ok) {
    final nb = ok ? (box + 1).clamp(1, 6).toInt() : 0;
    return CardState(
      box: nb,
      due: dkey(addDays(today(), boxDays[nb])),
      right: right + (ok ? 1 : 0),
      wrong: wrong + (ok ? 0 : 1),
    );
  }

  static CardState first(bool ok) => CardState(due: todayKey()).answer(ok);

  Map<String, dynamic> toJson() => {'b': box, 'd': due, 'r': right, 'w': wrong};

  factory CardState.fromJson(Map<String, dynamic> j) => CardState(
        box: asInt(j['b']).clamp(0, 6).toInt(),
        due: j['d']?.toString() ?? todayKey(),
        right: asInt(j['r']),
        wrong: asInt(j['w']),
      );
}
