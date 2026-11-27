/// Бюджет — траты, доходы и копилки (чистая логика, проверяется тестами).
library;

import '../shifts/models.dart' show dayKey, parseDay;

export '../shifts/models.dart' show dayKey, parseDay, money;

class BudgetCat {
  final String id, name, emoji;
  final bool income;
  final int color;
  const BudgetCat(this.id, this.name, this.emoji, this.color, {this.income = false});
}

/// Категории трат и доходов. Порядок — как в выборе.
const budgetCats = [
  BudgetCat('food', 'Продукты', '🛒', 0xFF6EE7B7),
  BudgetCat('cafe', 'Кафе и доставка', '🍔', 0xFFFFAA5A),
  BudgetCat('transport', 'Транспорт', '🚆', 0xFF7FC8FF),
  BudgetCat('home', 'Жильё и счета', '🏠', 0xFFB48CFF),
  BudgetCat('phone', 'Связь и подписки', '📱', 0xFF9AD0FF),
  BudgetCat('clothes', 'Одежда', '👕', 0xFFFF78AA),
  BudgetCat('games', 'Игры и развлечения', '🎮', 0xFFFF4D5E),
  BudgetCat('sport', 'Спорт', '🏋️', 0xFFF5B942),
  BudgetCat('care', 'Здоровье и уход', '💊', 0xFF5EE6A8),
  BudgetCat('gifts', 'Подарки', '🎁', 0xFFFF7A6B),
  BudgetCat('tech', 'Техника', '💻', 0xFF8AB4F8),
  BudgetCat('other', 'Другое', '📦', 0xFF8A9BB8),
  BudgetCat('salary', 'Зарплата', '💼', 0xFF6EE7B7, income: true),
  BudgetCat('gift_in', 'Подарили', '🎁', 0xFFFF78AA, income: true),
  BudgetCat('sale', 'Продал', '💸', 0xFFFFD166, income: true),
  BudgetCat('other_in', 'Другое', '➕', 0xFF8A9BB8, income: true),
];

/// Расходы на еду из КБЖУ Трекера (не хранятся в бюджете, подтягиваются).
const kbjuFoodCat = BudgetCat('kbju_food', 'Еда (из КБЖУ)', '🥗', 0xFFCE3535);

BudgetCat catById(String id) {
  if (id == kbjuFoodCat.id) return kbjuFoodCat;
  for (final c in budgetCats) {
    if (c.id == id) return c;
  }
  return budgetCats.firstWhere((c) => c.id == 'other');
}

/// Одна запись: трата или доход.
class Tx {
  final String id, day, cat, note;
  final double amount; // всегда > 0
  final bool income;

  const Tx({required this.id, required this.day, required this.amount, required this.cat, this.income = false, this.note = ''});

  DateTime get date => parseDay(day);

  Map<String, dynamic> toJson() => {
        'id': id,
        'd': day,
        'a': amount,
        'c': cat,
        if (income) 'i': true,
        if (note.isNotEmpty) 'n': note,
      };

  static Tx? fromJson(dynamic j) {
    if (j is! Map) return null;
    final day = j['d']?.toString() ?? '';
    final a = (j['a'] as num?)?.toDouble() ?? 0;
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day) || a <= 0) return null;
    return Tx(
      id: j['id']?.toString() ?? '$day-$a',
      day: day,
      amount: a,
      cat: j['c']?.toString() ?? 'other',
      income: j['i'] == true,
      note: j['n']?.toString() ?? '',
    );
  }

  Tx copyWith({String? day, double? amount, String? cat, bool? income, String? note}) => Tx(
        id: id,
        day: day ?? this.day,
        amount: amount ?? this.amount,
        cat: cat ?? this.cat,
        income: income ?? this.income,
        note: note ?? this.note,
      );
}

/// Копилка: на что коплю, сколько нужно, сколько уже есть.
class Goal {
  final String id, name, emoji;
  final double target, saved;
  const Goal({required this.id, required this.name, required this.target, this.saved = 0, this.emoji = '🎯'});

  double get progress => target <= 0 ? 0 : (saved / target).clamp(0, 1).toDouble();
  double get left => (target - saved) < 0 ? 0 : target - saved;
  bool get done => target > 0 && saved >= target;

  Map<String, dynamic> toJson() => {'id': id, 'n': name, 't': target, 's': saved, 'e': emoji};

  static Goal? fromJson(dynamic j) {
    if (j is! Map || j['id'] == null) return null;
    return Goal(
      id: j['id'].toString(),
      name: j['n']?.toString() ?? '',
      target: (j['t'] as num?)?.toDouble() ?? 0,
      saved: (j['s'] as num?)?.toDouble() ?? 0,
      emoji: j['e']?.toString() ?? '🎯',
    );
  }

  Goal copyWith({String? name, double? target, double? saved, String? emoji}) =>
      Goal(id: id, name: name ?? this.name, target: target ?? this.target, saved: saved ?? this.saved, emoji: emoji ?? this.emoji);
}

/// Сколько месяцев копить при [perMonth] в месяц (null — не накопить).
int? monthsToGoal(Goal g, double perMonth) {
  if (g.done) return 0;
  if (perMonth <= 0) return null;
  return (g.left / perMonth).ceil();
}

/// Итог месяца.
class BudgetMonth {
  final double income, expense;
  final Map<String, double> byCat; // только траты
  const BudgetMonth(this.income, this.expense, this.byCat);
  double get balance => income - expense;

  /// Категории по убыванию суммы.
  List<MapEntry<String, double>> get topCats => byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}

bool inMonth(String day, int year, int month) {
  final d = parseDay(day);
  return d.year == year && d.month == month;
}

/// Итог за месяц. [extraExpense] — траты извне (еда из КБЖУ), по категориям.
BudgetMonth summarizeMonth(Iterable<Tx> txs, int year, int month, {Map<String, double> extraExpense = const {}}) {
  var inc = 0.0, exp = 0.0;
  final by = <String, double>{};
  for (final t in txs) {
    if (!inMonth(t.day, year, month)) continue;
    if (t.income) {
      inc += t.amount;
    } else {
      exp += t.amount;
      by[t.cat] = (by[t.cat] ?? 0) + t.amount;
    }
  }
  extraExpense.forEach((cat, v) {
    if (v <= 0) return;
    exp += v;
    by[cat] = (by[cat] ?? 0) + v;
  });
  return BudgetMonth(inc, exp, by);
}

/// Сколько можно тратить в день до конца месяца, чтобы уложиться в [limit].
/// [today] — сегодняшний день; для прошлых месяцев — null, для будущих — весь месяц.
double? perDayLeft(double limit, double spent, int year, int month, DateTime today) {
  if (limit <= 0) return null;
  final days = DateTime(year, month + 1, 0).day;
  int left;
  if (today.year == year && today.month == month) {
    left = days - today.day + 1;
  } else if (DateTime(year, month).isAfter(DateTime(today.year, today.month))) {
    left = days;
  } else {
    return null;
  }
  final rest = limit - spent;
  return rest <= 0 ? 0 : rest / left;
}

/// Записи месяца, сгруппированные по дням (новые сверху).
List<MapEntry<String, List<Tx>>> byDay(Iterable<Tx> txs, int year, int month) {
  final m = <String, List<Tx>>{};
  for (final t in txs) {
    if (!inMonth(t.day, year, month)) continue;
    (m[t.day] ??= []).add(t);
  }
  final out = m.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  return out;
}

/// Траты по месяцам за последние [n] месяцев до [year]/[month] включительно — для графика.
List<double> expenseHistory(Iterable<Tx> txs, int year, int month, int n) {
  final out = <double>[];
  for (var i = n - 1; i >= 0; i--) {
    final d = DateTime(year, month - i);
    out.add(summarizeMonth(txs, d.year, d.month).expense);
  }
  return out;
}

/// Сумму из текста: «12,50», «12.5», «1 200».
double? parseAmount(String s) {
  final v = double.tryParse(s.replaceAll(RegExp(r'\s'), '').replaceAll(',', '.'));
  if (v == null || v.isNaN || v.isInfinite || v <= 0) return null;
  return (v * 100).roundToDouble() / 100;
}

String todayKey([DateTime? now]) => dayKey(now ?? DateTime.now());
