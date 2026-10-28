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

  @override
  void dispose() {
    weight.dispose();
    reps.dispose();
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
