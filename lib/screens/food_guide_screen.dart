import 'package:flutter/material.dart';

import '../food/food_guide.dart';
import '../i18n/i18n.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';

const _tierColors = {
  'SSS': Color(0xFFFF4D6D),
  'SS': Color(0xFFFF8A3D),
  'S': Color(0xFFF2B14C),
  'A': Color(0xFF3DD68C),
  'B': Color(0xFF4CC9F0),
  'C': Color(0xFF8E9AAF),
  'D': Color(0xFF5C5F66),
};

enum _Tab { tiers, simple, tasty }

/// Тир-лист еды и подборки блюд.
class FoodGuideScreen extends StatefulWidget {
  const FoodGuideScreen({super.key});

  @override
  State<FoodGuideScreen> createState() => _FoodGuideScreenState();
}

class _FoodGuideScreenState extends State<FoodGuideScreen> {
  _Tab _tab = _Tab.tiers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Тир-лист и блюда')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Segmented<_Tab>(
            values: _Tab.values,
            label: (t) => switch (t) { _Tab.tiers => tr('Тир-лист'), _Tab.simple => tr('Простые'), _Tab.tasty => tr('Вкусные') },
            selected: _tab,
            onChanged: (t) => setState(() => _tab = t),
          ),
          const SizedBox(height: 12),
          ...switch (_tab) {
            _Tab.tiers => [for (final t in foodTiers) _TierCard(t)],
            _Tab.simple => [
                Text(tr('Простые и питательные: минимум продуктов и времени, много белка.'), style: Txt.small),
                const SizedBox(height: 10),
                for (final d in simpleDishes) _DishCard(d),
              ],
            _Tab.tasty => [
                Text(tr('Вкусные, но всё ещё влезают в норму. КБЖУ — на одну порцию.'), style: Txt.small),
                const SizedBox(height: 10),
                for (final d in tastyDishes) _DishCard(d),
              ],
          },
          const SizedBox(height: 8),
          Text(tr('КБЖУ примерные: по средним табличным значениям продуктов.'), style: Txt.small, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  final FoodTier t;
  const _TierCard(this.t);

  @override
  Widget build(BuildContext context) {
    final c = _tierColors[t.tier] ?? AppColors.accent;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        borderColor: c.withValues(alpha: 0.6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
              child: Text(t.tier, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: t.tier.length > 2 ? 18 : 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(t.note), style: Txt.small.copyWith(color: c)),
                  const SizedBox(height: 6),
                  for (final (name, why) in t.foods)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(name), style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                          Text(tr(why), style: Txt.small),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DishCard extends StatefulWidget {
  final GuideDish d;
  const _DishCard(this.d);

  @override
  State<_DishCard> createState() => _DishCardState();
}

class _DishCardState extends State<_DishCard> {
  bool _open = false;

  void _save() {
    final store = StoreScope.read(context);
    final d = widget.d;
    if (store.food.recipes.any((r) => r.name == d.name)) {
      showToast(context, tr('Этот рецепт уже есть в «Моих рецептах»'));
      return;
    }
    store.food.saveRecipe(d.toRecipe(store.food.newId('recipe')));
    showToast(context, tr('Добавлено в «Мои рецепты» — теперь его можно записать в дневник'));
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final n = d.perPortion;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => setState(() => _open = !_open),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(tr(d.name), style: Txt.body.copyWith(fontWeight: FontWeight.w700))),
                Icon(_open ? Icons.expand_less : Icons.expand_more, color: AppColors.muted),
              ],
            ),
            const SizedBox(height: 2),
            Text(tr(d.about), style: Txt.small),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              Pill('${n.kcal.round()} ${tr('ккал')}'),
              Pill('${tr('Б')} ${n.p.round()}', color: AppColors.protein),
              Pill('${tr('Ж')} ${n.f.round()}', color: AppColors.fat),
              Pill('${tr('У')} ${n.c.round()}', color: AppColors.carbs),
              if (d.portions > 1) Pill(trf('{0} порции', [d.portions]), color: AppColors.accent2),
            ]),
            if (_open) ...[
              const SizedBox(height: 12),
              Text(tr('Продукты'), style: Txt.label),
              const SizedBox(height: 4),
              for (final (name, grams) in d.items)
                Text('• ${tr(name)} — ${grams.round()} ${tr('г')}', style: Txt.small.copyWith(color: AppColors.text)),
              const SizedBox(height: 10),
              Text(tr('Как готовить'), style: Txt.label),
              const SizedBox(height: 4),
              for (var i = 0; i < d.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${i + 1}. ${tr(d.steps[i])}', style: Txt.small.copyWith(color: AppColors.text)),
                ),
              const SizedBox(height: 10),
              GhostButton(tr('В мои рецепты'), icon: Icons.bookmark_add_outlined, onPressed: _save),
            ],
          ],
        ),
      ),
    );
  }
}
