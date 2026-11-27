/// Смены и зарплата — данные и расчёты (чистая логика, проверяется тестами).
library;

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDay(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// «6:00», «14:30».
String hm(int minutes) {
  final m = minutes % (24 * 60);
  return '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';
}

/// «7 ч 30 мин», «8 ч».
String hoursText(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '$m мин';
  return m == 0 ? '$h ч' : '$h ч $m мин';
}

/// «1 234,50».
String money(double v) {
  final neg = v < 0;
  final cents = (v.abs() * 100).round();
  final whole = (cents ~/ 100).toString();
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(' ');
    buf.write(whole[i]);
  }
  return '${neg ? '−' : ''}$buf,${(cents % 100).toString().padLeft(2, '0')}';
}

class Shift {
  final String id;
  final String day; // yyyy-MM-dd — день начала смены
  final int start, end; // минуты от полуночи; end <= start — смена через полночь
  final int breakMin; // неоплачиваемый перерыв
  final double? rate; // своя ставка за час (null — общая)
  final String note;

  const Shift({required this.id, required this.day, required this.start, required this.end, this.breakMin = 0, this.rate, this.note = ''});

  /// Оплачиваемые минуты.
  int get minutes {
    var len = end - start;
    if (len <= 0) len += 24 * 60;
    return (len - breakMin).clamp(0, 24 * 60);
  }

  DateTime get startsAt {
    final d = parseDay(day);
    return DateTime(d.year, d.month, d.day, start ~/ 60, start % 60);
  }

  DateTime get endsAt => startsAt.add(Duration(minutes: (end - start) <= 0 ? end - start + 24 * 60 : end - start));

  double pay(double defaultRate) => minutes / 60 * (rate ?? defaultRate);

  Shift copyWith({String? day, int? start, int? end, int? breakMin, double? rate, bool clearRate = false, String? note, String? id}) => Shift(
        id: id ?? this.id,
        day: day ?? this.day,
        start: start ?? this.start,
        end: end ?? this.end,
        breakMin: breakMin ?? this.breakMin,
        rate: clearRate ? null : (rate ?? this.rate),
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        's': start,
        'e': end,
        if (breakMin > 0) 'b': breakMin,
        if (rate != null) 'r': rate,
        if (note.isNotEmpty) 'n': note,
      };

  static Shift? fromJson(dynamic j) {
    if (j is! Map) return null;
    final day = j['day']?.toString() ?? '';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(day)) return null;
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    return Shift(
      id: j['id']?.toString() ?? '$day-${i(j['s'])}',
      day: day,
      start: i(j['s']).clamp(0, 24 * 60 - 1),
      end: i(j['e']).clamp(0, 24 * 60),
      breakMin: i(j['b']).clamp(0, 600),
      rate: (j['r'] as num?)?.toDouble(),
      note: j['n']?.toString() ?? '',
    );
  }
}

/// Шаблон смены: «Утро 6:00–14:00».
class ShiftTemplate {
  final String name;
  final int start, end, breakMin;
  const ShiftTemplate(this.name, this.start, this.end, [this.breakMin = 0]);

  Map<String, dynamic> toJson() => {'n': name, 's': start, 'e': end, 'b': breakMin};

  static ShiftTemplate? fromJson(dynamic j) {
    if (j is! Map) return null;
    int i(Object? v) => (v as num?)?.toInt() ?? 0;
    return ShiftTemplate(j['n']?.toString() ?? '', i(j['s']), i(j['e']), i(j['b']));
  }

  String get label => '${name.isEmpty ? '' : '$name '}${hm(start)}–${hm(end)}';
}

/// Как считать «на руки».
enum PayMode {
  /// Только брутто.
  none,

  /// Свой процент вычетов из расчётного листа.
  custom,

  /// Umowa zlecenie, до 26 лет: ZUS + здоровье, PIT 0 (ulga dla młodych).
  zlecenieYoung,

  /// Umowa zlecenie, 26 лет и старше: ZUS + здоровье + PIT 12 %.
  zlecenie,

  /// Студент / ученик до 26 лет на zlecenie: ничего не вычитают.
  student,
}

PayMode payModeFrom(Object? s, double deduction) {
  for (final m in PayMode.values) {
    if (m.name == s) return m;
  }
  return deduction > 0 ? PayMode.custom : PayMode.none;
}

/// Ставки 2026 года для umowa zlecenie — часть, которую платит сам работник.
class ZlecenieRates {
  static const pension = 0.0976; // emerytalna
  static const disability = 0.015; // rentowa
  static const sickness = 0.0245; // chorobowa — по желанию
  static const health = 0.09; // zdrowotna, от брутто минус соц. взносы
  static const costs = 0.20; // koszty uzyskania przychodu
  static const pit = 0.12; // первая ставка налога
  static const youngLimit = 85528.0; // ulga dla młodych — лимит в год
  static const pit2 = 300.0; // kwota zmniejszająca podatek в месяц (если подан PIT-2)
}

/// Из чего складывается «на руки».
class NetBreakdown {
  final double gross, social, health, pit;
  const NetBreakdown(this.gross, {this.social = 0, this.health = 0, this.pit = 0});
  double get deductions => social + health + pit;
  double get net => gross - deductions;
}

double _r2(double v) => (v * 100).roundToDouble() / 100;

/// Брутто → нетто.
/// [ytdBefore] — сколько брутто уже заработано в этом году до этих денег (для лимита ulga dla młodych).
NetBreakdown netFromGross(
  double gross,
  PayMode mode, {
  bool sickness = false,
  bool pit2 = false,
  double deductionPct = 0,
  double ytdBefore = 0,
}) {
  if (gross <= 0) return NetBreakdown(gross < 0 ? 0 : gross);
  switch (mode) {
    case PayMode.none:
    case PayMode.student:
      return NetBreakdown(gross);
    case PayMode.custom:
      return NetBreakdown(gross, social: _r2(gross * deductionPct.clamp(0, 100) / 100));
    case PayMode.zlecenie:
    case PayMode.zlecenieYoung:
      final social = _r2(gross * (ZlecenieRates.pension + ZlecenieRates.disability + (sickness ? ZlecenieRates.sickness : 0)));
      final health = _r2((gross - social) * ZlecenieRates.health);
      // Какая часть денег облагается налогом: для молодых — только то, что выше годового лимита.
      var taxedGross = gross;
      if (mode == PayMode.zlecenieYoung) {
        double over(double v) => v > ZlecenieRates.youngLimit ? v - ZlecenieRates.youngLimit : 0;
        taxedGross = over(ytdBefore + gross) - over(ytdBefore);
      }
      var pit = 0.0;
      if (taxedGross > 0) {
        final taxedSocial = social * taxedGross / gross;
        final income = taxedGross - taxedSocial;
        final base = (income - income * ZlecenieRates.costs).roundToDouble(); // база — до целых злотых
        pit = (base * ZlecenieRates.pit - (pit2 ? ZlecenieRates.pit2 : 0)).roundToDouble(); // налог — до целых злотых
        if (pit < 0) pit = 0;
      }
      return NetBreakdown(gross, social: social, health: health, pit: pit);
  }
}

class MonthSummary {
  final int shifts, minutes;
  final NetBreakdown pay;
  const MonthSummary(this.shifts, this.minutes, this.pay);
  double get brutto => pay.gross;
  double get netto => pay.net;
}

/// Итог за месяц: смены, часы, сколько заработано до и после вычетов.
/// [deductionPct] — процент вычетов, который человек сам берёт из своего расчётного листа
/// (используется, когда [mode] не задан или [PayMode.custom]).
MonthSummary summarize(
  Iterable<Shift> shifts,
  int year,
  int month,
  double rate,
  double deductionPct, {
  PayMode? mode,
  bool sickness = false,
  bool pit2 = false,
}) {
  var n = 0, min = 0;
  var brutto = 0.0, before = 0.0;
  for (final s in shifts) {
    final d = parseDay(s.day);
    if (d.year != year) continue;
    if (d.month < month) {
      before += s.pay(rate);
      continue;
    }
    if (d.month != month) continue;
    n++;
    min += s.minutes;
    brutto += s.pay(rate);
  }
  final m = mode ?? (deductionPct > 0 ? PayMode.custom : PayMode.none);
  return MonthSummary(n, min, netFromGross(brutto, m, sickness: sickness, pit2: pit2, deductionPct: deductionPct, ytdBefore: before));
}

/// Ближайшая смена, которая ещё не закончилась.
Shift? nextShift(Iterable<Shift> shifts, DateTime now) {
  Shift? best;
  for (final s in shifts) {
    if (!s.endsAt.isAfter(now)) continue;
    if (best == null || s.startsAt.isBefore(best.startsAt)) best = s;
  }
  return best;
}

/// «через 3 ч 20 мин», «через 2 дн.», «идёт сейчас».
String untilText(DateTime at, DateTime now, {DateTime? endsAt}) {
  if (!at.isAfter(now)) return endsAt != null && endsAt.isAfter(now) ? 'идёт сейчас' : 'прошла';
  final m = at.difference(now).inMinutes;
  if (m < 60) return 'через $m мин';
  if (m < 20 * 60) return 'через ${hoursText(m)}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(at.year, at.month, at.day);
  final days = DateTime.utc(day.year, day.month, day.day).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  return switch (days) { 0 => 'сегодня', 1 => 'завтра', _ => 'через $days дн.' };
}
