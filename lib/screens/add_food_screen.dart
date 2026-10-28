import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../gemini.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/item_fields.dart';
import '../i18n/i18n.dart';

class AddFoodScreen extends StatefulWidget {
  final DateTime date;
  final Meal meal;
  const AddFoodScreen({super.key, required this.date, required this.meal});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  late Meal meal = widget.meal;
  Uint8List? image;
  final hint = TextEditingController();
  bool loading = false;
  bool saving = false;
  String? error;
  String? note;
  List<ItemFields> items = [];

  @override
  void dispose() {
    hint.dispose();
    for (final i in items) {
      i.dispose();
    }
    super.dispose();
  }

  /// Контроллеры удаляем после кадра, чтобы поля успели отвязаться.
  void _disposeLater(List<ItemFields> list) {
    if (list.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final i in list) {
        i.dispose();
      }
    });
  }

  Future<void> _pick(ImageSource src) async {
    try {
      final x = await ImagePicker().pickImage(
        source: src,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        image = bytes;
        error = null;
      });
      if (StoreScope.read(context).apiKey.isNotEmpty) _analyze();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = trf('Не удалось открыть {0}: {1}', [src == ImageSource.camera ? tr('камеру') : tr('галерею'), e]));
    }
  }

  Future<void> _analyze() async {
    final store = StoreScope.read(context);
    if (image == null && hint.text.trim().isEmpty) {
      setState(() => error = tr('Сделай фото или опиши еду текстом'));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = null;
      note = null;
    });
    try {
      final r = await GeminiService.analyze(
        apiKey: store.apiKey,
        model: store.model,
        image: image,
        hint: hint.text,
      );
      if (!mounted) return;
      final old = items;
      setState(() {
        items = r.items
            .map((i) => ItemFields(
                  name: i.name,
                  grams: i.grams,
                  kcal: i.kcal,
                  protein: i.protein,
                  fat: i.fat,
                  carbs: i.carbs,
                ))
            .toList();
        note = r.note.isEmpty ? null : r.note;
        if (items.isEmpty) error = r.note.isEmpty ? tr('ИИ не нашёл еду на фото') : r.note;
      });
      _disposeLater(old);
    } on GeminiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = trf('Ошибка: {0}', [e]));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _addManual() {
    setState(() => items = [...items, ItemFields()]);
  }

  void _remove(ItemFields f) {
    setState(() => items = items.where((x) => x != f).toList());
    _disposeLater([f]);
  }

  Future<void> _save() async {
    final valid = items.where((i) => i.isValid).toList();
    if (valid.isEmpty) {
      showToast(context, tr('Добавь хотя бы одну позицию с названием'));
      return;
    }
    final store = StoreScope.read(context);
    setState(() => saving = true);
    String? photo;
    if (image != null) photo = await store.savePhoto(image!);
    final now = DateTime.now();
    final d = widget.date;
    final time = DateTime(d.year, d.month, d.day, now.hour, now.minute, now.second).millisecondsSinceEpoch;
    store.addEntries([
      for (var n = 0; n < valid.length; n++)
        FoodEntry(
          id: store.newId(),
          date: dkey(d),
          time: time + n,
          meal: meal,
          name: valid[n].name.text.trim(),
          grams: valid[n].gramsV,
          kcal: valid[n].kcalV,
          protein: valid[n].proteinV,
          fat: valid[n].fatV,
          carbs: valid[n].carbsV,
          photo: photo,
        ),
    ]);
    if (!mounted) return;
    showToast(context, trf('Добавлено позиций: {0}', [valid.length]));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final hasKey = store.apiKey.isNotEmpty;
    double k = 0, p = 0, f = 0, c = 0;
    for (final i in items) {
      k += i.kcalV;
      p += i.proteinV;
      f += i.fatV;
      c += i.carbsV;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(tr('Добавить еду'), style: Txt.h2),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: Text(fmtDate(widget.date), style: Txt.small)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Segmented<Meal>(
            values: Meal.values,
            label: (m) => m.title,
            selected: meal,
            onChanged: (m) => setState(() => meal = m),
          ),
          const SizedBox(height: 14),
          if (!hasKey) ...[
            AppCard(
              borderColor: AppColors.under.withValues(alpha: 0.5),
              child: Row(
                children: [
                  Icon(Icons.key_outlined, color: AppColors.under),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr('Чтобы считать КБЖУ по фото, вставь бесплатный ключ Gemini во вкладке «Профиль». Пока можно добавить еду вручную.'),
                      style: Txt.small,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          _photoBlock(hasKey),
          const SizedBox(height: 12),
          TextField(
            controller: hint,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: Txt.body,
            decoration: fieldDeco(
              image == null ? tr('Или опиши еду текстом') : tr('Уточнение (необязательно)'),
              hint: tr('например: 200 г гречки, куриная грудка 150 г'),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            items.isEmpty ? tr('Рассчитать КБЖУ') : tr('Пересчитать'),
            icon: Icons.auto_awesome,
            loading: loading,
            onPressed: hasKey ? _analyze : null,
          ),
          if (loading) ...[
            const SizedBox(height: 10),
            Center(child: Text(tr('ИИ анализирует еду…'), style: Txt.small)),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            AppCard(
              borderColor: AppColors.over.withValues(alpha: 0.5),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.over, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(error!, style: Txt.small.copyWith(color: AppColors.text))),
                ],
              ),
            ),
          ],
          if (note != null && items.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.accent2, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(note!, style: Txt.small)),
              ],
            ),
          ],
          SectionLabel(
            tr('Позиции'),
            trailing: GestureDetector(
              onTap: _addManual,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: AppColors.accent),
                  SizedBox(width: 4),
                  Text(tr('Вручную'), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
              ),
            ),
          ),
          if (items.isEmpty)
            AppCard(
              onTap: _addManual,
              child: Row(
                children: [
                  Icon(Icons.edit_note, color: AppColors.muted),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tr('Здесь появятся блюда с КБЖУ. Их можно поправить. Или нажми, чтобы ввести вручную.'),
                      style: Txt.small,
                    ),
                  ),
                ],
              ),
            ),
          for (final it in items)
            Padding(
              key: ObjectKey(it),
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ItemFieldsEditor(
                    f: it,
                    onChanged: () => setState(() {}),
                    onRemove: () => _remove(it),
                  ),
                ),
              ),
            ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 6),
            AppCard(
              color: AppColors.surface2,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('ИТОГО'), style: Txt.label),
                        const SizedBox(height: 4),
                        Text(trf('{0} ккал', [fmtInt(k)]), style: Txt.num(22, color: AppColors.accent)),
                      ],
                    ),
                  ),
                  _macro(tr('Б'), p, AppColors.protein),
                  _macro(tr('Ж'), f, AppColors.fat),
                  _macro(tr('У'), c, AppColors.carbs),
                ],
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(tr('Сохранить в дневник'), icon: Icons.check, loading: saving, onPressed: _save),
          ],
        ],
      ),
    );
  }

  Widget _macro(String l, double v, Color c) => Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Column(
          children: [
            Text(l, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(height: 4),
            Text(fmt1(v), style: Txt.num(15)),
          ],
        ),
      );

  Widget _photoBlock(bool hasKey) {
    if (image == null) {
      return Row(
        children: [
          Expanded(child: _bigBtn(Icons.photo_camera_outlined, tr('Камера'), () => _pick(ImageSource.camera))),
          const SizedBox(width: 10),
          Expanded(child: _bigBtn(Icons.photo_library_outlined, tr('Галерея'), () => _pick(ImageSource.gallery))),
        ],
      );
    }
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(image!, height: 220, width: double.infinity, fit: BoxFit.cover),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _iconOver(Icons.photo_camera_outlined, () => _pick(ImageSource.camera)),
              const SizedBox(width: 6),
              _iconOver(Icons.photo_library_outlined, () => _pick(ImageSource.gallery)),
              const SizedBox(width: 6),
              _iconOver(Icons.close, () => setState(() => image = null)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconOver(IconData icon, VoidCallback onTap) => Material(
        color: Colors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
        ),
      );

  Widget _bigBtn(IconData icon, String text, VoidCallback onTap) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
              ),
              child: Icon(icon, color: AppColors.accent, size: 26),
            ),
            const SizedBox(height: 10),
            Text(text, style: Txt.body.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
