import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../gemini.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'profile_editor.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const Text('Профиль', style: Txt.h1),
            ProfileEditor(
              initial: store.profile,
              submitText: 'Сохранить и пересчитать',
              onSubmit: (p) {
                store.saveProfile(p);
                showToast(context, 'Сохранено. Нормы пересчитаны');
              },
            ),
            const SectionLabel('Распознавание по фото'),
            const _AiCard(),
            const SectionLabel('Данные'),
            const _DataCard(),
            const SizedBox(height: 16),
            const Text(
              'Расчёт по формуле Миффлина — Сан Жеора. Это ориентир, а не медицинская рекомендация. '
              'При заболеваниях, беременности или резких изменениях веса посоветуйся с врачом.',
              style: Txt.small,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _AiCard extends StatefulWidget {
  const _AiCard();

  @override
  State<_AiCard> createState() => _AiCardState();
}

class _AiCardState extends State<_AiCard> {
  final key = TextEditingController();
  final model = TextEditingController();
  bool hidden = true;
  bool testing = false;
  bool loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!loaded) {
      final s = StoreScope.read(context);
      key.text = s.apiKey;
      model.text = s.model;
      loaded = true;
    }
  }

  @override
  void dispose() {
    key.dispose();
    model.dispose();
    super.dispose();
  }

  void _save() {
    FocusScope.of(context).unfocus();
    StoreScope.read(context).setAi(key.text, model.text);
    model.text = StoreScope.read(context).model;
    showToast(context, key.text.trim().isEmpty ? 'Ключ удалён' : 'Ключ сохранён');
  }

  Future<void> _test() async {
    if (key.text.trim().isEmpty) {
      showToast(context, 'Сначала вставь ключ');
      return;
    }
    setState(() => testing = true);
    final err = await GeminiService.testKey(key.text);
    if (!mounted) return;
    setState(() => testing = false);
    if (err == null) {
      StoreScope.read(context).setAi(key.text, model.text);
      showToast(context, 'Ключ работает и сохранён ✓');
    } else {
      showToast(context, err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = StoreScope.of(context).apiKey.isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.accent2, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Google Gemini', style: Txt.h2)),
              Pill(hasKey ? 'подключён' : 'нет ключа', color: hasKey ? AppColors.good : AppColors.under),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Как получить бесплатный ключ:\n'
            '1. Открой aistudio.google.com и войди в Google-аккаунт\n'
            '2. Нажми «Get API key» → «Create API key»\n'
            '3. Скопируй ключ и вставь сюда\n'
            'Ключ хранится только на этом телефоне.',
            style: Txt.small,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(const ClipboardData(text: 'https://aistudio.google.com/apikey'));
                showToast(context, 'Ссылка скопирована — вставь её в браузер');
              },
              child: const Text(
                'Скопировать ссылку',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: key,
            obscureText: hidden,
            autocorrect: false,
            enableSuggestions: false,
            style: Txt.body,
            decoration: fieldDeco('API-ключ').copyWith(
              suffixIcon: IconButton(
                icon: Icon(hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.muted, size: 20),
                onPressed: () => setState(() => hidden = !hidden),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: model,
            autocorrect: false,
            style: Txt.body,
            decoration: fieldDeco('Модель', hint: AppStore.defaultModel),
          ),
          const SizedBox(height: 4),
          const Text('Модель можно не трогать. Если она перестанет работать, приложение само попробует другие.',
              style: Txt.small),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GhostButton(testing ? 'Проверяю…' : 'Проверить',
                    icon: Icons.wifi_tethering, onPressed: testing ? null : _test),
              ),
              const SizedBox(width: 8),
              Expanded(child: PrimaryButton('Сохранить', onPressed: _save)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DataCard extends StatelessWidget {
  const _DataCard();

  Future<void> _import(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Восстановить из копии', style: Txt.h2),
        content: TextField(
          controller: ctrl,
          minLines: 4,
          maxLines: 8,
          style: Txt.small.copyWith(color: AppColors.text),
          decoration: fieldDeco('Вставь сюда текст копии'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Восстановить',
                style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    final txt = ctrl.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (ok != true || !context.mounted) return;
    final err = StoreScope.read(context).importJson(txt);
    showToast(context, err ?? 'Данные восстановлены');
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Записей о еде: ${store.entries.length} · взвешиваний: ${store.weights.length}\n'
            'Всё сохраняется в памяти телефона автоматически. Резервная копия — текстом через буфер обмена '
            '(фото в копию не входят).',
            style: Txt.small,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GhostButton('Копия', icon: Icons.upload_outlined, onPressed: () {
                  Clipboard.setData(ClipboardData(text: store.exportJson()));
                  showToast(context, 'Копия данных скопирована в буфер обмена');
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton('Восстановить', icon: Icons.download_outlined, onPressed: () => _import(context)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GhostButton('Удалить все данные', icon: Icons.delete_forever_outlined, color: AppColors.over,
              onPressed: () async {
            final ok = await confirm(context, 'Удалить все данные?',
                'Профиль, дневник питания, вес и история будут удалены без возможности восстановления.',
                ok: 'Удалить');
            if (ok && context.mounted) StoreScope.read(context).resetAll();
          }),
        ],
      ),
    );
  }
}
