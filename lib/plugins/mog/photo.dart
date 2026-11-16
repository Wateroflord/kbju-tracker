import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Фото, готовое к отправке: уменьшенное для ИИ и маленькое превью для истории.
class Photo {
  final Uint8List full;
  final Uint8List thumb;
  const Photo(this.full, this.thumb);

  String get thumbB64 => base64Encode(thumb);
}

List<Uint8List>? _process(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) return null;
  final oriented = img.bakeOrientation(decoded);
  img.Image fit(int maxSide) {
    final w = oriented.width, h = oriented.height;
    if (w <= maxSide && h <= maxSide) return oriented;
    return w >= h ? img.copyResize(oriented, width: maxSide) : img.copyResize(oriented, height: maxSide);
  }

  final full = Uint8List.fromList(img.encodeJpg(fit(1280), quality: 86));
  final thumb = Uint8List.fromList(img.encodeJpg(fit(360), quality: 78));
  return [full, thumb];
}

Future<Photo?> photoFromBytes(Uint8List raw) async {
  final r = await compute(_process, raw);
  if (r == null) return null;
  return Photo(r[0], r[1]);
}

bool get canUseCamera => Platform.isAndroid || Platform.isIOS;

/// Выбор фото: на телефоне — камера или галерея, на ПК — файл.
Future<Photo?> pickPhoto(BuildContext context) async {
  final ImageSource source;
  if (canUseCamera) {
    final picked = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Сфотографировать'),
            onTap: () => Navigator.pop(c, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Выбрать из галереи'),
            onTap: () => Navigator.pop(c, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (picked == null) return null;
    source = picked;
  } else {
    source = ImageSource.gallery;
  }
  try {
    final x = await ImagePicker().pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 92,
      preferredCameraDevice: CameraDevice.front,
    );
    if (x == null) return null;
    final p = await photoFromBytes(await x.readAsBytes());
    if (p == null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось открыть это фото.')));
    }
    return p;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось выбрать фото: $e')));
    }
    return null;
  }
}
