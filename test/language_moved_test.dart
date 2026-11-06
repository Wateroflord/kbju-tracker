import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/learn/learn_logic.dart';
import 'package:kbju_tracker/learn/words.dart';
import 'package:kbju_tracker/screens/language_moved_screen.dart';
import 'package:kbju_tracker/store.dart';

void main() {
  test('файл прогресса для Winter Language: только учёба, без данных о питании и здоровье', () {
    final s = AppStore();
    s.life.recordAnswer('pl', words.first, true);
    s.life.addLearnSeconds('pl', 600);
    s.life.setLearnLang('pl');
    final j = jsonDecode(LanguageMovedScreen.progressJson(s)) as Map;
    final life = j['life'] as Map;
    expect(life['learnLang'], 'pl');
    expect((life['learnCards'] as Map)['pl'], contains(words.first.id));
    expect(life.keys.every((k) => '$k'.startsWith('learn')), isTrue);
    expect(j.containsKey('entries'), isFalse);
    expect(j.containsKey('profile'), isFalse);
  });

  test('привычки и напоминания про язык больше не создаются', () {
    final s = AppStore();
    expect(s.life.habits.any((h) => h.id == 'learn'), isFalse);
    expect(s.life.reminders.containsKey('learn'), isFalse);
  });
}
