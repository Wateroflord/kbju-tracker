import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import 'common.dart';
import 'item_fields.dart';

Future<T?> showAppSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: child,
    ),
  );
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(top: 10, bottom: 14),
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
        ),
      );
}

/// Смена программы (набор / сушка / поддержание).
Future<void> showGoalSheet(BuildContext context) {
  return showAppSheet(context, Builder(builder: (ctx) {
    final store = StoreScope.of(ctx);
    final current = store.profile?.goal;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          const Text('Программа', style: Txt.h2),
          const SizedBox(height: 4),
          const Text('Нормы КБЖУ пересчитаются автоматически. Смена сохранится в истории.', style: Txt.small),
          const SizedBox(height: 14),
          for (final g in [Goal.bulk, Goal.cut, Goal.maintain])
            OptionTile(
              icon: g.icon,
              title: g.title,
              desc: g.desc,
              selected: g == current,
              onTap: () {
                store.setGoal(g);
                Navigator.pop(ctx);
                showToast(context, 'Программа: ${g.title}');
              },
            ),
        ],
      ),
    );
  }));
}

/// Редактирование записи о еде.
Future<void> showEntryEditor(BuildContext context, FoodEntry e) {
  return showAppSheet(context, EntryEditor(entry: e));
}

class EntryEditor extends StatefulWidget {
  final FoodEntry entry;
  const EntryEditor({super.key, required this.entry});

  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  late final ItemFields f = ItemFields(
    name: widget.entry.name,
    grams: widget.entry.grams,
    kcal: widget.entry.kcal,
    protein: widget.entry.protein,
    fat: widget.entry.fat,
    carbs: widget.entry.carbs,
  );
  late Meal meal = widget.entry.meal;

  @override
  void dispose() {
    f.dispose();
    super.dispose();
  }

  void _save() {
    if (!f.isValid) {
      showToast(context, 'Введи название');
      return;
    }
    StoreScope.read(context).updateEntry(widget.entry.copyWith(
      meal: meal,
      name: f.name.text.trim(),
      grams: f.gramsV,
      kcal: f.kcalV,
      protein: f.proteinV,
      fat: f.fatV,
      carbs: f.carbsV,
    ));
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final ok = await confirm(context, 'Удалить запись?', widget.entry.name, ok: 'Удалить');
    if (!ok || !mounted) return;
    StoreScope.read(context).deleteEntry(widget.entry.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    final photo = store.photoFile(widget.entry.photo);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Row(
            children: [
              const Expanded(child: Text('Запись', style: Txt.h2)),
              Text(fmtDate(parseKey(widget.entry.date)), style: Txt.small),
            ],
          ),
          const SizedBox(height: 14),
          if (photo != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(photo, height: 150, width: double.infinity, fit: BoxFit.cover),
            ),
            const SizedBox(height: 14),
          ],
          Segmented<Meal>(
            values: Meal.values,
            label: (m) => m.title,
            selected: meal,
            onChanged: (m) => setState(() => meal = m),
          ),
          const SizedBox(height: 12),
          ItemFieldsEditor(f: f, onChanged: () => setState(() {})),
          const SizedBox(height: 18),
          Row(
            children: [
              GhostButton('Удалить', icon: Icons.delete_outline, color: AppColors.over, onPressed: _delete),
              const SizedBox(width: 10),
              Expanded(child: PrimaryButton('Сохранить', icon: Icons.check, onPressed: _save)),
            ],
          ),
        ],
      ),
    );
  }
}
