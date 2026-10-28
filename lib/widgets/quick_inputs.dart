import 'package:flutter/material.dart';

import '../life/models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import 'common.dart';
import 'sheets.dart';
import '../i18n/i18n.dart';

/// Кольцо со значением в центре и подписью снизу.
class MiniRing extends StatelessWidget {
  final double ratio;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double size;

  const MiniRing({
    super.key,
    required this.ratio,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
    this.size = 66,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: RingPainter(progress: ratio, color: color, stroke: 6),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(value, style: Txt.num(13)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: Txt.small.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// Ввод шагов вручную.
Future<void> showStepsInput(BuildContext context, DateTime date) async {
  final store = StoreScope.read(context);
  final key = dkey(date);
  final ctrl = TextEditingController(text: '${store.life.stepsFor(key)}');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(trf('Шаги за {0}', [sameDay(date, DateTime.now()) ? tr('сегодня') : fmtDate(date)]), style: Txt.h2),
      content: NumField(ctrl, tr('Шаги'), suffix: tr('шагов')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(tr('Отмена'), style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(tr('Сохранить'), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  final v = parseNum(ctrl.text);
  WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
  if (ok == true && v != null) store.life.setSteps(key, v.round());
}

/// Быстрое добавление воды.
Future<void> showWaterSheet(BuildContext context, DateTime date) {
  final key = dkey(date);
  return showAppSheet(context, Builder(builder: (ctx) {
    final store = StoreScope.of(ctx);
    final ml = store.waterFor(key);
    final target = store.targetsFor(key).waterMl;
    Widget btn(String t, int d) => Expanded(
          child: GhostButton(t, color: AppColors.water, onPressed: () => store.addWater(key, d)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, color: AppColors.water, size: 20),
              const SizedBox(width: 8),
              Text(tr('Вода'), style: Txt.h2),
              const Spacer(),
              Text(fmtInt(ml), style: Txt.num(18, color: AppColors.water)),
              Text(trf(' / {0} мл', [fmtInt(target)]), style: Txt.small),
            ],
          ),
          const SizedBox(height: 12),
          ProgressLine(ratio: target > 0 ? ml / target : 0, color: AppColors.water, overIsBad: false),
          const SizedBox(height: 16),
          Row(children: [btn('−250', -250), const SizedBox(width: 8), btn('+250', 250), const SizedBox(width: 8), btn('+500', 500)]),
        ],
      ),
    );
  }));
}

/// Ввод сна: во сколько лёг и встал. Сон записывается на день пробуждения.
Future<void> showSleepInput(BuildContext context, DateTime wakeDay) async {
  final store = StoreScope.read(context);
  final key = dkey(wakeDay);
  final existing = store.life.sleepFor(key);
  var bed = existing != null
      ? TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(existing.bed))
      : const TimeOfDay(hour: 23, minute: 0);
  var wake = existing != null
      ? TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(existing.wake))
      : const TimeOfDay(hour: 7, minute: 0);

  String fmtT(TimeOfDay t) => '${two(t.hour)}:${two(t.minute)}';

  SleepEntry build() {
    final day = dayOnly(wakeDay);
    final w = DateTime(day.year, day.month, day.day, wake.hour, wake.minute);
    var b = DateTime(day.year, day.month, day.day, bed.hour, bed.minute);
    if (!b.isBefore(w)) b = addDays(b, -1);
    return SleepEntry(b.millisecondsSinceEpoch, w.millisecondsSinceEpoch);
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) {
        Future<void> pick(bool isBed) async {
          final t = await showTimePicker(
            context: ctx,
            initialTime: isBed ? bed : wake,
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
          );
          if (t == null) return;
          setD(() {
            if (isBed) {
              bed = t;
            } else {
              wake = t;
            }
          });
        }

        final hours = build().hours;
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            sameDay(wakeDay, DateTime.now()) ? tr('Сон прошлой ночью') : trf('Сон перед {0}', [fmtDate(wakeDay)]),
            style: Txt.h2,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: GhostButton(trf('Лёг в {0}', [fmtT(bed)]), icon: Icons.bedtime_outlined, onPressed: () => pick(true)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: GhostButton(trf('Встал в {0}', [fmtT(wake)]), icon: Icons.wb_sunny_outlined, onPressed: () => pick(false)),
              ),
              const SizedBox(height: 14),
              Text(trf('{0} ч', [fmt1(hours)]), style: Txt.num(28, color: hours >= 7 ? AppColors.good : AppColors.under)),
            ],
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () {
                  store.life.deleteSleep(key);
                  Navigator.pop(ctx, false);
                },
                child: Text(tr('Удалить'), style: TextStyle(color: AppColors.over)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('Отмена'), style: TextStyle(color: AppColors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('Сохранить'), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    ),
  );
  if (ok == true) {
    final e = build();
    if (e.hours > 0 && e.hours < 20) store.life.setSleep(key, e);
  }
}
