import 'dart:ui' show PlatformDispatcher;

import 'strings_en.dart';
import 'strings_pl.dart';
import 'strings_uk.dart';

/// Языки интерфейса. Русский — исходный: строки в коде написаны на нём и служат ключами.
enum AppLang { ru, uk, en, pl }

extension AppLangX on AppLang {
  String get code => name;

  String get nativeName => switch (this) {
        AppLang.ru => 'Русский',
        AppLang.uk => 'Українська',
        AppLang.en => 'English',
        AppLang.pl => 'Polski',
      };

  String get flag => switch (this) {
        AppLang.ru => 'RU',
        AppLang.uk => 'UA',
        AppLang.en => 'EN',
        AppLang.pl => 'PL',
      };

  /// Десятичный разделитель.
  String get decimal => this == AppLang.en ? '.' : ',';
}

/// Текущий язык интерфейса (меняется в профиле).
AppLang appLang = AppLang.ru;

AppLang langFromCode(String? code) {
  for (final l in AppLang.values) {
    if (l.name == code) return l;
  }
  return AppLang.ru;
}

/// Язык телефона, если он из поддерживаемых, иначе русский.
AppLang detectDeviceLang() {
  final code = PlatformDispatcher.instance.locale.languageCode;
  return switch (code) {
    'uk' => AppLang.uk,
    'en' => AppLang.en,
    'pl' => AppLang.pl,
    _ => AppLang.ru,
  };
}

const Map<AppLang, Map<String, String>> _dict = {
  AppLang.uk: stringsUk,
  AppLang.en: stringsEn,
  AppLang.pl: stringsPl,
};

/// Перевод строки. Ключ — русский текст. Если перевода нет, возвращается исходный текст
/// (так работают и свои названия пользователя).
String tr(String ru) {
  if (appLang == AppLang.ru) return ru;
  return _dict[appLang]?[ru] ?? ru;
}

/// Перевод шаблона с подстановками {0}, {1}, …
String trf(String ru, List<Object?> args) {
  var s = tr(ru);
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', '${args[i]}');
  }
  return s;
}

// ---------------- Даты ----------------

const _monthsNom = {
  AppLang.ru: ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'],
  AppLang.uk: ['Січень', 'Лютий', 'Березень', 'Квітень', 'Травень', 'Червень', 'Липень', 'Серпень', 'Вересень', 'Жовтень', 'Листопад', 'Грудень'],
  AppLang.en: ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'],
  AppLang.pl: ['Styczeń', 'Luty', 'Marzec', 'Kwiecień', 'Maj', 'Czerwiec', 'Lipiec', 'Sierpień', 'Wrzesień', 'Październik', 'Listopad', 'Grudzień'],
};

const _monthsGen = {
  AppLang.ru: ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'],
  AppLang.uk: ['січня', 'лютого', 'березня', 'квітня', 'травня', 'червня', 'липня', 'серпня', 'вересня', 'жовтня', 'листопада', 'грудня'],
  AppLang.en: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'],
  AppLang.pl: ['stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca', 'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia'],
};

const _weekdaysShort = {
  AppLang.ru: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
  AppLang.uk: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд'],
  AppLang.en: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'],
  AppLang.pl: ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'Sb', 'Nd'],
};

const _weekdaysFull = {
  AppLang.ru: ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'],
  AppLang.uk: ['Понеділок', 'Вівторок', 'Середа', 'Четвер', 'Пʼятниця', 'Субота', 'Неділя'],
  AppLang.en: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  AppLang.pl: ['Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela'],
};

List<String> get monthsNom => _monthsNom[appLang]!;
List<String> get monthsGen => _monthsGen[appLang]!;
List<String> get weekdaysShort => _weekdaysShort[appLang]!;
List<String> get weekdaysFull => _weekdaysFull[appLang]!;

/// «28 октября», «28 października», «Oct 28».
String formatDayMonth(int day, int month, {int? year}) {
  final m = monthsGen[month - 1];
  final base = appLang == AppLang.en ? '$m $day' : '$day $m';
  return year == null ? base : (appLang == AppLang.en ? '$base, $year' : '$base $year');
}
