import 'package:flutter/material.dart';

import '../gemini.dart';
import '../life/ai_program.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../i18n/i18n.dart';

/// ИИ-генератор программы тренировок.
class AiProgramScreen extends StatefulWidget {
  const AiProgramScreen({super.key});

  @override
  State<AiProgramScreen> createState() => _AiProgramScreenState();
}

class _AiProgramScreenState extends State<AiProgramScreen> {
  String goal = 'muscle';
  String level = 'beginner';
  int days = 3;
  int minutes = 60;
  String equipment = 'gym';
  final notes = TextEditingController();
  bool loading = false;
  String? error;
  AiProgramResult? result;

  @override
  void initState() {
    super.initState();
    final g = StoreScope.read(context).profile?.goal;
    goal = switch (g) {
      Goal.cut => 'fatloss',
      Goal.maintain => 'health',
      _ => 'muscle',
    };
  }

  @override
  void dispose() {
    notes.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final store = StoreScope.read(context);
    FocusScope.of(context).unfocus();
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await generateProgram(
        store,
        AiProgramRequest(goal: goal, level: level, days: days, minutes: minutes, equipment: equipment, notes: notes.text),
      );
      if (mounted) setState(() => result = r);
    } on GeminiException catch (e) {
      if (mounted) setState(() => error = e.message);
    } catch (e) {
      if (mounted) setState(() => error = trf('Ошибка: {0}', [e]));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _chips<T>(List<T> values, T selected, String Function(T) label, ValueChanged<T> onTap) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final v in values)
            Pill(label(v), color: v == selected ? AppColors.accent : AppColors.accent2, onTap: () => setState(() => onTap(v))),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final hasKey = store.apiKey.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Программа от ИИ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(tr('Ответь на несколько вопросов — ИИ составит программу под тебя. Её можно потом изменить вручную.'),
              style: Txt.small),
          SectionLabel(tr('Цель')),
          _chips<String>(const ['muscle', 'strength', 'fatloss', 'health'], goal, (v) => switch (v) {
                'muscle' => tr('Набор мышц'),
                'strength' => tr('Сила'),
                'fatloss' => tr('Похудение'),
                _ => tr('Здоровье и тонус'),
              }, (v) => goal = v),
          SectionLabel(tr('Опыт')),
          _chips<String>(const ['beginner', 'intermediate', 'advanced'], level, (v) => switch (v) {
                'beginner' => tr('Новичок'),
                'intermediate' => tr('Средний'),
                _ => tr('Опытный'),
              }, (v) => level = v),
          SectionLabel(tr('Тренировок в неделю')),
          _chips<int>(const [2, 3, 4, 5, 6], days, (v) => '$v', (v) => days = v),
          SectionLabel(tr('Длительность')),
          _chips<int>(const [30, 45, 60, 90], minutes, (v) => trf('{0} мин', [v]), (v) => minutes = v),
          SectionLabel(tr('Где тренируешься')),
          _chips<String>(const ['gym', 'dumbbells', 'bar', 'none'], equipment, (v) => switch (v) {
                'gym' => tr('Тренажёрный зал'),
                'dumbbells' => tr('Дома с гантелями'),
                'bar' => tr('Турник и резинки'),
                _ => tr('Без инвентаря'),
              }, (v) => equipment = v),
          const SizedBox(height: 14),
          TextField(
            controller: notes,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: Txt.body,
            decoration: fieldDeco(tr('Пожелания и ограничения (необязательно)'),
                hint: tr('например: болит колено, хочу больше рук')),
          ),
          const SizedBox(height: 14),
          if (!hasKey)
            Text(tr('Для генерации нужен бесплатный ключ Gemini (Профиль → ИИ).'), style: Txt.small)
          else
            PrimaryButton(
              result == null ? tr('Составить программу') : tr('Другой вариант'),
              icon: Icons.auto_awesome,
              loading: loading,
              onPressed: _generate,
            ),
          if (loading) ...[
            const SizedBox(height: 10),
            Center(child: Text(tr('ИИ составляет программу… это занимает до минуты'), style: Txt.small)),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            AppCard(
              borderColor: AppColors.over.withValues(alpha: 0.5),
              child: Text(error!, style: Txt.small.copyWith(color: AppColors.text)),
            ),
          ],
          if (result != null) ..._preview(store, result!),
        ],
      ),
    );
  }

  List<Widget> _preview(AppStore store, AiProgramResult r) {
    final p = r.program;
    final names = {for (final e in r.newExercises) e.id: e.name};
    String exName(String id) => names[id] ?? tr(store.life.exerciseById(id).name);
    return [
      SectionLabel(tr('Результат')),
      AppCard(
        borderColor: AppColors.accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.title, style: Txt.h2),
            if (p.desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(p.desc, style: Txt.small),
            ],
            const SizedBox(height: 6),
            Text(trf('Дни: {0}', [p.weekdays.map((d) => weekdaysShort[d - 1]).join(', ')]), style: Txt.small.copyWith(color: AppColors.accent2)),
            for (final d in p.days) ...[
              const SizedBox(height: 14),
              Text(d.title.toUpperCase(), style: Txt.label),
              const SizedBox(height: 6),
              for (final pe in d.exercises)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(exName(pe.exId), style: Txt.body.copyWith(fontSize: 13.5))),
                      Text(pe.scheme, style: Txt.num(13, color: AppColors.accent2)),
                    ],
                  ),
                ),
            ],
            if (r.newExercises.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(trf('Новых упражнений: {0} — с техникой выполнения.', [r.newExercises.length]), style: Txt.small),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      PrimaryButton(tr('Сохранить и начать'), icon: Icons.check, onPressed: () {
        saveAiProgram(store, r);
        showToast(context, trf('Программа «{0}» теперь активная', [p.title]));
        Navigator.pop(context);
      }),
    ];
  }
}
