import 'dart:async';

import 'package:flutter/services.dart';

import '../game/game.dart';
import '../store.dart';
import '../util.dart';
import '../i18n/i18n.dart';

/// Передаёт данные за сегодня в виджет на главном экране телефона.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static const _ch = MethodChannel('kbju/widget');
  AppStore? _store;
  Timer? _debounce;
  String _last = '';

  void attach(AppStore store) {
    _store = store;
    store.addListener(_schedule);
    _schedule();
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
    };
    final sig = data.toString();
    if (sig == _last) return;
    _last = sig;
    try {
      await _ch.invokeMethod('update', data);
    } catch (_) {}
  }
}
