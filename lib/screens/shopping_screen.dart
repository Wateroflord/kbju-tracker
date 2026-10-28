import 'package:flutter/material.dart';

import '../life/content.dart';
import '../life/models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/habit_row.dart';
import '../widgets/nav.dart';
import '../i18n/i18n.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  static String price(ShopItem s) {
    if (s.pricePln <= 0) return '';
    final max = s.pricePlnMax;
    final pln = max != null && max > s.pricePln ? '${fmtInt(s.pricePln)}–${fmtInt(max)} zł' : '${fmt1(s.pricePln)} zł';
    final usdMin = s.pricePln / plnPerUsd;
    final usd = max != null && max > s.pricePln
        ? '\$${fmtInt(usdMin)}–${fmtInt(max / plnPerUsd)}'
        : '≈ \$${fmt1(usdMin)}';
    return '$pln · $usd';
  }

  Future<void> _edit(BuildContext context, ShopItem? item) async {
    final store = StoreScope.read(context);
    final name = TextEditingController(text: item == null ? '' : tr(item.name));
    final pr = TextEditingController(text: item == null || item.pricePln <= 0 ? '' : fmt1(item.pricePln));
    final note = TextEditingController(text: item == null ? '' : tr(item.note));
    final cat = TextEditingController(text: item == null ? tr('Разное') : tr(item.category));
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(item == null ? tr('Новый товар') : tr('Товар'), style: Txt.h2),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, style: Txt.body, textCapitalization: TextCapitalization.sentences, decoration: fieldDeco(tr('Название'))),
              const SizedBox(height: 8),
              NumField(pr, tr('Цена'), suffix: 'zł'),
              const SizedBox(height: 8),
              TextField(controller: cat, style: Txt.body, textCapitalization: TextCapitalization.sentences, decoration: fieldDeco(tr('Категория'))),
              const SizedBox(height: 8),
              TextField(controller: note, style: Txt.body, textCapitalization: TextCapitalization.sentences, decoration: fieldDeco(tr('Заметка'))),
            ],
          ),
        ),
        actions: [
          if (item != null)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'delete'),
              child: Text(tr('Удалить'), style: TextStyle(color: AppColors.over)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(tr('Отмена'), style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(tr('Сохранить'), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    final n = name.text.trim(), p = parseNum(pr.text) ?? 0, nt = note.text.trim(), c = cat.text.trim();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      name.dispose();
      pr.dispose();
      note.dispose();
      cat.dispose();
    });
    if (res == 'delete' && item != null) {
      store.life.deleteShopItem(item.id);
    } else if (res == 'save' && n.isNotEmpty) {
      store.life.saveShopItem(ShopItem(
        id: item?.id ?? store.life.newId('shop'),
        category: c.isEmpty ? tr('Разное') : c,
        name: n,
        pricePln: p,
        pricePlnMax: (item != null && item.pricePln == p) ? item.pricePlnMax : null,
        note: nt,
        bought: item?.bought ?? false,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final items = store.life.shopping;
    final cats = <String>[];
    for (final s in items) {
      if (!cats.contains(s.category)) cats.add(s.category);
    }
    final left = items.where((s) => !s.bought).fold<double>(0, (a, s) => a + s.pricePln);

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Список покупок')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Row(
            children: [
              Expanded(child: StatTile(label: tr('Осталось купить'), value: '${items.where((s) => !s.bought).length}', sub: tr('позиций'))),
              const SizedBox(width: 8),
              Expanded(
                child: StatTile(
                  label: tr('Примерно'),
                  value: '${fmtInt(left)} zł',
                  sub: '≈ \$${fmtInt(left / plnPerUsd)}',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          for (final c in cats) ...[
            SectionLabel(tr(c)),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final s in items.where((x) => x.category == c))
                    InkWell(
                      onTap: () => store.life.toggleBought(s.id),
                      onLongPress: () => _edit(context, s),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                        child: Row(
                          children: [
                            CheckMark(done: s.bought),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tr(s.name),
                                    style: Txt.body.copyWith(
                                      fontSize: 13.5,
                                      color: s.bought ? AppColors.muted : AppColors.text,
                                      decoration: s.bought ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                  if (price(s).isNotEmpty || s.note.isNotEmpty)
                                    Text(
                                      [price(s), tr(s.note)].where((x) => x.isNotEmpty).join(' · '),
                                      style: Txt.small.copyWith(fontSize: 11.5),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _edit(context, s),
                              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            tr('Цены — ориентир из польских интернет-аптек и магазинов на октябрь 2026, доллары по курсу ~3,6 zł. Нажми на товар, чтобы отметить покупку, на карандаш — чтобы изменить.'),
            style: Txt.small,
          ),
        ],
      ),
    );
  }
}
