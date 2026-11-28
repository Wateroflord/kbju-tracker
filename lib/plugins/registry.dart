import 'package:flutter/material.dart';

import '../arc/arc_score.dart' show ArcRules;
import '../i18n/i18n.dart';
import '../kbju_app.dart';
import 'budget/app.dart' as budget;
import 'chess/app.dart' as chess;
import 'draw/app.dart' as draw;
import 'expiry/app.dart' as expiry;
import 'expiry/notifications.dart' as expiry_n;
import 'expiry/storage.dart' as expiry_s;
import 'focus/app.dart' as focus;
import 'forest/app.dart' as forest;
import 'guitar/app.dart' as guitar;
import 'language/app.dart' as language;
import 'language/store.dart' as language_s;
import 'mines/app.dart' as mines;
import 'mog/app.dart' as mog;
import 'mog/store.dart' as mog_s;
import 'music/app.dart' as music;
import 'music/media.dart' as music_m;
import 'paint/app.dart' as paint;
import 'pushups/app.dart' as pushups;
import 'pushups/stats.dart' as pushups_s;
import 'shifts/app.dart' as shifts;
import 'walks/app.dart' as walks;
import 'walks/run.dart' as walks_run;
import 'walks/run_model.dart' as walks_run_model;

/// Плагин супер-приложения: бывшее отдельное приложение Winter.
class WinterPlugin {
  final String id;
  final String name;
  final String tagline;
  final Color color;

  /// Картинка для шторки (assets/…).
  final String icon;

  /// Корень плагина — его собственный MaterialApp (своя тема и навигация).
  final Widget Function() build;

  /// Подготовка при первом открытии (загрузка данных и т.п.).
  final Future<void> Function()? init;

  /// Основа — её нельзя выключить.
  final bool core;

  const WinterPlugin({
    required this.id,
    required this.name,
    required this.tagline,
    required this.color,
    required this.icon,
    required this.build,
    this.init,
    this.core = false,
  });
}

language_s.AppStore? _languageStore;

/// Все плагины. Порядок — как в шторке.
final List<WinterPlugin> winterPlugins = [
  WinterPlugin(
    id: 'kbju',
    name: 'КБЖУ Трекер',
    tagline: 'Питание, спорт, уход и прогресс',
    color: const Color(0xFFCE3535),
    icon: 'assets/icon/icon.png',
    build: () => const KbjuApp(),
    core: true,
  ),
  WinterPlugin(
    id: 'expiry',
    name: 'Просрочка',
    tagline: 'Сроки годности на полках',
    color: const Color(0xFF7CC4FF),
    icon: 'assets/plugins/expiry/icon.png',
    build: () => const expiry.ExpiryApp(),
    init: () async {
      await expiry_s.AppStore.instance.load();
      await expiry_n.Notifier.init();
      expiry_n.Notifier.reschedule(expiry_s.AppStore.instance);
    },
  ),
  WinterPlugin(
    id: 'language',
    name: 'Winter Language',
    tagline: 'Английский, польский и немецкий',
    color: const Color(0xFF7FD8FF),
    icon: 'assets/plugins/language/icon.png',
    build: () => language_s.StoreScope(store: _languageStore!, child: const language.LanguageApp()),
    init: () async {
      final s = language_s.AppStore();
      await s.load();
      _languageStore = s;
    },
  ),
  WinterPlugin(
    id: 'chess',
    name: 'Шахматы',
    tagline: 'Бот Stockfish, задачи и уроки',
    color: const Color(0xFFE8D5A8),
    icon: 'assets/plugins/chess/icon.png',
    build: () => const chess.ChessApp(),
  ),
  WinterPlugin(
    id: 'mines',
    name: 'Сапёр',
    tagline: 'Классика на время',
    color: const Color(0xFF9AD0FF),
    icon: 'assets/plugins/mines/icon.png',
    build: () => const mines.MinesApp(),
  ),
  WinterPlugin(
    id: 'music',
    name: 'Winter Music',
    tagline: 'Музыка, лайки и плейлисты',
    color: const Color(0xFFFF78AA),
    icon: 'assets/plugins/music/icon.png',
    build: () => const music.MusicApp(),
    init: music_m.initMedia,
  ),
  WinterPlugin(
    id: 'paint',
    name: 'Winter Paint',
    tagline: 'Рисование и пиксель-арт',
    color: const Color(0xFFB48CFF),
    icon: 'assets/plugins/paint/icon.png',
    build: () => const paint.PaintApp(),
  ),
  WinterPlugin(
    id: 'draw',
    name: 'Уроки рисования',
    tagline: 'Курс рисования с нуля',
    color: const Color(0xFFFFAA5A),
    icon: 'assets/plugins/draw/icon.png',
    build: () => const draw.DrawSchoolApp(),
  ),
  WinterPlugin(
    id: 'walks',
    name: 'Winter Walks',
    tagline: 'Куда пойти гулять, где фоткать и пробежки',
    color: const Color(0xFF7FC8FF),
    icon: 'assets/plugins/walks/icon.png',
    build: () => const walks.WalksApp(),
  ),
  WinterPlugin(
    id: 'forest',
    name: 'Выживание в лесу',
    tagline: 'Справочник, компас, фонарик',
    color: const Color(0xFF6ED28C),
    icon: 'assets/plugins/forest/icon.png',
    build: () => const forest.ForestApp(),
  ),
  WinterPlugin(
    id: 'mog',
    name: 'Mog Battle',
    tagline: 'ИИ оценивает внешность и стиль',
    color: const Color(0xFFF5B942),
    icon: 'assets/plugins/mog/icon.png',
    build: () => const mog.MogApp(),
    init: mog_s.Store.I.load,
  ),
  WinterPlugin(
    id: 'pushups',
    name: 'Push-Up Arena',
    tagline: 'Отжимания один на один',
    color: const Color(0xFFFF4D5E),
    icon: 'assets/plugins/pushups/icon.png',
    build: () => const pushups.PushupsApp(),
    init: pushups_s.PushStats.I.load,
  ),
  WinterPlugin(
    id: 'guitar',
    name: 'Winter Guitar',
    tagline: 'Тюнер, метроном и аккорды',
    color: const Color(0xFFFFB35C),
    icon: 'assets/plugins/guitar/icon.png',
    build: () => const guitar.GuitarApp(),
    init: guitar.GuitarStore.load,
  ),
  WinterPlugin(
    id: 'shifts',
    name: 'Смены и зарплата',
    tagline: 'График, часы и заработок',
    color: const Color(0xFF6EE7B7),
    icon: 'assets/plugins/shifts/icon.png',
    build: () => const shifts.ShiftsApp(),
    init: shifts.ShiftStore.I.load,
  ),
  WinterPlugin(
    id: 'budget',
    name: 'Бюджет',
    tagline: 'Траты, доходы и копилки',
    color: const Color(0xFFFFD166),
    icon: 'assets/plugins/budget/icon.png',
    build: () => const budget.BudgetApp(),
    init: budget.BudgetStore.I.load,
  ),
  WinterPlugin(
    id: 'focus',
    name: 'Фокус',
    tagline: 'Помидоры и задачи по проектам',
    color: const Color(0xFFFF7A6B),
    icon: 'assets/plugins/focus/icon.png',
    build: () => const focus.FocusApp(),
    init: focus.FocusStore.I.load,
  ),
];

WinterPlugin? pluginById(String id) {
  for (final p in winterPlugins) {
    if (p.id == id) return p;
  }
  return null;
}

/// Связать плагины с КБЖУ: общий язык интерфейса, общий ключ Gemini (Mog, камера в шахматах), перенос учёбы, расходы на еду для «Бюджета».
void connectPluginsToKbju({
  required void Function(AppLang lang) setLang,
  required String Function() geminiKey,
  required Map<String, dynamic> Function() life,
  double Function(int year, int month)? foodSpent,
  void Function()? arcSync,
}) {
  language_s.AppStore.onUiLang = setLang;
  language_s.AppStore.kbjuLife = life;
  mog_s.Store.sharedKey = geminiKey;
  chess.Store.sharedKey = geminiKey;
  budget.BudgetStore.kbjuFood = foodSpent;
  // Пробежки Winter Walks идут в Winter Arc как тренировки.
  ArcRules.runDays = () => walks_run_model.arcRunDays(walks_run.RunStore.I.runs);
  walks_run.RunStore.onChanged = arcSync;
  walks_run.RunStore.I.load().then((_) => arcSync?.call());
}
