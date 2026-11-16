import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../notifications.dart';
import '../storage.dart';
import '../widgets.dart';
import 'edit_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final AppStore _store = AppStore.instance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: Shelf.values.length, vsync: this);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Notifier.requestPermission());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Shelf get _currentShelf => Shelf.values[_tab.index];

  void _open({Item? item, bool scan = false}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditScreen(
        shelf: item?.shelf ?? _currentShelf,
        item: item,
        startWithScan: scan,
      ),
    ));
  }

  void _remove(Item item) {
    _store.markRemoved(item);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Снято: ${item.name}'),
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () => _store.restore(item),
        ),
      ));
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _exportBackup() async {
    try {
      final dir = await getTemporaryDirectory();
      final d = DateTime.now();
      final name = 'prosrochka-${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}.json';
      final f = File('${dir.path}/$name');
      await f.writeAsString(_store.exportBackup());
      await SharePlus.instance.share(ShareParams(
          files: [XFile(f.path, mimeType: 'application/json')], subject: 'Просрочка — резервная копия'));
    } catch (e) {
      _snack('Не удалось сохранить копию: $e');
    }
  }

  Future<void> _importBackup() async {
    try {
      final r = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      final file = r?.files.single;
      if (file == null) return;
      final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
      if (bytes == null) return;
      final n = await _store.importBackup(utf8.decode(bytes, allowMalformed: true));
      _snack('Восстановлено товаров: $n');
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Не удалось восстановить: $e');
    }
  }

  void _openSettings() {
    var warn = _store.warnDays;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Настройки', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              Text('Предупреждать за $warn дн. до конца срока'),
              Slider(
                value: warn.toDouble(),
                min: 1,
                max: 7,
                divisions: 6,
                label: '$warn',
                onChanged: (v) => setSheet(() => warn = v.round()),
                onChangeEnd: (v) => _store.updateSettings(warn: v.round()),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm),
                title: const Text('Время уведомлений'),
                trailing: Text(fmtTime(_store.notifyHour, _store.notifyMinute),
                    style: const TextStyle(fontSize: 16)),
                onTap: () async {
                  final t = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay(
                        hour: _store.notifyHour, minute: _store.notifyMinute),
                  );
                  if (t == null) return;
                  await _store.updateSettings(hour: t.hour, minute: t.minute);
                  if (ctx.mounted) setSheet(() {});
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.notifications_active_outlined),
                title: const Text('Проверить уведомление'),
                onTap: () => Notifier.showTest(),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.upload_file),
                title: const Text('Сохранить резервную копию'),
                subtitle: const Text('Файл можно отправить себе в Telegram или на Google Диск'),
                onTap: _exportBackup,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restore),
                title: const Text('Восстановить из копии'),
                onTap: () async {
                  await _importBackup();
                  if (ctx.mounted) setSheet(() => warn = _store.warnDays);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabLabel(Shelf s) {
    final n = _store.alertCount(s);
    return Tab(
      icon: Badge(
        isLabelVisible: n > 0,
        label: Text('$n'),
        child: Text(s.emoji, style: const TextStyle(fontSize: 22)),
      ),
      child: FittedBox(fit: BoxFit.scaleDown, child: Text(s.title)),
    );
  }

  Widget _list(Shelf shelf) {
    final list = _store.activeFor(shelf);
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            '${shelf.emoji}\n\nЗдесь пусто.\nНажми «+», чтобы добавить товар',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Color(0xFF8DA2C0)),
          ),
        ),
      );
    }
    final expired =
        list.where((i) => i.status(_store.warnDays) == ExpiryStatus.expired).length;
    final soon =
        list.where((i) => i.status(_store.warnDays) == ExpiryStatus.soon).length;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 6, bottom: 160),
      itemCount: list.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('Всего: ${list.length}', const Color(0xFF8DA2C0)),
                if (expired > 0) _chip('Просрочено: $expired', kRed),
                if (soon > 0) _chip('Скоро: $soon', kOrange),
              ],
            ),
          );
        }
        final item = list[i - 1];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.startToEnd,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
                color: kGreen, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Row(
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 8),
                Text('Снято',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          onDismissed: (_) => _remove(item),
          child: ItemTile(
            item: item,
            warnDays: _store.warnDays,
            onTap: () => _open(item: item),
            onRemove: () => _remove(item),
          ),
        );
      },
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Просрочка',
              style: TextStyle(fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              tooltip: 'Снято с полки',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const HistoryScreen())),
            ),
            IconButton(
              tooltip: 'Настройки',
              icon: const Icon(Icons.settings_outlined),
              onPressed: _openSettings,
            ),
          ],
          bottom: TabBar(
            controller: _tab,
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            tabs: Shelf.values.map(_tabLabel).toList(),
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: Shelf.values.map(_list).toList(),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton(
              heroTag: 'scan',
              tooltip: 'Сразу сканировать',
              onPressed: () => _open(scan: true),
              child: const Icon(Icons.qr_code_scanner),
            ),
            const SizedBox(height: 14),
            FloatingActionButton.large(
              heroTag: 'add',
              tooltip: 'Добавить товар',
              onPressed: () => _open(),
              child: const Icon(Icons.add, size: 40),
            ),
          ],
        ),
      ),
    );
  }
}
