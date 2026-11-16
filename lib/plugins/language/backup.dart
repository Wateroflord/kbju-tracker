import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart' as fs;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../i18n/i18n.dart';
import 'store.dart';
import '../../util.dart';

/// Файлы: резервная копия и перенос прогресса из КБЖУ Трекера.
class Backup {
  /// Сохранить копию и предложить, куда её отправить (Telegram, Google Диск…).
  static Future<String?> save(AppStore s) async {
    try {
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final f = File('${dir.path}/winter-language-${dkey(now)}.json');
      await f.writeAsString(s.exportJson(), flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(f.path)], subject: tr('Копия Winter Language')));
      return null;
    } catch (e) {
      return trf('Не удалось сохранить копию: {0}', [e]);
    }
  }

  /// Выбрать файл и загрузить. null — успех, '' — файл не выбран, иначе текст ошибки.
  static Future<String?> load(AppStore s) async {
    try {
      const group = fs.XTypeGroup(
        label: 'backup',
        extensions: ['json', 'txt'],
        mimeTypes: ['application/json', 'text/plain', 'application/octet-stream'],
      );
      final f = await fs.openFile(acceptedTypeGroups: [group]);
      if (f == null) return '';
      return s.importJson(utf8.decode(await f.readAsBytes(), allowMalformed: true));
    } catch (e) {
      return trf('Не удалось прочитать файл: {0}', [e]);
    }
  }
}
