import 'package:flutter/material.dart';

import '../life/training.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import 'training_screen.dart';
import '../i18n/i18n.dart';

/// Калькулятор максимума на 1 повтор и сводка силы по упражнениям.
class OneRmScreen extends StatefulWidget {
  const OneRmScreen({super.key});

  @override
  State<OneRmScreen> createState() => _OneRmScreenState();
}

class _OneRmScreenState extends State<OneRmScreen> {
  final weight = TextEditingController(text: '60');
  final reps = TextEditingController(text: '8');
  final plateTarget = TextEditingController(text: '60');
  double bar = 20;

  @override
  void dispose() {
    weight.dispose();
    reps.dispose();
    plateTarget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final w = parseNum(weight.text) ?? 0;
    final r = (parseNum(reps.text) ?? 0).round();
    final max = (r >= 1 && r <= 20) ? e1rm(w, r) : 0.0;

    // Сила по упражнениям: лучший 1ПМ и изменение за 4 недели.
    final rows = <(String, double, double?)>[];
    final monthAgo = dkey(addDays(today(), -28));
    for (final id in life.trainedExerciseIds()) {
      final h = life.e1rmHistory(id);
      if (h.isEmpty) continue;
      double? before;
      for (final e in h) {
        if (e.key.compareTo(monthAgo) <= 0) before = e.value;
      }
      rows.add((id, h.last.value, before));
    }
    rows.sort((a, b) => b.$2.compareTo(a.$2));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Калькулятор 1ПМ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            tr('1ПМ — максимальный вес, который ты поднимешь один раз. Не проверяй его в зале — посчитай по обычному подходу.'),
            style: Txt.small,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: NumField(weight, tr('Вес'), suffix: tr('кг'), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(child: NumField(reps, tr('Повторы'), onChanged: (_) => setState(() {}))),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('ТВОЙ 1ПМ'), style: Txt.label),
                const SizedBox(height: 4),
                Text(max > 0 ? trf('{0} кг', [fmt1(max)]) : '—', style: Txt.num(32, color: AppColors.accent)),
                if (r > 12) ...[
                  const SizedBox(height: 4),
                  Text(tr('При больших повторах расчёт менее точный. Лучше считать по подходу на 3–10 повторов.'), style: Txt.small),
                ],
                if (max > 0) ...[
                  const SizedBox(height: 14),
                  Text(tr('ВЕС ПОД НУЖНОЕ ЧИСЛО ПОВТОРОВ'), style: Txt.label),
                  const SizedBox(height: 6),
                  for (final n in const [1, 3, 5, 8, 10, 12, 15])
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          SizedBox(width: 72, child: Text(trf('{0} повт.', [n]), style: Txt.small.copyWith(color: AppColors.text))),
                          Expanded(
                            child: ProgressLine(ratio: pctForReps(n), color: AppColors.accent2, overIsBad: false, height: 4),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 74,
                            child: Text(trf('{0} кг', [fmt1(_round25(max * pctForReps(n)))]),
                                textAlign: TextAlign.right, style: Txt.num(14)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(tr('Веса округлены до 2,5 кг. Для набора мышц чаще работай в 6–12 повторах, для силы — в 3–6.'),
                      style: Txt.small),
                ],
              ],
            ),
          ),
          SectionLabel(tr('Блины на штангу')),
          _PlatesCard(
            target: plateTarget,
            bar: bar,
            onBar: (v) => setState(() => bar = v),
            onChanged: () => setState(() {}),
          ),
          SectionLabel(tr('Сила по упражнениям')),
          if (rows.isEmpty)
            AppCard(child: Text(tr('После тренировок с весом здесь появится расчётный 1ПМ по каждому упражнению.'), style: Txt.small))
          else
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final row in rows)
                    InkWell(
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExerciseStatsScreen(exId: row.$1))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Expanded(child: Text(tr(life.exerciseById(row.$1).name), style: Txt.body.copyWith(fontSize: 13.5))),
                            if (row.$3 != null && (row.$2 - row.$3!).abs() >= 0.5)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: Text(
                                  '${row.$2 > row.$3! ? '+' : '−'}${fmt1((row.$2 - row.$3!).abs())}',
                                  style: Txt.num(12, color: row.$2 > row.$3! ? AppColors.good : AppColors.over),
                                ),
                              ),
                            Text(trf('{0} кг', [fmt1(row.$2)]), style: Txt.num(14)),
                            const Icon(Icons.chevron_right, size: 18, color: AppColors.muted),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(tr('Зелёное число — рост за 4 недели. Прогресс силы виден лучше, чем рабочий вес: учитываются и повторы.'),
              style: Txt.small),
        ],
      ),
    );
  }
}

double _round25(double v) => (v / 2.5).round() * 2.5;

/// Калькулятор блинов: что повесить на каждую сторону.
class _PlatesCard extends StatelessWidget {
  final TextEditingController target;
  final double bar;
  final ValueChanged<double> onBar;
  final VoidCallback onChanged;
  const _PlatesCard({required this.target, required this.bar, required this.onBar, required this.onChanged});

  static Color _color(double p) => switch (p) {
        25.0 => const Color(0xFFE5484D),
        20.0 => const Color(0xFF3E7BFA),
        15.0 => const Color(0xFFF5C542),
        10.0 => const Color(0xFF3DD68C),
        5.0 => const Color(0xFFEDEDEF),
        2.5 => const Color(0xFFB04A4D),
        _ => const Color(0xFF8B8D93),
      };

  static String _kg(double v) => v == v.roundToDouble()
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll('.', appLang.decimal);

  @override
  Widget build(BuildContext context) {
    final t = parseNum(target.text) ?? 0;
    final r = platesFor(t, bar: bar);
    // Одинаковые блины — группой: «20 × 2».
    final groups = <double, int>{};
    for (final p in r.perSide) {
      groups[p] = (groups[p] ?? 0) + 1;
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: NumField(target, tr('Нужный вес'), suffix: tr('кг'), onChanged: (_) => onChanged())),
              const SizedBox(width: 10),
              for (final b in const [20.0, 15.0, 10.0])
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ChoiceChip(
                    label: Text(_kg(b)),
                    selected: bar == b,
                    onSelected: (_) => onBar(b),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr('Гриф: 20 кг — обычный, 15 — женский, 10 — лёгкий'), style: Txt.small),
          const SizedBox(height: 14),
          if (t <= bar)
            Text(tr('Только гриф — блины не нужны.'), style: Txt.body)
          else ...[
            Text(tr('НА КАЖДУЮ СТОРОНУ'), style: Txt.label),
            const SizedBox(height: 8),
            // Рисунок штанги: блины от центра наружу.
            SizedBox(
              height: 70,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(width: 40, height: 8, color: AppColors.accent2),
                  Container(width: 6, height: 26, color: AppColors.accent2),
                  for (final p in r.perSide)
                    Container(
                      width: 12,
                      height: 22 + 48 * (p / 25),
                      margin: const EdgeInsets.only(left: 2),
                      decoration: BoxDecoration(color: _color(p), borderRadius: BorderRadius.circular(3)),
                    ),
                  Container(width: 18, height: 8, color: AppColors.accent2),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(groups.entries.map((e) => e.value > 1 ? '${_kg(e.key)} × ${e.value}' : _kg(e.key)).join('  +  '), style: Txt.num(18)),
            const SizedBox(height: 4),
            Text(
              (r.total - t).abs() < 0.01
                  ? trf('Итого {0} кг', [_kg(r.total)])
                  : trf('Ровно не собрать — получится {0} кг', [_kg(r.total)]),
              style: Txt.small,
            ),
          ],
        ],
      ),
    );
  }
}
