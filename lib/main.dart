import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'game/widget_service.dart';
import 'life/notifications.dart';
import 'life/steps_service.dart';
import 'platform.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'store.dart';
import 'theme.dart';
import 'i18n/i18n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  store.applyLang();
  // Шаги, напоминания и виджет есть только на телефоне.
  if (isAndroid) {
    StepsService.instance.init(store);
    NotificationService.instance.sync(store);
    WidgetService.instance.attach(store);
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(StoreScope(store: store, child: const KbjuApp()));
}

class KbjuApp extends StatelessWidget {
  const KbjuApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Перестраиваем всё приложение при смене языка.
    final lang = StoreScope.of(context).lang;
    return MaterialApp(
      key: ValueKey('app_$lang'),
      title: tr('КБЖУ Трекер'),
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: Locale(appLang.code),
      supportedLocales: const [Locale('ru'), Locale('uk'), Locale('en'), Locale('pl')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Всё приложение (и нижние панели) — выше системных кнопок телефона.
      builder: (context, child) => ColoredBox(
        color: AppColors.surface,
        child: SafeArea(top: false, left: false, right: false, child: child ?? const SizedBox()),
      ),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return store.profile == null ? const OnboardingScreen() : const HomeShell();
  }
}
