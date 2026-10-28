import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../i18n/i18n.dart';
import '../learn/learn_logic.dart';
import '../learn/tts.dart';
import '../learn/words.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import 'dialogue_screen.dart';
import 'learn_session.dart';

IconData topicIcon(String key) => switch (key) {
      'chat' => Icons.chat_bubble_outline,
      'star' => Icons.star_outline,
      'bolt' => Icons.bolt,
      'numbers' => Icons.pin_outlined,
      'time' => Icons.schedule,
      'food' => Icons.restaurant_outlined,
      'shop' => Icons.shopping_bag_outlined,
      'city' => Icons.directions_bus_outlined,
      'people' => Icons.people_outline,
      'home' => Icons.home_outlined,
      'work' => Icons.work_outline,
      'health' => Icons.favorite_border,
      'palette' => Icons.palette_outlined,
      _ => Icons.translate,
    };

String langTitle(String code) => switch (code) {
      'pl' => tr('Польский'),
      'de' => tr('Немецкий'),
      _ => tr('Английский'),
    };

/// Вкладка «Учёба»: английский и польский по методу 20 часов.
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  void _open(BuildContext context, LearnMode mode, {String? topic}) {
    final lang = StoreScope.read(context).life.learnLang;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LearnSessionScreen(mode: mode, lang: lang, topic: topic),
    ));
  }

  Future<void> _editGoal(BuildContext context) async {
    final life = StoreScope.read(context).life;
    final lang = life.learnLang;
    final ctrl = TextEditingController(text: life.learnGoalText[lang] ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(tr('Шаг 1. Выбери финиш'), style: Txt.h2),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Один конкретный навык + конкретный результат. Не «выучить английский», а «уметь заказать еду в ресторане».'),
              style: Txt.small,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: Txt.body,
              decoration: fieldDeco(tr('Моя цель'), hint: tr('например: объясниться в аптеке')),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Отмена'), style: const TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('Сохранить'), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    final t = ctrl.text;
    WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose());
    if (ok == true) life.setLearnGoalText(lang, t);
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final life = store.life;
    final lang = life.learnLang;
    final totalH = life.totalSeconds(lang) / 3600;
    final todayMin = life.minutesToday();
    final due = life.dueWords(lang).length;
    final seen = life.seenCount(lang);
    final known = life.knownCount(lang);
    final goal = life.learnGoalText[lang] ?? '';
    final streak = life.learnStreak();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
          children: [
            TabHeader(tr('Учёба'), subtitle: tr('Языки по методу 20 часов')),
            const SizedBox(height: 14),
            Segmented<String>(
              values: const ['en', 'pl', 'de'],
              label: langTitle,
              selected: lang,
              onChanged: life.setLearnLang,
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(fmt1(totalH), style: Txt.num(32, color: AppColors.accent)),
                      Text(trf(' / 20 ч · {0}', [langTitle(lang).toLowerCase()]), style: Txt.small),
                      const Spacer(),
                      if (streak > 0) Pill(trf('{0} дн. подряд', [streak]), icon: Icons.local_fire_department_outlined),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ProgressLine(ratio: totalH / 20, color: AppColors.accent, overIsBad: false),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Expanded(child: Text(trf('Сегодня {0} из {1} мин', [todayMin, life.learnGoalMin]), style: Txt.small)),
                      GestureDetector(
                        onTap: () => _pickGoal(context),
                        child: Text(tr('Изменить'), style: const TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ProgressLine(ratio: todayMin / life.learnGoalMin, color: AppColors.good, height: 4, overIsBad: false),
                ],
              ),
            ),
            const SizedBox(height: 10),
            AppCard(
              onTap: () => _editGoal(context),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined, color: AppColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Мой финиш'), style: Txt.label),
                        const SizedBox(height: 3),
                        Text(
                          goal.isEmpty ? tr('Задай конкретную цель: например, «заказать еду в ресторане»') : goal,
                          style: goal.isEmpty ? Txt.small : Txt.body,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.edit_outlined, color: AppColors.muted, size: 18),
                ],
              ),
            ),
            SectionLabel(tr('Заниматься')),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.replay,
                    title: tr('Повторение'),
                    sub: due > 0 ? trf('{0} слов ждут', [due]) : tr('всё повторено'),
                    highlight: due > 0,
                    onTap: () => _open(context, LearnMode.review),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.add_circle_outline,
                    title: tr('Новые слова'),
                    sub: tr('10 карточек'),
                    highlight: due == 0,
                    onTap: () => _open(context, LearnMode.learn),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.quiz_outlined,
                    title: tr('Тест'),
                    sub: tr('выбери перевод'),
                    onTap: () => _open(context, LearnMode.quiz),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.headphones_outlined,
                    title: tr('Аудирование'),
                    sub: tr('узнай на слух'),
                    onTap: () => _open(context, LearnMode.listen),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ActionTile(
                    icon: Icons.keyboard_outlined,
                    title: tr('Напиши слово'),
                    sub: tr('вспомни и набери'),
                    onTap: () => _open(context, LearnMode.type),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionTile(
                    icon: Icons.forum_outlined,
                    title: tr('Диалоги'),
                    sub: tr('сцены из жизни'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => DialoguesScreen(lang: lang)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: StatTile(label: tr('Выучено'), value: '$known', sub: trf('из {0} слов', [words.length]), color: AppColors.good)),
                const SizedBox(width: 8),
                Expanded(child: StatTile(label: tr('В процессе'), value: '${seen - known}', sub: tr('на повторении'))),
              ],
            ),
            SectionLabel(tr('Темы — от самых нужных')),
            for (final t in topics) _TopicRow(topic: t, lang: lang),
            const SectionLabel(''),
            AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MethodScreen())),
              child: Row(
                children: [
                  const Icon(Icons.school_outlined, color: AppColors.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tr('Метод 20 часов'), style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(tr('Шпаргалка и 3 промпта для нейросети'), style: Txt.small),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pickGoal(BuildContext context) {
    final life = StoreScope.read(context).life;
    showDialog<void>(
      context: context,
      builder: (ctx) => SimpleDialog(
        backgroundColor: AppColors.surface,
        title: Text(tr('Минут в день'), style: Txt.h2),
        children: [
          for (final m in const [15, 30, 45, 60])
            SimpleDialogOption(
              onPressed: () {
                life.setLearnGoal(m);
                Navigator.pop(ctx);
              },
              child: Text(
                m == 45 ? trf('{0} мин — как советует автор метода', [m]) : trf('{0} мин', [m]),
                style: Txt.body.copyWith(color: life.learnGoalMin == m ? AppColors.accent : AppColors.text),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool highlight;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.sub, required this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      borderColor: highlight ? AppColors.accent : null,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: highlight ? AppColors.accent : AppColors.accent2, size: 22),
          const SizedBox(height: 8),
          Text(title, style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(sub, style: Txt.small, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TopicRow extends StatelessWidget {
  final Topic topic;
  final String lang;
  const _TopicRow({required this.topic, required this.lang});

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final (known, seen, total) = life.topicProgress(lang, topic.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TopicScreen(topic: topic))),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(topicIcon(topic.icon), size: 20, color: known == total ? AppColors.good : AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(tr(topic.title), style: Txt.body.copyWith(fontSize: 13.5, fontWeight: FontWeight.w500))),
                      Text('$known/$total', style: Txt.num(12.5, color: AppColors.muted)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ProgressLine(ratio: (known + seen) / (2 * total), color: AppColors.good, height: 4, overIsBad: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Слова темы: слушать, смотреть статус, учить только эту тему.
class TopicScreen extends StatelessWidget {
  final Topic topic;
  const TopicScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final lang = life.learnLang;
    final native = life.nativeFor(lang);
    final list = wordsOf(topic.id);
    void open(LearnMode m) => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => LearnSessionScreen(mode: m, lang: lang, topic: topic.id),
        ));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr(topic.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(
            children: [
              Expanded(child: PrimaryButton(tr('Учить тему'), icon: Icons.play_arrow, onPressed: () => open(LearnMode.learn))),
              const SizedBox(width: 8),
              Expanded(child: GhostButton(tr('Тест'), icon: Icons.quiz_outlined, onPressed: () => open(LearnMode.quiz))),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < list.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  _wordRow(context, life.cardOf(lang, list[i])?.known, life.cardOf(lang, list[i]) != null,
                      list[i].inLang(lang), list[i].inLang(native), lang),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(tr('Зелёная точка — выучено, жёлтая — на повторении, серая — ещё не видел.'), style: Txt.small),
        ],
      ),
    );
  }

  Widget _wordRow(BuildContext context, bool? known, bool seen, String target, String native, String lang) {
    final color = known == true ? AppColors.good : (seen ? AppColors.under : AppColors.border);
    return InkWell(
      onTap: () => Tts.speak(target, lang),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            Dot(color, size: 7),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(target, style: Txt.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(native, style: Txt.small),
                ],
              ),
            ),
            const Icon(Icons.volume_up_outlined, size: 20, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Шпаргалка метода 20 часов и промпты для нейросети.
class MethodScreen extends StatelessWidget {
  const MethodScreen({super.key});

  static const _prompts = [
    (
      'Разобрать навык по принципу Парето',
      'Разбей навык [английский для работы] на 5 ключевых поднавыков по правилу Парето для абсолютного новичка. Что мне нужно освоить в первые 2 часа, чтобы получить нормальный результат?',
      'Помогает не изучать всё подряд, а сразу найти самые важные элементы навыка.',
    ),
    (
      'Метод Фейнмана — проверить знания',
      'Представь, что ты 10-летний ребёнок. Я сейчас объясню тебе, как работает [тема], а ты найди ошибки в моём объяснении и покажи, где у меня пробелы.',
      'Показывает, действительно ли ты разобрался или тебе только кажется.',
    ),
    (
      'Нейросеть как личный репетитор',
      'Задавай мне практические вопросы по [тема]. Жди мой ответ и после каждого разбирай, где я ошибся.',
      'Вместо чтения теории ты активно вспоминаешь, отвечаешь и получаешь обратную связь.',
    ),
  ];

  static const _steps = [
    ('Шаг 1. Выбери финиш', 'Один конкретный навык + конкретный результат. Плохо: «выучить английский». Хорошо: «уметь заказать еду в ресторане».'),
    ('Шаг 2. Взломай навык', 'Разбей навык на поднавыки и найди «детали лего», которые дают 80% результата. Здесь темы уже разложены от самых нужных.'),
    ('Шаг 3. Минимум теории', 'Узнай только необходимое для старта и сразу практикуйся: ошибка → обратная связь → исправление.'),
    ('Шаг 4. Настрой трение', 'Сделай практику максимально доступной (приложение на главном экране, напоминание) и убери отвлечения (уведомления на время занятия).'),
    ('Набери 20 часов', 'Примерно 45 минут в день в течение месяца. 20 часов — это первый реальный результат, дальше можно ставить новые цели.'),
    ('Переживи кринж', 'Разреши себе ошибаться первые 20 часов. Первые попытки почти всегда кажутся плохими — это нормальная часть обучения.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Метод 20 часов')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            child: Text(
              tr('Чтобы начать говорить на языке или освоить новый навык, не нужны годы: около 20 часов осознанной практики дают первый реальный результат.'),
              style: Txt.body,
            ),
          ),
          SectionLabel(tr('Схема')),
          for (var i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${i + 1}', style: Txt.num(13, color: AppColors.accent)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(_steps[i].$1), style: Txt.section),
                          const SizedBox(height: 4),
                          Text(tr(_steps[i].$2), style: Txt.body.copyWith(fontSize: 13.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SectionLabel(tr('3 промпта для нейросети')),
          for (final p in _prompts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(p.$1), style: Txt.section),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text('«${tr(p.$2)}»', style: Txt.body.copyWith(fontSize: 13.5)),
                    ),
                    const SizedBox(height: 6),
                    Text(tr(p.$3), style: Txt.small),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: tr(p.$2)));
                          showToast(context, tr('Промпт скопирован'));
                        },
                        icon: const Icon(Icons.copy, size: 16, color: AppColors.accent),
                        label: Text(tr('Копировать'), style: const TextStyle(color: AppColors.accent)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
