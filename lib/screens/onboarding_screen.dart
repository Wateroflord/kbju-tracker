import 'package:flutter/material.dart';

import '../store.dart';
import '../theme.dart';
import '../widgets/lang_picker.dart';
import 'profile_editor.dart';
import '../i18n/i18n.dart';

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
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 12),
                Text(tr('КБЖУ Трекер'), style: Txt.h1),
              ],
            ),
            const SizedBox(height: 18),
            const LangPicker(),
            const SizedBox(height: 14),
            Text(
              tr('Фоткай еду — ИИ посчитает калории, белки, жиры и углеводы. Сначала укажи параметры, чтобы рассчитать твою норму.'),
              style: Txt.body,
            ),
            ProfileEditor(
              initial: null,
              submitText: tr('Рассчитать и начать'),
              onSubmit: (p) {
                if (store.lang.isEmpty) store.lang = appLang.code;
                store.saveProfile(p);
              },
            ),
          ],
        ),
      ),
    );
  }
}
