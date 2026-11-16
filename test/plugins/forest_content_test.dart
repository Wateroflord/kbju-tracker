import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/forest/content.dart';

void main() {
  test('у статей уникальные id и существующие разделы', () {
    final cats = {for (final c in categories) c.id};
    final ids = <String>{};
    for (final a in articles) {
      expect(ids.add(a.id), isTrue, reason: 'повтор id ${a.id}');
      expect(cats, contains(a.cat), reason: 'статья ${a.id}: нет раздела ${a.cat}');
      expect(a.title.trim(), isNotEmpty, reason: a.id);
      expect(a.blocks, isNotEmpty, reason: a.id);
    }
  });

  test('в каждом разделе есть статьи', () {
    for (final c in categories) {
      expect(articles.where((a) => a.cat == c.id), isNotEmpty, reason: c.title);
    }
  });

  test('блоки статей только известных типов и не пустые', () {
    const kinds = {'h', 'p', 'li', 'n', 'w', 't'};
    for (final a in articles) {
      for (final (k, text) in a.blocks) {
        expect(kinds, contains(k), reason: '${a.id}: тип блока «$k»');
        expect(text.trim(), isNotEmpty, reason: '${a.id}: пустой блок');
      }
    }
  });

  test('в тесте правильный ответ существует', () {
    expect(quiz, isNotEmpty);
    for (final (q, options, correct, why) in quiz) {
      expect(options.length, greaterThanOrEqualTo(2), reason: q);
      expect(correct, inInclusiveRange(0, options.length - 1), reason: q);
      expect(why.trim(), isNotEmpty, reason: q);
      expect(options.toSet().length, options.length, reason: 'повтор вариантов: $q');
    }
  });

  test('номер экстренной службы — 112', () {
    final text = articles.expand((a) => a.blocks).map((b) => b.$2).join(' ');
    expect(text, contains('112'));
    expect(kitItems, isNotEmpty);
  });
}
