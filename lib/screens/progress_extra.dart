import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../life/eval.dart';
import '../life/life_store.dart';
import '../life/models.dart';
import '../life/training.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import 'habits_screen.dart';
import 'sleep_screen.dart';
import 'steps_screen.dart';
import 'training_screen.dart';

/// Шаги, сон, тренировки и привычки за выбранный период.
class ActivityCard extends StatelessWidget {
  final DateTime from;
  const ActivityCard({super.key, required this.from});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final life = store.life;
    final now = today();
    final days = daysBetween(from, now) + 1;

    var stepSum = 0, stepCnt = 0, stepHit = 0;
    var sleepSum = 0.0, sleepCnt = 0;
    var habitSum = 0.0, habitCnt = 0;
    for (var i = 0; i < days; i++) {
      final d = addDays(from, i);
      final k = dkey(d);
      final st = life.stepsFor(k);
      if (st > 0) {
        stepSum += st;
        stepCnt++;
        if (st >= life.stepGoal) stepHit++;
      }
      final sl = life.sleepFor(k);
      if (sl != null) {
        sleepSum += sl.hours;
        sleepCnt++;
      }
      final r = store.dailyRatio(d);
      if (r != null) {
        habitSum += r;
        habitCnt++;
      }
    }
    final sessions = life.sessions
        .where((s) => s.finished && s.date.compareTo(dkey(from)) >= 0)
        .toList();
    final volume = sessions.fold<double>(0, (a, s) => a + s.volume);

    final chartDays = math.min(days, 60);
    final chartFrom = addDays(now, -(chartDays - 1));
    final bars = <BarDatum>[
      for (var i = 0; i < chartDays; i++)
        () {
          final d = addDays(chartFrom, i);
          final v = life.stepsFor(dkey(d));
          return BarDatum(d, v.toDouble(), life.stepGoal.toDouble(), v >= life.stepGoal ? AppColors.good : AppColors.under);
        }(),
    ];

    void open(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt, color: AppColors.accent, size: 20),
              SizedBox(width: 8),
              Text('Активность', style: Txt.h2),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Шаги по дням. Белая черта — цель', style: Txt.small),
          const SizedBox(height: 12),
          BarChart(data: bars, height: 140),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => open(const StepsScreen()),
                  child: StatTile(
                    label: 'Шаги в среднем',
                    value: stepCnt > 0 ? fmtInt(stepSum / stepCnt) : '—',
                    sub: 'цель: $stepHit дн.',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => open(const SleepScreen()),
                  child: StatTile(
                    label: 'Сон в среднем',
                    value: sleepCnt > 0 ? '${fmt1(sleepSum / sleepCnt)} ч' : '—',
                    sub: '$sleepCnt ноч. записано',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => open(const RecordsScreen()),
                  child: StatTile(
                    label: 'Тренировки',
                    value: '${sessions.length}',
                    sub: volume > 0 ? '${fmtInt(volume)} кг объём' : 'за период',
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => open(const HabitsScreen()),
                  child: StatTile(
                    label: 'Привычки',
                    value: habitCnt > 0 ? '${(habitSum / habitCnt * 100).round()}%' : '—',
                    sub: 'выполнено в среднем',
                    color: AppColors.good,
                  ),
                ),
              ),
            ],
          ),
          if (life.trainedExerciseIds().isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Рекорды', style: Txt.section),
            const SizedBox(height: 6),
            for (final id in life.trainedExerciseIds().take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: _recordLine(life, id),
              ),
          ],
        ],
      ),
    );
  }

  Widget _recordLine(LifeStore life, String id) {
    final ex = life.exerciseById(id);
    final r = life.recordOf(id);
    final useW = !ex.bodyweight && !ex.timed;
    return Row(
      children: [
        const Icon(Icons.emoji_events_outlined, size: 16, color: AppColors.accent),
        const SizedBox(width: 8),
        Expanded(child: Text(ex.name, style: Txt.body.copyWith(fontSize: 13))),
        Text(
          r == null ? '—' : (useW ? '${fmt1(r.value)} кг × ${r.reps}' : '${r.value.round()} ${ex.timed ? 'с' : 'повт.'}'),
          style: Txt.num(13),
        ),
      ],
    );
  }
}

/// Карточка фото прогресса на экране «Прогресс».
class PhotosCard extends StatelessWidget {
  const PhotosCard({super.key});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final photos = store.life.photos;
    final first = photos.isNotEmpty ? store.photoFile(photos.first.path) : null;
    final last = photos.length > 1 ? store.photoFile(photos.last.path) : null;
    final lastDate = photos.isNotEmpty ? parseKey(photos.last.date) : null;
    final due = lastDate == null || daysBetween(lastDate, today()) >= 7;

    return AppCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhotosScreen())),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_camera_outlined, color: AppColors.accent, size: 20),
              const SizedBox(width: 8),
              const Expanded(child: Text('Фото прогресса', style: Txt.h2)),
              Text('${photos.length} фото', style: Txt.small),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 10),
          if (first != null)
            Row(
              children: [
                Expanded(child: _thumb(first, 'До · ${fmtShort(parseKey(photos.first.date))}')),
                const SizedBox(width: 8),
                Expanded(
                  child: last != null
                      ? _thumb(last, 'Сейчас · ${fmtShort(parseKey(photos.last.date))}')
                      : Container(
                          height: 150,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(8)),
                          child: const Text('Сделай следующее\nфото через неделю', textAlign: TextAlign.center, style: Txt.small),
                        ),
                ),
              ],
            )
          else
            const Text('Сделай первое фото: в одном месте, при одном свете, в одной позе. '
                'Потом сравнивай раз в неделю или месяц.', style: Txt.small),
          if (due) ...[
            const SizedBox(height: 10),
            Text(photos.isEmpty ? 'Пора сделать первое фото' : 'Прошла неделя — пора новое фото',
                style: Txt.small.copyWith(color: AppColors.accent)),
          ],
        ],
      ),
    );
  }

  static Widget _thumb(File file, String label) => Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(file, height: 150, width: double.infinity, fit: BoxFit.cover, cacheWidth: 400),
          ),
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
        ],
      );
}

/// Все фото: добавить, удалить, сравнить два.
class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final selected = <String>[];
  bool busy = false;

  Future<void> _add(ImageSource src) async {
    final store = StoreScope.read(context);
    setState(() => busy = true);
    try {
      final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 85);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      final path = await store.savePhoto(bytes);
      if (path != null) store.life.addPhoto(ProgressPhoto(todayKey(), path));
    } catch (e) {
      if (mounted) showToast(context, 'Не удалось добавить фото: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final photos = store.life.photos.reversed.toList();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar('Фото прогресса', actions: [
        if (selected.length == 2)
          TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => _CompareScreen(a: selected[0], b: selected[1]),
            )),
            child: const Text('Сравнить', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
          ),
      ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Row(
            children: [
              Expanded(child: GhostButton('Камера', icon: Icons.photo_camera_outlined, onPressed: busy ? null : () => _add(ImageSource.camera))),
              const SizedBox(width: 8),
              Expanded(child: GhostButton('Галерея', icon: Icons.photo_library_outlined, onPressed: busy ? null : () => _add(ImageSource.gallery))),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            photos.length >= 2 ? 'Выбери два фото, чтобы сравнить их рядом. Долгое нажатие — удалить.' : 'Фото хранятся только на телефоне.',
            style: Txt.small,
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: photos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (_, i) {
              final p = photos[i];
              final f = store.photoFile(p.path);
              final sel = selected.contains(p.path);
              return GestureDetector(
                onTap: () => setState(() {
                  if (!selected.remove(p.path)) {
                    if (selected.length == 2) selected.removeAt(0);
                    selected.add(p.path);
                  }
                }),
                onLongPress: () async {
                  final ok = await confirm(context, 'Удалить фото?', fmtDate(parseKey(p.date), year: true), ok: 'Удалить');
                  if (ok) {
                    selected.remove(p.path);
                    store.life.deletePhoto(p.path);
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: f == null
                          ? Container(color: AppColors.surface2)
                          : Image.file(f, fit: BoxFit.cover, cacheWidth: 300),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? AppColors.accent : Colors.transparent, width: 3),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      bottom: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(5)),
                        child: Text(fmtShort(parseKey(p.date)), style: const TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CompareScreen extends StatelessWidget {
  final String a;
  final String b;
  const _CompareScreen({required this.a, required this.b});

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final all = store.life.photos;
    ProgressPhoto? pa, pb;
    for (final p in all) {
      if (p.path == a) pa = p;
      if (p.path == b) pb = p;
    }
    var first = pa, second = pb;
    if (first != null && second != null && first.date.compareTo(second.date) > 0) {
      final t = first;
      first = second;
      second = t;
    }
    final w1 = first == null ? null : _weightNear(store, first.date);
    final w2 = second == null ? null : _weightNear(store, second.date);

    Widget col(ProgressPhoto? p, double? w) {
      final f = p == null ? null : store.photoFile(p.path);
      return Expanded(
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: f == null ? Container(color: AppColors.surface2) : Image.file(f, fit: BoxFit.cover, width: double.infinity),
              ),
            ),
            const SizedBox(height: 8),
            Text(p == null ? '' : fmtDate(parseKey(p.date), year: true), style: Txt.section),
            if (w != null) Text('${fmt1(w)} кг', style: Txt.num(16, color: AppColors.accent2)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar('До / После'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
        child: Row(
          children: [col(first, w1), const SizedBox(width: 8), col(second, w2)],
        ),
      ),
    );
  }

  double? _weightNear(AppStore store, String date) {
    double? best;
    var bestDiff = 1 << 30;
    store.weights.forEach((k, v) {
      final diff = daysBetween(parseKey(k), parseKey(date)).abs();
      if (diff < bestDiff && diff <= 7) {
        bestDiff = diff;
        best = v;
      }
    });
    return best;
  }
}
