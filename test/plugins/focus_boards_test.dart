import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/focus/boards_model.dart';

void main() {
  group('Фокус: общие доски', () {
    test('доска из ответа сервера', () {
      final b = SharedBoard.fromJson({
        'id': 'b1',
        'name': 'FalseMemory',
        'owner': 'u1',
        'color': 2,
        'members': ['u1', 'u2'],
        'expand': {
          'owner': {'id': 'u1', 'name': 'Стас', 'username': 'stas'},
          'members': [
            {'id': 'u1', 'name': 'Стас', 'username': 'stas'},
            {'id': 'u2', 'name': '', 'username': 'sm1le'},
          ],
        },
      });
      expect(b.isOwner('u1'), isTrue);
      expect(b.nameOf('u2'), 'sm1le');
      expect(b.othersText('u1'), 'С тобой: sm1le');
      expect(b.othersText('u2'), 'С тобой: Стас');
      expect(SharedBoard.fromJson({'id': 'x', 'members': ['me']}).othersText('me'), 'Пока только ты');
    });

    test('колонки, порядок и следующий шаг', () {
      final tasks = [
        BoardTask.fromJson({'id': '1', 'title': 'Меню', 'status': 'todo', 'sort': 2}),
        BoardTask.fromJson({'id': '2', 'title': 'Враги', 'status': 'todo', 'sort': 1}),
        BoardTask.fromJson({'id': '3', 'title': 'Звук', 'status': 'done', 'assignee': 'u2'}),
        BoardTask.fromJson({'id': '4', 'title': 'Странный статус', 'status': 'lol'}),
      ];
      expect(column(tasks, 'todo').map((t) => t.id), ['4', '2', '1']);
      expect(column(tasks, 'done').single.title, 'Звук');
      expect(nextStatus('todo'), 'doing');
      expect(nextStatus('doing'), 'done');
      expect(nextStatus('done'), 'todo');
      expect(doneBy(tasks), {'u2': 1});
      expect(statusTitle('doing'), 'В работе');
    });

    test('фильтр PocketBase экранирует кавычки', () {
      expect(pbQuote('abc'), "'abc'");
      expect(pbQuote("a'b"), r"'a\'b'");
    });
  });
}
