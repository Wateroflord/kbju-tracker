import 'package:flutter/material.dart';

import '../theme.dart';
import '../util.dart';
import 'common.dart';

/// Поля одной позиции еды. При изменении веса КБЖУ пересчитываются пропорционально.
class ItemFields {
  final TextEditingController name;
  final TextEditingController grams;
  final TextEditingController kcal;
  final TextEditingController protein;
  final TextEditingController fat;
  final TextEditingController carbs;

  // Значения на 1 грамм — для пропорционального пересчёта.
  double _dk = 0, _dp = 0, _df = 0, _dc = 0;

  ItemFields({
    String name = '',
    double grams = 0,
    double kcal = -1,
    double protein = -1,
    double fat = -1,
    double carbs = -1,
  })  : name = TextEditingController(text: name),
        grams = TextEditingController(text: grams > 0 ? fmt1(grams) : ''),
        kcal = TextEditingController(text: _show(kcal)),
        protein = TextEditingController(text: _show(protein)),
        fat = TextEditingController(text: _show(fat)),
        carbs = TextEditingController(text: _show(carbs)) {
    _updateDensity();
  }

  /// Отрицательное значение — пустое поле (для ручного ввода).
  static String _show(double v) => v < 0 ? '' : fmt1(v);

  double get gramsV => parseNum(grams.text) ?? 0;
  double get kcalV => parseNum(kcal.text) ?? 0;
  double get proteinV => parseNum(protein.text) ?? 0;
  double get fatV => parseNum(fat.text) ?? 0;
  double get carbsV => parseNum(carbs.text) ?? 0;

  bool get isValid => name.text.trim().isNotEmpty;

  void _updateDensity() {
    final g = gramsV;
    if (g <= 0) return;
    _dk = kcalV / g;
    _dp = proteinV / g;
    _df = fatV / g;
    _dc = carbsV / g;
  }

  void onGramsChanged() {
    final g = gramsV;
    if (g <= 0) return;
    if (_dk == 0 && _dp == 0 && _df == 0 && _dc == 0) return;
    kcal.text = fmt1(_dk * g);
    protein.text = fmt1(_dp * g);
    fat.text = fmt1(_df * g);
    carbs.text = fmt1(_dc * g);
  }

  void onMacroChanged() => _updateDensity();

  void dispose() {
    name.dispose();
    grams.dispose();
    kcal.dispose();
    protein.dispose();
    fat.dispose();
    carbs.dispose();
  }
}

class ItemFieldsEditor extends StatelessWidget {
  final ItemFields f;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  const ItemFieldsEditor({super.key, required this.f, required this.onChanged, this.onRemove});

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
                decoration: fieldDeco('Название'),
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 6),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, color: AppColors.muted),
                tooltip: 'Убрать',
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NumField(f.grams, 'Вес', suffix: 'г', onChanged: (_) {
                f.onGramsChanged();
                onChanged();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumField(f.kcal, 'Калории', suffix: 'ккал', onChanged: (_) {
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
              child: NumField(f.protein, 'Белки', suffix: 'г', onChanged: (_) {
                f.onMacroChanged();
                onChanged();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumField(f.fat, 'Жиры', suffix: 'г', onChanged: (_) {
                f.onMacroChanged();
                onChanged();
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NumField(f.carbs, 'Углев.', suffix: 'г', onChanged: (_) {
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
