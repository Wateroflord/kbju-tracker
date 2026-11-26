import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/game.dart';
import '../kbju_app.dart';
import '../models.dart';
import '../plugins/shell.dart';
import '../screens/add_food_screen.dart';
import '../store.dart';
import '../util.dart';
import '../i18n/i18n.dart';

/// Приём пищи по времени суток (для кнопки «📷 Еда» на виджете).
Meal mealForNow([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 11) return Meal.breakfast;
  if (h < 16) return Meal.lunch;
  if (h < 21) return Meal.dinner;
  return Meal.snack;
}

/// Передаёт данные за сегодня в виджет на главном экране телефона
/// и принимает нажатия его кнопок («📷 Еда», «+ вода»).
class WidgetService with WidgetsBindingObserver {
  WidgetService._();
  static final WidgetService instance = WidgetService._();
  bool _handling = false;

  static const _ch = MethodChannel('kbju/widget');
  AppStore? _store;
  Timer? _debounce;
  String _last = '';

  void attach(AppStore store) {
    _store = store;
    store.addListener(_schedule);
    _schedule();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) => handleWidgetButtons());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) handleWidgetButtons();
  }

  /// Вода, добавленная с виджета, — в нужный день; «📷 Еда» — открыть добавление еды с камерой.
  Future<void> handleWidgetButtons() async {
    final store = _store;
    if (store == null || _handling) return;
    _handling = true;
    try {
      final w = await _ch.invokeMethod<String>('takeWater');
      if (w != null && w.length > 2) {
        final m = jsonDecode(w) as Map;
        for (final e in m.entries) {
          final ml = (e.value as num).toInt();
          if (ml != 0) store.addWater('${e.key}', ml);
        }
      }
      final a = await _ch.invokeMethod<String>('takeAction');
      if (a == 'photo' && store.profile != null) {
        await WinterShell.switchTo('kbju');
        NavigatorState? nav;
        for (var i = 0; i < 30 && (nav = kbjuNavKey.currentState) == null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        nav?.push(MaterialPageRoute(
          builder: (_) => AddFoodScreen(date: DateTime.now(), meal: mealForNow(), openCamera: true),
        ));
      }
    } catch (_) {
    } finally {
      _handling = false;
    }
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), push);
  }

  Future<void> push() async {
    final store = _store;
    if (store == null || store.profile == null) return;
    final k = todayKey();
    final t = store.targetsFor(k);
    final tot = store.totalsFor(k);
    final data = <String, Object>{
      'day': k,
      'kcal': tot.kcal.round(),
      'kcalT': t.kcal,
      'protein': tot.protein.round(),
      'proteinT': t.protein,
      'water': store.waterFor(k),
      'waterT': t.waterMl,
      'steps': store.life.stepsFor(k),
      'stepsT': store.life.stepGoal,
      'title': tr('КБЖУ Трекер'),
      'level': trf('Ур. {0}', [computeGame(store).level]),
      'kcalL': tr('Калории'),
      'proteinL': tr('Белок'),
      'stepsL': tr('Шаги'),
      'waterL': tr('Вода'),
      'g': tr('г'),
      'ml': tr('мл'),
      'photoBtn': '📷 ${tr('Еда')}',
      'waterBtn': '💧 +250 ${tr('мл')}',
      'waterStep': 250,
    };
    final sig = data.toString();
    if (sig == _last) return;
    _last = sig;
    try {
      await _ch.invokeMethod('update', data);
    } catch (_) {}
  }
}
