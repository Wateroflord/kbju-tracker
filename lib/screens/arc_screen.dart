import 'package:flutter/material.dart';

import '../arc/arc_score.dart';
import '../arc/arc_service.dart';
import '../i18n/i18n.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';

const _ice = Color(0xFF7ADCFF);

String _medal(int i) => switch (i) { 0 => '🥇', 1 => '🥈', 2 => '🥉', _ => '${i + 1}' };

/// Карточка Winter Arc на экране «Сегодня».
class ArcCard extends StatelessWidget {
  const ArcCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return ListenableBuilder(
      listenable: ArcService.I,
      builder: (context, _) {
        final arc = ArcService.I;
        final mine = arcScores(store, todayKey(), todayKey()).first;
        final rows = arc.board(ArcPeriod.arc);
        final place = rows.indexWhere((r) => r.userId == arc.userId);
        return AppCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ArcScreen())),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _ice.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _ice),
                ),
                child: const Icon(Icons.ac_unit, color: _ice),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      arc.connected && arc.running ? trf('Winter Arc · день {0} из 365', [arc.dayNumber]) : 'Winter Arc',
                      style: Txt.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !arc.connected
                          ? tr('Соревнуйся с друзьями в дисциплине — нажми, чтобы подключиться')
                          : place >= 0
                              ? trf('Сегодня {0} / 100 · место {1} из {2}', [mine.total, place + 1, rows.length])
                              : trf('Сегодня {0} / 100', [mine.total]),
                      style: Txt.small,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        );
      },
    );
  }
}

class ArcScreen extends StatefulWidget {
  const ArcScreen({super.key});

  @override
  State<ArcScreen> createState() => _ArcScreenState();
}

class _ArcScreenState extends State<ArcScreen> {
  final _server = TextEditingController();
  final _login = TextEditingController();
  final _pass = TextEditingController();
  String? _loginError;
  ArcPeriod _period = ArcPeriod.arc;

  @override
  void initState() {
    super.initState();
    _server.text = ArcService.I.server;
    WidgetsBinding.instance.addPostFrameCallback((_) => ArcService.I.sync(StoreScope.read(context)));
  }

  @override
  void dispose() {
    _server.dispose();
    _login.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    FocusScope.of(context).unfocus();
    final err = await ArcService.I.login(StoreScope.read(context), _server.text, _login.text, _pass.text);
    if (!mounted) return;
    setState(() => _loginError = err);
    if (err == null) _pass.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ArcService.I,
      builder: (context, _) {
        final arc = ArcService.I;
        return Scaffold(
          backgroundColor: AppColors.bg,
          appBar: subAppBar('Winter Arc', actions: [
            if (arc.connected)
              IconButton(
                tooltip: tr('Обновить'),
                icon: arc.busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                onPressed: arc.busy ? null : () => arc.sync(StoreScope.read(context)),
              ),
          ]),
          body: arc.connected ? _board(arc) : _connect(arc),
        );
      },
    );
  }

  Widget _connect(ArcService arc) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.ac_unit, color: _ice, size: 32),
                const SizedBox(height: 8),
                Text(tr('Winter Arc с друзьями'), style: Txt.h2),
                const SizedBox(height: 6),
                Text(
                  tr('365 дней дисциплины. Каждый день приложение само считает твои очки за питание, воду, сон, шаги и тренировки и отправляет их на сервер Winter Chat. Там же видно, у кого из друзей больше.'),
                  style: Txt.small,
                ),
              ],
            ),
          ),
          SectionLabel(tr('Вход — тем же логином, что в Winter Chat')),
          TextField(controller: _server, style: Txt.body, decoration: fieldDeco(tr('Адрес сервера'), hint: '192.168.1.5')),
          const SizedBox(height: 10),
          TextField(controller: _login, style: Txt.body, autocorrect: false, decoration: fieldDeco(tr('Логин'))),
          const SizedBox(height: 10),
          TextField(
            controller: _pass,
            style: Txt.body,
            obscureText: true,
            onSubmitted: (_) => _doLogin(),
            decoration: fieldDeco(tr('Пароль')),
          ),
          if (_loginError != null) ...[
            const SizedBox(height: 10),
            Text(_loginError!, style: Txt.small.copyWith(color: AppColors.over)),
          ],
          const SizedBox(height: 16),
          PrimaryButton(tr('Войти'), icon: Icons.login, loading: arc.busy, onPressed: arc.busy ? null : _doLogin),
          const SizedBox(height: 16),
          _rules(),
        ],
      );

  Widget _board(ArcService arc) {
    final store = StoreScope.of(context);
    final mine = arcScores(store, todayKey(), todayKey()).first;
    final rows = arc.board(_period);
    final n = arc.dayNumber;
    return RefreshIndicator(
      onRefresh: () => arc.sync(store),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(n < 1 ? '—' : '${n.clamp(1, 365)}', style: Txt.num(32, color: _ice)),
                    Text(tr(' / 365 дней'), style: Txt.small),
                    const Spacer(),
                    Text(arc.name, style: Txt.small),
                  ],
                ),
                const SizedBox(height: 8),
                ProgressLine(ratio: n / 365, color: _ice, overIsBad: false),
                const SizedBox(height: 6),
                Text(
                  arc.start.isEmpty
                      ? ''
                      : n < 1
                          ? trf('Начнётся {0}', [fmtDate(parseKey(arc.start), year: true)])
                          : n > 365
                              ? tr('Winter Arc завершён!')
                              : trf('С {0} по {1}', [fmtDate(parseKey(arc.start)), fmtDate(parseKey(arc.end), year: true)]),
                  style: Txt.small,
                ),
              ],
            ),
          ),
          if (arc.error != null) ...[
            const SizedBox(height: 10),
            Text(arc.error!, style: Txt.small.copyWith(color: AppColors.under)),
          ],
          SectionLabel(trf('Мои очки сегодня: {0} / 100', [mine.total])),
          Wrap(spacing: 6, runSpacing: 6, children: [
            _part(tr('Питание'), mine.food, 30),
            _part(tr('Вода'), mine.water, 10),
            _part(tr('Сон'), mine.sleep, 20),
            _part(tr('Шаги'), mine.steps, 20),
            _part(tr('Тренировка'), mine.workout, 20),
          ]),
          SectionLabel(tr('Рейтинг')),
          Segmented<ArcPeriod>(
            values: ArcPeriod.values,
            label: (p) => switch (p) { ArcPeriod.today => tr('Сегодня'), ArcPeriod.week => tr('7 дней'), ArcPeriod.arc => tr('Весь Arc') },
            selected: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(tr('Пока никто не набрал очков. Начни первым!'), style: Txt.small, textAlign: TextAlign.center),
            ),
          for (var i = 0; i < rows.length; i++) _row(i, rows[i], rows[i].userId == arc.userId),
          if (arc.syncedAt != null) ...[
            const SizedBox(height: 8),
            Text(trf('Обновлено в {0}', ['${two(arc.syncedAt!.hour)}:${two(arc.syncedAt!.minute)}']), style: Txt.small, textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          _rules(),
          const SizedBox(height: 16),
          GhostButton(tr('Выйти из Winter Arc'), icon: Icons.logout, onPressed: arc.logout),
        ],
      ),
    );
  }

  Widget _part(String title, int v, int max) => Pill(
        '$title $v/$max',
        color: v >= max ? AppColors.good : (v > 0 ? AppColors.under : AppColors.muted),
      );

  Widget _row(int i, ArcRow r, bool me) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          color: me ? _ice.withValues(alpha: 0.08) : null,
          borderColor: me ? _ice : null,
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: Row(
            children: [
              SizedBox(width: 34, child: Text(_medal(i), style: Txt.h2, textAlign: TextAlign.center)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me ? trf('{0} (ты)', [r.name]) : r.name, style: Txt.body.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      [
                        if (r.streak > 0) trf('🔥 {0} дн. подряд', [r.streak]),
                        trf('сегодня {0}', [r.today]),
                        if (_period != ArcPeriod.today) trf('дней с очками: {0}', [r.days]),
                      ].join(' · '),
                      style: Txt.small,
                    ),
                  ],
                ),
              ),
              Text('${r.points}', style: Txt.num(20, color: me ? _ice : AppColors.text)),
            ],
          ),
        ),
      );

  Widget _rules() => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('Как считаются очки (до 100 в день)'), style: Txt.body.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final line in [
              tr('Питание: калории в норме — 30, записал еду, но мимо нормы — 10'),
              tr('Вода: выпил дневную норму — 10'),
              tr('Сон: 7+ часов — 20, 6–7 часов — 10'),
              tr('Шаги: дневная цель — 20, хотя бы 70% цели — 10'),
              tr('Тренировка: завершённая тренировка — 20 (в неделю — не больше, чем в твоём плане)'),
              tr('Серия 🔥 — дни подряд с 50+ очками'),
              tr('Очки за последние 7 дней можно добрать: например, записать сон утром.'),
            ])
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $line', style: Txt.small)),
          ],
        ),
      );
}
