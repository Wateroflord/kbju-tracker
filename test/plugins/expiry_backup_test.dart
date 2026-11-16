import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/expiry/backup.dart';
import 'package:kbju_tracker/plugins/expiry/models.dart';

Item _item(String id, {String name = 'Вода', bool removed = false}) => Item(
      id: id,
      shelf: Shelf.water,
      name: name,
      barcode: '4600000000001',
      expiry: DateTime(2026, 12, 1),
      quantity: 3,
      removed: removed,
      createdAt: DateTime(2026, 11, 1),
    );

void main() {
  group('Дата', () {
    test('разные форматы ввода', () {
      expect(parseDate('12.11.26'), DateTime(2026, 11, 12));
      expect(parseDate('12.11.2026'), DateTime(2026, 11, 12));
      expect(parseDate('121126'), DateTime(2026, 11, 12));
      expect(parseDate('12112026'), DateTime(2026, 11, 12));
      expect(parseDate('12/11/26'), DateTime(2026, 11, 12));
      expect(parseDate('12.11')!.month, 11);
    });

    test('неправильные даты не принимаются', () {
      expect(parseDate('31.02.26'), isNull);
      expect(parseDate('13.13.26'), isNull);
      expect(parseDate(''), isNull);
      expect(parseDate('123'), isNull);
    });

    test('статус по дням', () {
      expect(statusText(-2), contains('ПРОСРОЧЕНО'));
      expect(statusText(0), 'сегодня последний день');
      expect(statusText(1), 'завтра последний день');
      expect(daysBetween(DateTime(2026, 11, 1, 23), DateTime(2026, 11, 2, 1)), 1);
    });
  });

  group('Резервная копия', () {
    test('сохраняется и читается без потерь', () {
      final b = Backup(
        items: [_item('a'), _item('b', name: 'Пиво', removed: true)],
        products: {'4600000000001': const ProductInfo(name: 'Вода', shelf: Shelf.water)},
        warnDays: 4,
        notifyHour: 8,
        notifyMinute: 30,
      );
      final back = Backup.parse(b.encode());
      expect(back.items.length, 2);
      expect(back.items[1].name, 'Пиво');
      expect(back.items[1].removed, isTrue);
      expect(back.items[0].quantity, 3);
      expect(back.items[0].expiry, DateTime(2026, 12, 1));
      expect(back.products['4600000000001']!.name, 'Вода');
      expect(back.warnDays, 4);
      expect(back.notifyHour, 8);
      expect(back.notifyMinute, 30);
    });

    test('чужой файл не принимается', () {
      expect(() => Backup.parse('привет'), throwsFormatException);
      expect(() => Backup.parse('{"app":"other"}'), throwsFormatException);
    });

    test('битые записи пропускаются, плохие настройки заменяются', () {
      final b = Backup.parse('{"app":"winter-expiry","items":[{"id":"x"},'
          '{"id":"ok","shelf":"beer","expiry":"2026-12-01T00:00:00.000"}],'
          '"settings":{"warnDays":99,"notifyHour":"7"}}');
      expect(b.items.map((e) => e.id), ['ok']);
      expect(b.items.single.shelf, Shelf.beer);
      expect(b.warnDays, 2);
      expect(b.notifyHour, 7);
    });

    test('слияние заменяет записи с тем же id', () {
      final merged = Backup.merge([_item('a'), _item('b')], [_item('b', name: 'Энергетик'), _item('c')]);
      expect(merged.length, 3);
      expect(merged.firstWhere((i) => i.id == 'b').name, 'Энергетик');
    });
  });
}
