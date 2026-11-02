import 'package:flutter/material.dart';

import '../food/fill_advisor.dart';
import '../gemini.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import '../i18n/i18n.dart';

/// «Чем добрать норму»: варианты из своих продуктов и от ИИ.
Future<void> showFillSheet(BuildContext context, DateTime date) {
  return showAppSheet<void>(context, _FillSheet(date: dayOnly(date)));
}

class _FillSheet extends StatefulWidget {
  final DateTime date;
  const _FillSheet({required this.date});

  @override
  State<_FillSheet> createState() => _FillSheetState();
}

class _FillSheetState extends State<_FillSheet> {
  List<FillIdea>? aiIdeas;
  String note = '';
  bool loading = false;
  String? error;
  final added = <String>{};

  String get _key => dkey(widget.date);

  Future<void> _askAi() async {
    final store = StoreScope.read(context);
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final (list, n) = await FillAdvisor.ai(store, _key);
      if (!mounted) return;
      setState(() {
        aiIdeas = list;
        note = n;
        if (list.isEmpty) error = tr('ИИ не предложил вариантов. Попробуй ещё раз.');
      });
    } on GeminiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = trf('Ошибка: {0}', [e]));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _add(FillIdea idea) {
    final store = StoreScope.read(context);
    final now = DateTime.now();
    final d = widget.date;
    final isToday = sameDay(d, now);
    final it = idea.item;
    store.addEntries([
      FoodEntry(
        id: store.newId(),
        date: _key,
        time: DateTime(d.year, d.month, d.day, now.hour, now.minute, now.second).millisecondsSinceEpoch,
        meal: isToday ? MealX.byTime(now) : Meal.snack,
        name: it.name,
        grams: it.grams,
        kcal: it.kcal,
        protein: it.protein,
        fat: it.fat,
        carbs: it.carbs,
        fiber: it.fiber,
        salt: it.salt,
      ),
    ]);
    setState(() => added.add(it.name));
    showToast(context, trf('Добавлено: {0}', [it.name]));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final rem = Remaining.of(store, _key);
    final local = FillAdvisor.local(store, _key);
    final hasKey = store.apiKey.isNotEmpty;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const SheetHandle(),
          Text(tr('Чем добрать норму'), style: Txt.h2),
          const SizedBox(height: 6),
          Text(
            rem.done
                ? tr('Норма на сегодня уже набрана — ничего добавлять не нужно.')
                : trf('Осталось: {0} ккал · Б {1} · Ж {2} · У {3}', [fmtInt(rem.kcal), fmtInt(rem.protein), fmtInt(rem.fat), fmtInt(rem.carbs)]),
            style: Txt.small.copyWith(color: AppColors.text),
          ),
          if (!rem.done) ...[
            SectionLabel(tr('Из твоих продуктов')),
            if (local.isEmpty)
              Text(tr('Пока мало записей, чтобы подобрать из своего. Добавь продукты в избранное или создай рецепты.'), style: Txt.small),
            for (final i in local) _tile(i),
            SectionLabel(tr('Идеи от ИИ')),
            if (!hasKey)
              Text(tr('Добавь ключ Gemini в профиле, чтобы ИИ предложил варианты.'), style: Txt.small)
            else ...[
              if (aiIdeas == null || error != null)
                PrimaryButton(aiIdeas == null ? tr('Предложить варианты') : tr('Попробовать ещё раз'),
                    icon: Icons.auto_awesome, loading: loading, onPressed: _askAi),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, style: Txt.small.copyWith(color: AppColors.over)),
              ],
              for (final i in aiIdeas ?? const <FillIdea>[]) _tile(i),
              if (note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.accent2, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(note, style: Txt.small)),
                  ],
                ),
              ],
              if (aiIdeas != null && error == null) ...[
                const SizedBox(height: 8),
                GhostButton(tr('Другие варианты'), icon: Icons.refresh, onPressed: loading ? null : _askAi),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _tile(FillIdea idea) {
    final it = idea.item;
    final done = added.contains(it.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.name, style: Txt.body.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    trf('{0} г · {1} ккал · Б {2} Ж {3} У {4}', [fmt1(it.grams), fmtInt(it.kcal), fmt1(it.protein), fmt1(it.fat), fmt1(it.carbs)]),
                    style: Txt.small.copyWith(fontSize: 11.5),
                  ),
                  if (idea.why.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(idea.why, style: Txt.small.copyWith(fontSize: 11.5, color: AppColors.accent2)),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: tr('Добавить'),
              onPressed: done ? null : () => _add(idea),
              icon: Icon(done ? Icons.check : Icons.add_circle_outline, color: done ? AppColors.good : AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
