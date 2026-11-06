import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../i18n/i18n.dart';
import '../learn/learn_logic.dart';
import '../platform.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';

/// Вкладка «Учёба» переехала в отдельное приложение Winter Language.
/// Здесь — только перенос прогресса.
class LanguageMovedScreen extends StatelessWidget {
  const LanguageMovedScreen({super.key});

  /// Прогресс учёбы отдельным файлом (без данных о питании и здоровье).
  static String progressJson(AppStore s) {
    final life = s.life.toJson();
    return const JsonEncoder.withIndent(' ').convert({
      'app': 'kbju-learn-export',
      'exported': DateTime.now().toIso8601String(),
      'life': {for (final e in life.entries) if (e.key.startsWith('learn')) e.key: e.value},
    });
  }

  Future<void> _save(BuildContext context) async {
    final store = StoreScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = isWindows ? (await getDownloadsDirectory() ?? await getTemporaryDirectory()) : await getTemporaryDirectory();
      final f = File('${dir.path}/learn-progress-${todayKey()}.json');
      await f.writeAsString(progressJson(store), flush: true);
      if (isWindows) {
        messenger.showSnackBar(SnackBar(content: Text(trf('Сохранено в «Загрузки»: {0}', [f.uri.pathSegments.last]))));
      } else {
        await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: tr('Прогресс для Winter Language')));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(trf('Не удалось сохранить копию: {0}', [e]))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    var known = 0, seconds = 0;
    for (final l in const ['en', 'pl', 'de']) {
      known += life.knownCount(l);
      seconds += life.totalSeconds(l);
    }
    final has = life.learnCards.values.any((m) => m.isNotEmpty) || seconds > 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            TabHeader(tr('Учёба')),
            const SizedBox(height: 14),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.translate, color: AppColors.accent, size: 32),
                  const SizedBox(height: 10),
                  Text(tr('Изучение языков переехало в Winter Language'), style: Txt.h2),
                  const SizedBox(height: 8),
                  Text(
                    tr('Те же слова, тесты, диалоги и озвучка — в отдельном приложении. Установи его через Winter Hub, а потом перенеси прогресс файлом.'),
                    style: Txt.small,
                  ),
                ],
              ),
            ),
            if (has) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: StatTile(label: tr('Выучено'), value: '$known', sub: tr('слов'), color: AppColors.good)),
                  const SizedBox(width: 8),
                  Expanded(child: StatTile(label: tr('Практика'), value: fmt1(seconds / 3600), sub: tr('часов'))),
                ],
              ),
              const SizedBox(height: 16),
              PrimaryButton(tr('Сохранить прогресс'), icon: Icons.upload_file, onPressed: () => _save(context)),
              const SizedBox(height: 10),
              Text(
                tr('Отправь файл себе (например, в Telegram) и в Winter Language открой Настройки → «Выбрать файл из КБЖУ».'),
                style: Txt.small,
              ),
            ],
            const SizedBox(height: 16),
            Text(tr('Эту вкладку можно скрыть: Профиль → Разделы приложения.'), style: Txt.small),
          ],
        ),
      ),
    );
  }
}
