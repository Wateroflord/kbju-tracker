import 'package:flutter/material.dart';

import '../life/models.dart';
import '../life/notifications.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';

class RemindersScreen extends StatelessWidget {
  const RemindersScreen({super.key});

  IconData _icon(String id) => switch (id) {
        'water' => Icons.water_drop_outlined,
        'care_am' => Icons.wb_sunny_outlined,
        'care_pm' => Icons.nightlight_outlined,
        'workout' => Icons.fitness_center,
        'bedtime' => Icons.bedtime_outlined,
        'weigh' => Icons.monitor_weight_outlined,
        _ => Icons.notifications_none,
      };

  Future<void> _toggle(BuildContext context, Reminder r, bool v) async {
    final store = StoreScope.read(context);
    if (v) {
      final ok = await NotificationService.instance.requestPermission();
      if (!ok) {
        if (context.mounted) showToast(context, 'Разреши уведомления в настройках Android');
        return;
      }
    }
    store.life.updateReminder(r.copyWith(enabled: v));
    await NotificationService.instance.sync(store);
  }

  Future<void> _pickTime(BuildContext context, Reminder r) async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: r.hour, minute: r.minute),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null || !context.mounted) return;
    final store = StoreScope.read(context);
    store.life.updateReminder(r.copyWith(hour: t.hour, minute: t.minute));
    await NotificationService.instance.sync(store);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.life.reminderList;
    final trainDays = store.life.weekdaysOf(store.life.activeProgram);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar('Напоминания'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 56, color: AppColors.border),
                  _row(context, list[i], trainDays),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Нажми на время, чтобы изменить его. Напоминание о тренировке приходит в дни '
            'выбранной программы. Если уведомления не приходят, проверь, что для приложения '
            'не включена экономия батареи.',
            style: Txt.small,
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, Reminder r, List<int> trainDays) {
    final days = r.fromProgram ? trainDays : r.weekdays;
    final when = days.isEmpty ? 'каждый день' : days.map((d) => weekdaysShort[d - 1]).join(', ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          Icon(_icon(r.id), size: 20, color: r.enabled ? AppColors.accent : AppColors.muted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.title, style: Txt.body.copyWith(fontWeight: FontWeight.w500)),
                Text('$when · ${r.body}', style: Txt.small.copyWith(fontSize: 11.5), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _pickTime(context, r),
            child: Text('${two(r.hour)}:${two(r.minute)}',
                style: Txt.num(15, color: r.enabled ? AppColors.text : AppColors.muted)),
          ),
          Switch(value: r.enabled, onChanged: (v) => _toggle(context, r, v)),
        ],
      ),
    );
  }
}
