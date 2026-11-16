import 'package:flutter/material.dart';

import '../models.dart';
import '../photo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'result.dart';

/// Мог-батл: два фото, ИИ сравнивает по категориям.
class BattleScreen extends StatefulWidget {
  final VoidCallback onOpenSettings;
  const BattleScreen({super.key, required this.onOpenSettings});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  Kind _kind = Kind.looks;
  Photo? _a, _b;
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _start() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultPage(job: Job(kind: _kind, a: _a!, b: _b!, opponent: _name.text)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мог-батл')),
      body: StoreBuilder(
        builder: (context, s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Narrow(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (!s.hasKey) NoKeyBanner(onOpenSettings: widget.onOpenSettings),
                const Text('Загрузи своё фото и фото соперника — ИИ разберёт, кто где сильнее и почему.',
                    style: TextStyle(color: C.muted, height: 1.4)),
                const SizedBox(height: 16),
                KindPicker(value: _kind, onChanged: (k) => setState(() => _kind = k)),
                const SizedBox(height: 18),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                    child: PhotoSlot(
                      photo: _a,
                      label: 'Ты',
                      color: C.a,
                      onPicked: (p) => setState(() => _a = p),
                      onClear: () => setState(() => _a = null),
                    ),
                  ),
                  Container(
                    width: 44,
                    alignment: Alignment.center,
                    child: const Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: C.gold)),
                  ),
                  Expanded(
                    child: PhotoSlot(
                      photo: _b,
                      label: 'Соперник',
                      color: C.b,
                      onPicked: (p) => setState(() => _b = p),
                      onClear: () => setState(() => _b = null),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 16, color: C.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_kind.hint, style: const TextStyle(color: C.muted, fontSize: 12.5, height: 1.3)),
                  ),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Имя соперника (необязательно)',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: (_a != null && _b != null && s.hasKey) ? _start : null,
                  icon: const Icon(Icons.local_fire_department_rounded),
                  label: const Text('В БОЙ'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Сравнивай только с теми, кто согласен на батл. Фото отправляются в Google Gemini для оценки, '
                  'в приложении остаются только маленькие превью в истории.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.muted, fontSize: 12, height: 1.35),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
