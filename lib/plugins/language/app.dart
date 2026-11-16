import 'dart:convert';

import 'package:flutter/material.dart';

import '../../i18n/i18n.dart';
import 'screens/learn_screen.dart';
import 'life/life_store.dart';
import 'store.dart';
import '../../theme.dart';

class LanguageApp extends StatelessWidget {
  const LanguageApp({super.key});

  @override
  Widget build(BuildContext context) {
    StoreScope.of(context); // перерисовка при смене языка интерфейса
    return MaterialApp(
      title: 'Winter Language',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _Home(),
    );
  }
}

class _Home extends StatefulWidget {
  const _Home();

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerImport());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      StoreScope.read(context).flush();
    }
  }

  /// Первый запуск: прогресс учёбы из КБЖУ переносится сам (всё в одном приложении).
  Future<void> _offerImport() async {
    final store = StoreScope.read(context);
    if (store.importOffered) return;
    final life = AppStore.kbjuLife?.call();
    if (life != null && LifeStore.hasLearnData(life)) {
      final err = store.importJson(jsonEncode(life));
      if (err == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Прогресс учёбы из КБЖУ перенесён'))));
      }
    }
    store.markImportOffered();
  }

  @override
  Widget build(BuildContext context) => const LearnScreen();
}
