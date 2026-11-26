import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../i18n/i18n.dart';

/// Фото прогресса тела: снимки по датам и сравнение «до / после».
///
/// Фото лежат только на этом устройстве (папка progress_photos) и не попадают в резервную
/// копию Android — у неё лимит 25 МБ. Перед сменой телефона их можно сохранить кнопкой «Поделиться».
class ProgressPhoto {
  final File file;
  final String day; // yyyy-MM-dd
  const ProgressPhoto(this.file, this.day);
}

class ProgressPhotos {
  static Future<Directory> dir() async {
    final d = Directory('${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}progress_photos');
    await d.create(recursive: true);
    return d;
  }

  /// Все фото, новые первыми. Имя файла: 2026-11-26_1764180000000.jpg
  static Future<List<ProgressPhoto>> list() async {
    final d = await dir();
    final out = <ProgressPhoto>[];
    for (final f in d.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      final m = RegExp(r'^(\d{4}-\d{2}-\d{2})_\d+\.(jpg|jpeg|png)$').firstMatch(name);
      if (m != null) out.add(ProgressPhoto(f, m.group(1)!));
    }
    out.sort((a, b) => b.file.path.compareTo(a.file.path));
    return out;
  }

  static Future<ProgressPhoto?> add(ImageSource src, DateTime day) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1440, maxHeight: 1920, imageQuality: 85);
    if (x == null) return null;
    final key = dkey(day);
    final d = await dir();
    final ext = x.path.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    final f = File('${d.path}${Platform.pathSeparator}${key}_${DateTime.now().millisecondsSinceEpoch}.$ext');
    await f.writeAsBytes(await x.readAsBytes(), flush: true);
    return ProgressPhoto(f, key);
  }
}

class ProgressPhotosScreen extends StatefulWidget {
  const ProgressPhotosScreen({super.key});

  @override
  State<ProgressPhotosScreen> createState() => _ProgressPhotosScreenState();
}

class _ProgressPhotosScreenState extends State<ProgressPhotosScreen> {
  List<ProgressPhoto> photos = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final l = await ProgressPhotos.list();
    if (mounted) {
      setState(() {
        photos = l;
        loading = false;
      });
    }
  }

  Future<void> _add() async {
    final src = Platform.isAndroid
        ? await showModalBottomSheet<ImageSource>(
            context: context,
            backgroundColor: AppColors.surface,
            builder: (c) => SafeArea(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text(tr('Сфотографировать')),
                  onTap: () => Navigator.pop(c, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(tr('Из галереи')),
                  onTap: () => Navigator.pop(c, ImageSource.gallery),
                ),
              ]),
            ),
          )
        : ImageSource.gallery;
    if (src == null) return;
    try {
      await ProgressPhotos.add(src, DateTime.now());
      await _reload();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Фото прогресса')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onPressed: _add,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(tr('Добавить фото'), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              children: [
                Text(
                  tr('Фотографируйся раз в 1–2 недели в одном месте, при одном свете и в одной позе — так разница видна лучше всего. '
                      'Фото хранятся только на этом телефоне и не попадают в резервную копию.'),
                  style: Txt.small,
                ),
                const SizedBox(height: 12),
                if (photos.length >= 2)
                  PrimaryButton(
                    tr('Сравнить «до» и «после»'),
                    icon: Icons.compare,
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => PhotoCompareScreen(photos: photos),
                    )),
                  ),
                if (photos.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Center(child: Text(tr('Пока нет фото.'), style: Txt.small)),
                  ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.75,
                  children: [
                    for (final p in photos)
                      GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _PhotoView(photo: p)));
                          _reload();
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(fit: StackFit.expand, children: [
                            Image.file(p.file, fit: BoxFit.cover, cacheWidth: 360),
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                color: Colors.black54,
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Text(fmtDate(parseKey(p.day)),
                                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ),
                            ),
                          ]),
                        ),
                      ),
                  ],
                ),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  GhostButton(
                    tr('Сохранить все фото (поделиться)'),
                    icon: Icons.ios_share,
                    onPressed: () => SharePlus.instance.share(ShareParams(
                      files: [for (final p in photos) XFile(p.file.path)],
                      subject: tr('Фото прогресса'),
                    )),
                  ),
                ],
              ],
            ),
    );
  }
}

String _weightText(AppStore store, String day) {
  final w = store.weights[day];
  return w == null ? '' : ' · ${fmt1(w)} ${tr('кг')}';
}

class _PhotoView extends StatelessWidget {
  final ProgressPhoto photo;
  const _PhotoView({required this.photo});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${fmtDate(parseKey(photo.day), year: true)}${_weightText(store, photo.day)}', style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            onPressed: () => SharePlus.instance.share(ShareParams(files: [XFile(photo.file.path)])),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await confirm(context, tr('Удалить фото?'), fmtDate(parseKey(photo.day), year: true), ok: tr('Удалить'));
              if (!ok) return;
              try {
                await photo.file.delete();
              } catch (_) {}
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: InteractiveViewer(child: Center(child: Image.file(photo.file))),
    );
  }
}

/// Сравнение двух фото: шторка, которую можно двигать пальцем.
class PhotoCompareScreen extends StatefulWidget {
  final List<ProgressPhoto> photos; // новые первыми
  const PhotoCompareScreen({super.key, required this.photos});

  @override
  State<PhotoCompareScreen> createState() => _PhotoCompareScreenState();
}

class _PhotoCompareScreenState extends State<PhotoCompareScreen> {
  late ProgressPhoto before = widget.photos.last;
  late ProgressPhoto after = widget.photos.first;
  double split = 0.5;

  Future<void> _choose(bool isBefore) async {
    final p = await showModalBottomSheet<ProgressPhoto>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (c) => SafeArea(
        child: GridView.count(
          crossAxisCount: 4,
          padding: const EdgeInsets.all(12),
          shrinkWrap: true,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 0.75,
          children: [
            for (final x in widget.photos)
              GestureDetector(
                onTap: () => Navigator.pop(c, x),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(x.file, fit: BoxFit.cover, cacheWidth: 240),
                ),
              ),
          ],
        ),
      ),
    );
    if (p != null) setState(() => isBefore ? before = p : after = p);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    Widget label(String title, ProgressPhoto p, bool isBefore) => Expanded(
          child: GestureDetector(
            onTap: () => _choose(isBefore),
            child: AppCard(
              padding: const EdgeInsets.all(10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Txt.small),
                Text('${fmtDate(parseKey(p.day), year: true)}${_weightText(store, p.day)}',
                    style: Txt.body.copyWith(fontWeight: FontWeight.w700)),
                Text(tr('Нажми, чтобы выбрать другое'), style: Txt.small.copyWith(fontSize: 11)),
              ]),
            ),
          ),
        );
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('До и после')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [label(tr('До'), before, true), const SizedBox(width: 8), label(tr('После'), after, false)]),
        ),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            return GestureDetector(
              onHorizontalDragUpdate: (d) => setState(() => split = ((d.localPosition.dx) / c.maxWidth).clamp(0.0, 1.0)),
              onTapDown: (d) => setState(() => split = (d.localPosition.dx / c.maxWidth).clamp(0.0, 1.0)),
              child: Stack(fit: StackFit.expand, children: [
                Image.file(after.file, fit: BoxFit.contain),
                ClipRect(
                  clipper: _LeftClipper(split),
                  child: Image.file(before.file, fit: BoxFit.contain),
                ),
                Positioned(
                  left: c.maxWidth * split - 1,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 2, color: Colors.white),
                ),
              ]),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(tr('Веди пальцем по фото: слева «до», справа «после».'), style: Txt.small, textAlign: TextAlign.center),
        ),
      ]),
    );
  }
}

class _LeftClipper extends CustomClipper<Rect> {
  final double part;
  _LeftClipper(this.part);
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * part, size.height);
  @override
  bool shouldReclip(_LeftClipper old) => old.part != part;
}
