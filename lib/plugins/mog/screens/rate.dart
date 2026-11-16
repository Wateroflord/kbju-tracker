import 'package:flutter/material.dart';

import '../models.dart';
import '../photo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';
import 'result.dart';

/// Оценка одного фото: внешность, стиль или синергия.
class RateScreen extends StatefulWidget {
  final VoidCallback onOpenSettings;
  const RateScreen({super.key, required this.onOpenSettings});

  @override
  State<RateScreen> createState() => _RateScreenState();
}

class _RateScreenState extends State<RateScreen> {
  Kind _kind = Kind.looks;
  Photo? _photo;

  void _start() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ResultPage(job: Job(kind: _kind, a: _photo!)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оценка')),
      body: StoreBuilder(
        builder: (context, s) {
          // Последняя оценка этого типа — чтобы видеть прогресс.
          final last = s.history.where((e) => !e.battle && e.kind == _kind).take(1).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Narrow(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (!s.hasKey) NoKeyBanner(onOpenSettings: widget.onOpenSettings),
                  const Text('Скинь своё фото — получишь оценку по категориям и конкретные советы, как стать лучше.',
                      style: TextStyle(color: C.muted, height: 1.4)),
                  const SizedBox(height: 16),
                  KindPicker(value: _kind, onChanged: (k) => setState(() => _kind = k)),
                  const SizedBox(height: 18),
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: PhotoSlot(
                        photo: _photo,
                        label: 'Твоё фото',
                        color: C.gold,
                        onPicked: (p) => setState(() => _photo = p),
                        onClear: () => setState(() => _photo = null),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 16, color: C.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_kind.hint, style: const TextStyle(color: C.muted, fontSize: 12.5, height: 1.3)),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: (_photo != null && s.hasKey) ? _start : null,
                    icon: Icon(_kind.icon),
                    label: const Text('ОЦЕНИТЬ'),
                  ),
                  if (last.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Panel(
                      padding: const EdgeInsets.all(12),
                      child: InkWell(
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => ResultPage(entry: last.first))),
                        child: Row(children: [
                          PhotoBox(b64: last.first.thumbA, width: 48, height: 60, radius: 10),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Прошлая оценка: ${_kind.title.toLowerCase()}',
                                  style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text(fmtDate(last.first.date), style: const TextStyle(color: C.muted, fontSize: 12.5)),
                            ]),
                          ),
                          Text(fmtScore(last.first.solo.overall),
                              style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: scoreColor(last.first.solo.overall))),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, color: C.muted),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
}

String fmtDate(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}
