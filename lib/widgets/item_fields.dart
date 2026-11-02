import 'package:flutter/material.dart';

import '../theme.dart';
import '../util.dart';
import 'common.dart';
import '../i18n/i18n.dart';

/// Поля одной позиции еды. При изменении веса КБЖУ пересчитываются пропорционально.
class ItemFields {
  final TextEditingController name;
  final TextEditingController grams;
  final TextEditingController kcal;
  final TextEditingController protein;
  final TextEditingController fat;
  final TextEditingController carbs;
  final TextEditingController fiber;
  final TextEditingController salt;

  /// Позиция пришла от ИИ (при пересчёте заменяется новыми).
  bool ai = false;

  // Значения на 1 грамм — для пропорционального пересчёта.
  double _dk = 0, _dp = 0, _df = 0, _dc = 0, _dfi = 0, _ds = 0;

  ItemFields({
    String name = '',
    double grams = 0,
    double kcal = -1,
    double protein = -1,
    double fat = -1,
    double carbs = -1,
    double fiber = 0,
    double salt = 0,
  })  : name = TextEditingController(text: name),
        grams = TextEditingController(text: grams > 0 ? fmt1(grams) : ''),
        kcal = TextEditingController(text: _show(kcal)),
        protein = TextEditingController(text: _show(protein)),
        fat = TextEditingController(text: _show(fat)),
        carbs = TextEditingController(text: _show(carbs)),
        fiber = TextEditingController(text: fiber > 0 ? fmt1(fiber) : ''),
        salt = TextEditingController(text: salt > 0 ? fmt1(salt) : '') {
    _updateDensity();
  }

  /// Отрицательное значение — пустое поле (для ручного ввода).
  static String _show(double v) => v < 0 ? '' : fmt1(v);

  double get gramsV => parseNum(grams.text) ?? 0;
  double get kcalV => parseNum(kcal.text) ?? 0;
  double get proteinV => parseNum(protein.text) ?? 0;
  double get fatV => parseNum(fat.text) ?? 0;
  double get carbsV => parseNum(carbs.text) ?? 0;
  double get fiberV => parseNum(fiber.text) ?? 0;
  double get saltV => parseNum(salt.text) ?? 0;

  bool get isValid => name.text.trim().isNotEmpty;

  void _updateDensity() {
    final g = gramsV;
    if (g <= 0) return;
    _dk = kcalV / g;
    _dp = proteinV / g;
    _df = fatV / g;
    _dc = carbsV / g;
    _dfi = fiberV / g;
    _ds = saltV / g;
  }

  void onGramsChanged() {
    final g = gramsV;
    if (g <= 0) return;
    if (_dk == 0 && _dp == 0 && _df == 0 && _dc == 0) return;
    kcal.text = fmt1(_dk * g);
    protein.text = fmt1(_dp * g);
    fat.text = fmt1(_df * g);
    carbs.text = fmt1(_dc * g);
    if (_dfi > 0) fiber.text = fmt1(_dfi * g);
    if (_ds > 0) salt.text = fmt1(_ds * g);
  }

  void onMacroChanged() => _updateDensity();

  void dispose() {
    name.dispose();
    grams.dispose();
    kcal.dispose();
    protein.dispose();
    fat.dispose();
    carbs.dispose();
    fiber.dispose();
    salt.dispose();
  }
}

class ItemFieldsEditor extends StatelessWidget {
  final ItemFields f;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final bool? favorite;
  final VoidCallback? onFavorite;

  const ItemFieldsEditor({
    super.key,
    required this.f,
    required this.onChanged,
    this.onRemove,
    this.favorite,
    this.onFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: f.name,
                onChanged: (_) => onChanged(),
                textCapitalization: TextCapitalization.sentences,
                style: Txt.body.copyWith(fontWeight: FontWeight.w600),
                decoration: fieldDeco(tr('Название')),
              ),
            ),
            if (onFavorite != null)
              IconButton(
                onPressed: onFavorite,
                icon: Icon(favorite == true ? Icons.star : Icons.star_border,
                    color: favorite == true ? AppColors.fat : AppColors.muted),
                tooltip: tr('Избранное'),
              ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, color: AppColors.muted),
                tooltip: tr('Убрать'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NumField(f.grams, tr('Вес'), suffix: tr('г'), onChanged: (_) {
                f.onGramsChanged();
                onChanged();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumField(f.kcal, tr('Калории'), suffix: tr('ккал'), onChanged: (_) {
                f.onMacroChanged();
                onChanged();
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NumField(f.protein, tr('Белки'), suffix: tr('г'), onChanged: (_) {
                f.onMacroChanged();
                onChanged();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumField(f.fat, tr('Жиры'), suffix: tr('г'), onChanged: (_) {
                f.onMacroChanged();
                onChanged();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumField(f.carbs, tr('Углев.'), suffix: tr('г'), onChanged: (_) {
                f.onMacroChanged();
                onChanged();
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NumField(f.fiber, tr('Клетчатка'), suffix: tr('г'), onChanged: (_) {
                f.onMacroChanged();
                onChanged();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumField(f.salt, tr('Соль'), suffix: tr('г'), onChanged: (_) {
                f.onMacroChanged();
                onChanged();
              }),
            ),
          ],
        ),
      ],
    );
  }
}
