import 'package:flutter/material.dart';

import '../data_export.dart';
import '../life/health_sync.dart';
import '../platform.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../i18n/i18n.dart';

/// Какие вкладки показывать внизу.
class TabsCard extends StatelessWidget {
  const TabsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ex = store.extra;
    Widget row(String id, IconData icon, String title, String desc) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(icon, color: AppColors.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                    Text(desc, style: Txt.small),
                  ],
                ),
              ),
              Switch(value: ex.tabVisible(id), onChanged: (v) => ex.setTabVisible(id, v)),
            ],
          ),
        );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Выключи вкладки, которыми не пользуешься, — меню станет проще. Данные не удаляются, вкладку можно вернуть в любой момент.'),
              style: Txt.small),
          const SizedBox(height: 8),
          row('training', Icons.fitness_center, tr('Спорт'), tr('Тренировки, программы, разминки')),
          row('care', Icons.spa_outlined, tr('Уход'), tr('Кожа, волосы, покупки')),
          row('learn', Icons.translate, tr('Учёба'), tr('Переехала в Winter Language')),
        ],
      ),
    );
  }
}

/// Вес, сон и тренировки из Health Connect.
class HealthConnectCard extends StatefulWidget {
  const HealthConnectCard({super.key});

  @override
  State<HealthConnectCard> createState() => _HealthConnectCardState();
}

class _HealthConnectCardState extends State<HealthConnectCard> {
  bool busy = false;

  Future<void> _connect() async {
    final store = StoreScope.read(context);
    setState(() => busy = true);
    final err = await HealthSync.instance.connect(store);
    if (!mounted) return;
    setState(() => busy = false);
    showToast(context, err ?? tr('Health Connect подключён, данные подтянуты'));
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final ex = store.extra;
    Widget sw(String title, String desc, bool v, ValueChanged<bool> on) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                  Text(desc, style: Txt.small),
                ],
              ),
            ),
            Switch(value: v, onChanged: on),
          ],
        );
    final last = ex.hcLastSync > 0 ? DateTime.fromMillisecondsSinceEpoch(ex.hcLastSync) : null;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Подтягивает данные с умных весов и часов (Samsung Health, Google Fit, Mi Fitness, Garmin — всё, что пишет в Health Connect). То, что ты ввёл вручную, не перезаписывается.'),
            style: Txt.small,
          ),
          const SizedBox(height: 8),
          sw(tr('Вес'), tr('С умных весов'), ex.hcWeight, (v) => ex.setHc(weight: v)),
          sw(tr('Сон'), tr('С часов или браслета'), ex.hcSleep, (v) => ex.setHc(sleep: v)),
          sw(tr('Тренировки'), tr('Бег, вело, зал — со временем и калориями'), ex.hcWorkouts, (v) => ex.setHc(workouts: v)),
          const SizedBox(height: 10),
          PrimaryButton(
            ex.hcLastSync > 0 ? tr('Синхронизировать сейчас') : tr('Подключить Health Connect'),
            icon: Icons.favorite_border,
            loading: busy,
            onPressed: ex.hcAny ? _connect : null,
          ),
          if (last != null) ...[
            const SizedBox(height: 6),
            Text(trf('Последняя синхронизация: {0}, {1}:{2}', [fmtDate(last), two(last.hour), two(last.minute)]),
                style: Txt.small, textAlign: TextAlign.center),
          ],
          ValueListenableBuilder<String>(
            valueListenable: HealthSync.instance.status,
            builder: (_, v, __) => v.isEmpty
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(v, style: Txt.small.copyWith(color: AppColors.over)),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Резервная копия файлом и выгрузка в таблицы.
class BackupCard extends StatefulWidget {
  const BackupCard({super.key});

  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  bool busy = false;

  Future<void> _run(Future<String?> Function(AppStore) f, {String? ok}) async {
    final store = StoreScope.read(context);
    setState(() => busy = true);
    final msg = await f(store);
    if (!mounted) return;
    setState(() => busy = false);
    if (msg == null) {
      if (ok != null) showToast(context, ok);
    } else if (msg.isNotEmpty) {
      showToast(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!isWindows) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_done_outlined, color: AppColors.good, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr('Автокопия на Google Диск включена: Android сам сохраняет данные примерно раз в сутки (когда телефон заряжается и есть Wi-Fi) и возвращает их при установке приложения на новый телефон. Проверь, что включено: Настройки → Google → Резервное копирование. Фото в автокопию не входят.'),
                    style: Txt.small,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Text(
            isWindows
                ? tr('Копия и таблицы сохраняются в папку «Загрузки».')
                : tr('Копию можно сохранить и вручную — файлом на Google Диск, в Telegram или на почту.'),
            style: Txt.small,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GhostButton(tr('Копия файлом'), icon: Icons.save_alt,
                    onPressed: busy ? null : () => _run(DataExport.backupFile)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GhostButton(tr('Из файла'), icon: Icons.file_open_outlined,
                    onPressed: busy ? null : () => _run(DataExport.restoreFile, ok: tr('Данные восстановлены'))),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GhostButton(tr('Таблица для Excel (CSV)'), icon: Icons.table_chart_outlined,
              onPressed: busy ? null : () => _run(DataExport.csvFiles)),
        ],
      ),
    );
  }
}
