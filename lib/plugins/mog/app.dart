import 'package:flutter/material.dart';

import 'screens/battle.dart';
import 'screens/history.dart';
import 'screens/rate.dart';
import 'screens/settings.dart';
import 'store.dart';
import 'theme.dart';

class MogApp extends StatelessWidget {
  const MogApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Mog Battle',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 0;

  void _openSettings() => setState(() => _tab = 3);

  static const _dest = [
    (Icons.local_fire_department_outlined, Icons.local_fire_department_rounded, 'Батл'),
    (Icons.face_outlined, Icons.face_retouching_natural, 'Оценка'),
    (Icons.history_rounded, Icons.history_rounded, 'История'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Настройки'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      BattleScreen(onOpenSettings: _openSettings),
      RateScreen(onOpenSettings: _openSettings),
      const HistoryScreen(),
      const SettingsScreen(),
    ];
    final body = IndexedStack(index: _tab, children: pages);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            backgroundColor: const Color(0xFF130F1A),
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            labelType: NavigationRailLabelType.all,
            indicatorColor: C.gold.withValues(alpha: 0.18),
            selectedIconTheme: const IconThemeData(color: C.gold),
            unselectedIconTheme: const IconThemeData(color: C.muted),
            selectedLabelTextStyle: const TextStyle(color: C.gold, fontWeight: FontWeight.w700),
            unselectedLabelTextStyle: const TextStyle(color: C.muted),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text('MOG', style: TextStyle(color: C.gold, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2)),
            ),
            destinations: [
              for (final d in _dest)
                NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1, color: C.border),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final d in _dest) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
