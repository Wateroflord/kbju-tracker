import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/language/learn/dialogues.dart';
import 'package:kbju_tracker/plugins/language/learn/learn_logic.dart';
import 'package:kbju_tracker/learn/srs.dart';
import 'package:kbju_tracker/learn/words.dart';
import 'package:kbju_tracker/plugins/language/life/life_store.dart';
import 'package:kbju_tracker/plugins/language/store.dart';
import 'package:kbju_tracker/util.dart';

void main() {
  group('Словарь', () {
    test('у слов уникальные id, у всех есть тема и переводы', () {
      final ids = <String>{};
      final topicIds = {for (final t in topics) t.id};
      for (final w in words) {
        expect(ids.add(w.id), isTrue, reason: 'повтор ${w.id}');
        expect(topicIds, contains(w.topic), reason: w.id);
        for (final l in const ['en', 'pl', 'de', 'ru', 'uk']) {
          expect(w.inLang(l).trim(), isNotEmpty, reason: '${w.id} [$l]');
        }
      }
      for (final t in topics) {
        expect(wordsOf(t.id), isNotEmpty, reason: t.id);
      }
    });

    test('в диалогах все реплики переведены', () {
      expect(dialogues, isNotEmpty);
      for (final d in dialogues) {
        for (final line in d.lines) {
          for (final l in const ['en', 'pl', 'de', 'ru', 'uk']) {
            expect(line.t.inLang(l).trim(), isNotEmpty, reason: '${d.id} [$l]');
          }
        }
      }
    });
  });

  group('Интервальное повторение', () {
    test('правильный ответ увеличивает интервал, ошибка сбрасывает', () {
      var c = CardState.first(true);
      expect(c.box, 1);
      expect(c.due, dkey(addDays(today(), 1)));
      c = c.answer(true).answer(true);
      expect(c.box, 3);
      expect(c.known, isTrue);
      c = c.answer(false);
      expect(c.box, 0);
      expect(c.known, isFalse);
      expect(c.right, 3);
      expect(c.wrong, 1);
      for (var i = 0; i < 10; i++) {
        c = c.answer(true);
      }
      expect(c.box, 6);
      expect(c.due, dkey(addDays(today(), 30)));
    });

    test('карточка сохраняется и читается', () {
      final c = CardState.first(true).answer(true);
      final back = CardState.fromJson(c.toJson());
      expect([back.box, back.due, back.right, back.wrong], [c.box, c.due, c.right, c.wrong]);
    });
  });

  group('Прогресс', () {
    test('ответы, минуты и серия дней', () {
      final life = LifeStore(() {});
      final w = words.first;
      life.recordAnswer('en', w, true);
      expect(life.seenCount('en'), 1);
      expect(life.knownCount('en'), 0);
      expect(life.newWords('en', 3).map((e) => e.id), isNot(contains(w.id)));
      life.addLearnSeconds('en', 90);
      life.addLearnSeconds('pl', 30);
      expect(life.minutesToday(), 2);
      expect(life.totalSeconds('en'), 90);
      expect(life.learnStreak(), 1);
      life.setLearnGoal(500);
      expect(life.learnGoalMin, 180);
    });
  });

  group('Перенос из КБЖУ Трекера', () {
    Map<String, dynamic> kbjuBackup() => {
          'entries': [],
          'profile': {'weight': 80},
          'life': {
            'learnLang': 'pl',
            'learnGoalMin': 30,
            'learnCards': {
              'pl': {
                words[0].id: {'b': 4, 'd': '2026-11-20', 'r': 5, 'w': 1},
                words[1].id: {'b': 1, 'd': '2026-11-07', 'r': 1, 'w': 0},
              },
            },
            'learnSeconds': {
              'pl': {'2026-11-01': 1200, '2026-11-02': 600},
            },
            'learnGoalText': {'pl': 'объясниться в аптеке'},
            'habits': [],
          },
        };

    test('полная копия КБЖУ переносится, лишние данные не мешают', () {
      final s = AppStore();
      expect(s.importJson(jsonEncode(kbjuBackup())), isNull);
      expect(s.life.learnLang, 'pl');
      expect(s.life.learnGoalMin, 30);
      expect(s.life.seenCount('pl'), 2);
      expect(s.life.knownCount('pl'), 1);
      expect(s.life.totalSeconds('pl'), 1800);
      expect(s.life.learnGoalText['pl'], 'объясниться в аптеке');
      expect(s.importOffered, isTrue);
    });

    test('перенос не затирает то, что уже выучено здесь', () {
      final s = AppStore();
      s.life.recordAnswer('pl', words[1], true);
      s.life.recordAnswer('pl', words[1], true);
      s.life.recordAnswer('pl', words[1], true);
      s.life.recordAnswer('en', words[2], true);
      s.life.learnSeconds['pl'] = {'2026-11-02': 900};
      expect(s.importJson(jsonEncode(kbjuBackup())), isNull);
      expect(s.life.cardOf('pl', words[1])!.right, 3); // здесь ответов больше — оставили своё
      expect(s.life.cardOf('pl', words[0])!.box, 4); // из КБЖУ
      expect(s.life.seenCount('en'), 1);
      expect(s.life.learnSeconds['pl']!['2026-11-02'], 900);
      expect(s.life.learnSeconds['pl']!['2026-11-01'], 1200);
    });

    test('свой файл копии восстанавливается целиком', () {
      final a = AppStore();
      a.life.recordAnswer('de', words[3], true);
      a.life.setLearnLang('de');
      final b = AppStore();
      b.life.recordAnswer('en', words[4], true);
      expect(b.importJson(a.exportJson()), isNull);
      expect(b.life.learnLang, 'de');
      expect(b.life.seenCount('de'), 1);
      expect(b.life.seenCount('en'), 0);
    });

    test('чужие файлы не принимаются', () {
      final s = AppStore();
      expect(s.importJson('не json'), isNotNull);
      expect(s.importJson('{"entries":[],"profile":{}}'), isNotNull);
      expect(s.life.seenTotal(), 0);
    });
  });
}
