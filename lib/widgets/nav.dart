import 'package:flutter/material.dart';

import '../screens/profile_screen.dart';
import '../theme.dart';

/// Квадратная кнопка-иконка в стиле приложения.
class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final Color? color;

  const SquareIconButton(this.icon, {super.key, this.onTap, this.tooltip, this.color});

  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, size: 20, color: onTap == null ? AppColors.border : (color ?? AppColors.text)),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Кнопка профиля в правом верхнем углу главных экранов.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) => SquareIconButton(
        Icons.person_outline,
        tooltip: 'Профиль',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
        ),
      );
}

/// Заголовок вкладки: крупный текст слева, кнопки справа.
class TabHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const TabHeader(this.title, {super.key, this.subtitle, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Txt.h1),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: Txt.small),
              ],
            ],
          ),
        ),
        for (final a in actions) ...[const SizedBox(width: 6), a],
        const SizedBox(width: 6),
        const ProfileButton(),
      ],
    );
  }
}

/// Верхняя панель для экранов, открытых поверх вкладок.
PreferredSizeWidget subAppBar(String title, {List<Widget>? actions}) => AppBar(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: Txt.h2),
      actions: actions,
    );
