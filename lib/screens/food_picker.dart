import 'package:flutter/material.dart';

import '../food/food_models.dart';
import '../gemini.dart' show AiFoodItem;
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import '../i18n/i18n.dart';

/// Выбор из недавних или избранных продуктов. Возвращает выбранные позиции.
Future<List<AiFoodItem>?> showFoodPicker(BuildContext context, {bool favorites = false}) {
  return showAppSheet<List<AiFoodItem>>(context, _FoodPicker(startFavorites: favorites));
}

class _FoodPicker extends StatefulWidget {
  final bool startFavorites;
  const _FoodPicker({required this.startFavorites});

  @override
  State<_FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<_FoodPicker> {
  late bool fav = widget.startFavorites;
  final search = TextEditingController();
  final picked = <String, FavFood>{}; // norm -> продукт

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final q = search.text.trim().toLowerCase();
    final all = fav ? store.food.favorites : store.recentFoods();
    final list = q.isEmpty ? all : all.where((f) => f.norm.contains(q)).toList();
    final h = MediaQuery.of(context).size.height;

    return SizedBox(
      height: h * 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SheetHandle(),
            Segmented<bool>(
              values: const [false, true],
              label: (v) => v ? tr('Избранное') : tr('Недавние'),
              selected: fav,
              onChanged: (v) => setState(() => fav = v),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              style: Txt.body,
              decoration: fieldDeco(tr('Поиск')).copyWith(prefixIcon: const Icon(Icons.search, color: AppColors.muted)),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          fav
                              ? tr('Пока пусто. Нажми звёздочку у продукта, чтобы добавить его в избранное.')
                              : tr('Здесь появятся продукты, которые ты уже записывал.'),
                          textAlign: TextAlign.center,
                          style: Txt.small,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _tile(store, list[i]),
                    ),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              picked.isEmpty ? tr('Выбери продукты') : trf('Добавить ({0})', [picked.length]),
              icon: Icons.add,
              onPressed: picked.isEmpty
                  ? null
                  : () => Navigator.pop(context, [
                        for (final f in picked.values)
                          AiFoodItem(
                            name: f.name,
                            grams: f.grams,
                            kcal: f.kcal,
                            protein: f.protein,
                            fat: f.fat,
                            carbs: f.carbs,
                          ),
                      ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(AppStore store, FavFood f) {
    final sel = picked.containsKey(f.norm);
    final isFav = store.food.isFavorite(f.name);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      borderColor: sel ? AppColors.accent : null,
      color: sel ? AppColors.accent.withValues(alpha: 0.08) : null,
      onTap: () => setState(() {
        if (sel) {
          picked.remove(f.norm);
        } else {
          picked[f.norm] = f;
        }
      }),
      child: Row(
        children: [
          Icon(sel ? Icons.check_box : Icons.check_box_outline_blank, color: sel ? AppColors.accent : AppColors.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  trf('{0} г · {1} ккал · Б {2} Ж {3} У {4}', [fmt1(f.grams), fmtInt(f.kcal), fmt1(f.protein), fmt1(f.fat), fmt1(f.carbs)]),
                  style: Txt.small.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('Избранное'),
            icon: Icon(isFav ? Icons.star : Icons.star_border, color: isFav ? AppColors.fat : AppColors.muted),
            onPressed: () => store.food.toggleFavorite(FavFood(
              id: store.food.newId('fav'),
              name: f.name,
              grams: f.grams,
              kcal: f.kcal,
              protein: f.protein,
              fat: f.fat,
              carbs: f.carbs,
            )),
          ),
        ],
      ),
    );
  }
}
