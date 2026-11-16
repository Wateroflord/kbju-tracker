import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../kbju_app.dart';
import 'chess/app.dart' as chess;
import 'draw/app.dart' as draw;
import 'expiry/app.dart' as expiry;
import 'expiry/notifications.dart' as expiry_n;
import 'expiry/storage.dart' as expiry_s;
import 'forest/app.dart' as forest;
import 'language/app.dart' as language;
import 'language/store.dart' as language_s;
import 'mines/app.dart' as mines;
import 'mog/app.dart' as mog;
import 'mog/store.dart' as mog_s;
import 'music/app.dart' as music;
import 'music/media.dart' as music_m;
import 'paint/app.dart' as paint;
import 'walks/app.dart' as walks;

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
    tagline: 'Куда пойти гулять и где фоткать',
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
];

WinterPlugin? pluginById(String id) {
  for (final p in winterPlugins) {
    if (p.id == id) return p;
  }
  return null;
}

/// Связать плагины с КБЖУ: общий язык интерфейса, общий ключ Gemini, перенос учёбы.
void connectPluginsToKbju({
  required void Function(AppLang lang) setLang,
  required String Function() geminiKey,
  required Map<String, dynamic> Function() life,
}) {
  language_s.AppStore.onUiLang = setLang;
  language_s.AppStore.kbjuLife = life;
  mog_s.Store.sharedKey = geminiKey;
}
