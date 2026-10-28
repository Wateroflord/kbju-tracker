import 'package:flutter/material.dart';

import '../life/models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/quick_inputs.dart';
import 'reminders_screen.dart';
import '../i18n/i18n.dart';

class SleepScreen extends StatelessWidget {
  const SleepScreen({super.key});

  String _time(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final life = store.life;
    final now = today();
    final last = life.sleepFor(dkey(now));
    final sleeping = life.sleepStartedAt > 0;

    final bars = <BarDatum>[];
    var sum = 0.0, cnt = 0;
    for (var i = 6; i >= 0; i--) {
      final d = addDays(now, -i);
      final e = life.sleepFor(dkey(d));
      final h = e?.hours ?? 0;
      if (e != null) {
        sum += h;
        cnt++;
      }
      bars.add(BarDatum(d, h, life.sleepGoal, h >= 7 ? AppColors.good : AppColors.under));
    }

    // Средний час отбоя за 14 дней (для совета ложиться в одно время).
    final beds = <int>[];
    for (var i = 0; i < 14; i++) {
      final e = life.sleepFor(dkey(addDays(now, -i)));
      if (e == null) continue;
      final b = DateTime.fromMillisecondsSinceEpoch(e.bed);
      var m = b.hour * 60 + b.minute;
      if (m < 12 * 60) m += 24 * 60;
      beds.add(m);
    }
    String? bedAvg;
    int? spread;
    if (beds.length >= 3) {
      final avg = beds.reduce((a, b) => a + b) ~/ beds.length;
      final mm = avg % (24 * 60);
      bedAvg = '${two(mm ~/ 60)}:${two(mm % 60)}';
      beds.sort();
      spread = beds.last - beds.first;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Сон')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('ПРОШЛОЙ НОЧЬЮ'), style: Txt.label),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(last == null ? '—' : fmt1(last.hours),
                        style: Txt.num(34, color: last == null ? AppColors.muted : (last.hours >= 7 ? AppColors.good : AppColors.under))),
                    Text(tr('  ч'), style: Txt.small),
                    const Spacer(),
                    if (last != null) Text('${_time(last.bed)} → ${_time(last.wake)}', style: Txt.num(14, color: AppColors.accent2)),
                  ],
                ),
                const SizedBox(height: 10),
                ProgressLine(ratio: last == null ? 0 : last.hours / life.sleepGoal, color: AppColors.carbs, overIsBad: false),
                const SizedBox(height: 14),
                if (sleeping)
                  PrimaryButton(tr('Я проснулся'), icon: Icons.wb_sunny_outlined, onPressed: () {
                    final e = life.finishSleep();
                    if (e != null) showToast(context, trf('Записано: {0} ч сна', [fmt1(e.hours)]));
                  })
                else
                  PrimaryButton(tr('Ложусь спать'), icon: Icons.bedtime_outlined, onPressed: () {
                    life.startSleep();
                    showToast(context, tr('Спокойной ночи! Утром нажми «Я проснулся»'));
                  }),
                if (sleeping) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(child: Text(trf('Лёг в {0}', [_time(life.sleepStartedAt)]), style: Txt.small)),
                      TextButton(
                        onPressed: life.cancelSleep,
                        child: Text(tr('Отменить'), style: TextStyle(color: AppColors.muted)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                GhostButton(tr('Ввести время вручную'), icon: Icons.edit_outlined, onPressed: () => showSleepInput(context, now)),
              ],
            ),
          ),
          SectionLabel(tr('Неделя'), trailing: Text(trf('цель {0} ч', [fmt1(life.sleepGoal)]), style: Txt.small)),
          AppCard(
            child: Column(
              children: [
                BarChart(data: bars, height: 150),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatTile(label: tr('В среднем'), value: cnt > 0 ? trf('{0} ч', [fmt1(sum / cnt)]) : '—', sub: trf('за {0} ноч.', [cnt]))),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile(label: tr('Средний отбой'), value: bedAvg ?? '—', sub: spread == null ? tr('нужно 3+ ночи') : trf('разброс {0} ч {1} мин', [spread ~/ 60, spread % 60]))),
                  ],
                ),
              ],
            ),
          ),
          if (spread != null && spread > 60) ...[
            const SizedBox(height: 10),
            AppCard(
              borderColor: AppColors.under.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: AppColors.under, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(tr('Время отбоя гуляет больше чем на час. Попробуй ложиться в одно время — включи напоминание «Пора спать».'), style: Txt.small),
                  ),
                ],
              ),
            ),
          ],
          SectionLabel(tr('Настройки')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.flag_outlined, color: AppColors.muted),
                  title: Text(tr('Цель сна'), style: Txt.body),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => life.setSleepGoal(life.sleepGoal - 0.5),
                        icon: const Icon(Icons.remove, size: 18),
                      ),
                      Text(trf('{0} ч', [fmt1(life.sleepGoal)]), style: Txt.num(14)),
                      IconButton(
                        onPressed: () => life.setSleepGoal(life.sleepGoal + 0.5),
                        icon: const Icon(Icons.add, size: 18),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_none, color: AppColors.muted),
                  title: Text(tr('Напоминание ложиться спать'), style: Txt.body),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RemindersScreen())),
                ),
              ],
            ),
          ),
          SectionLabel(tr('Последние ночи')),
          for (var i = 0; i < 14; i++) _row(context, life.sleepFor(dkey(addDays(now, -i))), addDays(now, -i)),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, SleepEntry? e, DateTime d) {
    return InkWell(
      onTap: () => showSleepInput(context, d),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Dot(e == null ? AppColors.border : (e.hours >= 7 ? AppColors.good : AppColors.under), size: 7),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sameDay(d, DateTime.now()) ? tr('Сегодня') : '${weekdaysShort[d.weekday - 1]}, ${fmtDate(d)}',
                style: Txt.body.copyWith(fontSize: 13),
              ),
            ),
            if (e != null) ...[
              Text('${_time(e.bed)}–${_time(e.wake)}  ', style: Txt.small),
              Text(trf('{0} ч', [fmt1(e.hours)]), style: Txt.num(14)),
            ] else
              Text(tr('нет записи'), style: Txt.small),
          ],
        ),
      ),
    );
  }
}
