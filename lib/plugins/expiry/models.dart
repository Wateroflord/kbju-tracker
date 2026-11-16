import 'package:flutter/material.dart';

/// Раздел (полка).
enum Shelf { water, beer, energy }

extension ShelfInfo on Shelf {
  String get title {
    switch (this) {
      case Shelf.water:
        return 'Вода';
      case Shelf.beer:
        return 'Пиво';
      case Shelf.energy:
        return 'Энергетики';
    }
  }

  String get emoji {
    switch (this) {
      case Shelf.water:
        return '💧';
      case Shelf.beer:
        return '🍺';
      case Shelf.energy:
        return '⚡';
    }
  }
}

Shelf shelfFromName(String? s) =>
    Shelf.values.firstWhere((e) => e.name == s, orElse: () => Shelf.water);

/// Разница в календарных днях (без проблем с переводом часов).
int daysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;

String _two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) => '${_two(d.day)}.${_two(d.month)}.${d.year}';

String fmtTime(int h, int m) => '${_two(h)}:${_two(m)}';

/// Понимает «12.11.26», «12.11.2026», «12/11/26», «121126», «12112026», «12.11».
DateTime? parseDate(String input) {
  final parts = input
      .replaceAll(RegExp(r'[^0-9]'), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  int? d;
  int? m;
  int? y;
  if (parts.length >= 2) {
    d = int.tryParse(parts[0]);
    m = int.tryParse(parts[1]);
    if (parts.length >= 3) y = int.tryParse(parts[2]);
  } else if (parts.length == 1) {
    final t = parts[0];
    if (t.length == 4 || t.length == 6 || t.length == 8) {
      d = int.parse(t.substring(0, 2));
      m = int.parse(t.substring(2, 4));
      if (t.length > 4) y = int.parse(t.substring(4));
    } else {
      return null;
    }
  } else {
    return null;
  }
  if (d == null || m == null) return null;
  y ??= DateTime.now().year;
  if (y < 100) y += 2000;
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 2000 || y > 2100) return null;
  final dt = DateTime(y, m, d);
  if (dt.month != m || dt.day != d) return null; // например 31.02
  return dt;
}

enum ExpiryStatus { expired, soon, ok }

const Color kRed = Color(0xFFE5484D);
const Color kOrange = Color(0xFFF5A524);
const Color kGreen = Color(0xFF46A758);

Color statusColor(ExpiryStatus s) {
  switch (s) {
    case ExpiryStatus.expired:
      return kRed;
    case ExpiryStatus.soon:
      return kOrange;
    case ExpiryStatus.ok:
      return kGreen;
  }
}

String statusText(int daysLeft) {
  if (daysLeft < 0) return 'ПРОСРОЧЕНО (${-daysLeft} дн.)';
  if (daysLeft == 0) return 'сегодня последний день';
  if (daysLeft == 1) return 'завтра последний день';
  return 'осталось $daysLeft дн.';
}

class Item {
  Item({
    required this.id,
    required this.shelf,
    required this.name,
    required this.barcode,
    required this.expiry,
    this.quantity = 1,
    this.imageUrl,
    this.removed = false,
    this.removedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  Shelf shelf;
  String name;
  String barcode;
  DateTime expiry;
  int quantity;
  String? imageUrl;
  bool removed;
  DateTime? removedAt;
  final DateTime createdAt;

  int get daysLeft => daysBetween(DateTime.now(), expiry);

  ExpiryStatus status(int warnDays) {
    final d = daysLeft;
    if (d < 0) return ExpiryStatus.expired;
    if (d <= warnDays) return ExpiryStatus.soon;
    return ExpiryStatus.ok;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'shelf': shelf.name,
        'name': name,
        'barcode': barcode,
        'expiry': expiry.toIso8601String(),
        'quantity': quantity,
        'imageUrl': imageUrl,
        'removed': removed,
        'removedAt': removedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        id: j['id'] as String,
        shelf: shelfFromName(j['shelf'] as String?),
        name: (j['name'] as String?) ?? '',
        barcode: (j['barcode'] as String?) ?? '',
        expiry: DateTime.parse(j['expiry'] as String),
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        imageUrl: j['imageUrl'] as String?,
        removed: (j['removed'] as bool?) ?? false,
        removedAt: j['removedAt'] == null
            ? null
            : DateTime.parse(j['removedAt'] as String),
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.parse(j['createdAt'] as String),
      );
}

/// То, что приложение запомнило про штрихкод (название, картинка, раздел).
class ProductInfo {
  const ProductInfo({required this.name, this.imageUrl, this.shelf});

  final String name;
  final String? imageUrl;
  final Shelf? shelf;

  Map<String, dynamic> toJson() => {
        'name': name,
        'imageUrl': imageUrl,
        'shelf': shelf?.name,
      };

  factory ProductInfo.fromJson(Map<String, dynamic> j) => ProductInfo(
        name: (j['name'] as String?) ?? '',
        imageUrl: j['imageUrl'] as String?,
        shelf: j['shelf'] == null ? null : shelfFromName(j['shelf'] as String?),
      );
}
