import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../life/life_store.dart';
import '../life/steps_service.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/quick_inputs.dart';
import '../i18n/i18n.dart';

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  int range = 7;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final s = StoreScope.read(context);
    if (s.life.stepSource == 'health') _refresh();
  }

  Future<void> _refresh() async {
    setState(() => busy = true);
    await StepsService.instance.syncHealth();
    if (mounted) setState(() => busy = false);
  }

  Future<void> _connect(Future<String?> Function() f) async {
    setState(() => busy = true);
    final err = await f();
    if (!mounted) return;
    setState(() => busy = false);
    showToast(context, err ?? tr('Подключено'));
  }

  Future<void> _askSensor() async {
    final ok = await confirm(
      context,
      tr('Разрешение на активность'),
      tr('Шагомер будет считать шаги в фоне, даже когда приложение закрыто. Android попросит доступ к «Физической активности» и к уведомлениям — в шторке будет тихое уведомление с шагами за сегодня. Данные остаются только на телефоне.'),
      ok: tr('Продолжить'),
    );
    if (ok) await _connect(StepsService.instance.connectSensor);
  }

  Future<void> _editGoal(AppStore store) async {
    final ctrl = TextEditingController(text: '${store.life.stepGoal}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(tr('Цель по шагам'), style: Txt.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NumField(ctrl, tr('Шагов в день'), suffix: tr('шагов')),
            const SizedBox(height: 8),
            Text(tr('8 км ≈ 10 500 шагов'), style: Txt.small),
          ],
        ),
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
    if (ok == true && v != null) store.life.setStepGoal(v.round());
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final life = store.life;
    final now = today();
    final steps = life.stepsFor(dkey(now));
    final goal = life.stepGoal;
    final km = LifeStore.stepsToKm(steps);
    final mins = LifeStore.stepsToMinutes(steps);

    final bars = <BarDatum>[];
    var sum = 0, cnt = 0, hit = 0;
    for (var i = range - 1; i >= 0; i--) {
      final d = addDays(now, -i);
      final v = life.stepsFor(dkey(d));
      if (v > 0) {
        sum += v;
        cnt++;
        if (v >= goal) hit++;
      }
      bars.add(BarDatum(d, v.toDouble(), goal.toDouble(), v >= goal ? AppColors.good : AppColors.under));
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Шаги'), actions: [
        if (life.stepSource == 'health')
          IconButton(
            onPressed: busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: tr('Обновить из Health Connect'),
          ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CustomPaint(
                    painter: RingPainter(progress: steps / goal, color: AppColors.good, stroke: 10),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(fmtInt(steps), style: Txt.num(24)),
                          Text(trf('из {0}', [fmtInt(goal)]), style: Txt.small),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('ДИСТАНЦИЯ'), style: Txt.label),
                      const SizedBox(height: 3),
                      Text(trf('{0} км', [fmt1(km)]), style: Txt.num(20)),
                      const SizedBox(height: 10),
                      Text(tr('ВРЕМЯ ХОДЬБЫ'), style: Txt.label),
                      const SizedBox(height: 3),
                      Text(trf('{0} мин', [mins]), style: Txt.num(20)),
                      const SizedBox(height: 10),
                      Text(
                        steps >= goal ? tr('Цель выполнена') : trf('Осталось {0}', [fmtInt(math.max(0, goal - steps))]),
                        style: Txt.small.copyWith(color: steps >= goal ? AppColors.good : AppColors.accent2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GhostButton(tr('Ввести вручную'), icon: Icons.edit_outlined, onPressed: () => showStepsInput(context, now)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton(tr('Цель'), icon: Icons.flag_outlined, onPressed: () => _editGoal(store)),
              ),
            ],
          ),
          SectionLabel(tr('Источник шагов')),
          _sourceCard(life),
          ValueListenableBuilder<String>(
            valueListenable: StepsService.instance.status,
            builder: (_, msg, __) => msg.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(msg, style: Txt.small.copyWith(color: AppColors.under)),
                  ),
          ),
          SectionLabel(tr('История'), trailing: SizedBox(
            width: 150,
            child: Segmented<int>(
              values: const [7, 30],
              label: (v) => trf('{0} дн.', [v]),
              selected: range,
              onChanged: (v) => setState(() => range = v),
            ),
          )),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BarChart(data: bars, height: 160),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatTile(label: tr('В среднем'), value: cnt > 0 ? fmtInt(sum / cnt) : '—', sub: tr('шагов в день'))),
                    const SizedBox(width: 8),
                    Expanded(child: StatTile(label: tr('Цель выполнена'), value: '$hit', sub: trf('из {0} дн.', [range]), color: AppColors.good)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('Нажми на день в истории ниже, чтобы поправить шаги вручную.'),
            style: Txt.small,
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < math.min(range, 14); i++) _dayRow(life, addDays(now, -i), goal),
        ],
      ),
    );
  }

  Widget _dayRow(LifeStore life, DateTime d, int goal) {
    final v = life.stepsFor(dkey(d));
    return InkWell(
      onTap: () => showStepsInput(context, d),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Dot(v >= goal ? AppColors.good : (v > 0 ? AppColors.under : AppColors.border), size: 7),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sameDay(d, DateTime.now()) ? tr('Сегодня') : '${weekdaysShort[d.weekday - 1]}, ${fmtDate(d)}',
                style: Txt.body.copyWith(fontSize: 13),
              ),
            ),
            Text(fmtInt(v), style: Txt.num(14)),
            Text(trf('  {0} км', [fmt1(LifeStore.stepsToKm(v))]), style: Txt.small),
          ],
        ),
      ),
    );
  }

  Widget _sourceCard(LifeStore life) {
    final src = life.stepSource;
    Widget option(String id, IconData icon, String title, String desc, VoidCallback onTap) {
      final sel = src == id;
      return OptionTile(icon: icon, title: title, desc: desc, selected: sel, onTap: busy ? () {} : onTap);
    }

    return Column(
      children: [
        option('sensor', Icons.directions_walk, tr('Шагомер телефона — рекомендуем'),
            tr('Считает сам, когда ходишь с телефоном, даже если приложение закрыто и после перезагрузки.'),
            _askSensor),
        option('health', Icons.favorite_border, 'Health Connect',
            tr('Если носишь часы или браслет: берёт шаги из Google Fit, Samsung Health, Mi Fitness.'),
            () => _connect(StepsService.instance.connectHealth)),
        option('manual', Icons.edit_outlined, tr('Вручную'), tr('Вводишь шаги сам, например с часов.'),
            () => StepsService.instance.useManual()),
        if (src == 'sensor') const _BatteryHint(),
        if (src != 'health')
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => StepsService.instance.installHealthConnect(),
              child: Text(tr('Нет Health Connect? Установить из Google Play'),
                  style: TextStyle(color: AppColors.accent, fontSize: 13)),
            ),
          ),
      ],
    );
  }
}


/// Подсказка снять ограничения батареи — иначе некоторые телефоны усыпляют шагомер.
class _BatteryHint extends StatefulWidget {
  const _BatteryHint();

  @override
  State<_BatteryHint> createState() => _BatteryHintState();
}

class _BatteryHintState extends State<_BatteryHint> {
  bool? ok;

  @override
  void initState() {
    super.initState();
    StepsService.instance.batteryUnrestricted.then((v) {
      if (mounted) setState(() => ok = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (ok == null) return const SizedBox.shrink();
    if (ok!) {
      return Padding(
        padding: EdgeInsets.only(top: 2, bottom: 6),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 16, color: AppColors.good),
            SizedBox(width: 8),
            Expanded(child: Text(tr('Шагомер работает в фоне без ограничений батареи'), style: Txt.small)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: AppCard(
        borderColor: AppColors.under.withValues(alpha: 0.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.battery_alert_outlined, color: AppColors.under, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('Чтобы телефон не усыплял шагомер, сними для приложения ограничения батареи. Особенно важно на Xiaomi, Huawei, Honor и Samsung.'),
                    style: Txt.small,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GhostButton(tr('Снять ограничения'), icon: Icons.battery_charging_full, onPressed: () async {
              final v = await StepsService.instance.requestNoBatteryLimit();
              if (mounted) setState(() => ok = v);
            }),
          ],
        ),
      ),
    );
  }
}
