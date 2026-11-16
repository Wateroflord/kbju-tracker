import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Ищет товар по штрихкоду в открытой базе Open Food Facts.
class ProductLookup {
  static Future<ProductInfo?> fetch(String barcode) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$code.json'
        '?fields=product_name,product_name_ru,product_name_pl,product_name_en,'
        'brands,quantity,image_front_url,image_url');
    try {
      final r = await http.get(uri, headers: {
        'User-Agent': 'WinterExpiry/1.0 (Android; personal app)',
      }).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      final raw = data['product'];
      if (raw is! Map) return null;
      final Map<String, dynamic> p = Map<String, dynamic>.from(raw);

      String? pick(String key) {
        final v = p[key];
        if (v is String && v.trim().isNotEmpty) return v.trim();
        return null;
      }

      var name = pick('product_name_ru') ??
          pick('product_name_pl') ??
          pick('product_name') ??
          pick('product_name_en') ??
          '';
      final brand = pick('brands')?.split(',').first.trim();
      if (brand != null &&
          brand.isNotEmpty &&
          !name.toLowerCase().contains(brand.toLowerCase())) {
        name = name.isEmpty ? brand : '$brand $name';
      }
      final qty = pick('quantity');
      if (qty != null && name.isNotEmpty && !name.contains(qty)) {
        name = '$name $qty';
      }
      final image = pick('image_front_url') ?? pick('image_url');
      if (name.isEmpty && image == null) return null;
      return ProductInfo(name: name, imageUrl: image);
    } catch (e) {
      debugPrint('Поиск товара $code: $e');
      return null;
    }
  }
}
