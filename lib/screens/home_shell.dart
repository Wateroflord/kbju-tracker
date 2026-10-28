import 'package:flutter/material.dart';

import '../life/notifications.dart';
import '../life/steps_service.dart';
import '../store.dart';
import '../theme.dart';
import 'care_screen.dart';
import 'day_view.dart';
import 'progress_screen.dart';
import 'today_screen.dart';
import 'training_screen.dart';

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
      StepsService.instance.onResume();
      NotificationService.instance.sync(StoreScope.read(context));
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      StoreScope.read(context).flush();
    }
  }

  static const _tabs = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Сегодня'),
    (Icons.restaurant_outlined, Icons.restaurant, 'Питание'),
    (Icons.fitness_center_outlined, Icons.fitness_center, 'Тренировки'),
    (Icons.spa_outlined, Icons.spa, 'Уход'),
    (Icons.show_chart, Icons.show_chart, 'Прогресс'),
  ];

  void _open(int i) {
    FocusScope.of(context).unfocus();
    setState(() => index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: index,
        children: [
          TodayScreen(onOpenTab: _open),
          const DayView(),
          const TrainingScreen(),
          const CareScreen(),
          const ProgressScreen(),
        ],
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
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: InkWell(
                      onTap: () => _open(i),
                      child: _NavItem(
                        icon: index == i ? _tabs[i].$2 : _tabs[i].$1,
                        label: _tabs[i].$3,
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
          width: 52,
          height: 28,
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: c, size: 21),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.text : AppColors.muted,
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
