import 'package:flutter/material.dart';

import '../common/ui.dart';
import 'pose_camera.dart';
import 'stats.dart';
import 'style.dart';
import 'training.dart';

/// Плагин «Push-Up Arena»: соревнования в отжиманиях.
/// Этап 1: подсчёт камерой, тренировка до отказа, личные рекорды.
/// Дальше: дуэли с друзьями через сервер Winter Chat, рейтинг и ранги.
class PushupsApp extends StatelessWidget {
  const PushupsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Push-Up Arena',
        debugShowCheckedModeBanner: false,
        theme: winterTheme(Arena.red),
        home: const MenuScreen(),
      );
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  Future<void> _train() async {
    if (!poseSupported) {
      toast(context, 'Подсчёт отжиманий работает только на телефоне');
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TrainingScreen()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = PushStats.I;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              children: [
                Text('PUSH-UP ARENA', style: Arena.title(32)),
                const SizedBox(height: 4),
                const Text('Отжимания один на один', style: W.small),
                const SizedBox(height: 18),
                // ---- рекорды ----
                Row(children: [
                  _stat('Рекорд', '${s.best}', W.warn),
                  const SizedBox(width: 8),
                  _stat('Сегодня', '${s.today}', Arena.ice),
                  const SizedBox(width: 8),
                  _stat('Всего', '${s.total}', W.good),
                ]),
                const Section('Режимы'),
                _mode(
                  icon: Icons.fitness_center_rounded,
                  title: 'Тренировка до отказа',
                  text: poseSupported ? 'Без рейтинга. Камера считает, ты отжимаешься' : 'Подсчёт работает только на телефоне',
                  onTap: _train,
                  color: Arena.red,
                ),
                const SizedBox(height: 8),
                _mode(
                  icon: Icons.sports_mma_rounded,
                  title: 'Дуэль с другом',
                  text: 'Скоро: вызов друга из Winter Arc',
                  locked: true,
                ),
                const SizedBox(height: 8),
                _mode(
                  icon: Icons.emoji_events_rounded,
                  title: 'Рейтинговый бой',
                  text: 'Скоро: MMR, ранги от Снежинки до Ледяного Бога',
                  locked: true,
                ),
                const Section('Последние подходы'),
                if (s.history.isEmpty)
                  const WCard(child: Text('Пока пусто. Сделай первый подход!', style: W.small))
                else
                  for (final h in s.history.take(15))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: WCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(children: [
                          Text('${h.reps}', style: W.h2),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_date(h.at), style: W.small)),
                          Text(fmtDuration(h.ms), style: W.small),
                        ]),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value, Color c) => Expanded(
        child: WCard(
          child: Column(children: [
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c)),
            Text(label, style: W.small),
          ]),
        ),
      );

  Widget _mode({required IconData icon, required String title, required String text, VoidCallback? onTap, Color? color, bool locked = false}) =>
      Opacity(
        opacity: locked ? 0.5 : 1,
        child: WCard(
          onTap: locked ? null : onTap,
          borderColor: color?.withValues(alpha: 0.6),
          child: Row(children: [
            Icon(icon, size: 30, color: color ?? W.muted),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: W.h2),
                const SizedBox(height: 2),
                Text(text, style: W.small),
              ]),
            ),
            Icon(locked ? Icons.lock_rounded : Icons.chevron_right_rounded, color: W.muted),
          ]),
        ),
      );

  static String _date(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }
}
