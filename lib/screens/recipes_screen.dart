import 'package:flutter/material.dart';

import '../food/food_models.dart';
import '../gemini.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/item_fields.dart';
import '../widgets/nav.dart';
import '../widgets/sheets.dart';
import '../i18n/i18n.dart';
import 'barcode_screen.dart';
import 'food_picker.dart';

/// Рецепт как одна позиция еды на [grams] граммов готового блюда.
AiFoodItem recipeItem(Recipe r, double grams) {
  final base = AiFoodItem(
    name: r.name,
    grams: r.weight,
    kcal: r.kcal,
    protein: r.protein,
    fat: r.fat,
    carbs: r.carbs,
    fiber: r.fiber,
    salt: r.salt,
  );
  return base.scaled(grams);
}

/// Список своих рецептов.
class RecipesScreen extends StatelessWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.food.recipes;
    void open([Recipe? r]) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipeEditorScreen(recipe: r)));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Рецепты')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new_recipe',
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => open(),
        icon: const Icon(Icons.add),
        label: Text(tr('Новый рецепт'), style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        children: [
          Text(
            tr('Собери блюдо из ингредиентов (борщ, плов, сырники) — приложение посчитает КБЖУ на 100 г. Потом добавляй его в дневник одним нажатием по весу порции.'),
            style: Txt.small,
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            AppCard(
              onTap: () => open(),
              child: Row(
                children: [
                  const Icon(Icons.menu_book_outlined, color: AppColors.muted),
                  const SizedBox(width: 12),
                  Expanded(child: Text(tr('Рецептов пока нет. Нажми, чтобы создать первый.'), style: Txt.small)),
                ],
              ),
            ),
          for (final r in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecipeTile(recipe: r, onTap: () => open(r)),
            ),
        ],
      ),
    );
  }
}

class RecipeTile extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final Widget? trailing;
  const RecipeTile({super.key, required this.recipe, required this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final r = recipe;
    final k = r.factor(100);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.menu_book_outlined, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  trf('100 г: {0} ккал · Б {1} Ж {2} У {3}', [fmtInt(r.kcal * k), fmt1(r.protein * k), fmt1(r.fat * k), fmt1(r.carbs * k)]),
                  style: Txt.small.copyWith(fontSize: 11.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  trf('{0} ингр. · {1} порц. по {2} г', [r.items.length, r.portions, fmtInt(r.portionGrams)]),
                  style: Txt.small.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          trailing ?? const Icon(Icons.chevron_right, color: AppColors.muted),
        ],
      ),
    );
  }
}

/// Создание и редактирование рецепта.
class RecipeEditorScreen extends StatefulWidget {
  final Recipe? recipe;
  const RecipeEditorScreen({super.key, this.recipe});

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  late final name = TextEditingController(text: widget.recipe?.name ?? '');
  late final portions = TextEditingController(text: '${widget.recipe?.portions ?? 1}');
  late final cooked = TextEditingController(
      text: (widget.recipe?.cookedGrams ?? 0) > 0 ? fmt1(widget.recipe!.cookedGrams) : '');
  final aiText = TextEditingController();
  late List<ItemFields> items = [
    for (final i in widget.recipe?.items ?? const <RecipeIngredient>[])
      ItemFields(
        name: i.name,
        grams: i.grams,
        kcal: i.kcal,
        protein: i.protein,
        fat: i.fat,
        carbs: i.carbs,
        fiber: i.fiber,
        salt: i.salt,
      ),
  ];
  bool aiLoading = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    portions.dispose();
    cooked.dispose();
    aiText.dispose();
    for (final i in items) {
      i.dispose();
    }
    super.dispose();
  }

  void _add(List<AiFoodItem> list) {
    if (list.isEmpty) return;
    setState(() {
      items = [
        ...items,
        for (final i in list)
          ItemFields(
              name: i.name, grams: i.grams, kcal: i.kcal, protein: i.protein, fat: i.fat, carbs: i.carbs, fiber: i.fiber, salt: i.salt),
      ];
      error = null;
    });
  }

  void _remove(ItemFields f) {
    setState(() => items = items.where((x) => x != f).toList());
    WidgetsBinding.instance.addPostFrameCallback((_) => f.dispose());
  }

  Future<void> _ai() async {
    final store = StoreScope.read(context);
    final text = aiText.text.trim();
    if (text.isEmpty) {
      setState(() => error = tr('Перечисли ингредиенты с весом, например: курица 500 г, рис 200 г, масло 1 ст. л.'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      aiLoading = true;
      error = null;
    });
    try {
      final r = await GeminiService.analyze(
        apiKey: store.apiKey,
        model: store.model,
        hint: 'These are raw ingredients of one home-made recipe. Return every ingredient as a separate item '
            'with its raw weight. Ingredients: $text',
      );
      if (!mounted) return;
      _add(r.items);
      if (r.items.isEmpty) setState(() => error = r.note.isEmpty ? tr('ИИ не нашёл ингредиентов') : r.note);
      aiText.clear();
    } on GeminiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = trf('Ошибка: {0}', [e]));
    } finally {
      if (mounted) setState(() => aiLoading = false);
    }
  }

  Recipe? _build() {
    final valid = items.where((i) => i.isValid && i.gramsV > 0).toList();
    if (name.text.trim().isEmpty) {
      showToast(context, tr('Введи название рецепта'));
      return null;
    }
    if (valid.isEmpty) {
      showToast(context, tr('Добавь хотя бы один ингредиент с весом'));
      return null;
    }
    return Recipe(
      id: widget.recipe?.id ?? StoreScope.read(context).food.newId('recipe'),
      name: name.text.trim(),
      items: [
        for (final i in valid)
          RecipeIngredient(
            name: i.name.text.trim(),
            grams: i.gramsV,
            kcal: i.kcalV,
            protein: i.proteinV,
            fat: i.fatV,
            carbs: i.carbsV,
            fiber: i.fiberV,
            salt: i.saltV,
          ),
      ],
      cookedGrams: parseNum(cooked.text) ?? 0,
      portions: (parseNum(portions.text) ?? 1).round().clamp(1, 50).toInt(),
    );
  }

  void _save() {
    final r = _build();
    if (r == null) return;
    StoreScope.read(context).food.saveRecipe(r);
    showToast(context, tr('Рецепт сохранён'));
    Navigator.pop(context);
  }

  void _delete() {
    final old = widget.recipe;
    if (old == null) return;
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final removed = store.food.deleteRecipe(old.id);
    Navigator.pop(context);
    if (removed != null && messenger != null) {
      showUndoToast(messenger, trf('Удалено: {0}', [removed.name]), () => store.food.restoreRecipe(removed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final hasKey = store.apiKey.isNotEmpty;
    double g = 0, k = 0, p = 0, f = 0, c = 0;
    for (final i in items) {
      g += i.gramsV;
      k += i.kcalV;
      p += i.proteinV;
      f += i.fatV;
      c += i.carbsV;
    }
    final cookedG = parseNum(cooked.text) ?? 0;
    final weight = cookedG > 0 ? cookedG : g;
    final m = weight > 0 ? 100 / weight : 0.0;
    final por = (parseNum(portions.text) ?? 1).round().clamp(1, 50);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(widget.recipe == null ? tr('Новый рецепт') : tr('Рецепт'), actions: [
        if (widget.recipe != null)
          IconButton(
            tooltip: tr('Удалить'),
            icon: const Icon(Icons.delete_outline, color: AppColors.over),
            onPressed: _delete,
          ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.sentences,
            style: Txt.body.copyWith(fontWeight: FontWeight.w700),
            decoration: fieldDeco(tr('Название'), hint: tr('например: Плов с курицей')),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: NumField(portions, tr('Порций'), onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: NumField(cooked, tr('Вес готового блюда'), suffix: tr('г'), onChanged: (_) => setState(() {})),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tr('Вес готового блюда необязателен. Если взвесишь кастрюлю после варки (без её веса), КБЖУ на 100 г будет точнее: вода выкипает, крупы набухают.'),
            style: Txt.small.copyWith(fontSize: 11.5),
          ),
          SectionLabel(tr('Ингредиенты')),
          if (hasKey) ...[
            TextField(
              controller: aiText,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: Txt.body,
              decoration: fieldDeco(tr('Перечисли ингредиенты — ИИ посчитает'),
                  hint: tr('курица 500 г, рис 300 г, морковь 2 шт, масло 2 ст. л.')),
            ),
            const SizedBox(height: 8),
            PrimaryButton(tr('Посчитать ингредиенты'), icon: Icons.auto_awesome, loading: aiLoading, onPressed: _ai),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: GhostButton(tr('Вручную'), icon: Icons.edit_note, onPressed: () => setState(() => items = [...items, ItemFields()])),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton(tr('Мои'), icon: Icons.history, onPressed: () async {
                  final l = await showFoodPicker(context);
                  if (l != null) _add(l);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton(tr('Код'), icon: Icons.qr_code_scanner, onPressed: () async {
                  final it = await scanBarcodeFlow(context);
                  if (it != null) _add([it]);
                }),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(error!, style: Txt.small.copyWith(color: AppColors.over)),
          ],
          const SizedBox(height: 12),
          for (final it in items)
            Padding(
              key: ObjectKey(it),
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ItemFieldsEditor(f: it, onChanged: () => setState(() {}), onRemove: () => _remove(it)),
                ),
              ),
            ),
          if (items.isNotEmpty)
            AppCard(
              color: AppColors.surface2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trf('ВСЁ БЛЮДО · {0} г', [fmtInt(weight)]), style: Txt.label),
                  const SizedBox(height: 4),
                  Text(trf('{0} ккал · Б {1} Ж {2} У {3}', [fmtInt(k), fmt1(p), fmt1(f), fmt1(c)]), style: Txt.body),
                  const SizedBox(height: 10),
                  Text(tr('НА 100 Г'), style: Txt.label),
                  const SizedBox(height: 4),
                  Text(trf('{0} ккал', [fmtInt(k * m)]), style: Txt.num(22, color: AppColors.accent)),
                  Text(trf('Б {0} · Ж {1} · У {2}', [fmt1(p * m), fmt1(f * m), fmt1(c * m)]), style: Txt.small),
                  if (por > 1) ...[
                    const SizedBox(height: 10),
                    Text(trf('ПОРЦИЯ · {0} г', [fmtInt(weight / por)]), style: Txt.label),
                    const SizedBox(height: 4),
                    Text(trf('{0} ккал · Б {1} Ж {2} У {3}', [fmtInt(k / por), fmt1(p / por), fmt1(f / por), fmt1(c / por)]),
                        style: Txt.body),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 14),
          PrimaryButton(tr('Сохранить рецепт'), icon: Icons.check, onPressed: _save),
        ],
      ),
    );
  }
}

/// Выбрать рецепт и вес порции. Возвращает позицию для дневника.
Future<AiFoodItem?> showRecipePicker(BuildContext context) {
  return showAppSheet<AiFoodItem>(context, const _RecipePicker());
}

class _RecipePicker extends StatefulWidget {
  const _RecipePicker();

  @override
  State<_RecipePicker> createState() => _RecipePickerState();
}

class _RecipePickerState extends State<_RecipePicker> {
  Recipe? selected;
  final grams = TextEditingController();

  @override
  void dispose() {
    grams.dispose();
    super.dispose();
  }

  void _pick(Recipe r) {
    setState(() {
      selected = r;
      grams.text = fmtInt(r.portionGrams).replaceAll(' ', '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.food.recipes;
    final r = selected;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Text(r == null ? tr('Рецепты') : r.name, style: Txt.h2),
            const SizedBox(height: 10),
            if (r == null) ...[
              if (list.isEmpty) ...[
                Text(tr('Рецептов пока нет.'), style: Txt.small),
                const SizedBox(height: 10),
                GhostButton(tr('Создать рецепт'), icon: Icons.add, onPressed: () {
                  final nav = Navigator.of(context);
                  nav.pop();
                  nav.push(MaterialPageRoute(builder: (_) => const RecipeEditorScreen()));
                }),
              ],
              Expanded(
                child: ListView(
                  children: [
                    for (final x in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: RecipeTile(recipe: x, onTap: () => _pick(x), trailing: const Icon(Icons.add, color: AppColors.accent)),
                      ),
                  ],
                ),
              ),
            ] else ...[
              Text(tr('Сколько граммов готового блюда ты съел?'), style: Txt.small),
              const SizedBox(height: 10),
              NumField(grams, tr('Вес'), suffix: tr('г'), onChanged: (_) => setState(() {})),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in [0.5, 1.0, 1.5, 2.0])
                    Pill(trf('{0} порц.', [fmt1(n)]),
                        onTap: () => setState(() => grams.text = fmtInt(r.portionGrams * n).replaceAll(' ', ''))),
                ],
              ),
              const SizedBox(height: 12),
              Builder(builder: (_) {
                final g = parseNum(grams.text) ?? 0;
                final it = recipeItem(r, g);
                return AppCard(
                  color: AppColors.surface2,
                  child: Row(
                    children: [
                      Expanded(child: Text(trf('{0} ккал', [fmtInt(it.kcal)]), style: Txt.num(22, color: AppColors.accent))),
                      Text(trf('Б {0} · Ж {1} · У {2}', [fmt1(it.protein), fmt1(it.fat), fmt1(it.carbs)]), style: Txt.small),
                    ],
                  ),
                );
              }),
              const Spacer(),
              Row(
                children: [
                  GhostButton(tr('Назад'), icon: Icons.arrow_back, onPressed: () => setState(() => selected = null)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PrimaryButton(tr('Добавить'), icon: Icons.add, onPressed: () {
                      final g = parseNum(grams.text) ?? 0;
                      if (g <= 0) {
                        showToast(context, tr('Введи вес'));
                        return;
                      }
                      Navigator.pop(context, recipeItem(r, g));
                    }),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
