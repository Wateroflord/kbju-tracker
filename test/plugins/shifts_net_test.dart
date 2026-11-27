import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/shifts/models.dart';

void main() {
  group('Смены: брутто → нетто (umowa zlecenie 2026)', () {
    test('26+: ZUS, здоровье и налог', () {
      final p = netFromGross(3000, PayMode.zlecenie);
      expect(p.social, closeTo(337.80, 0.001));
      expect(p.health, closeTo(239.60, 0.001));
      expect(p.pit, 256); // база 2130 × 12 % = 255,60 → до целых
      expect(p.net, closeTo(2166.60, 0.001));
    });

    test('до 26: налог 0', () {
      final p = netFromGross(3000, PayMode.zlecenieYoung);
      expect(p.pit, 0);
      expect(p.net, closeTo(2422.60, 0.001));
    });

    test('до 26: налог только с суммы выше годового лимита', () {
      final p = netFromGross(3000, PayMode.zlecenieYoung, ytdBefore: 85000);
      expect(p.pit, 211);
      expect(netFromGross(3000, PayMode.zlecenieYoung, ytdBefore: 90000).pit, netFromGross(3000, PayMode.zlecenie).pit);
    });

    test('больничный взнос и PIT-2', () {
      final p = netFromGross(3000, PayMode.zlecenie, sickness: true, pit2: true);
      expect(p.social, closeTo(411.30, 0.001));
      expect(p.pit, 0); // 2071 × 12 % = 248,52 минус 300 → не меньше нуля
      expect(netFromGross(5000, PayMode.zlecenie, pit2: true).pit, netFromGross(5000, PayMode.zlecenie).pit - 300);
    });

    test('студент, только брутто и свой процент', () {
      expect(netFromGross(2000, PayMode.student).net, 2000);
      expect(netFromGross(2000, PayMode.none).net, 2000);
      expect(netFromGross(2000, PayMode.custom, deductionPct: 25).net, 1500);
    });

    test('месяц учитывает заработок с начала года', () {
      final list = [
        for (var m = 1; m <= 11; m++) Shift(id: '$m', day: '2026-${m.toString().padLeft(2, '0')}-10', start: 0, end: 20 * 60, rate: 400),
      ];
      // 8000 брутто в месяц: к ноябрю лимит 85 528 уже превышен.
      final nov = summarize(list, 2026, 11, 0, 0, mode: PayMode.zlecenieYoung);
      expect(nov.brutto, 8000);
      expect(nov.pay.pit, greaterThan(0));
      expect(summarize(list, 2026, 3, 0, 0, mode: PayMode.zlecenieYoung).pay.pit, 0);
    });

    test('старые настройки: процент без режима → «свой %»', () {
      expect(payModeFrom(null, 20), PayMode.custom);
      expect(payModeFrom(null, 0), PayMode.none);
      expect(payModeFrom('zlecenieYoung', 0), PayMode.zlecenieYoung);
    });
  });
}
