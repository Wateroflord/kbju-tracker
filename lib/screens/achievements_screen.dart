import 'package:flutter/material.dart';

import '../game/game.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../i18n/i18n.dart';

/// Карточка уровня на экране «Сегодня». Заодно отмечает новые достижения.
class LevelCard extends StatefulWidget {
  const LevelCard({super.key});

  @override
  State<LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<LevelCard> {
  bool _checking = false;

  void _check(AppStore store, GameStats g) {
    if (_checking) return;
    _checking = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checking = false;
      if (!mounted) return;
      final fresh = syncAchievements(store, g);
      if (fresh.isEmpty) return;
      showToast(
        context,
        fresh.length == 1
            ? trf('Новое достижение: {0}', [tr(fresh.first.title)])
            : trf('Новых достижений: {0}', [fresh.length]),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = computeGame(store);
    _check(store, g);
    final l = g.level;
    final from = xpForLevel(l), to = xpForLevel(l + 1);
    final got = store.life.achievements.length;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsScreen())),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.accent),
            ),
            child: Text('$l', style: Txt.num(20, color: AppColors.accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(trf('Уровень {0} · {1}', [l, levelTitle(l)]), style: Txt.section)),
                    Text(trf('{0}/{1} XP', [fmtInt(g.xp - from), fmtInt(to - from)]), style: Txt.small),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressLine(ratio: (g.xp - from) / (to - from), color: AppColors.accent, overIsBad: false, height: 5),
                const SizedBox(height: 4),
                Text(trf('Достижения: {0} из {1}', [got, achievements.length]), style: Txt.small.copyWith(fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final g = computeGame(store);
    final l = g.level;
    final from = xpForLevel(l), to = xpForLevel(l + 1);
    final got = store.life.achievements;
    final sorted = [...achievements]..sort((a, b) {
        final ga = got.containsKey(a.id), gb = got.containsKey(b.id);
        if (ga != gb) return ga ? -1 : 1;
        final pa = a.progress(g) / a.target, pb = b.progress(g) / b.target;
        return pb.compareTo(pa);
      });

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Уровень и достижения')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Column(
              children: [
                Text(trf('УРОВЕНЬ {0}', [l]), style: Txt.label),
                const SizedBox(height: 6),
                Text(levelTitle(l), style: Txt.h1.copyWith(color: AppColors.accent)),
                const SizedBox(height: 12),
                ProgressLine(ratio: (g.xp - from) / (to - from), color: AppColors.accent, overIsBad: false),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(trf('Всего {0} XP', [fmtInt(g.xp)]), style: Txt.small),
                    const Spacer(),
                    Text(trf('до уровня {0}: {1} XP', [l + 1, fmtInt(to - g.xp)]), style: Txt.small),
                  ],
                ),
              ],
            ),
          ),
          SectionLabel(trf('Достижения · {0}/{1}', [got.length, achievements.length])),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.25,
            children: [for (final a in sorted) _AchTile(a: a, g: g, date: got[a.id])],
          ),
          SectionLabel(tr('Откуда опыт')),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                if (g.parts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text(tr('Записывай еду, ходи, тренируйся и учи слова — за всё начисляется опыт.'), style: Txt.small),
                  ),
                for (final p in g.parts)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(p.title, style: Txt.body.copyWith(fontSize: 13))),
                        Text('+${fmtInt(p.xp)}', style: Txt.num(13, color: AppColors.accent)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(tr('Опыт пересчитывается по всей истории: удалишь запись — уйдёт и опыт за неё.'), style: Txt.small),
        ],
      ),
    );
  }
}

class _AchTile extends StatelessWidget {
  final Achievement a;
  final GameStats g;
  final String? date;
  const _AchTile({required this.a, required this.g, this.date});

  @override
  Widget build(BuildContext context) {
    final done = date != null;
    final p = a.progress(g).clamp(0, a.target);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? AppColors.accent.withValues(alpha: 0.10) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: done ? AppColors.accent : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(a.icon, color: done ? AppColors.accent : AppColors.muted, size: 24),
          const SizedBox(height: 8),
          Text(tr(a.title),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Txt.body.copyWith(fontWeight: FontWeight.w700, fontSize: 13.5, color: done ? AppColors.text : AppColors.accent2)),
          const SizedBox(height: 2),
          Expanded(child: Text(tr(a.desc), maxLines: 2, overflow: TextOverflow.ellipsis, style: Txt.small.copyWith(fontSize: 11.5))),
          if (done)
            Text(fmtDate(parseKey(date!)), style: Txt.small.copyWith(fontSize: 11, color: AppColors.accent))
          else
            ProgressLine(ratio: p / a.target, color: AppColors.accent2, overIsBad: false, height: 4),
        ],
      ),
    );
  }
}
