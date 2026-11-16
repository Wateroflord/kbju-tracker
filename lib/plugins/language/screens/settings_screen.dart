import 'package:flutter/material.dart';

import '../backup.dart';
import '../../../i18n/i18n.dart';
import '../store.dart';
import '../../../theme.dart';
import '../../../widgets/common.dart';
import '../widgets/nav.dart';

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Перенос прогресса из КБЖУ Трекера (кнопка в настройках и окно при первом запуске).
Future<void> importFromKbju(BuildContext context) async {
  final store = StoreScope.read(context);
  final err = await Backup.load(store);
  if (!context.mounted || err == '') return;
  showMessage(context, err ?? tr('Прогресс перенесён'));
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SectionLabel(tr('Язык интерфейса')),
          Text(tr('На этом языке показываются переводы слов.'), style: Txt.small),
          const SizedBox(height: 8),
          Segmented<AppLang>(
            values: AppLang.values,
            label: (l) => l.flag,
            selected: store.uiLang,
            onChanged: store.setUiLang,
          ),
          SectionLabel(tr('Перенос из КБЖУ Трекера')),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Раньше учёба была вкладкой в КБЖУ Трекере. В КБЖУ открой вкладку «Учёба» и нажми «Сохранить прогресс» (или сделай обычную копию в профиле), потом выбери этот файл здесь. Уже выученное в Winter Language не пропадёт.'),
                  style: Txt.small,
                ),
                const SizedBox(height: 12),
                PrimaryButton(tr('Выбрать файл из КБЖУ'), icon: Icons.download_outlined, onPressed: () => importFromKbju(context)),
              ],
            ),
          ),
          SectionLabel(tr('Резервная копия')),
          Row(
            children: [
              Expanded(
                child: GhostButton(tr('Сохранить'), icon: Icons.upload_file, onPressed: () async {
                  final err = await Backup.save(store);
                  if (err != null && context.mounted) showMessage(context, err);
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton(tr('Восстановить'), icon: Icons.restore, onPressed: () async {
                  final err = await Backup.load(store);
                  if (!context.mounted || err == '') return;
                  showMessage(context, err ?? tr('Данные восстановлены'));
                }),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(tr('Winter Language — приложение семейства Winter Hub. Обновления ставятся через Winter Hub.'), style: Txt.small),
        ],
      ),
    );
  }
}
