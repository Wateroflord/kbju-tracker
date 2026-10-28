import 'package:flutter/material.dart';

import '../calc.dart';
import '../models.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../i18n/i18n.dart';

/// Форма параметров: пол, возраст, рост, вес, активность, программа, свои нормы.
class ProfileEditor extends StatefulWidget {
  final Profile? initial;
  final String submitText;
  final ValueChanged<Profile> onSubmit;

  const ProfileEditor({
    super.key,
    required this.initial,
    required this.submitText,
    required this.onSubmit,
  });

  @override
  State<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<ProfileEditor> {
  Sex sex = Sex.male;
  int activity = 1;
  Goal goal = Goal.maintain;
  bool custom = false;

  final age = TextEditingController();
  final height = TextEditingController();
  final weight = TextEditingController();
  final target = TextEditingController();
  final cK = TextEditingController();
  final cP = TextEditingController();
  final cF = TextEditingController();
  final cC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load(widget.initial);
  }

  @override
  void didUpdateWidget(covariant ProfileEditor old) {
    super.didUpdateWidget(old);
    if (!identical(old.initial, widget.initial)) _load(widget.initial);
  }

  void _load(Profile? p) {
    sex = p?.sex ?? Sex.male;
    activity = p?.activity ?? 1;
    goal = p?.goal ?? Goal.maintain;
    custom = p?.customTargets ?? false;
    age.text = p == null ? '' : '${p.age}';
    height.text = p == null ? '' : fmt1(p.heightCm);
    weight.text = p == null ? '' : fmt1(p.weightKg);
    target.text = p?.targetWeightKg == null ? '' : fmt1(p!.targetWeightKg!);
    final c = p?.custom;
    cK.text = c == null ? '' : '${c.kcal}';
    cP.text = c == null ? '' : '${c.protein}';
    cF.text = c == null ? '' : '${c.fat}';
    cC.text = c == null ? '' : '${c.carbs}';
  }

  @override
  void dispose() {
    for (final c in [age, height, weight, target, cK, cP, cF, cC]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Профиль без «своих норм» — для предпросмотра автоматического расчёта.
  Profile? _base() {
    final a = parseNum(age.text);
    final h = parseNum(height.text);
    final w = parseNum(weight.text);
    if (a == null || h == null || w == null) return null;
    if (a < 10 || a > 100 || h < 100 || h > 250 || w < 25 || w > 350) return null;
    final tw = parseNum(target.text);
    return Profile(
      sex: sex,
      age: a.round(),
      heightCm: h,
      weightKg: w,
      targetWeightKg: (tw != null && tw >= 25 && tw <= 350) ? tw : null,
      activity: activity,
      goal: goal,
    );
  }

  Targets? _customTargets() {
    final k = parseNum(cK.text);
    final p = parseNum(cP.text);
    final f = parseNum(cF.text);
    final c = parseNum(cC.text);
    if (k == null || p == null || f == null || c == null || k < 500) return null;
    return Targets(kcal: k.round(), protein: p.round(), fat: f.round(), carbs: c.round(), waterMl: 0);
  }

  Profile? _draft() {
    final b = _base();
    if (b == null) return null;
    final ct = _customTargets();
    return Profile(
      sex: b.sex,
      age: b.age,
      heightCm: b.heightCm,
      weightKg: b.weightKg,
      targetWeightKg: b.targetWeightKg,
      activity: b.activity,
      goal: b.goal,
      customTargets: custom && ct != null,
      custom: ct ?? widget.initial?.custom,
    );
  }

  void _toggleCustom(bool v) {
    setState(() {
      custom = v;
      if (v && cK.text.isEmpty) {
        final b = _base();
        if (b != null) {
          final t = autoTargets(b);
          cK.text = '${t.kcal}';
          cP.text = '${t.protein}';
          cF.text = '${t.fat}';
          cC.text = '${t.carbs}';
        }
      }
    });
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final p = _draft();
    if (p == null) {
      showToast(context, tr('Проверь возраст (10–100), рост (100–250 см) и вес (25–350 кг)'));
      return;
    }
    if (custom && _customTargets() == null) {
      showToast(context, tr('Заполни свои нормы: калории (от 500), белки, жиры, углеводы'));
      return;
    }
    widget.onSubmit(p);
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft();
    void changed(String _) => setState(() {});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(tr('Пол')),
        Segmented<Sex>(
          values: Sex.values,
          label: (s) => s == Sex.male ? tr('Мужчина') : tr('Женщина'),
          selected: sex,
          onChanged: (s) => setState(() => sex = s),
        ),
        SectionLabel(tr('Параметры')),
        Row(
          children: [
            Expanded(child: NumField(age, tr('Возраст'), suffix: tr('лет'), onChanged: changed)),
            const SizedBox(width: 8),
            Expanded(child: NumField(height, tr('Рост'), suffix: tr('см'), onChanged: changed)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: NumField(weight, tr('Вес'), suffix: tr('кг'), onChanged: changed)),
            const SizedBox(width: 8),
            Expanded(child: NumField(target, tr('Желаемый вес'), suffix: tr('кг'), onChanged: changed)),
          ],
        ),
        SectionLabel(tr('Активность')),
        for (var i = 0; i < activityLevels.length; i++)
          OptionTile(
            title: tr(activityLevels[i].title),
            desc: tr(activityLevels[i].desc),
            selected: activity == i,
            onTap: () => setState(() => activity = i),
          ),
        SectionLabel(tr('Программа')),
        for (final g in [Goal.bulk, Goal.cut, Goal.maintain])
          OptionTile(
            icon: g.icon,
            title: g.title,
            desc: g.desc,
            selected: goal == g,
            onTap: () => setState(() => goal = g),
          ),
        SectionLabel(tr('Твоя норма в день')),
        _preview(draft),
        const SizedBox(height: 10),
        AppCard(
          padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr('Свои нормы'), style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(tr('Задать калории и БЖУ вручную'), style: Txt.small),
                  ],
                ),
              ),
              Switch(
                value: custom,
                onChanged: _toggleCustom,
                activeTrackColor: AppColors.accent,
              ),
            ],
          ),
        ),
        if (custom) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: NumField(cK, tr('Калории'), suffix: tr('ккал'), onChanged: changed)),
              const SizedBox(width: 8),
              Expanded(child: NumField(cP, tr('Белки'), suffix: tr('г'), onChanged: changed)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: NumField(cF, tr('Жиры'), suffix: tr('г'), onChanged: changed)),
              const SizedBox(width: 8),
              Expanded(child: NumField(cC, tr('Углеводы'), suffix: tr('г'), onChanged: changed)),
            ],
          ),
        ],
        const SizedBox(height: 18),
        PrimaryButton(widget.submitText, icon: Icons.check, onPressed: _submit),
      ],
    );
  }

  Widget _preview(Profile? p) {
    if (p == null) {
      return AppCard(
        child: Text(tr('Заполни возраст, рост и вес — здесь появится расчёт.'), style: Txt.small),
      );
    }
    final t = computeTargets(p);
    return AppCard(
      borderColor: AppColors.accent.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtInt(t.kcal), style: Txt.num(32, color: AppColors.accent)),
              Text(tr('  ккал / день'), style: Txt.small),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Pill(trf('Белки {0} г', [t.protein]), color: AppColors.protein),
              Pill(trf('Жиры {0} г', [t.fat]), color: AppColors.fat),
              Pill(trf('Углеводы {0} г', [t.carbs]), color: AppColors.carbs),
              Pill(trf('Вода {0} мл', [fmtInt(t.waterMl)]), color: AppColors.water),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            trf('Базовый обмен {0} ккал · расход с активностью {1} ккал{2}', [fmtInt(calcBmr(p)), fmtInt(calcTdee(p)), p.customTargets ? tr(' · заданы вручную') : '']),
            style: Txt.small,
          ),
        ],
      ),
    );
  }
}
