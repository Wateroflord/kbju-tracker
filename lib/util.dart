// Даты, форматирование чисел и разбор ввода.

String two(int v) => v.toString().padLeft(2, '0');

/// Ключ дня: 2026-10-27
String dkey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime today() => dayOnly(DateTime.now());
String todayKey() => dkey(DateTime.now());

/// Безопасно для перехода на летнее/зимнее время.
DateTime addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

const monthsNom = [
  'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
  'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
];
const monthsGen = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];
const weekdaysShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const weekdaysFull = [
  'Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье',
];

String fmtDate(DateTime d, {bool year = false}) =>
    '${d.day} ${monthsGen[d.month - 1]}${year ? ' ${d.year}' : ''}';

String fmtShort(DateTime d) => '${two(d.day)}.${two(d.month)}';

/// 2450 -> "2 450"
String fmtInt(num v) {
  final n = v.round();
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return (n < 0 ? '−' : '') + b.toString();
}

/// 78.4 -> "78,4", 78.0 -> "78"
String fmt1(double v) {
  final r = (v * 10).round() / 10;
  final s = r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1);
  return s.replaceAll('.', ',');
}

double? parseNum(String s) {
  final t = s.trim().replaceAll(',', '.').replaceAll(' ', '').replaceAll(' ', '');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

double asDouble(dynamic v, [double d = 0]) {
  if (v is num) return v.toDouble();
  if (v == null) return d;
  return parseNum(v.toString()) ?? d;
}

int asInt(dynamic v, [int d = 0]) {
  if (v is num) return v.round();
  if (v == null) return d;
  return parseNum(v.toString())?.round() ?? d;
}
