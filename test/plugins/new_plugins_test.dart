import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/focus/model.dart';
import 'package:kbju_tracker/plugins/guitar/chords.dart';
import 'package:kbju_tracker/plugins/guitar/pitch.dart';
import 'package:kbju_tracker/plugins/guitar/sound.dart';
import 'package:kbju_tracker/plugins/shifts/models.dart';

Float64List _tone(double hz, {int rate = 22050, int n = 2048}) => Float64List.fromList([
      for (var i = 0; i < n; i++)
        // Как у гитары: основной тон слабее обертонов.
        0.15 * math.sin(2 * math.pi * hz * i / rate) +
            0.3 * math.sin(2 * math.pi * 2 * hz * i / rate + 0.3) +
            0.2 * math.sin(2 * math.pi * 3 * hz * i / rate + 1),
    ]);

void main() {
  group('Winter Guitar', () {
    test('тюнер узнаёт все струны стандартного строя точнее 2 центов', () {
      for (final midi in tunings.first.midi) {
        final hz = hzOfMidi(midi);
        final got = detectPitch(_tone(hz), 22050)!;
        expect(centsOff(got, midi).abs(), lessThan(2), reason: noteName(midi));
        expect(nearestString(tunings.first, got), tunings.first.midi.indexOf(midi));
      }
    });

    test('тишина — без ноты', () {
      expect(detectPitch(Float64List(2048), 22050), isNull);
    });

    test('названия нот', () {
      expect(noteName(40), 'E2');
      expect(noteName(69), 'A4');
      expect(noteName(61), 'C#4');
      expect(hzOfMidi(69), 440);
    });

    test('аккорды: 6 струн, пальцы на зажатых ладах, имена не повторяются', () {
      final names = <String>{};
      for (final c in allChords) {
        expect(names.add(c.name), isTrue, reason: c.name);
        expect(c.frets.length, 6, reason: c.name);
        expect(c.fingers.length, 6, reason: c.name);
        for (var s = 0; s < 6; s++) {
          if (c.frets[s] > 0) expect(c.fingers[s], inInclusiveRange(1, 4), reason: '${c.name} струна $s');
          if (c.frets[s] <= 0) expect(c.fingers[s], 0, reason: '${c.name} струна $s');
        }
        expect(c.maxFret - c.baseFret, lessThan(5), reason: '${c.name} влезает в 5 ладов');
      }
      expect(chordByName('Am')!.frets, [-1, 0, 2, 2, 1, 0]);
    });

    test('метроном: целое число отсчётов на долю, файл из целых тактов', () {
      expect(samplesPerBeat(120), 11025);
      final wav = metronomeWav(120, 4, minSeconds: 3);
      final samples = (wav.length - 44) ~/ 2;
      expect(samples % (11025 * 4), 0);
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    });
  });

  group('Смены и зарплата', () {
    test('часы и деньги: перерыв и смена через полночь', () {
      const day = Shift(id: '1', day: '2026-11-26', start: 6 * 60, end: 14 * 60, breakMin: 30);
      expect(day.minutes, 450);
      expect(day.pay(30), 225);
      const night = Shift(id: '2', day: '2026-11-26', start: 22 * 60, end: 6 * 60);
      expect(night.minutes, 480);
      expect(night.endsAt, DateTime(2026, 11, 27, 6));
      const own = Shift(id: '3', day: '2026-11-26', start: 0, end: 60, rate: 50);
      expect(own.pay(30), 50);
    });

    test('итог месяца и вычеты', () {
      final list = [
        const Shift(id: 'a', day: '2026-11-03', start: 360, end: 840),
        const Shift(id: 'b', day: '2026-11-04', start: 360, end: 840),
        const Shift(id: 'c', day: '2026-12-01', start: 360, end: 840),
      ];
      final s = summarize(list, 2026, 11, 30.5, 20);
      expect(s.shifts, 2);
      expect(s.minutes, 960);
      expect(s.brutto, closeTo(488, 0.001));
      expect(s.netto, closeTo(390.4, 0.001));
    });

    test('ближайшая смена и сохранение', () {
      final list = [
        const Shift(id: 'old', day: '2026-11-20', start: 360, end: 840),
        const Shift(id: 'now', day: '2026-11-26', start: 360, end: 840),
        const Shift(id: 'next', day: '2026-11-28', start: 360, end: 840),
      ];
      expect(nextShift(list, DateTime(2026, 11, 26, 10))!.id, 'now');
      expect(nextShift(list, DateTime(2026, 11, 26, 15))!.id, 'next');
      final back = Shift.fromJson(list[1].copyWith(breakMin: 15, note: 'касса').toJson())!;
      expect(back.breakMin, 15);
      expect(back.note, 'касса');
      expect(Shift.fromJson({'day': 'вчера'}), isNull);
    });

    test('форматирование', () {
      expect(money(1234.5), '1 234,50');
      expect(money(0), '0,00');
      expect(hm(6 * 60 + 5), '6:05');
      expect(hoursText(450), '7 ч 30 мин');
      expect(untilText(DateTime(2026, 11, 27, 6), DateTime(2026, 11, 26, 23)), 'через 7 ч');
      expect(untilText(DateTime(2026, 11, 28, 6), DateTime(2026, 11, 26, 8)), 'через 2 дн.');
    });
  });

  group('Фокус', () {
    test('после 4-го помидора — длинный перерыв', () {
      expect(nextPhase(Phase.work, 1, 4), Phase.shortBreak);
      expect(nextPhase(Phase.work, 4, 4), Phase.longBreak);
      expect(nextPhase(Phase.shortBreak, 2, 4), Phase.work);
      expect(nextPhase(Phase.longBreak, 0, 4), Phase.work);
    });

    test('статистика по дням, проектам и серия', () {
      const logs = [
        FocusLog('2026-11-24', 'game', 50),
        FocusLog('2026-11-25', 'game', 25),
        FocusLog('2026-11-25', 'study', 25),
        FocusLog('2026-11-26', 'game', 25),
        FocusLog('2026-11-10', 'game', 100),
      ];
      final byDay = minutesByDay(logs);
      expect(byDay['2026-11-25'], 50);
      expect(minutesByProject(logs, '2026-11-20', '2026-11-26'), {'game': 100, 'study': 25});
      expect(focusStreak(byDay, DateTime(2026, 11, 26)), 3);
      expect(focusStreak(byDay, DateTime(2026, 11, 27)), 3); // сегодня ещё не начинал — серия жива
      expect(focusStreak(byDay, DateTime(2026, 11, 29)), 0);
      expect(durText(85), '1 ч 25 мин');
    });

    test('настройки не ломаются от мусора', () {
      final s = FocusSettings.fromJson({'w': 0, 's': 'x', 'l': 999});
      expect(s.work, 1);
      expect(s.shortBreak, 5);
      expect(s.longBreak, 90);
      expect(FocusSettings.fromJson(null).work, 25);
    });
  });
}
