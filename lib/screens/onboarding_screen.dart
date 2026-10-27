import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import 'profile_editor.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.read(context);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.45), blurRadius: 18)],
                  ),
                  child: const Icon(Icons.bolt, color: Colors.black, size: 28),
                ),
                const SizedBox(width: 12),
                const Text('КБЖУ Трекер', style: Txt.h1),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Фоткай еду — ИИ посчитает калории, белки, жиры и углеводы. '
              'Сначала укажи параметры, чтобы рассчитать твою норму.',
              style: Txt.body,
            ),
            ProfileEditor(
              initial: null,
              submitText: 'Рассчитать и начать',
              onSubmit: store.saveProfile,
            ),
          ],
        ),
      ),
    );
  }
}
