import 'package:flutter/material.dart';

import '../models.dart';
import '../storage.dart';
import '../widgets.dart';

/// Всё, что уже снято с полки.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _clear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text('Все снятые товары удалятся навсегда.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Очистить')),
        ],
      ),
    );
    if (ok == true) await AppStore.instance.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Снято с полки'),
        actions: [
          IconButton(
            tooltip: 'Очистить',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _clear(context),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final list = store.history;
          if (list.isEmpty) {
            return const Center(child: Text('Пока ничего не снято'));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final it = list[i];
              final removed = it.removedAt;
              return Card(
                color: kCard,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading:
                      ProductImage(url: it.imageUrl, shelf: it.shelf, size: 44),
                  title: Text(it.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${it.shelf.emoji} ×${it.quantity} · срок до ${fmtDate(it.expiry)}'
                    '${removed == null ? '' : '\nснято ${fmtDate(removed)}'}',
                  ),
                  isThreeLine: removed != null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Вернуть на полку',
                        icon: const Icon(Icons.undo),
                        onPressed: () => store.restore(it),
                      ),
                      IconButton(
                        tooltip: 'Удалить',
                        icon: const Icon(Icons.close),
                        onPressed: () => store.delete(it),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
