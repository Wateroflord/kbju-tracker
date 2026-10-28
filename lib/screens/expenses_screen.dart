import 'package:flutter/material.dart';

import '../food/food_models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../widgets/sheets.dart';
import '../i18n/i18n.dart';

String expenseCategoryTitle(String c) => switch (c) {
      'groceries' => tr('Продукты'),
      'eatout' => tr('Кафе и доставка'),
      'sport' => tr('Спортпит'),
      _ => tr('Другое'),
    };

IconData expenseCategoryIcon(String c) => switch (c) {
      'groceries' => Icons.shopping_basket_outlined,
      'eatout' => Icons.delivery_dining_outlined,
      'sport' => Icons.fitness_center,
      _ => Icons.more_horiz,
    };

String fmtPln(double v) => trf('{0} zł', [fmtInt(v)]);

/// Мини-карточка расходов для вкладки «Питание».
class ExpensesMiniCard extends StatelessWidget {
  const ExpensesMiniCard({super.key});

  @override
  Widget build(BuildContext context) {
    final f = StoreScope.of(context).food;
    final now = DateTime.now();
    final total = f.expensesOfMonth(now.year, now.month).fold<double>(0, (s, e) => s + f.toPln(e));
    final ratio = f.budgetPln > 0 ? total / f.budgetPln : 0.0;
    return AppCard(
      padding: const EdgeInsets.all(12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ExpensesScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 18, color: AppColors.accent2),
              const SizedBox(width: 6),
              Expanded(child: Text(tr('Расходы'), style: Txt.section, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(fmtPln(total), style: Txt.num(20)),
          const SizedBox(height: 2),
          Text(f.budgetPln > 0 ? trf('из {0} за месяц', [fmtPln(f.budgetPln)]) : trf('≈ {0} за месяц', ['\$${fmtInt(total / f.usdRate)}']),
              style: Txt.small, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          ProgressLine(ratio: ratio, color: AppColors.accent2, height: 4),
        ],
      ),
    );
  }
}

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final f = store.food;
    final list = f.expensesOfMonth(month.year, month.month);
    final total = list.fold<double>(0, (s, e) => s + f.toPln(e));
    final byCat = <String, double>{};
    for (final e in list) {
      byCat[e.category] = (byCat[e.category] ?? 0) + f.toPln(e);
    }
    // ккал за месяц — сколько стоит 1000 ккал
    double kcal = 0;
    final p = '${month.year}-${two(month.month)}';
    for (final e in store.entries) {
      if (e.date.startsWith(p)) kcal += e.kcal;
    }
    final now = DateTime.now();
    final isCur = month.year == now.year && month.month == now.month;
    final daysPassed = isCur ? now.day : DateTime(month.year, month.month + 1, 0).day;
    final canNext = DateTime(month.year, month.month + 1, 1).isBefore(DateTime(now.year, now.month + 1, 1));

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Расходы на еду'), actions: [
        IconButton(
          tooltip: tr('Бюджет и курс'),
          icon: const Icon(Icons.tune),
          onPressed: () => _settings(store),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: () => _edit(store, null),
        icon: const Icon(Icons.add),
        label: Text(tr('Расход'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => month = DateTime(month.year, month.month - 1, 1)),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(child: Text('${monthsNom[month.month - 1]} ${month.year}', textAlign: TextAlign.center, style: Txt.section)),
              IconButton(
                onPressed: canNext ? () => setState(() => month = DateTime(month.year, month.month + 1, 1)) : null,
                icon: Icon(Icons.chevron_right, color: canNext ? AppColors.text : AppColors.border),
              ),
            ],
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('ПОТРАЧЕНО'), style: Txt.label),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmtPln(total), style: Txt.num(30, color: AppColors.accent)),
                    const SizedBox(width: 10),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('≈ \$${fmtInt(total / f.usdRate)}', style: Txt.small),
                    ),
                  ],
                ),
                if (f.budgetPln > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(trf('Бюджет {0}', [fmtPln(f.budgetPln)]), style: Txt.small),
                      const Spacer(),
                      Text(
                        total <= f.budgetPln ? trf('осталось {0}', [fmtPln(f.budgetPln - total)]) : trf('перерасход {0}', [fmtPln(total - f.budgetPln)]),
                        style: Txt.small.copyWith(color: total <= f.budgetPln ? AppColors.text : AppColors.over),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressLine(ratio: total / f.budgetPln, color: AppColors.accent2),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatTile(label: tr('В день'), value: fmtPln(daysPassed > 0 ? total / daysPassed : 0))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: StatTile(
                        label: tr('1000 ккал'),
                        value: kcal > 500 ? fmtPln(total / kcal * 1000) : '—',
                        sub: tr('по дневнику еды'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (byCat.isNotEmpty) ...[
            SectionLabel(tr('По категориям')),
            AppCard(
              child: Column(
                children: [
                  for (final c in expenseCategories)
                    if (byCat[c] != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(expenseCategoryIcon(c), size: 18, color: AppColors.accent2),
                                const SizedBox(width: 8),
                                Expanded(child: Text(expenseCategoryTitle(c), style: Txt.body.copyWith(fontSize: 13))),
                                Text(fmtPln(byCat[c]!), style: Txt.num(14)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ProgressLine(ratio: total > 0 ? byCat[c]! / total : 0, color: AppColors.accent, overIsBad: false, height: 4),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ],
          SectionLabel(tr('Записи')),
          if (list.isEmpty)
            Text(tr('За этот месяц расходов нет. Записывай чеки из магазина, кафе и доставку — увидишь, сколько уходит на еду.'),
                style: Txt.small),
          for (final e in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AppCard(
                padding: const EdgeInsets.all(12),
                onTap: () => _edit(store, e),
                child: Row(
                  children: [
                    Icon(expenseCategoryIcon(e.category), size: 20, color: AppColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.note.isEmpty ? expenseCategoryTitle(e.category) : e.note,
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                          Text(fmtDate(parseKey(e.date)), style: Txt.small),
                        ],
                      ),
                    ),
                    Text(e.currency == 'USD' ? '\$${fmt1(e.amount)}' : fmtPln(e.amount), style: Txt.num(15)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(AppStore store, Expense? old) async {
    await showAppSheet<void>(context, _ExpenseForm(old: old, month: month));
  }

  Future<void> _settings(AppStore store) async {
    final f = store.food;
    final budget = TextEditingController(text: f.budgetPln > 0 ? fmtInt(f.budgetPln).replaceAll(' ', '') : '');
    final rate = TextEditingController(text: f.usdRate.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(tr('Бюджет и курс'), style: Txt.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NumField(budget, tr('Бюджет на еду в месяц'), suffix: 'zł'),
            const SizedBox(height: 10),
            NumField(rate, tr('Курс: злотых за 1 \$'), suffix: 'zł'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Отмена'), style: const TextStyle(color: AppColors.muted))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Сохранить'), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    final b = parseNum(budget.text) ?? 0;
    final r = parseNum(rate.text) ?? f.usdRate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      budget.dispose();
      rate.dispose();
    });
    if (ok == true) f.setBudget(b, r);
  }
}

class _ExpenseForm extends StatefulWidget {
  final Expense? old;
  final DateTime month;
  const _ExpenseForm({this.old, required this.month});

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late final amount = TextEditingController(text: widget.old == null ? '' : fmt1(widget.old!.amount));
  late final note = TextEditingController(text: widget.old?.note ?? '');
  late String currency = widget.old?.currency ?? 'PLN';
  late String category = widget.old?.category ?? 'groceries';
  late DateTime date = widget.old != null ? parseKey(widget.old!.date) : _defaultDate();

  DateTime _defaultDate() {
    final now = today();
    final m = widget.month;
    if (m.year == now.year && m.month == now.month) return now;
    return DateTime(m.year, m.month + 1, 0);
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void _save() {
    final a = parseNum(amount.text) ?? 0;
    if (a <= 0) {
      showToast(context, tr('Введи сумму'));
      return;
    }
    final f = StoreScope.read(context).food;
    f.saveExpense(Expense(
      id: widget.old?.id ?? f.newId('exp'),
      date: dkey(date),
      amount: a,
      currency: currency,
      category: category,
      note: note.text.trim(),
    ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SheetHandle(),
          Text(widget.old == null ? tr('Новый расход') : tr('Расход'), style: Txt.h2),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 3, child: NumField(amount, tr('Сумма'))),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Segmented<String>(
                  values: const ['PLN', 'USD'],
                  label: (v) => v == 'PLN' ? 'zł' : '\$',
                  selected: currency,
                  onChanged: (v) => setState(() => currency = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in expenseCategories)
                Pill(expenseCategoryTitle(c),
                    icon: expenseCategoryIcon(c),
                    color: c == category ? AppColors.accent : AppColors.accent2,
                    onTap: () => setState(() => category = c)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: note,
            textCapitalization: TextCapitalization.sentences,
            style: Txt.body,
            decoration: fieldDeco(tr('Комментарий'), hint: tr('например: Biedronka, пицца')),
          ),
          const SizedBox(height: 10),
          GhostButton(
            sameDay(date, today()) ? tr('Сегодня') : fmtDate(date, year: true),
            icon: Icons.event,
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: today());
              if (d != null) setState(() => date = dayOnly(d));
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.old != null) ...[
                GhostButton(tr('Удалить'), icon: Icons.delete_outline, color: AppColors.over, onPressed: () {
                  StoreScope.read(context).food.deleteExpense(widget.old!.id);
                  Navigator.pop(context);
                }),
                const SizedBox(width: 10),
              ],
              Expanded(child: PrimaryButton(tr('Сохранить'), icon: Icons.check, onPressed: _save)),
            ],
          ),
        ],
      ),
    );
  }
}
