import 'package:flutter/material.dart';

import '../life/health_sync.dart';
import '../life/notifications.dart';
import '../life/steps_service.dart';
import '../store.dart';
import '../i18n/i18n.dart';
import '../theme.dart';
import '../widgets/nav.dart';
import 'care_screen.dart';
import 'day_view.dart';
import 'language_moved_screen.dart';
import 'progress_screen.dart';
import 'today_screen.dart';
import 'training_screen.dart';
import '../arc/arc_service.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final arc = ArcService.I;
      if (arc.connected && (arc.syncedAt == null || DateTime.now().difference(arc.syncedAt!).inMinutes >= 5)) {
        arc.sync(StoreScope.read(context));
      }
      StepsService.instance.onResume();
      NotificationService.instance.sync(StoreScope.read(context));
      HealthSync.instance.sync(StoreScope.read(context));
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      StepsService.instance.onPause();
      StoreScope.read(context).flush();
      if (state == AppLifecycleState.paused && ArcService.I.connected) ArcService.I.sync(StoreScope.read(context));
    }
  }

  // id вкладки (для скрытия в настройках), иконки, подпись
  static const _tabs = [
    ('today', Icons.dashboard_outlined, Icons.dashboard, 'Сегодня'),
    ('food', Icons.restaurant_outlined, Icons.restaurant, 'Питание'),
    ('training', Icons.fitness_center_outlined, Icons.fitness_center, 'Спорт'),
    ('care', Icons.spa_outlined, Icons.spa, 'Уход'),
    ('learn', Icons.translate, Icons.translate, 'Учёба'),
    ('progress', Icons.show_chart, Icons.show_chart, 'Прогресс'),
  ];

  Widget _page(int i) => switch (i) {
        0 => TodayScreen(onOpenTab: _open),
        1 => const DayView(),
        2 => const TrainingScreen(),
        3 => const CareScreen(),
        4 => const LanguageMovedScreen(),
        _ => const ProgressScreen(),
      };

  /// [i] — номер вкладки в полном списке. Скрытая вкладка открывается отдельным экраном.
  void _open(int i) {
    FocusScope.of(context).unfocus();
    if (!StoreScope.read(context).extra.tabVisible(_tabs[i].$1)) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(backgroundColor: AppColors.bg, appBar: subAppBar(tr(_tabs[i].$4)), body: _page(i)),
      ));
      return;
    }
    setState(() => index = i);
  }

  @override
  Widget build(BuildContext context) {
    final extra = StoreScope.of(context).extra;
    final visible = [for (var i = 0; i < _tabs.length; i++) if (extra.tabVisible(_tabs[i].$1)) i];
    if (!visible.contains(index)) index = 0;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: visible.indexOf(index),
        children: [for (final i in visible) KeyedSubtree(key: ValueKey(_tabs[i].$1), child: _page(i))],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (final i in visible)
                  Expanded(
                    child: InkWell(
                      onTap: () => _open(i),
                      child: _NavItem(
                        icon: index == i ? _tabs[i].$3 : _tabs[i].$2,
                        label: tr(_tabs[i].$4),
                        selected: index == i,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  const _NavItem({required this.icon, required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    final c = selected ? AppColors.accent : AppColors.muted;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 46,
          height: 28,
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: c, size: 21),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected ? AppColors.text : AppColors.muted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
