import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models.dart';
import 'platform.dart';
import 'store.dart';
import 'util.dart';
import 'i18n/i18n.dart';

/// Резервная копия и выгрузка в CSV.
/// На телефоне файл отправляется через «Поделиться» (можно выбрать Google Диск, Telegram, почту),
/// на ПК — сохраняется в «Загрузки».
class DataExport {
  static String _stamp() {
    final n = DateTime.now();
    return '${dkey(n)}_${two(n.hour)}${two(n.minute)}';
  }

  static Future<Directory> _dir() async {
    if (isWindows) {
      final d = await getDownloadsDirectory();
      if (d != null) return d;
    }
    return getTemporaryDirectory();
  }

  /// Возвращает текст для сообщения: куда сохранено или ошибка.
  static Future<String> _deliver(List<File> files, String subject) async {
    if (isWindows) {
      return trf('Сохранено в «Загрузки»: {0}', [files.map((f) => f.uri.pathSegments.last).join(', ')]);
    }
    await SharePlus.instance.share(ShareParams(files: [for (final f in files) XFile(f.path)], subject: subject));
    return '';
  }

  /// Полная копия данных одним файлом JSON (без фото).
  static Future<String> backupFile(AppStore s) async {
    try {
      final dir = await _dir();
      final f = File('${dir.path}/kbju_backup_${_stamp()}.json');
      await f.writeAsString(s.exportJson(), flush: true);
      return await _deliver([f], tr('Копия КБЖУ Трекера'));
    } catch (e) {
      return trf('Не удалось сохранить копию: {0}', [e]);
    }
  }

  /// Восстановить из файла копии. Возвращает null при успехе или текст ошибки.
  /// Если файл не выбран — пустую строку.
  static Future<String?> restoreFile(AppStore s) async {
    try {
      const group = fs.XTypeGroup(
        label: 'backup',
        extensions: ['json', 'txt'],
        mimeTypes: ['application/json', 'text/plain', 'application/octet-stream'],
      );
      final f = await fs.openFile(acceptedTypeGroups: [group]);
      if (f == null) return '';
      final bytes = await f.readAsBytes();
      return s.importJson(utf8.decode(bytes, allowMalformed: true));
    } catch (e) {
      return trf('Не удалось прочитать файл: {0}', [e]);
    }
  }

  static String _csv(List<Object?> row) => row.map((v) {
        final t = v == null ? '' : (v is double ? _num(v) : v.toString());
        return t.contains(RegExp(r'[",;\n]')) ? '"${t.replaceAll('"', '""')}"' : t;
      }).join(',');

  static String _num(double v) => ((v * 100).round() / 100).toString();

  static String foodCsv(AppStore s) {
    final b = StringBuffer()
      ..writeln(_csv(['date', 'time', 'meal', 'name', 'grams', 'kcal', 'protein', 'fat', 'carbs', 'fiber', 'salt']));
    final list = [...s.entries]..sort((a, b) => a.time.compareTo(b.time));
    for (final e in list) {
      final t = DateTime.fromMillisecondsSinceEpoch(e.time);
      b.writeln(_csv([e.date, '${two(t.hour)}:${two(t.minute)}', e.meal.name, e.name, e.grams, e.kcal, e.protein, e.fat, e.carbs, e.fiber, e.salt]));
    }
    return b.toString();
  }

  static String daysCsv(AppStore s) {
    final b = StringBuffer()
      ..writeln(_csv(['date', 'kcal', 'protein', 'fat', 'carbs', 'fiber', 'salt', 'kcal_target', 'water_ml', 'weight_kg', 'steps', 'sleep_h']));
    final totals = s.allTotals();
    final days = <String>{...totals.keys, ...s.weights.keys, ...s.water.keys}.toList()..sort();
    for (final d in days) {
      final t = totals[d] ?? Totals();
      final sl = s.life.sleepFor(d);
      b.writeln(_csv([
        d,
        t.kcal,
        t.protein,
        t.fat,
        t.carbs,
        t.fiber,
        t.salt,
        s.targetsFor(d).kcal,
        s.waterFor(d),
        s.weights[d],
        s.life.stepsFor(d),
        sl == null ? null : (sl.hours * 10).round() / 10,
      ]));
    }
    return b.toString();
  }

  /// Две таблицы: все записи о еде и итоги по дням. Открываются в Excel и Google Таблицах.
  static Future<String> csvFiles(AppStore s) async {
    try {
      final dir = await _dir();
      final st = _stamp();
      // BOM — чтобы Excel правильно показал кириллицу.
      const bom = '﻿';
      final food = File('${dir.path}/kbju_food_$st.csv');
      final days = File('${dir.path}/kbju_days_$st.csv');
      await food.writeAsString(bom + foodCsv(s), flush: true);
      await days.writeAsString(bom + daysCsv(s), flush: true);
      return await _deliver([food, days], tr('Данные КБЖУ Трекера (CSV)'));
    } catch (e) {
      return trf('Не удалось выгрузить: {0}', [e]);
    }
  }
}
