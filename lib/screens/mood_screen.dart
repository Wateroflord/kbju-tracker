import 'package:flutter/material.dart';

import '../life/models.dart';
import '../life/wellbeing.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/sheets.dart';
import '../i18n/i18n.dart';

const moodIcons = [
  Icons.sentiment_very_dissatisfied,
  Icons.sentiment_dissatisfied,
  Icons.sentiment_neutral,
  Icons.sentiment_satisfied,
  Icons.sentiment_very_satisfied,
];

const moodColors = [
  Color(0xFFFF5C7A),
  Color(0xFFF2994A),
  Color(0xFFAFB3BA),
  Color(0xFF7FD08A),
  Color(0xFF3DD68C),
];

String moodTitle(int v) => switch (v) {
      1 => tr('Плохо'),
      2 => tr('Так себе'),
      3 => tr('Нормально'),
      4 => tr('Хорошо'),
      _ => tr('Отлично'),
    };

/// Быстрая отметка настроения на экране «Сегодня».
class MoodQuickCard extends StatelessWidget {
  const MoodQuickCard({super.key});

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final e = life.moods[todayKey()];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MoodScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(e == null ? tr('Как ты сегодня?') : trf('Сегодня: {0}', [moodTitle(e.mood).toLowerCase()]),
                    style: Txt.section),
              ),
              if (e != null) Text(trf('энергия {0}/5 · стресс {1}/5', [e.energy, e.stress]), style: Txt.small),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 1; i <= 5; i++)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => showMoodSheet(context, initialMood: i),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(moodIcons[i - 1],
                        size: 34, color: e?.mood == i ? moodColors[i - 1] : AppColors.muted.withValues(alpha: e == null ? 1 : 0.5)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showMoodSheet(BuildContext context, {int? initialMood, DateTime? date}) =>
    showAppSheet<void>(context, _MoodForm(initialMood: initialMood, date: date ?? today()));

class _MoodForm extends StatefulWidget {
  final int? initialMood;
  final DateTime date;
  const _MoodForm({this.initialMood, required this.date});

  @override
  State<_MoodForm> createState() => _MoodFormState();
}

class _MoodFormState extends State<_MoodForm> {
  late MoodEntry? old = StoreScope.read(context).life.moods[dkey(widget.date)];
  late int mood = widget.initialMood ?? old?.mood ?? 3;
  late int energy = old?.energy ?? 3;
  late int stress = old?.stress ?? 2;
  late final note = TextEditingController(text: old?.note ?? '');

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  Widget _scale(String title, String low, String high, int value, ValueChanged<int> onChanged, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Txt.label),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 1; i <= 5; i++) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => onChanged(i)),
                    child: Container(
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: i == value ? color.withValues(alpha: 0.2) : AppColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: i == value ? color : AppColors.border),
                      ),
                      child: Text('$i', style: Txt.num(15, color: i == value ? color : AppColors.muted)),
                    ),
                  ),
                ),
                if (i < 5) const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(low, style: Txt.small.copyWith(fontSize: 11)),
              const Spacer(),
              Text(high, style: Txt.small.copyWith(fontSize: 11)),
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Row(
            children: [
              Expanded(child: Text(tr('Самочувствие'), style: Txt.h2)),
              Text(sameDay(widget.date, today()) ? tr('Сегодня') : fmtDate(widget.date), style: Txt.small),
            ],
          ),
          const SizedBox(height: 14),
          Text(tr('НАСТРОЕНИЕ'), style: Txt.label),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => setState(() => mood = i),
                  child: Column(
                    children: [
                      Icon(moodIcons[i - 1], size: 38, color: i == mood ? moodColors[i - 1] : AppColors.muted),
                      const SizedBox(height: 2),
                      Text(moodTitle(i),
                          style: TextStyle(fontSize: 10, color: i == mood ? AppColors.text : AppColors.muted)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _scale(tr('ЭНЕРГИЯ'), tr('без сил'), tr('бодрость'), energy, (v) => energy = v, AppColors.good),
          const SizedBox(height: 14),
          _scale(tr('СТРЕСС'), tr('спокойно'), tr('очень напряжён'), stress, (v) => stress = v, AppColors.over),
          const SizedBox(height: 14),
          TextField(
            controller: note,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: Txt.body,
            decoration: fieldDeco(tr('Заметка (необязательно)'), hint: tr('что повлияло на день?')),
          ),
          const SizedBox(height: 16),
          PrimaryButton(tr('Сохранить'), icon: Icons.check, onPressed: () {
            StoreScope.read(context).life.setMood(
                  dkey(widget.date),
                  MoodEntry(mood: mood, energy: energy, stress: stress, note: note.text.trim()),
                );
            Navigator.pop(context);
          }),
        ],
      ),
    );
  }
}

/// Дневник самочувствия: графики и связи с привычками.
class MoodScreen extends StatelessWidget {
  const MoodScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final life = store.life;
    final from = dkey(addDays(today(), -29));
    final entries = life.moods.entries.where((e) => e.key.compareTo(from) >= 0).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final insights = computeInsights(store);
    double avg(int Function(MoodEntry) f) =>
        entries.isEmpty ? 0.0 : entries.map((e) => f(e.value)).reduce((a, b) => a + b) / entries.length;
    final all = life.moods.entries.toList()..sort((a, b) => b.key.compareTo(a.key));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Дневник самочувствия')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => showMoodSheet(context),
        icon: const Icon(Icons.add),
        label: Text(tr('Отметить'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Row(
            children: [
              Expanded(child: StatTile(label: tr('Настроение'), value: entries.isEmpty ? '—' : fmt1(avg((e) => e.mood)), sub: tr('за 30 дней'))),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                    label: tr('Энергия'), value: entries.isEmpty ? '—' : fmt1(avg((e) => e.energy)), sub: tr('за 30 дней'), color: AppColors.good),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                    label: tr('Стресс'), value: entries.isEmpty ? '—' : fmt1(avg((e) => e.stress)), sub: tr('за 30 дней'), color: AppColors.over),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('Настроение за 30 дней'), style: Txt.section),
                const SizedBox(height: 10),
                if (entries.length >= 2)
                  LineChart(
                    points: [for (final e in entries) ChartPoint(parseKey(e.key), e.value.mood.toDouble())],
                    color: AppColors.accent,
                    height: 140,
                  )
                else
                  Text(tr('Отмечай самочувствие каждый день — появится график.'), style: Txt.small),
                if (entries.length >= 2) ...[
                  const SizedBox(height: 14),
                  Text(tr('Энергия'), style: Txt.section),
                  const SizedBox(height: 10),
                  LineChart(
                    points: [for (final e in entries) ChartPoint(parseKey(e.key), e.value.energy.toDouble())],
                    color: AppColors.good,
                    height: 120,
                  ),
                ],
              ],
            ),
          ),
          SectionLabel(tr('Что на тебя влияет')),
          if (insights.isEmpty)
            AppCard(
              child: Text(
                tr('Нужно хотя бы 1–2 недели записей настроения вместе со сном, шагами и едой. Тогда здесь появятся связи: например, как сон влияет на энергию.'),
                style: Txt.small,
              ),
            )
          else
            AppCard(
              child: Column(
                children: [
                  for (final i in insights)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(i.good ? Icons.trending_up : Icons.warning_amber_rounded,
                              size: 18, color: i.good ? AppColors.good : AppColors.fat),
                          const SizedBox(width: 10),
                          Expanded(child: Text(i.text, style: Txt.body.copyWith(fontSize: 13.5))),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(tr('Это совпадения в твоих данных, а не медицинские выводы.'), style: Txt.small.copyWith(fontSize: 11)),
                ],
              ),
            ),
          SectionLabel(tr('Записи')),
          if (all.isEmpty) Text(tr('Пока нет записей.'), style: Txt.small),
          for (final e in all.take(30))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => showMoodSheet(context, date: parseKey(e.key)),
                child: Row(
                  children: [
                    Icon(moodIcons[e.value.mood - 1], color: moodColors[e.value.mood - 1], size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fmtDate(parseKey(e.key)), style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                          Text(
                            e.value.note.isEmpty
                                ? trf('энергия {0}/5 · стресс {1}/5', [e.value.energy, e.value.stress])
                                : e.value.note,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Txt.small,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
