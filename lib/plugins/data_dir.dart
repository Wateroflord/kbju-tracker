import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Папка данных плагина: <данные приложения>/plugins/<id>.
/// У каждого плагина своя папка, чтобы файлы разных плагинов и КБЖУ не пересекались.
Future<Directory> pluginDataDir(String id) async {
  final base = await getApplicationSupportDirectory();
  final d = Directory('${base.path}${Platform.pathSeparator}plugins${Platform.pathSeparator}$id');
  await d.create(recursive: true);
  return d;
}
