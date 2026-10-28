import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';

/// Временная вкладка для разделов, которые появятся в следующих обновлениях.
class ComingSoonScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String text;
  const ComingSoonScreen({super.key, required this.title, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            TabHeader(title),
            const SizedBox(height: 14),
            AppCard(
              child: Row(
                children: [
                  Icon(icon, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text, style: Txt.body)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
