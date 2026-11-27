import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/widget_service.dart';
import 'life/health_sync.dart';
import 'life/notifications.dart';
import 'life/steps_service.dart';
import 'platform.dart';
import 'store.dart';
import 'theme.dart';
import 'plugins/host.dart';
import 'plugins/registry.dart';
import 'plugins/shell.dart';
import 'package:winter_core/winter_core.dart';
import 'arc/arc_service.dart';

Future<void> main() => runWinterApp(repo: 'kbju-tracker', appName: 'КБЖУ Трекер', body: _main);

Future<void> _main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  store.applyLang();
  await ArcService.I.load(store);
  ArcService.I.sync(store); // Winter Arc: отправить очки и обновить рейтинг (в фоне)
  // Шаги, напоминания и виджет есть только на телефоне.
  if (isAndroid) {
    StepsService.instance.init(store);
    HealthSync.instance.sync(store);
    NotificationService.instance.sync(store);
    WidgetService.instance.attach(store);
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  // Плагины (шахматы, сапёр, музыка…): общий язык, общий ключ Gemini, перенос учёбы.
  connectPluginsToKbju(
    setLang: store.setLang,
    geminiKey: () => store.apiKey,
    life: () => store.life.toJson(),
    foodSpent: (y, m) => store.food.expensesOfMonth(y, m).fold<double>(0, (s, e) => s + store.food.toPln(e)),
  );
  await PluginHost.I.load();
  // Вкладки «Учёба» больше нет — языки только в плагине Winter Language. У кого есть выученные слова,
  // плагин включается сам (один раз: если потом выключить, сам больше не включится).
  if (store.life.learnCards.values.any((m) => m.isNotEmpty)) await PluginHost.I.enableOnce('language');
  runApp(WinterCrashBanner(child: StoreScope(store: store, child: const WinterShell())));
}
