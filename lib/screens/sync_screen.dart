import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../i18n/i18n.dart';
import '../platform.dart';
import '../store.dart';
import '../sync/sync_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';

/// Синхронизация телефон ↔ ПК по Wi-Fi.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final sync = SyncService.instance;
  bool busy = false;
  String? result;
  final ip = TextEditingController(), port = TextEditingController(text: '4747'), code = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = StoreScope.read(context);
      sync.loadInfo(s);
      if (isWindows) sync.startHost(s);
    });
  }

  @override
  void dispose() {
    if (isWindows) sync.stopHost();
    ip.dispose();
    port.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> _run(SyncTicket t) async {
    setState(() {
      busy = true;
      result = null;
    });
    final r = await sync.syncWith(StoreScope.read(context), t);
    if (!mounted) return;
    setState(() {
      busy = false;
      result = r;
    });
  }

  Future<void> _scan() async {
    final v = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _QrScan()));
    if (v == null) return;
    final t = SyncTicket.parse(v);
    if (t == null) {
      if (mounted) showToast(context, tr('Это не QR синхронизации'));
      return;
    }
    await _run(t);
  }

  String _ago(int ms) {
    if (ms == 0) return tr('ещё не было');
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Синхронизация телефон ↔ ПК')),
      body: ListenableBuilder(
        listenable: sync,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
          children: [
            Text(
              tr('Еда, вес, вода, привычки, тренировки и фото становятся одинаковыми на телефоне и ПК. Интернет не нужен — только одна сеть Wi-Fi.'),
              style: Txt.small,
            ),
            const SizedBox(height: 6),
            Text(trf('Последняя синхронизация: {0}', [_ago(sync.lastSync)]), style: Txt.small.copyWith(color: AppColors.text)),
            if (isWindows) ..._host() else ..._client(),
          ],
        ),
      ),
    );
  }

  List<Widget> _host() {
    final t = sync.ticket;
    return [
      SectionLabel(tr('Шаг 1. Открой это на телефоне')),
      AppCard(
        child: Text(tr('На телефоне: КБЖУ Трекер → Профиль и настройки → Синхронизация → «Сканировать QR с ПК».'), style: Txt.body),
      ),
      SectionLabel(tr('Шаг 2. Наведи камеру телефона на код')),
      AppCard(
        child: t == null
            ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: AppColors.accent)))
            : Column(children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(10),
                  child: QrImageView(data: t.qr, size: 240),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  trf('Или введи вручную: адрес {0}, порт {1}, код {2}', [t.hosts.first, t.port, t.token]),
                  textAlign: TextAlign.center,
                  style: Txt.body,
                ),
              ]),
      ),
      const SizedBox(height: 10),
      Text(sync.status, style: Txt.body.copyWith(color: sync.status.contains('Синхрон') ? AppColors.good : AppColors.text)),
      const SizedBox(height: 10),
      Text(
        tr('Если Windows спросит про брандмауэр — нажми «Разрешить» (частные сети), иначе телефон не сможет подключиться.'),
        style: Txt.small,
      ),
    ];
  }

  List<Widget> _client() => [
        SectionLabel(tr('С компьютером')),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(tr('На ПК открой КБЖУ Трекер → Профиль и настройки → Синхронизация. Там появится QR-код.'), style: Txt.body),
            const SizedBox(height: 12),
            PrimaryButton(busy ? tr('Синхронизирую…') : tr('Сканировать QR с ПК'), icon: Icons.qr_code_scanner, loading: busy, onPressed: busy ? null : _scan),
          ]),
        ),
        if (result != null) ...[
          const SizedBox(height: 10),
          Text(result!, style: Txt.body.copyWith(color: result!.startsWith(tr('Готово')) ? AppColors.good : AppColors.over)),
        ],
        SectionLabel(tr('Без камеры')),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextField(controller: ip, style: Txt.body, keyboardType: TextInputType.url, decoration: fieldDeco(tr('Адрес ПК, например 192.168.1.5'))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(controller: port, style: Txt.body, keyboardType: TextInputType.number, decoration: fieldDeco(tr('Порт')))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: code, style: Txt.body, keyboardType: TextInputType.number, decoration: fieldDeco(tr('Код')))),
            ]),
            const SizedBox(height: 10),
            GhostButton(tr('Синхронизировать'), icon: Icons.sync, onPressed: busy
                ? null
                : () {
                    final p = int.tryParse(port.text.trim());
                    if (ip.text.trim().isEmpty || p == null || code.text.trim().isEmpty) {
                      showToast(context, tr('Заполни адрес, порт и код с экрана ПК'));
                      return;
                    }
                    _run(SyncTicket([ip.text.trim()], p, code.text.trim()));
                  }),
          ]),
        ),
      ];
}

class _QrScan extends StatefulWidget {
  const _QrScan();

  @override
  State<_QrScan> createState() => _QrScanState();
}

class _QrScanState extends State<_QrScan> {
  bool done = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: subAppBar(tr('Наведи на QR-код на экране ПК')),
        body: MobileScanner(
          onDetect: (capture) {
            if (done) return;
            for (final b in capture.barcodes) {
              final v = b.rawValue;
              if (v != null && v.startsWith('kbju-sync:')) {
                done = true;
                Navigator.of(context).pop(v);
                return;
              }
            }
          },
        ),
      );
}
