import 'package:flutter/material.dart';

import '../theme.dart';
import 'calendar_screen.dart';
import 'day_view.dart';
import 'profile_screen.dart';
import 'progress_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  static const _tabs = [
    (Icons.today_outlined, Icons.today, 'Сегодня'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Календарь'),
    (Icons.show_chart, Icons.show_chart, 'Прогресс'),
    (Icons.person_outline, Icons.person, 'Профиль'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: index,
        children: const [
          DayView(),
          CalendarScreen(),
          ProgressScreen(),
          ProfileScreen(),
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
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        setState(() => index = i);
                      },
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
          duration: const Duration(milliseconds: 200),
          width: selected ? 22 : 0,
          height: 3,
          margin: const EdgeInsets.only(bottom: 7),
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(3),
            boxShadow: selected
                ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.7), blurRadius: 8)]
                : null,
          ),
        ),
        Icon(icon, color: c, size: 23),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(color: c, fontSize: 11, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      ],
    );
  }
}
