import 'package:flutter/material.dart';

import '../food/food_models.dart';
import '../food/meal_plan.dart';
import '../life/models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../i18n/i18n.dart';
import 'recipes_screen.dart';
import 'shopping_screen.dart';

/// План питания на неделю из своих рецептов. Одной кнопкой продукты на неделю попадают
/// в список покупок (одинаковые продукты складываются).
class MealPlanScreen extends StatelessWidget {
  const MealPlanScreen({super.key});

  static List<String> get dayNames =>
      [tr('Понедельник'), tr('Вторник'), tr('Среда'), tr('Четверг'), tr('Пятница'), tr('Суббота'), tr('Воскресенье')];

  Future<void> _addMeal(BuildContext context, int day) async {
    final store = StoreScope.read(context);
    final recipes = store.food.recipes;
    if (recipes.isEmpty) {
      final go = await confirm(context, tr('Сначала нужен рецепт'),
          tr('План составляется из твоих рецептов. Создать первый рецепт?'), ok: tr('Создать'));
      if (go && context.mounted) {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecipeEditorScreen()));
      }
      return;
    }
    Recipe? picked;
    double portions = 1;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(trf('Блюдо на {0}', [dayNames[day - 1].toLowerCase()]), style: Txt.h2),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * 0.45),
                child: ListView(shrinkWrap: true, children: [
                  for (final r in recipes)
                    RadioListTile<String>(
                      value: r.id,
                      groupValue: picked?.id,
                      onChanged: (_) => set(() => picked = r),
                      title: Text(r.name, style: Txt.body),
                      subtitle: Text(
                        trf('{0} ккал · {1} г белка на порцию', [
                          fmtInt(r.kcal / r.portions),
                          fmtInt(r.protein / r.portions),
                        ]),
                        style: Txt.small,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(tr('Порций'), style: Txt.body)),
                IconButton(
                  onPressed: portions > 0.5 ? () => set(() => portions -= 0.5) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(_portions(portions), style: Txt.num(18)),
                IconButton(onPressed: () => set(() => portions += 0.5), icon: const Icon(Icons.add_circle_outline)),
              ]),
              const SizedBox(height: 8),
              PrimaryButton(tr('Добавить'), onPressed: picked == null ? null : () => Navigator.pop(c, true)),
            ]),
          ),
        ),
      ),
    );
    if (ok == true && picked != null) store.food.addPlanMeal(day, picked!.id, portions);
  }

  static String _portions(double p) => p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(1).replaceAll('.', ',');

  Future<void> _toShopping(BuildContext context) async {
    final store = StoreScope.read(context);
    final items = planShopping(store.food.recipes, store.food.mealPlan);
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('В плане пока нет блюд.'))));
      return;
    }
    for (final p in items) {
      store.life.saveShopItem(ShopItem(
        id: planShopId(p.name),
        category: tr('Продукты на неделю'),
        name: p.name,
        pricePln: 0,
        note: gramsText(p.grams, gUnit: tr('г'), kgUnit: tr('кг')),
      ));
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(trf('В списке покупок: {0} продуктов', [items.length])),
      action: SnackBarAction(
        label: tr('Открыть'),
        textColor: AppColors.accent2,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShoppingScreen())),
      ),
    ));
  }

  Future<void> _copyDay(BuildContext context, int day) async {
    final store = StoreScope.read(context);
    final ok = await confirm(context, tr('Скопировать день'),
        trf('Поставить блюда дня «{0}» на все дни недели? Остальные дни заменятся.', [dayNames[day - 1]]), ok: tr('Скопировать'));
    if (ok) store.food.copyPlanDay(day, [1, 2, 3, 4, 5, 6, 7]);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final f = store.food;
    final byId = {for (final r in f.recipes) r.id: r};
    final target = store.targetsFor(todayKey());
    final today = DateTime.now().weekday;
    final products = planShopping(f.recipes, f.mealPlan);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('План питания'), actions: [
        if (f.mealPlan.isNotEmpty)
          IconButton(
            tooltip: tr('Очистить план'),
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () async {
              final ok = await confirm(context, tr('Очистить план?'), tr('Все блюда недели будут убраны.'), ok: tr('Очистить'));
              if (ok) f.clearPlan();
            },
          ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(tr('Расставь свои рецепты по дням — внизу кнопка сложит все продукты недели в список покупок.'), style: Txt.small),
          const SizedBox(height: 12),
          for (var d = 1; d <= 7; d++) ...[
            Builder(builder: (context) {
              final meals = f.mealPlan[d] ?? const <PlanMeal>[];
              var kcal = 0.0, prot = 0.0;
              for (final m in meals) {
                final r = byId[m.recipeId];
                if (r == null) continue;
                kcal += r.kcal / r.portions * m.portions;
                prot += r.protein / r.portions * m.portions;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(dayNames[d - 1],
                            style: Txt.h2.copyWith(color: d == today ? AppColors.accent : null)),
                      ),
                      if (meals.isNotEmpty)
                        Text(trf('{0} / {1} ккал · {2} г белка', [fmtInt(kcal), fmtInt(target.kcal), fmtInt(prot)]),
                            style: Txt.small.copyWith(color: kcal > target.kcal * 1.1 ? AppColors.over : AppColors.muted)),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20, color: AppColors.muted),
                        color: AppColors.surface,
                        onSelected: (v) => v == 'copy' ? _copyDay(context, d) : null,
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'copy', child: Text(tr('Этот день — на всю неделю'))),
                        ],
                      ),
                    ]),
                    for (var i = 0; i < meals.length; i++)
                      Row(children: [
                        Expanded(
                          child: Text(
                            byId[meals[i].recipeId] == null
                                ? tr('(рецепт удалён)')
                                : '${byId[meals[i].recipeId]!.name} × ${_portions(meals[i].portions)}',
                            style: Txt.body,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18, color: AppColors.muted),
                          onPressed: () => f.removePlanMeal(d, i),
                        ),
                      ]),
                    TextButton.icon(
                      onPressed: () => _addMeal(context, d),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(tr('Блюдо')),
                    ),
                  ]),
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
          PrimaryButton(
            products.isEmpty ? tr('Добавь блюда — появится список продуктов') : trf('В список покупок: {0} продуктов', [products.length]),
            icon: Icons.shopping_cart_outlined,
            onPressed: products.isEmpty ? null : () => _toShopping(context),
          ),
          if (products.isNotEmpty) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr('Продукты на неделю'), style: Txt.h2),
                const SizedBox(height: 6),
                for (final p in products)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(children: [
                      Expanded(child: Text(p.name, style: Txt.body)),
                      Text(gramsText(p.grams, gUnit: tr('г'), kgUnit: tr('кг')), style: Txt.small),
                    ]),
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}
