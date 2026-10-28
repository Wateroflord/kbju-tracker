import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../life/notifications.dart';
import '../store.dart';
import '../theme.dart';

/// Выбор языка интерфейса: Русский / Українська / English / Polski.
class LangPicker extends StatelessWidget {
  const LangPicker({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 3.6,
      children: [
        for (final l in AppLang.values)
          GestureDetector(
            onTap: () {
              if (l == appLang) return;
              store.setLang(l);
              NotificationService.instance.sync(store);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: l == appLang ? AppColors.accent.withValues(alpha: 0.14) : AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: l == appLang ? AppColors.accent : AppColors.border),
              ),
              child: Row(
                children: [
                  Text(l.flag,
                      style: Txt.num(12, color: l == appLang ? AppColors.accent : AppColors.muted)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.nativeName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: l == appLang ? AppColors.text : AppColors.accent2,
                      ),
                    ),
                  ),
                  if (l == appLang) const Icon(Icons.check, size: 16, color: AppColors.accent),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
