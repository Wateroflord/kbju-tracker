import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/sheets.dart';
import 'add_food_screen.dart';
import 'calendar_screen.dart';

/// Экран одного дня: калории, БЖУ, вода, приёмы пищи.
/// Используется и как вкладка «Сегодня», и для просмотра прошлых дней из календаря.
class DayView extends StatefulWidget {
  final DateTime? initialDate;
  final bool isRoot;
  const DayView({super.key, this.initialDate, this.isRoot = true});

  @override
  State<DayView> createState() => _DayViewState();
}

class _DayViewState extends State<DayView> {
  late DateTime date = dayOnly(widget.initialDate ?? DateTime.now());

  bool get _isToday => sameDay(date, DateTime.now());

  void _openAdd(Meal? meal) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddFoodScreen(
        date: date,
        meal: meal ?? (_isToday ? MealX.byTime(DateTime.now()) : Meal.lunch),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final key = dkey(date);
    final t = store.targetsFor(key);
    final tot = store.totalsFor(key);
    final entries = store.entriesFor(key);
    final goal = store.profile?.goal ?? Goal.maintain;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: widget.isRoot
          ? null
          : AppBar(
              backgroundColor: AppColors.bg,
              surfaceTintColor: Colors.transparent,
              title: const Text('Дневник', style: Txt.h2),
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_$key${widget.isRoot}',
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => _openAdd(null),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Еда', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
          children: [
            _header(goal),
            const SizedBox(height: 14),
            _calorieCard(tot, t),
            const SizedBox(height: 12),
            _waterCard(store, key, t),
            for (final m in Meal.values) ..._mealSection(store, m, entries.where((e) => e.meal == m).toList()),
          ],
        ),
      ),
    );
  }

  Widget _header(Goal goal) {
    if (!widget.isRoot) return _dateRow(goal);
    return Column(
      children: [
        TabHeader('Питание', actions: [
          SquareIconButton(
            Icons.calendar_month_outlined,
            tooltip: 'Календарь',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _dateRow(goal),
      ],
    );
  }

  Widget _dateRow(Goal goal) {
    final wd = weekdaysFull[date.weekday - 1];
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => date = today()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isToday ? 'Сегодня' : wd, style: widget.isRoot ? Txt.h2 : Txt.h1),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(fmtDate(date, year: true), style: Txt.small),
                    Pill(goal.title, icon: goal.icon, onTap: () => showGoalSheet(context)),
                  ],
                ),
              ],
            ),
          ),
        ),
        _navBtn(Icons.chevron_left, () => setState(() => date = addDays(date, -1))),
        const SizedBox(width: 6),
        _navBtn(Icons.chevron_right, _isToday ? null : () => setState(() => date = addDays(date, 1))),
      ],
    );
  }

  Widget _navBtn(IconData icon, VoidCallback? onTap) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: onTap == null ? AppColors.border : AppColors.text),
          ),
        ),
      );

  Widget _calorieCard(Totals tot, Targets t) {
    final left = t.kcal - tot.kcal;
    final over = left < 0;
    final ratio = t.kcal > 0 ? tot.kcal / t.kcal : 0.0;
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: CustomPaint(
                  painter: RingPainter(progress: ratio, color: AppColors.accent),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(fmtInt(tot.kcal), style: Txt.num(28)),
                        const SizedBox(height: 4),
                        Text('из ${fmtInt(t.kcal)}', style: Txt.small),
                        const Text('ККАЛ', style: Txt.label),
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
                    Text(over ? 'ПЕРЕБОР' : 'ОСТАЛОСЬ', style: Txt.label),
                    const SizedBox(height: 4),
                    Text(
                      '${fmtInt(left.abs())} ккал',
                      style: Txt.num(22, color: over ? AppColors.over : AppColors.accent),
                    ),
                    const SizedBox(height: 14),
                    const Text('ВЫПОЛНЕНО', style: Txt.label),
                    const SizedBox(height: 4),
                    Text('${(ratio * 100).round()}%', style: Txt.num(18)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          MacroBar(label: 'Белки', value: tot.protein, target: t.protein, color: AppColors.protein),
          const SizedBox(height: 12),
          MacroBar(label: 'Жиры', value: tot.fat, target: t.fat, color: AppColors.fat),
          const SizedBox(height: 12),
          MacroBar(label: 'Углеводы', value: tot.carbs, target: t.carbs, color: AppColors.carbs),
        ],
      ),
    );
  }

  Widget _waterCard(AppStore store, String key, Targets t) {
    final ml = store.waterFor(key);
    return AppCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop_outlined, color: AppColors.water, size: 20),
              const SizedBox(width: 8),
              const Text('Вода', style: Txt.h2),
              const Spacer(),
              Text(fmtInt(ml), style: Txt.num(16, color: AppColors.water)),
              Text(' / ${fmtInt(t.waterMl)} мл', style: Txt.small),
            ],
          ),
          const SizedBox(height: 10),
          ProgressLine(ratio: t.waterMl > 0 ? ml / t.waterMl : 0, color: AppColors.water, overIsBad: false),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _waterBtn('−250', () => store.addWater(key, -250))),
              const SizedBox(width: 8),
              Expanded(child: _waterBtn('+250', () => store.addWater(key, 250))),
              const SizedBox(width: 8),
              Expanded(child: _waterBtn('+500', () => store.addWater(key, 500))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _waterBtn(String text, VoidCallback onTap) => Material(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(text, style: Txt.num(14, color: AppColors.water, weight: FontWeight.w600)),
          ),
        ),
      );

  List<Widget> _mealSection(AppStore store, Meal m, List<FoodEntry> list) {
    final kcal = list.fold<double>(0, (s, e) => s + e.kcal);
    return [
      SectionLabel(
        m.title,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (list.isNotEmpty) Text('${fmtInt(kcal)} ккал', style: Txt.num(12, color: AppColors.muted)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _openAdd(m),
              child: const Icon(Icons.add_circle_outline, size: 20, color: AppColors.accent),
            ),
          ],
        ),
      ),
      if (list.isEmpty)
        AppCard(
          onTap: () => _openAdd(m),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(m.icon, color: AppColors.muted, size: 20),
              const SizedBox(width: 10),
              const Text('Пусто — нажми, чтобы добавить', style: Txt.small),
            ],
          ),
        )
      else
        for (final e in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _EntryTile(entry: e, store: store),
          ),
    ];
  }
}

class _EntryTile extends StatelessWidget {
  final FoodEntry entry;
  final AppStore store;
  const _EntryTile({required this.entry, required this.store});

  @override
  Widget build(BuildContext context) {
    final photo = store.photoFile(entry.photo);
    return AppCard(
      onTap: () => showEntryEditor(context, entry),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 48,
              height: 48,
              child: photo != null
                  ? Image.file(photo, fit: BoxFit.cover, cacheWidth: 160)
                  : Container(
                      color: AppColors.surface2,
                      child: Icon(entry.meal.icon, color: AppColors.muted, size: 22),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Txt.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: '${fmt1(entry.grams)} г   '),
                    TextSpan(text: 'Б ', style: const TextStyle(color: AppColors.protein)),
                    TextSpan(text: '${fmt1(entry.protein)}  '),
                    TextSpan(text: 'Ж ', style: const TextStyle(color: AppColors.fat)),
                    TextSpan(text: '${fmt1(entry.fat)}  '),
                    TextSpan(text: 'У ', style: const TextStyle(color: AppColors.carbs)),
                    TextSpan(text: fmt1(entry.carbs)),
                  ]),
                  style: Txt.small.copyWith(fontFeatures: Txt.tab),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtInt(entry.kcal), style: Txt.num(17)),
              const Text('ккал', style: Txt.small),
            ],
          ),
        ],
      ),
    );
  }
}

/// Экран дня, открываемый из календаря.
class DayScreen extends StatelessWidget {
  final DateTime date;
  const DayScreen({super.key, required this.date});

  @override
  Widget build(BuildContext context) => DayView(initialDate: date, isRoot: false);
}
