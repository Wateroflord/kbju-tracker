import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/mog/models.dart';

void main() {
  test('оценка фото: числа строкой, с запятой, за пределами 0–10', () {
    final r = SoloResult.fromJson({
      'overall': '7,46',
      'potential': 14,
      'summary': '  Хорошо  ',
      'categories': [
        {'name': 'Кожа', 'score': -3, 'comment': 'x'},
        {'name': '', 'score': 5},
        'мусор',
      ],
      'strengths': ['Улыбка', '', null],
      'tips': [
        {'title': 'Стрижка', 'text': 'Короче по бокам', 'impact': 'HIGH'},
        {'title': 'Свет', 'impact': 'огромный'},
        {'title': '', 'text': ''},
      ],
    });
    expect(r.overall, 7.5);
    expect(r.potential, 10);
    expect(r.summary, 'Хорошо');
    expect(r.categories.single.name, 'Кожа');
    expect(r.categories.single.score, 0);
    expect(r.strengths, ['Улыбка']);
    expect(r.tips.length, 2);
    expect(r.tips[0].impact, 'high');
    expect(r.tips[1].impact, 'medium');
  });

  test('оценка сохраняется и читается без потерь', () {
    final r = SoloResult.fromJson({'overall': 6.3, 'summary': 's', 'weaknesses': ['a'], 'photoNote': 'n'});
    final back = SoloResult.fromJson(r.toJson());
    expect(back.overall, 6.3);
    expect(back.potential, isNull);
    expect(back.weaknesses, ['a']);
    expect(back.photoNote, 'n');
  });

  test('батл: победитель считается сам, если ИИ его не указал', () {
    final r = BattleResult.fromJson({
      'a': {'overall': 6, 'summary': 'A'},
      'b': {'overall': 8.2},
      'winner': '???',
      'categories': [
        {'name': 'Стиль', 'a': 5, 'b': 5.02},
        {'name': 'Лицо', 'a': 9, 'b': 4},
        {'name': 'Обувь', 'a': 3, 'b': 7, 'winner': 'B'},
      ],
    });
    expect(r.winner, 'b');
    expect(r.aSummary, 'A');
    expect(r.categories.map((c) => c.winner), ['draw', 'a', 'b']);
  });

  test('уровни по оценке', () {
    expect(tierName(9.5), 'Легенда');
    expect(tierName(8), 'Топ');
    expect(tierName(5.5), 'Средний уровень');
    expect(tierName(1), 'Много точек роста');
    expect(fmtScore(null), '—');
    expect(fmtScore(7), '7.0');
  });
}
