import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../food/food_models.dart';
import '../food/off_api.dart';
import '../gemini.dart' show AiFoodItem;
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/sheets.dart';
import '../i18n/i18n.dart';

/// Сканер штрихкода → поиск товара → выбор порции. Возвращает позицию для дневника.
Future<AiFoodItem?> scanBarcodeFlow(BuildContext context) async {
  final code = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
  );
  if (code == null || code.isEmpty || !context.mounted) return null;
  final store = StoreScope.read(context);

  BarcodeProduct? product = store.food.products[code];
  if (product == null) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
    );
    String? err;
    try {
      product = await OpenFoodFacts.lookup(code);
    } on OffException catch (e) {
      err = e.message;
    }
    if (!context.mounted) return null;
    Navigator.of(context, rootNavigator: true).pop();
    if (err != null) {
      showToast(context, err);
      return null;
    }
    if (product != null && product.kcal > 0) store.food.saveProduct(product);
  }
  if (!context.mounted) return null;

  if (product == null || product.kcal <= 0) {
    return showAppSheet<AiFoodItem>(context, ManualProductSheet(code: code, name: product?.name ?? ''));
  }
  return showAppSheet<AiFoodItem>(context, PortionSheet(product: product));
}

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  final controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.upcE],
  );
  bool done = false;
  bool torch = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (done) return;
    for (final b in cap.barcodes) {
      final v = b.rawValue?.trim() ?? '';
      if (RegExp(r'^\d{6,14}$').hasMatch(v)) {
        done = true;
        HapticFeedback.mediumImpact();
        Navigator.pop(context, v);
        return;
      }
    }
  }

  Future<void> _manual() async {
    final ctrl = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(tr('Код с упаковки'), style: Txt.h2),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: Txt.num(18, weight: FontWeight.w600),
          decoration: fieldDeco(tr('Цифры под штрихкодом')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Отмена'), style: const TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(tr('Найти'), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (code != null && code.length >= 6 && mounted) {
      done = true;
      Navigator.pop(context, code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text(tr('Штрихкод'), style: Txt.h2.copyWith(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: tr('Фонарик'),
            icon: Icon(torch ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              controller.toggleTorch();
              setState(() => torch = !torch);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: MobileScanner(controller: controller, onDetect: _onDetect)),
          Center(
            child: Container(
              width: 280,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accent, width: 2),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                Text(
                  tr('Наведи камеру на штрихкод на упаковке'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                GhostButton(tr('Ввести код вручную'), icon: Icons.keyboard_outlined, onPressed: _manual),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Выбор порции товара из базы.
class PortionSheet extends StatefulWidget {
  final BarcodeProduct product;
  const PortionSheet({super.key, required this.product});

  @override
  State<PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<PortionSheet> {
  late final grams = TextEditingController(
      text: fmt1(widget.product.serving > 0 ? widget.product.serving : 100));

  @override
  void dispose() {
    grams.dispose();
    super.dispose();
  }

  double get g => parseNum(grams.text) ?? 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final k = g / 100;
    final presets = <(String, double)>[
      if (p.serving > 0) (trf('Порция {0} г', [fmt1(p.serving)]), p.serving),
      if (p.package > 0 && p.package != p.serving) (trf('Упаковка {0} г', [fmt1(p.package)]), p.package),
      for (final v in const [50.0, 100.0, 200.0]) (trf('{0} г', [fmt1(v)]), v),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Text(p.title, style: Txt.h2),
          const SizedBox(height: 4),
          Text(trf('На 100 г: {0} ккал · Б {1} · Ж {2} · У {3}', [fmtInt(p.kcal), fmt1(p.protein), fmt1(p.fat), fmt1(p.carbs)]),
              style: Txt.small),
          if (p.user) Text(tr('Данные введены тобой'), style: Txt.small.copyWith(color: AppColors.accent2)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final pr in presets)
                Pill(pr.$1, color: (g - pr.$2).abs() < 0.01 ? AppColors.accent : AppColors.accent2,
                    onTap: () => setState(() => grams.text = fmt1(pr.$2))),
            ],
          ),
          const SizedBox(height: 12),
          NumField(grams, tr('Сколько съел'), suffix: tr('г'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),
          AppCard(
            color: AppColors.surface2,
            child: Row(
              children: [
                Expanded(child: Text(trf('{0} ккал', [fmtInt(p.kcal * k)]), style: Txt.num(22, color: AppColors.accent))),
                Text(trf('Б {0} · Ж {1} · У {2}', [fmt1(p.protein * k), fmt1(p.fat * k), fmt1(p.carbs * k)]), style: Txt.small),
              ],
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            tr('Добавить'),
            icon: Icons.add,
            onPressed: g <= 0
                ? null
                : () => Navigator.pop(
                      context,
                      AiFoodItem(
                        name: p.title,
                        grams: g,
                        kcal: _r(p.kcal * k),
                        protein: _r(p.protein * k),
                        fat: _r(p.fat * k),
                        carbs: _r(p.carbs * k),
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

double _r(double v) => (v * 10).round() / 10;

/// Товара нет в базе: ввести КБЖУ с упаковки. Сохраняется, при следующем скане найдётся сразу.
class ManualProductSheet extends StatefulWidget {
  final String code;
  final String name;
  const ManualProductSheet({super.key, required this.code, this.name = ''});

  @override
  State<ManualProductSheet> createState() => _ManualProductSheetState();
}

class _ManualProductSheetState extends State<ManualProductSheet> {
  late final name = TextEditingController(text: widget.name);
  final kcal = TextEditingController();
  final prot = TextEditingController();
  final fat = TextEditingController();
  final carbs = TextEditingController();
  final grams = TextEditingController(text: '100');

  @override
  void dispose() {
    for (final c in [name, kcal, prot, fat, carbs, grams]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final k = parseNum(kcal.text) ?? 0;
    final g = parseNum(grams.text) ?? 0;
    if (name.text.trim().isEmpty || k <= 0 || g <= 0) {
      showToast(context, tr('Заполни название, калории и вес'));
      return;
    }
    final p = BarcodeProduct(
      code: widget.code,
      name: name.text.trim(),
      kcal: k,
      protein: parseNum(prot.text) ?? 0,
      fat: parseNum(fat.text) ?? 0,
      carbs: parseNum(carbs.text) ?? 0,
      user: true,
    );
    StoreScope.read(context).food.saveProduct(p);
    final m = g / 100;
    Navigator.pop(
      context,
      AiFoodItem(
        name: p.name,
        grams: g,
        kcal: _r(p.kcal * m),
        protein: _r(p.protein * m),
        fat: _r(p.fat * m),
        carbs: _r(p.carbs * m),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Text(tr('Товар не найден'), style: Txt.h2),
          const SizedBox(height: 4),
          Text(trf('Код {0}. Перепиши КБЖУ на 100 г с упаковки — в следующий раз товар найдётся сразу.', [widget.code]),
              style: Txt.small),
          const SizedBox(height: 14),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.sentences,
            style: Txt.body,
            decoration: fieldDeco(tr('Название')),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: NumField(kcal, tr('Ккал на 100 г'))),
              const SizedBox(width: 8),
              Expanded(child: NumField(prot, tr('Белки'), suffix: tr('г'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: NumField(fat, tr('Жиры'), suffix: tr('г'))),
              const SizedBox(width: 8),
              Expanded(child: NumField(carbs, tr('Углев.'), suffix: tr('г'))),
            ],
          ),
          const SizedBox(height: 8),
          NumField(grams, tr('Сколько съел'), suffix: tr('г')),
          const SizedBox(height: 14),
          PrimaryButton(tr('Сохранить и добавить'), icon: Icons.check, onPressed: _save),
        ],
      ),
    );
  }
}
