import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbju_tracker/plugins/registry.dart';

void main() {
  test('плагины: уникальные id, КБЖУ — основа, иконки на месте', () {
    final ids = <String>{};
    for (final p in winterPlugins) {
      expect(ids.add(p.id), isTrue, reason: 'повтор ${p.id}');
      expect(File(p.icon).existsSync(), isTrue, reason: p.icon);
    }
    expect(winterPlugins.first.id, 'kbju');
    expect(winterPlugins.where((p) => p.core).map((p) => p.id), ['kbju']);
    expect(winterPlugins.length, 12);
  });

  test('ассеты плагинов объявлены в pubspec.yaml', () {
    final pub = File('pubspec.yaml').readAsStringSync();
    for (final p in winterPlugins.where((p) => !p.core)) {
      expect(pub, contains('assets/plugins/${p.id}/'), reason: p.id);
    }
  });
}
