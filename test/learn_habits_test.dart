import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/store.dart';

void main() {
  test('привычки и напоминания про язык больше не создаются (языки — в плагине Winter Language)', () {
    final s = AppStore();
    expect(s.life.habits.any((h) => h.id == 'learn'), isFalse);
    expect(s.life.reminders.containsKey('learn'), isFalse);
  });
}
