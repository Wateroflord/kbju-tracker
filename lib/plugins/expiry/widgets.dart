import 'package:flutter/material.dart';

import 'models.dart';

const Color kCard = Color(0xFF14233D);

class ProductImage extends StatelessWidget {
  const ProductImage(
      {super.key, required this.url, required this.shelf, this.size = 56});

  final String? url;
  final Shelf shelf;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Center(
      child: Text(shelf.emoji, style: TextStyle(fontSize: size * 0.45)),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Container(
        width: size,
        height: size,
        color: (u == null || u.isEmpty) ? const Color(0xFF1E3152) : Colors.white,
        child: (u == null || u.isEmpty)
            ? placeholder
            : Image.network(
                u,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => Container(
                  color: const Color(0xFF1E3152),
                  child: placeholder,
                ),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              ),
      ),
    );
  }
}

class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.warnDays,
    required this.onTap,
    required this.onRemove,
  });

  final Item item;
  final int warnDays;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final d = item.daysLeft;
    final color = statusColor(item.status(warnDays));
    return Card(
      color: kCard,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: color),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Center(
                    child: ProductImage(url: item.imageUrl, shelf: item.shelf)),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'до ${fmtDate(item.expiry)} · ${statusText(d)}',
                        style: TextStyle(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      if (item.barcode.isNotEmpty)
                        Text(
                          item.barcode,
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF8DA2C0)),
                        ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '×${item.quantity}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Center(
                child: IconButton(
                  tooltip: 'Снято с полки',
                  icon: const Icon(Icons.check_circle_outline),
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
