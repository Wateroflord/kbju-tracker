import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../product_lookup.dart';
import '../storage.dart';
import '../widgets.dart';
import 'scanner_screen.dart';

/// Добавление / редактирование товара.
class EditScreen extends StatefulWidget {
  const EditScreen(
      {super.key, required this.shelf, this.item, this.startWithScan = false});

  final Shelf shelf;
  final Item? item;
  final bool startWithScan;

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  final AppStore _store = AppStore.instance;
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _date;
  late final TextEditingController _qty;
  late Shelf _shelf;
  DateTime? _expiry;
  String? _imageUrl;
  bool _loading = false;

  bool get _isNew => widget.item == null;

  @override
  void initState() {
    super.initState();
    final it = widget.item;
    _shelf = it?.shelf ?? widget.shelf;
    _name = TextEditingController(text: it?.name ?? '');
    _barcode = TextEditingController(text: it?.barcode ?? '');
    _expiry = it?.expiry;
    _date = TextEditingController(text: it == null ? '' : fmtDate(it.expiry));
    _qty = TextEditingController(text: '${it?.quantity ?? 1}');
    _imageUrl = it?.imageUrl;
    if (widget.startWithScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _date.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (code == null || !mounted) return;
    _barcode.text = code;
    await _lookup(code);
  }

  Future<void> _lookup(String input) async {
    final code = input.trim();
    if (code.isEmpty) {
      _toast('Сначала введи или отсканируй штрихкод');
      return;
    }
    final known = _store.known(code);
    if (known != null && known.name.isNotEmpty) {
      setState(() {
        _name.text = known.name;
        _imageUrl = known.imageUrl ?? _imageUrl;
        final ks = known.shelf;
        if (_isNew && ks != null) _shelf = ks;
      });
      _toast('Этот товар уже был — заполнил из памяти');
      return;
    }
    setState(() => _loading = true);
    final info = await ProductLookup.fetch(code);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (info != null) {
        if (info.name.isNotEmpty) _name.text = info.name;
        _imageUrl = info.imageUrl ?? _imageUrl;
      }
    });
    _toast(info == null
        ? 'В интернете не нашёл — впиши название сам, дальше запомню'
        : 'Нашёл: ${info.name}');
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 2);
    final last = DateTime(now.year + 6);
    var initial = _expiry ?? now;
    if (initial.isBefore(first) || initial.isAfter(last)) initial = now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'Годен до',
    );
    if (picked == null) return;
    setState(() {
      _expiry = picked;
      _date.text = fmtDate(picked);
    });
  }

  Future<void> _pasteImage() async {
    final ctrl = TextEditingController(text: _imageUrl ?? '');
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ссылка на картинку'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://...'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, ''),
              child: const Text('Убрать')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('OK')),
        ],
      ),
    );
    ctrl.dispose();
    if (url == null) return;
    setState(() => _imageUrl = url.isEmpty ? null : url);
  }

  void _changeQty(int delta) {
    final q = (int.tryParse(_qty.text) ?? 1) + delta;
    _qty.text = '${q.clamp(1, 9999)}';
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final exp = _expiry;
    if (name.isEmpty) {
      _toast('Впиши название товара');
      return;
    }
    if (exp == null) {
      _toast('Укажи дату «годен до»');
      return;
    }
    final old = widget.item;
    final item = Item(
      id: old?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      shelf: _shelf,
      name: name,
      barcode: _barcode.text.trim(),
      expiry: exp,
      quantity: (int.tryParse(_qty.text) ?? 1).clamp(1, 9999).toInt(),
      imageUrl: _imageUrl,
      removed: old?.removed ?? false,
      removedAt: old?.removedAt,
      createdAt: old?.createdAt,
    );
    await _store.save(item);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _markRemoved() async {
    final it = widget.item;
    if (it == null) return;
    await _store.markRemoved(it);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final it = widget.item;
    if (it == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить товар?'),
        content: Text(it.name),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (ok != true) return;
    await _store.delete(it);
    if (mounted) Navigator.of(context).pop();
  }

  String? _dateHelper() {
    if (_date.text.trim().isEmpty) return 'Можно писать коротко: 121126 или 12.11';
    final exp = _expiry;
    if (exp == null) return 'Не понимаю дату';
    return '${fmtDate(exp)} · ${statusText(daysBetween(DateTime.now(), exp))}';
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 14);
    final it = widget.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Новый товар' : 'Редактировать'),
        actions: [
          if (!_isNew)
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                ProductImage(url: _imageUrl, shelf: _shelf, size: 130),
                if (_loading) const CircularProgressIndicator(),
              ],
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: _pasteImage,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('Своя ссылка на картинку'),
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: _loading ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Сканировать штрихкод',
                style: TextStyle(fontSize: 16)),
          ),
          gap,
          Wrap(
            spacing: 8,
            children: Shelf.values
                .map((s) => ChoiceChip(
                      label: Text('${s.emoji} ${s.title}'),
                      selected: _shelf == s,
                      onSelected: (_) => setState(() => _shelf = s),
                    ))
                .toList(),
          ),
          gap,
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
          ),
          gap,
          TextField(
            controller: _barcode,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Штрихкод',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Найти по коду',
                icon: const Icon(Icons.search),
                onPressed: _loading ? null : () => _lookup(_barcode.text),
              ),
            ),
          ),
          gap,
          TextField(
            controller: _date,
            keyboardType: TextInputType.datetime,
            onChanged: (s) => setState(() => _expiry = parseDate(s)),
            decoration: InputDecoration(
              labelText: 'Годен до (ДД.ММ.ГГ)',
              hintText: '12.11.26',
              helperText: _dateHelper(),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Календарь',
                icon: const Icon(Icons.calendar_month),
                onPressed: _pickDate,
              ),
            ),
          ),
          gap,
          Row(
            children: [
              const Text('Количество', style: TextStyle(fontSize: 16)),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: () => _changeQty(-1),
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 72,
                child: TextField(
                  controller: _qty,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _changeQty(1),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: _loading ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Сохранить', style: TextStyle(fontSize: 16)),
          ),
          if (it != null && !it.removed) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style:
                  OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _markRemoved,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Снято с полки'),
            ),
          ],
        ],
      ),
    );
  }
}
