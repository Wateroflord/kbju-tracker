import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../ai.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'common.dart';

const appBuild = int.fromEnvironment('BUILD', defaultValue: 0);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _key = TextEditingController(text: Store.I.apiKey);
  final _model = TextEditingController(text: Store.I.model);
  bool _show = false;
  bool _testing = false;
  String? _status;
  bool _ok = false;

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    setState(() {
      _testing = true;
      _status = null;
    });
    final err = await Ai.testKey(_key.text);
    await Store.I.saveSettings(apiKey: _key.text);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _ok = err == null;
      _status = err ?? 'Ключ работает и сохранён.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: StoreBuilder(
        builder: (context, s) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            Narrow(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SectionTitle('Ключ Gemini', icon: Icons.key_rounded),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text(
                      'Оценку делает Google Gemini. Ключ бесплатный: открой Google AI Studio, нажми «Create API key» '
                      'и вставь его сюда. Можно тот же, что в КБЖУ Трекере.',
                      style: TextStyle(color: C.muted, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _key,
                      obscureText: !_show,
                      autocorrect: false,
                      enableSuggestions: false,
                      decoration: InputDecoration(
                        labelText: 'API-ключ',
                        suffixIcon: IconButton(
                          icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _show = !_show),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _testing ? null : _saveKey,
                          child: _testing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Проверить и сохранить'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
                        onPressed: () => launchUrl(Uri.parse('https://aistudio.google.com/apikey'),
                            mode: LaunchMode.externalApplication),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Взять ключ'),
                      ),
                    ]),
                    if (_status != null) ...[
                      const SizedBox(height: 10),
                      Text(_status!, style: TextStyle(color: _ok ? C.good : C.warn)),
                    ],
                  ]),
                ),
                const SectionTitle('Тон оценки', icon: Icons.record_voice_over_outlined),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        for (var i = 0; i < toneNames.length; i++) ButtonSegment(value: i, label: Text(toneNames[i])),
                      ],
                      selected: {s.tone},
                      onSelectionChanged: (v) => Store.I.saveSettings(tone: v.first),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      switch (s.tone) {
                        0 => 'Поддерживающе: сначала сильные стороны, минусы — мягко.',
                        2 => 'Жёстко и с юмором, как прожарка. Но без оскорблений и всегда с советами.',
                        _ => 'Прямо и по делу, как друг-стилист: без лести и без грубости.',
                      },
                      style: const TextStyle(color: C.muted, height: 1.35),
                    ),
                  ]),
                ),
                const SectionTitle('Модель ИИ', icon: Icons.memory_rounded),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TextField(
                      controller: _model,
                      autocorrect: false,
                      decoration: InputDecoration(
                        labelText: 'Модель (пусто — ${Ai.fallbackModels.first})',
                      ),
                      onSubmitted: (v) => Store.I.saveSettings(model: v),
                      onChanged: (v) => Store.I.saveSettings(model: v),
                    ),
                    const SizedBox(height: 8),
                    const Text('Менять не обязательно. Если модель недоступна, приложение само попробует другие.',
                        style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.35)),
                  ]),
                ),
                const SectionTitle('Данные', icon: Icons.lock_outline_rounded),
                Panel(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text(
                      'Фото отправляются в Google Gemini только для оценки. В приложении хранятся лишь маленькие '
                      'превью и результаты — в истории на этом устройстве.',
                      style: TextStyle(color: C.muted, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(foregroundColor: C.bad, minimumSize: const Size(0, 48)),
                      onPressed: s.history.isEmpty
                          ? null
                          : () async {
                              final yes = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Очистить историю?'),
                                  content: Text('Будет удалено записей: ${s.history.length}.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
                                    TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Удалить')),
                                  ],
                                ),
                              );
                              if (yes == true) await Store.I.clearHistory();
                            },
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: Text('Очистить историю (${s.history.length})'),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
                Text(
                  'Mog Battle · сборка ${appBuild == 0 ? 'dev' : appBuild}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.muted, fontSize: 12),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
