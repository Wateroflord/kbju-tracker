import 'package:flutter/material.dart';

import '../food/week_report.dart';
import '../gemini.dart';
import '../life/models.dart' show weekStart;
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../i18n/i18n.dart';

/// Карточка на вкладке «Прогресс».
class WeeklyReportCard extends StatelessWidget {
  const WeeklyReportCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final now = today();
    // По понедельникам и вторникам предлагаем разбор прошлой недели.
    final mon = weekStart(now.weekday <= 2 ? addDays(now, -7) : now);
    final has = store.food.reports.containsKey(dkey(mon));
    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WeeklyReportScreen(monday: mon))),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Разбор недели от ИИ'), style: Txt.h2),
                const SizedBox(height: 2),
                Text(
                  has
                      ? trf('Готов разбор за неделю с {0}', [fmtDate(mon)])
                      : tr('Что получилось, что улучшить и план на следующую неделю'),
                  style: Txt.small,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

class WeeklyReportScreen extends StatefulWidget {
  final DateTime monday;
  const WeeklyReportScreen({super.key, required this.monday});

  @override
  State<WeeklyReportScreen> createState() => _WeeklyReportScreenState();
}

class _WeeklyReportScreenState extends State<WeeklyReportScreen> {
  late DateTime monday = widget.monday;
  bool loading = false;
  String? error;

  Future<void> _generate(AppStore store, WeekStats w) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final text = await requestWeekReport(store, w);
      store.food.saveReport(dkey(monday), _clean(text));
    } on GeminiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = trf('Ошибка: {0}', [e]));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  static String _clean(String t) => t.replaceAll('**', '').replaceAll(RegExp(r'^#+\s*', multiLine: true), '').trim();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final w = computeWeek(store, monday);
    final report = store.food.reports[dkey(monday)];
    final sunday = addDays(monday, 6);
    final canNext = !addDays(monday, 7).isAfter(today());
    final hasKey = store.apiKey.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Разбор недели')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  monday = addDays(monday, -7);
                  error = null;
                }),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text('${fmtDate(monday)} — ${fmtDate(sunday)}', textAlign: TextAlign.center, style: Txt.section),
              ),
              IconButton(
                onPressed: canNext
                    ? () => setState(() {
                          monday = addDays(monday, 7);
                          error = null;
                        })
                    : null,
                icon: Icon(Icons.chevron_right, color: canNext ? AppColors.text : AppColors.border),
              ),
            ],
          ),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,
            children: [
              StatTile(label: tr('Калории'), value: w.logged == 0 ? '—' : fmtInt(w.avgKcal), sub: trf('норма {0}', [fmtInt(w.avgTKcal)])),
              StatTile(
                label: tr('Белки'),
                value: w.logged == 0 ? '—' : trf('{0} г', [fmtInt(w.avgProtein)]),
                sub: trf('норма {0}', [fmtInt(w.avgTProtein)]),
                color: AppColors.protein,
              ),
              StatTile(label: tr('В норме'), value: '${w.inNorm}/${w.days}', sub: trf('записей {0}', [w.logged]), color: AppColors.good),
              StatTile(
                label: tr('Вес'),
                value: w.weightChange == null ? '—' : '${w.weightChange! > 0 ? '+' : w.weightChange! < 0 ? '−' : ''}${fmt1(w.weightChange!.abs())}',
                sub: tr('кг за неделю'),
              ),
              StatTile(label: tr('Шаги'), value: w.stepsDays == 0 ? '—' : fmtInt(w.avgSteps), sub: tr('в среднем')),
              StatTile(label: tr('Сон'), value: w.sleepNights == 0 ? '—' : fmt1(w.avgSleep), sub: tr('часов')),
              StatTile(label: tr('Тренировки'), value: '${w.workouts}', sub: trf('план {0}', [store.workoutsPerWeek]), color: AppColors.accent),
              StatTile(label: tr('Привычки'), value: '${w.habitsPercent}%', sub: tr('выполнено')),
              StatTile(label: tr('Язык'), value: '${w.learnMinutes}', sub: tr('минут')),
            ],
          ),
          const SizedBox(height: 14),
          if (report != null) _ReportText(report),
          if (error != null) ...[
            const SizedBox(height: 12),
            AppCard(
              borderColor: AppColors.over.withValues(alpha: 0.5),
              child: Text(error!, style: Txt.small.copyWith(color: AppColors.text)),
            ),
          ],
          const SizedBox(height: 14),
          if (!hasKey)
            Text(tr('Для разбора нужен бесплатный ключ Gemini (Профиль → ИИ).'), style: Txt.small)
          else if (w.empty)
            Text(tr('За эту неделю пока мало данных. Записывай еду, шаги и сон — тогда разбор будет полезным.'), style: Txt.small)
          else
            PrimaryButton(
              report == null ? tr('Получить разбор') : tr('Обновить разбор'),
              icon: Icons.auto_awesome,
              loading: loading,
              onPressed: () => _generate(store, w),
            ),
          if (loading) ...[
            const SizedBox(height: 10),
            Center(child: Text(tr('ИИ изучает твою неделю…'), style: Txt.small)),
          ],
        ],
      ),
    );
  }
}

/// Простой вывод: строки с двоеточием в конце — заголовки, строки с «- » — пункты.
class _ReportText extends StatelessWidget {
  final String text;
  const _ReportText(this.text);

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            if (l.startsWith('- ') || l.startsWith('• ') || l.startsWith('* '))
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: Dot(AppColors.accent, size: 5),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l.substring(2), style: Txt.body.copyWith(fontSize: 13.5, height: 1.35))),
                  ],
                ),
              )
            else if (l.endsWith(':') && l.length < 60)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Text(l.substring(0, l.length - 1).replaceFirst(RegExp(r'^\d\)\s*'), '').toUpperCase(), style: Txt.label),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(l, style: Txt.body.copyWith(fontSize: 13.5, height: 1.4)),
              ),
        ],
      ),
    );
  }
}
