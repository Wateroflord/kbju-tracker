import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../common/backup_io.dart';
import '../common/ui.dart';
import '../shifts/app.dart' show ShiftStore;
import 'models.dart';

const _accent = Color(0xFFFFD166);
const _months = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
const _monthsGen = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
const _monthsShort = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
const _wd = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];
const _goalEmojis = ['🎯', '📱', '💻', '🎮', '🎸', '👟', '✈️', '🎁', '🏠', '🚗', '💪', '❄️'];

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Бюджет',
        debugShowCheckedModeBanner: false,
        theme: winterTheme(_accent),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const BudgetHome(),
      );
}

/// Хранилище: записи, копилки, лимит на месяц, настройки.
class BudgetStore extends ChangeNotifier {
  static final I = BudgetStore._();
  BudgetStore._();

  /// Траты на еду из КБЖУ за месяц (в злотых). Подключается в connectPluginsToKbju.
  static double Function(int year, int month)? kbjuFood;

  final _file = JsonStore('budget.json');
  bool loaded = false;
  List<Tx> txs = [];
  List<Goal> goals = [];
  List<Recurring> recurring = [];
  Map<String, double> catLimits = {}; // лимиты трат по категориям на месяц
  double limit = 0; // 0 — без лимита
  String currency = 'zł';
  bool useKbjuFood = true;

  Future<void> load() async {
    if (loaded) return;
    fromJson(await _file.read());
    loaded = true;
    await ShiftStore.I.load();
    await applyRecurring();
  }

  /// Создать записи по регулярным платежам, которым пришёл срок.
  Future<int> applyRecurring([DateTime? now]) async {
    if (recurring.isEmpty) return 0;
    final r = dueRecurring(recurring, now ?? DateTime.now());
    final have = {for (final t in txs) t.id};
    final add = r.txs.where((t) => !have.contains(t.id)).toList();
    var changed = add.isNotEmpty;
    for (var i = 0; i < recurring.length; i++) {
      if (r.recurring[i].last != recurring[i].last) changed = true;
    }
    recurring = r.recurring;
    if (add.isNotEmpty) txs = [...txs, ...add];
    if (changed) await save();
    return add.length;
  }

  /// Превышен ли лимит категории [cat] в месяце [year]/[month]: (потрачено, лимит) или null.
  ({double spent, double limit})? overLimit(String cat, int year, int month) =>
      overLimits(monthOf(year, month), {if (catLimits[cat] != null) cat: catLimits[cat]!})[cat];

  void fromJson(Map<String, dynamic> j) {
    txs = (j['txs'] as List? ?? []).map(Tx.fromJson).whereType<Tx>().toList();
    goals = (j['goals'] as List? ?? []).map(Goal.fromJson).whereType<Goal>().toList();
    recurring = (j['rec'] as List? ?? []).map(Recurring.fromJson).whereType<Recurring>().toList();
    catLimits = {
      for (final e in ((j['catLimits'] as Map?) ?? const {}).entries)
        if (e.value is num && (e.value as num) > 0) '${e.key}': (e.value as num).toDouble(),
    };
    limit = (j['limit'] as num?)?.toDouble() ?? 0;
    currency = j['currency']?.toString() ?? 'zł';
    useKbjuFood = j['kbjuFood'] != false;
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'txs': [for (final t in txs) t.toJson()],
        'goals': [for (final g in goals) g.toJson()],
        'rec': [for (final r in recurring) r.toJson()],
        'catLimits': catLimits,
        'limit': limit,
        'currency': currency,
        'kbjuFood': useKbjuFood,
      };

  Future<void> save() async {
    txs.sort((a, b) => b.day.compareTo(a.day));
    notifyListeners();
    await _file.write(toJson());
  }

  String id() => '${DateTime.now().microsecondsSinceEpoch}';

  /// Еда из КБЖУ за месяц (0, если выключено или нет данных).
  double kbjuFoodOf(int year, int month) {
    if (!useKbjuFood) return 0;
    try {
      return kbjuFood?.call(year, month) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  BudgetMonth monthOf(int year, int month) =>
      summarizeMonth(txs, year, month, extraExpense: {kbjuFoodCat.id: kbjuFoodOf(year, month)});

  /// Заработок по сменам за месяц («на руки», если в «Сменах» выбран расчёт, иначе брутто).
  double shiftsIncome(int year, int month) {
    final s = ShiftStore.I;
    if (!s.loaded) return 0;
    final sum = s.summaryFor(year, month);
    return s.showsNet ? sum.netto : sum.brutto;
  }

  static String shiftsTxId(int year, int month) => 'shifts-$year-${month.toString().padLeft(2, '0')}';

  Tx? shiftsTx(int year, int month) {
    final id = shiftsTxId(year, month);
    for (final t in txs) {
      if (t.id == id) return t;
    }
    return null;
  }
}

String _money(double v) => '${money(v)} ${BudgetStore.I.currency}';

String _short(double v) {
  final r = v.round();
  final s = r.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '${r < 0 ? '−' : ''}$b';
}

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');

String _dayTitle(String day) {
  final d = parseDay(day);
  final n = DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final diff = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == -1) return 'Вчера';
  return '${d.day} ${_monthsGen[d.month - 1]}, ${_wd[d.weekday - 1]}';
}

class BudgetHome extends StatefulWidget {
  const BudgetHome({super.key});

  @override
  State<BudgetHome> createState() => _BudgetHomeState();
}

class _BudgetHomeState extends State<BudgetHome> {
  final st = BudgetStore.I;
  late DateTime month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    month = DateTime(n.year, n.month);
    st.addListener(_changed);
    st.load().then((_) => st.applyRecurring()).then((_) => _changed());
  }

  @override
  void dispose() {
    st.removeListener(_changed);
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  Future<void> _edit({Tx? tx, bool income = false}) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TxEditor(tx: tx, income: income, month: month)),
      );

  Future<void> _addShiftsIncome(double amount) async {
    final have = st.shiftsTx(month.year, month.month);
    final n = DateTime.now();
    final last = DateTime(month.year, month.month + 1, 0);
    final day = (n.year == month.year && n.month == month.month) ? DateTime(n.year, n.month, n.day) : last;
    final t = Tx(
      id: BudgetStore.shiftsTxId(month.year, month.month),
      day: dayKey(day),
      amount: (amount * 100).roundToDouble() / 100,
      cat: 'salary',
      income: true,
      note: 'По сменам за ${_months[month.month - 1].toLowerCase()}',
    );
    st.txs = [for (final x in st.txs) if (x.id != t.id) x, t];
    await st.save();
    if (mounted) toast(context, have == null ? 'Зарплата записана в доходы' : 'Сумма обновлена');
  }

  @override
  Widget build(BuildContext context) {
    if (!st.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final sum = st.monthOf(month.year, month.month);
    final now = DateTime.now();
    final perDay = perDayLeft(st.limit, sum.expense, month.year, month.month, now);
    final shifts = st.shiftsIncome(month.year, month.month);
    final shiftsTx = st.shiftsTx(month.year, month.month);
    final days = byDay(st.txs, month.year, month.month);
    final kbju = st.kbjuFoodOf(month.year, month.month);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Бюджет'),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BudgetSettings())),
          ),
        ],
      ),
      floatingActionButton: Row(mainAxisSize: MainAxisSize.min, children: [
        FloatingActionButton.extended(
          heroTag: 'budget-in',
          backgroundColor: W.surface2,
          foregroundColor: W.good,
          onPressed: () => _edit(income: true),
          icon: const Icon(Icons.add),
          label: const Text('Доход'),
        ),
        const SizedBox(width: 10),
        FloatingActionButton.extended(
          heroTag: 'budget-out',
          onPressed: () => _edit(),
          icon: const Icon(Icons.remove),
          label: const Text('Трата'),
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 110), children: [
        Row(children: [
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text('${_months[month.month - 1]} ${month.year}', style: W.h2, textAlign: TextAlign.center)),
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
        ]),
        WCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _stat('Доходы', _short(sum.income), W.good),
              _stat('Расходы', _short(sum.expense), W.bad),
              _stat('Остаток', _short(sum.balance), sum.balance >= 0 ? W.text : W.bad),
            ]),
            if (st.limit > 0) ...[
              const Divider(height: 22, color: W.border),
              Row(children: [
                Expanded(child: Text('Лимит на месяц: ${_money(st.limit)}', style: W.small)),
                Text('${(sum.expense / st.limit * 100).round()}%', style: W.small),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (sum.expense / st.limit).clamp(0, 1).toDouble(),
                  minHeight: 8,
                  backgroundColor: W.border,
                  color: sum.expense > st.limit ? W.bad : (sum.expense > st.limit * 0.8 ? W.warn : W.accent),
                ),
              ),
              if (perDay != null) ...[
                const SizedBox(height: 8),
                Text(
                  sum.expense >= st.limit
                      ? 'Лимит превышен на ${_money(sum.expense - st.limit)}'
                      : 'Можно тратить ≈ ${_money(perDay)} в день до конца месяца',
                  style: W.body.copyWith(color: sum.expense >= st.limit ? W.bad : W.text),
                ),
              ],
            ],
          ]),
        ),
        if (shifts > 0) ...[
          const SizedBox(height: 10),
          WCard(
            child: Row(children: [
              const Text('💼', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('По сменам заработано ≈ ${_money(shifts)}', style: W.body),
                  Text(
                    shiftsTx == null
                        ? 'Из плагина «Смены». Запиши в доходы, когда придёт зарплата.'
                        : (shiftsTx.amount - shifts).abs() < 0.01
                            ? 'Уже записано в доходы ✓'
                            : 'В доходах ${_money(shiftsTx.amount)} — смены изменились',
                    style: W.small,
                  ),
                ]),
              ),
              if (shiftsTx == null || (shiftsTx.amount - shifts).abs() >= 0.01)
                TextButton(onPressed: () => _addShiftsIncome(shifts), child: Text(shiftsTx == null ? 'В доходы' : 'Обновить')),
            ]),
          ),
        ],
        if (sum.byCat.isNotEmpty) ...[
          const Section('Куда ушли деньги'),
          WCard(
            child: Column(children: [
              for (final e in sum.topCats) _catRow(catById(e.key), e.value, sum.expense, kbju: e.key == kbjuFoodCat.id),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Нажми на категорию, чтобы поставить ей лимит на месяц', style: W.small),
              ),
            ]),
          ),
        ],
        _History(txs: st.txs, month: month),
        Section(
          'Копилки',
          trailing: TextButton.icon(onPressed: () => _goalEditor(context), icon: const Icon(Icons.add, size: 18), label: const Text('Новая')),
        ),
        if (st.goals.isEmpty)
          WCard(
            onTap: () => _goalEditor(context),
            child: const Row(children: [
              Text('🎯', style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Expanded(child: Text('Копишь на что-то? Создай копилку — будет видно, сколько осталось и когда накопишь.', style: W.small)),
            ]),
          )
        else
          for (final g in st.goals) _GoalCard(goal: g, monthBalance: sum.balance),
        Section('Записи', trailing: Text('${days.fold<int>(0, (s, e) => s + e.value.length)}', style: W.small)),
        if (days.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Center(child: Text('В этом месяце записей нет.\nНажми «Трата» или «Доход».', style: W.small, textAlign: TextAlign.center)),
          )
        else
          for (final d in days) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
              child: Row(children: [
                Expanded(child: Text(_dayTitle(d.key), style: W.small.copyWith(color: W.text, fontWeight: FontWeight.w600))),
                Text(_dayTotal(d.value), style: W.small),
              ]),
            ),
            for (final t in d.value) _txTile(t),
          ],
      ]),
    );
  }

  String _dayTotal(List<Tx> l) {
    final out = l.where((t) => !t.income).fold<double>(0, (s, t) => s + t.amount);
    return out > 0 ? '−${_short(out)}' : '';
  }

  Widget _stat(String label, String value, Color c) => Expanded(
        child: Column(children: [
          FittedBox(child: Text(value, style: W.h2.copyWith(fontSize: 19, color: c))),
          const SizedBox(height: 2),
          Text(label, style: W.small),
        ]),
      );

  Widget _catRow(BudgetCat c, double v, double total, {bool kbju = false}) {
    final lim = st.catLimits[c.id] ?? 0;
    final over = lim > 0 && v > lim;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => editCatLimit(context, c),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(c.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(child: Text(c.name, style: W.body)),
            Text(
              lim > 0 ? '${money(v)} / ${_money(lim)}' : _money(v),
              style: W.body.copyWith(color: over ? W.bad : W.text),
            ),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: lim > 0 ? (v / lim).clamp(0, 1).toDouble() : (total <= 0 ? 0 : (v / total).clamp(0, 1).toDouble()),
              minHeight: 5,
              backgroundColor: W.border,
              color: over ? W.bad : (lim > 0 && v > lim * 0.8 ? W.warn : Color(c.color)),
            ),
          ),
          if (over)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('Лимит превышен на ${_money(v - lim)}', style: W.small.copyWith(color: W.bad)),
            ),
          if (kbju) const Padding(padding: EdgeInsets.only(top: 3), child: Text('Записано в КБЖУ → «Расходы»', style: W.small)),
        ]),
      ),
    );
  }

  Widget _txTile(Tx t) {
    final c = catById(t.cat);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Dismissible(
        key: ValueKey(t.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(color: W.bad.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(14)),
          child: const Icon(Icons.delete_outline, color: W.bad),
        ),
        onDismissed: (_) {
          st.txs = [for (final x in st.txs) if (x.id != t.id) x];
          st.save();
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: const Text('Запись удалена'),
              action: SnackBarAction(label: 'Вернуть', onPressed: () {
                st.txs = [...st.txs, t];
                st.save();
              }),
            ));
        },
        child: WCard(
          onTap: () => _edit(tx: t),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Color(c.color).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
              child: Text(c.emoji, style: const TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.note.isEmpty ? c.name : t.note, style: W.body, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (t.note.isNotEmpty) Text(c.name, style: W.small),
              ]),
            ),
            Text(
              '${t.income ? '+' : '−'}${money(t.amount)}',
              style: W.body.copyWith(color: t.income ? W.good : W.text, fontWeight: FontWeight.w600),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Траты за последние 6 месяцев — столбики.
class _History extends StatelessWidget {
  final List<Tx> txs;
  final DateTime month;
  const _History({required this.txs, required this.month});

  @override
  Widget build(BuildContext context) {
    final st = BudgetStore.I;
    final vals = <double>[];
    final labels = <String>[];
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(month.year, month.month - i);
      vals.add(st.monthOf(d.year, d.month).expense);
      labels.add(_monthsShort[d.month - 1]);
    }
    if (vals.where((v) => v > 0).length < 2) return const SizedBox.shrink();
    final max = vals.reduce((a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Section('Расходы по месяцам'),
      WCard(
        child: SizedBox(
          height: 130,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < vals.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    if (vals[i] > 0) FittedBox(child: Text(_short(vals[i]), style: W.small)),
                    const SizedBox(height: 4),
                    Container(
                      height: max <= 0 ? 2 : 2 + 80 * vals[i] / max,
                      decoration: BoxDecoration(
                        color: i == vals.length - 1 ? W.accent : W.accent.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i], style: W.small),
                  ]),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
}

/// Поставить / убрать лимит трат категории на месяц.
Future<void> editCatLimit(BuildContext context, BudgetCat c) async {
  final st = BudgetStore.I;
  final cur = st.catLimits[c.id] ?? 0;
  final ctl = TextEditingController(text: cur > 0 ? _num(cur) : '');
  final r = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text('${c.emoji} ${c.name}'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Сколько можно тратить на это в месяц?', style: W.small),
        const SizedBox(height: 10),
        TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Лимит', border: const OutlineInputBorder(), suffixText: st.currency),
          onSubmitted: (v) => Navigator.pop(d, v),
        ),
      ]),
      actions: [
        if (cur > 0) TextButton(onPressed: () => Navigator.pop(d, ''), child: const Text('Убрать лимит')),
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(d, ctl.text), child: const Text('Готово')),
      ],
    ),
  );
  if (r == null) return;
  final v = parseAmount(r);
  st.catLimits = {...st.catLimits}..remove(c.id);
  if (v != null) st.catLimits[c.id] = v;
  await st.save();
}

// ───────────────────────────── Копилки ─────────────────────────────

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final double monthBalance;
  const _GoalCard({required this.goal, required this.monthBalance});

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final eta = monthsToGoal(g, monthBalance);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WCard(
        onTap: () => _goalMoney(context, g),
        borderColor: g.done ? W.good : null,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(g.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Text(g.name, style: W.h2)),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.more_horiz, color: W.muted),
              onPressed: () => _goalEditor(context, goal: g),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: g.progress, minHeight: 8, backgroundColor: W.border, color: g.done ? W.good : W.accent),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: Text('${_money(g.saved)} из ${_money(g.target)}', style: W.small)),
            Text('${(g.progress * 100).round()}%', style: W.small.copyWith(color: W.text)),
          ]),
          if (!g.done)
            Text(
              eta == null
                  ? 'Осталось ${_money(g.left)}'
                  : 'Осталось ${_money(g.left)} · если откладывать остаток месяца — ≈ $eta мес.',
              style: W.small,
            )
          else
            Text('Накоплено! 🎉', style: W.small.copyWith(color: W.good)),
        ]),
      ),
    );
  }
}

/// Положить / забрать деньги из копилки.
Future<void> _goalMoney(BuildContext context, Goal g) async {
  final ctl = TextEditingController();
  final r = await showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (c) => Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${g.emoji} ${g.name}', style: W.h2),
        const SizedBox(height: 4),
        Text('Сейчас: ${_money(g.saved)} из ${_money(g.target)}', style: W.small),
        const SizedBox(height: 12),
        TextField(
          controller: ctl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Сумма', border: const OutlineInputBorder(), suffixText: BudgetStore.I.currency),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                final v = parseAmount(ctl.text);
                if (v != null) Navigator.pop(c, -v);
              },
              child: const Text('Забрать'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: () {
                final v = parseAmount(ctl.text);
                if (v != null) Navigator.pop(c, v);
              },
              child: const Text('Положить'),
            ),
          ),
        ]),
      ]),
    ),
  );
  // Контроллеры не закрываем вручную: шторка ещё доигрывает анимацию закрытия.
  if (r == null) return;
  final st = BudgetStore.I;
  final saved = (g.saved + r) < 0 ? 0.0 : g.saved + r;
  final updated = g.copyWith(saved: saved);
  st.goals = [for (final x in st.goals) x.id == g.id ? updated : x];
  await st.save();
  if (context.mounted && !g.done && updated.done) toast(context, 'Копилка «${g.name}» собрана! 🎉');
}

/// Создать или изменить копилку.
Future<void> _goalEditor(BuildContext context, {Goal? goal}) async {
  final st = BudgetStore.I;
  final name = TextEditingController(text: goal?.name ?? '');
  final target = TextEditingController(text: goal != null && goal.target > 0 ? _num(goal.target) : '');
  var emoji = goal?.emoji ?? '🎯';
  final r = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(c).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(goal == null ? 'Новая копилка' : 'Копилка', style: W.h2),
          const SizedBox(height: 12),
          TextField(
            controller: name,
            autofocus: goal == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'На что копишь', hintText: 'Телефон маме, новая гитара…', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Сколько нужно', border: const OutlineInputBorder(), suffixText: st.currency),
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final e in _goalEmojis)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => set(() => emoji = e),
                child: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: e == emoji ? W.accent.withValues(alpha: 0.25) : W.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: e == emoji ? W.accent : W.border),
                  ),
                  child: Text(e, style: const TextStyle(fontSize: 20)),
                ),
              ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            if (goal != null)
              TextButton(onPressed: () => Navigator.pop(c, 'delete'), child: const Text('Удалить', style: TextStyle(color: W.bad))),
            const Spacer(),
            FilledButton(onPressed: () => Navigator.pop(c, 'save'), child: const Text('Сохранить')),
          ]),
        ]),
      ),
    ),
  );
  final n = name.text.trim();
  final t = parseAmount(target.text) ?? 0;
  if (r == 'delete' && goal != null) {
    if (!context.mounted) return;
    if (!await confirmDialog(context, 'Удалить копилку?', '«${goal.name}» и сумма в ней (${_money(goal.saved)}) пропадут из приложения.', ok: 'Удалить')) {
      return;
    }
    st.goals = [for (final x in st.goals) if (x.id != goal.id) x];
    await st.save();
    return;
  }
  if (r != 'save' || n.isEmpty || t <= 0) {
    if (r == 'save' && context.mounted) toast(context, 'Нужно название и сумма');
    return;
  }
  if (goal == null) {
    st.goals = [...st.goals, Goal(id: st.id(), name: n, target: t, emoji: emoji)];
  } else {
    final upd = goal.copyWith(name: n, target: t, emoji: emoji);
    st.goals = [for (final x in st.goals) x.id == goal.id ? upd : x];
  }
  await st.save();
}

// ───────────────────────────── Запись ─────────────────────────────

class TxEditor extends StatefulWidget {
  final Tx? tx;
  final bool income;
  final bool repeat;
  final DateTime month;
  const TxEditor({super.key, this.tx, this.income = false, this.repeat = false, required this.month});

  @override
  State<TxEditor> createState() => _TxEditorState();
}

class _TxEditorState extends State<TxEditor> {
  final st = BudgetStore.I;
  late bool income = widget.tx?.income ?? widget.income;
  late bool repeat = widget.repeat;
  late String cat = widget.tx?.cat ?? (income ? 'salary' : 'food');
  late DateTime day;
  late final amount = TextEditingController(text: widget.tx != null ? _num(widget.tx!.amount) : '');
  late final note = TextEditingController(text: widget.tx?.note ?? '');

  @override
  void initState() {
    super.initState();
    if (widget.tx != null) {
      day = widget.tx!.date;
    } else {
      final n = DateTime.now();
      final m = widget.month;
      day = (n.year == m.year && n.month == m.month) ? DateTime(n.year, n.month, n.day) : DateTime(m.year, m.month, 1);
    }
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  void _setIncome(bool v) {
    if (v == income) return;
    setState(() {
      income = v;
      cat = v ? 'salary' : 'food';
    });
  }

  Future<void> _pickDay() async {
    final d = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2, 12, 31),
    );
    if (d != null) setState(() => day = d);
  }

  Future<void> _save() async {
    final a = parseAmount(amount.text);
    if (a == null) {
      toast(context, 'Впиши сумму');
      return;
    }
    final t = Tx(
      id: widget.tx?.id ?? st.id(),
      day: dayKey(day),
      amount: a,
      cat: cat,
      income: income,
      note: note.text.trim(),
    );
    st.txs = [for (final x in st.txs) if (x.id != t.id) x, t];
    if (widget.tx == null && repeat) {
      st.recurring = [
        ...st.recurring,
        Recurring(id: st.id(), amount: a, cat: cat, income: income, note: t.note, day: day.day, last: monthKey(day.year, day.month)),
      ];
    }
    await st.save();
    final made = await st.applyRecurring();
    if (!mounted) return;
    final over = income ? null : st.overLimit(cat, day.year, day.month);
    if (over != null) {
      toast(context, 'Лимит на «${catById(cat).name}» превышен: ${_money(over.spent)} из ${_money(over.limit)}');
    } else if (made > 0) {
      toast(context, 'Добавлены прошлые месяцы регулярного платежа: $made');
    }
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final t = widget.tx;
    if (t == null) return;
    st.txs = [for (final x in st.txs) if (x.id != t.id) x];
    await st.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cats = budgetCats.where((c) => c.income == income).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tx == null ? (income ? 'Новый доход' : 'Новая трата') : 'Запись'),
        actions: [
          if (widget.tx != null) IconButton(tooltip: 'Удалить', icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: [
        Row(children: [
          Expanded(child: _toggle('Трата', !income, () => _setIncome(false), W.bad)),
          const SizedBox(width: 10),
          Expanded(child: _toggle('Доход', income, () => _setIncome(true), W.good)),
        ]),
        const SizedBox(height: 16),
        TextField(
          controller: amount,
          autofocus: widget.tx == null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: W.text),
          decoration: InputDecoration(
            labelText: 'Сумма',
            border: const OutlineInputBorder(),
            suffixText: st.currency,
            prefixText: income ? '+ ' : '− ',
          ),
          onSubmitted: (_) => _save(),
        ),
        const Section('Категория'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in cats) Chip2('${c.emoji} ${c.name}', selected: cat == c.id, onTap: () => setState(() => cat = c.id)),
        ]),
        const SizedBox(height: 16),
        WCard(
          onTap: _pickDay,
          child: Row(children: [
            const Icon(Icons.event_outlined, color: W.muted),
            const SizedBox(width: 12),
            Expanded(child: Text(_dayTitle(dayKey(day)), style: W.body)),
            const Icon(Icons.chevron_right, color: W.muted),
          ]),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: note,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Заметка (необязательно)', hintText: 'Например: Biedronka, билет в Краков', border: OutlineInputBorder()),
        ),
        if (widget.tx == null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: repeat,
            onChanged: (v) => setState(() => repeat = v),
            title: const Text('Повторять каждый месяц', style: W.body),
            subtitle: Text(
              repeat ? 'Каждое ${day.day}-е число запись появится сама' : 'Телефон, подписки, проезд, аренда…',
              style: W.small,
            ),
          )
        else if (widget.tx!.id.startsWith('rec-'))
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Создано регулярным платежом. Изменить сам платёж — в настройках бюджета.', style: W.small),
          ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _save, child: const Padding(padding: EdgeInsets.all(12), child: Text('Сохранить'))),
      ]),
    );
  }

  Widget _toggle(String text, bool on, VoidCallback tap, Color c) => InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: tap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c.withValues(alpha: 0.18) : W.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? c : W.border),
          ),
          child: Text(text, style: W.h2.copyWith(color: on ? c : W.muted)),
        ),
      );
}

// ───────────────────────────── Настройки ─────────────────────────────

class BudgetSettings extends StatefulWidget {
  const BudgetSettings({super.key});

  @override
  State<BudgetSettings> createState() => _BudgetSettingsState();
}

class _BudgetSettingsState extends State<BudgetSettings> {
  final st = BudgetStore.I;
  late final limitCtl = TextEditingController(text: st.limit > 0 ? _num(st.limit) : '');
  late final curCtl = TextEditingController(text: st.currency);

  @override
  void dispose() {
    limitCtl.dispose();
    curCtl.dispose();
    super.dispose();
  }

  void _apply() {
    st.limit = parseAmount(limitCtl.text) ?? 0;
    st.currency = curCtl.text.trim().isEmpty ? 'zł' : curCtl.text.trim();
    st.save();
  }

  Widget _recTile(Recurring r) {
    final c = catById(r.cat);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Text(c.emoji, style: const TextStyle(fontSize: 20)),
      title: Text(r.note.isEmpty ? c.name : r.note, style: W.body),
      subtitle: Text('Каждое ${r.day}-е число · ${c.name}', style: W.small),
      trailing: Text('${r.income ? '+' : '−'}${money(r.amount)}', style: W.body.copyWith(color: r.income ? W.good : W.text)),
      onTap: () => _editRec(r),
    );
  }

  Future<void> _editRec(Recurring r) async {
    final amount = TextEditingController(text: _num(r.amount));
    final day = TextEditingController(text: '${r.day}');
    final res = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(r.note.isEmpty ? catById(r.cat).name : r.note),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Сумма', border: const OutlineInputBorder(), suffixText: st.currency),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: day,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Какого числа (1–31)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          const Text('Уже созданные записи не меняются — только следующие.', style: W.small),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, 'delete'), child: const Text('Удалить', style: TextStyle(color: W.bad))),
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(d, 'save'), child: const Text('Сохранить')),
        ],
      ),
    );
    if (res == null) return;
    if (res == 'delete') {
      st.recurring = [for (final x in st.recurring) if (x.id != r.id) x];
    } else {
      final a = parseAmount(amount.text);
      final dd = int.tryParse(day.text.trim());
      if (a == null || dd == null || dd < 1 || dd > 31) {
        if (mounted) toast(context, 'Проверь сумму и число');
        return;
      }
      st.recurring = [for (final x in st.recurring) x.id == r.id ? x.copyWith(amount: a, day: dd) : x];
    }
    await st.save();
    if (mounted) setState(() {});
  }

  Future<void> _addCatLimit() async {
    final cats = budgetCats.where((c) => !c.income && !st.catLimits.containsKey(c.id)).toList();
    final c = await showModalBottomSheet<BudgetCat>(
      context: context,
      builder: (b) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (final c in cats) Chip2('${c.emoji} ${c.name}', onTap: () => Navigator.pop(b, c)),
          ]),
        ),
      ),
    );
    if (c == null || !mounted) return;
    await editCatLimit(context, c);
    if (mounted) setState(() {});
  }

  Future<void> _exportCsv() async {
    final b = StringBuffer('Дата;Тип;Категория;Сумма;Заметка\n');
    for (final t in st.txs) {
      b.writeln([
        t.day,
        t.income ? 'Доход' : 'Трата',
        catById(t.cat).name,
        t.amount.toStringAsFixed(2).replaceAll('.', ','),
        t.note.replaceAll(';', ','),
      ].join(';'));
    }
    // BOM — чтобы Excel открыл кириллицу правильно.
    final path = await BackupIO.save('budget.csv', '﻿$b');
    if (path != null && mounted) toast(context, 'Сохранено: $path');
  }

  Future<void> _backup() async {
    final path = await BackupIO.save('winter_budget_${BackupIO.stamp()}.json', jsonEncode(st.toJson()));
    if (path != null && mounted) toast(context, 'Копия сохранена');
  }

  Future<void> _restore() async {
    final text = await BackupIO.open();
    if (text == null) return;
    try {
      final j = jsonDecode(text);
      if (j is! Map<String, dynamic> || j['txs'] is! List) throw const FormatException();
      if (!mounted) return;
      if (!await confirmDialog(context, 'Восстановить?', 'Текущие записи заменятся записями из файла (${(j['txs'] as List).length} шт.).', ok: 'Восстановить')) {
        return;
      }
      st.fromJson(j);
      await st.save();
      if (!mounted) return;
      limitCtl.text = st.limit > 0 ? _num(st.limit) : '';
      curCtl.text = st.currency;
      setState(() {});
      toast(context, 'Восстановлено');
    } catch (_) {
      if (mounted) toast(context, 'Это не копия «Бюджета»');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Настройки')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          const Section('Деньги'),
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: limitCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Лимит трат на месяц', border: OutlineInputBorder()),
                onChanged: (_) => _apply(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: curCtl,
                decoration: const InputDecoration(labelText: 'Валюта', border: OutlineInputBorder()),
                onChanged: (_) => _apply(),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('С лимитом видно, сколько можно тратить в день до конца месяца. Оставь пустым — без лимита.', style: W.small),
          Section(
            'Регулярные платежи',
            trailing: TextButton.icon(
              onPressed: () async {
                final n = DateTime.now();
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TxEditor(repeat: true, month: DateTime(n.year, n.month))),
                );
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Добавить'),
            ),
          ),
          if (st.recurring.isEmpty)
            const Text('Траты и доходы, которые бывают каждый месяц, — записываются сами в нужное число.', style: W.small)
          else
            for (final r in st.recurring) _recTile(r),
          Section(
            'Лимиты по категориям',
            trailing: TextButton.icon(onPressed: _addCatLimit, icon: const Icon(Icons.add, size: 18), label: const Text('Добавить')),
          ),
          if (st.catLimits.isEmpty)
            const Text('Например: «Кафе и доставка» — не больше 200 zł в месяц. Превысишь — бюджет предупредит.', style: W.small)
          else
            for (final e in st.catLimits.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(catById(e.key).emoji, style: const TextStyle(fontSize: 20)),
                title: Text(catById(e.key).name, style: W.body),
                trailing: Text('${_money(e.value)} / мес', style: W.body),
                onTap: () async {
                  await editCatLimit(context, catById(e.key));
                  if (mounted) setState(() {});
                },
              ),
          const Section('Связь с другими плагинами'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: st.useKbjuFood,
            onChanged: (v) {
              setState(() => st.useKbjuFood = v);
              st.save();
            },
            title: const Text('Считать расходы на еду из КБЖУ', style: W.body),
            subtitle: const Text(
              'Траты, которые записываешь в КБЖУ → Питание → «Расходы», попадут сюда сами. '
              'Если еду записываешь только здесь — выключи, чтобы не было двойного счёта.',
              style: W.small,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Зарплата из плагина «Смены» показывается карточкой в месяце — нажми «В доходы», когда она придёт.',
            style: W.small,
          ),
          const Section('Файлы'),
          OutlinedButton.icon(onPressed: _exportCsv, icon: const Icon(Icons.table_chart_outlined), label: const Text('Таблица (CSV для Excel)')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _backup, icon: const Icon(Icons.save_alt), label: const Text('Резервная копия')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _restore, icon: const Icon(Icons.restore), label: const Text('Восстановить из копии')),
        ]),
      );
}
