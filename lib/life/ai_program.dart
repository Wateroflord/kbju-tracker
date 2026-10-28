import '../gemini.dart';
import '../store.dart';
import '../util.dart';
import '../i18n/i18n.dart';
import 'models.dart';

/// Параметры генерации программы.
class AiProgramRequest {
  final String goal; // muscle | strength | fatloss | health
  final String level; // beginner | intermediate | advanced
  final int days;
  final int minutes;
  final String equipment; // gym | dumbbells | bar | none
  final String notes;
  const AiProgramRequest({
    required this.goal,
    required this.level,
    required this.days,
    required this.minutes,
    required this.equipment,
    this.notes = '',
  });
}

/// Результат: программа и новые упражнения, которых ещё нет в приложении.
class AiProgramResult {
  final Program program;
  final List<Exercise> newExercises;
  const AiProgramResult(this.program, this.newExercises);
}

const _goalEn = {
  'muscle': 'muscle growth (hypertrophy)',
  'strength': 'strength',
  'fatloss': 'fat loss while keeping muscle',
  'health': 'general fitness and health',
};
const _levelEn = {
  'beginner': 'beginner (0-6 months of training)',
  'intermediate': 'intermediate (6 months - 2 years)',
  'advanced': 'advanced (2+ years)',
};
const _equipEn = {
  'gym': 'full commercial gym (barbells, dumbbells, machines, cables)',
  'dumbbells': 'home: adjustable dumbbells and a bench',
  'bar': 'home: pull-up bar, resistance bands and bodyweight',
  'none': 'no equipment at all, bodyweight only',
};

Future<AiProgramResult> generateProgram(AppStore store, AiProgramRequest r) async {
  final life = store.life;
  final p = store.profile;
  final b = StringBuffer()
    ..writeln('You are an experienced strength and conditioning coach. Create a weekly training program.');
  if (p != null) {
    b.writeln('User: ${p.sex.name}, ${p.age} years, ${p.heightCm.round()} cm, ${p.weightKg.round()} kg, '
        'nutrition goal: ${p.goal.name}.');
  }
  b
    ..writeln('Training goal: ${_goalEn[r.goal]}. Level: ${_levelEn[r.level]}.')
    ..writeln('Training days per week: ${r.days}. Session length: about ${r.minutes} minutes including rest.')
    ..writeln('Equipment: ${_equipEn[r.equipment]}.');
  if (r.notes.trim().isNotEmpty) {
    b.writeln('User notes and limitations (respect them, avoid exercises that may hurt): ${r.notes.trim()}');
  }
  b.writeln('Exercises already in the app. Reuse them by id when they fit the equipment '
      '(names are in Russian; flags: BW = bodyweight, T = timed in seconds):');
  for (final e in life.allExercises) {
    b.writeln('- ${e.id}: ${e.name}${e.bodyweight ? ' [BW]' : ''}${e.timed ? ' [T]' : ''}');
  }
  b
    ..writeln('Rules:')
    ..writeln('- 2-3 days/week: full body A/B alternating. 4 days: upper/lower. 5-6 days: push/pull/legs or similar. '
        'Days are rotated in order, so give 2-3 distinct workout days (not one per weekday) unless the split needs more.')
    ..writeln('- 4-7 exercises per day so the session fits the time. Compound lifts first.')
    ..writeln('- sets 2-5. repMin/repMax is the rep range; for timed exercises it is seconds; repMax 0 means "to failure".')
    ..writeln('- For a new exercise use "id": "" and give name, technique (1-2 short sentences), easier (simpler variation), '
        'bodyweight and timed flags.')
    ..writeln('- weekdays: exactly ${r.days} numbers (1 = Monday ... 7 = Sunday), spread with rest days.')
    ..writeln('- title (max 30 chars) and desc (1 sentence: who it is for, how to progress).')
    ..writeln('Write title, desc, day titles, exercise names, technique and easier in ${GeminiService.outLang}.')
    ..writeln('Answer with exactly one JSON object, no markdown:')
    ..writeln('{"title":"","desc":"","weekdays":[1,3,5],"days":[{"title":"","exercises":[{"id":"squat","name":"",'
        '"technique":"","easier":"","bodyweight":false,"timed":false,"sets":3,"repMin":8,"repMax":12}]}]}');

  final text = await GeminiService.generate(apiKey: store.apiKey, model: store.model, prompt: b.toString(), json: true);
  return _parse(store, GeminiService.parseJsonObject(text), r.days);
}

AiProgramResult _parse(AppStore store, Map<String, dynamic> j, int daysPerWeek) {
  final life = store.life;
  final known = {for (final e in life.allExercises) e.id: e};
  final byName = {for (final e in life.allExercises) tr(e.name).toLowerCase(): e};
  final newEx = <Exercise>[];
  final days = <WorkoutDay>[];
  final rawDays = j['days'];
  if (rawDays is List) {
    var n = 0;
    for (final d in rawDays.whereType<Map>()) {
      n++;
      final list = <PlanExercise>[];
      final rawEx = d['exercises'];
      if (rawEx is List) {
        for (final e in rawEx.whereType<Map>()) {
          final id = e['id']?.toString().trim() ?? '';
          final name = e['name']?.toString().trim() ?? '';
          Exercise? ex = known[id];
          ex ??= byName[name.toLowerCase()];
          if (ex == null) {
            if (name.isEmpty) continue;
            ex = Exercise(
              id: life.newId('ex'),
              name: name,
              technique: e['technique']?.toString().trim() ?? '',
              easier: e['easier']?.toString().trim() ?? '',
              bodyweight: e['bodyweight'] == true,
              timed: e['timed'] == true,
              custom: true,
            );
            newEx.add(ex);
            known[ex.id] = ex;
            byName[name.toLowerCase()] = ex;
          }
          final sets = asInt(e['sets'], 3).clamp(1, 8).toInt();
          var lo = asInt(e['repMin'], 8).clamp(0, 300).toInt();
          var hi = asInt(e['repMax'], 12).clamp(0, 300).toInt();
          if (hi != 0 && hi < lo) {
            final t = lo;
            lo = hi;
            hi = t;
          }
          list.add(PlanExercise(ex.id, sets, lo, hi));
        }
      }
      if (list.isEmpty) continue;
      final title = d['title']?.toString().trim() ?? '';
      days.add(WorkoutDay(id: 'D$n', title: title.isEmpty ? trf('День {0}', [n]) : title, exercises: list));
    }
  }
  if (days.isEmpty) throw GeminiException(tr('ИИ не составил программу. Попробуй ещё раз.'));

  var weekdays = ((j['weekdays'] as List?) ?? const []).map((e) => asInt(e)).where((e) => e >= 1 && e <= 7).toSet().toList()
    ..sort();
  if (weekdays.isEmpty) weekdays = _defaultWeekdays(daysPerWeek);
  final title = j['title']?.toString().trim() ?? '';
  final program = Program(
    id: life.newId('p'),
    title: title.isEmpty ? tr('Программа от ИИ') : title,
    desc: j['desc']?.toString().trim() ?? '',
    days: days,
    weekdays: weekdays,
    custom: true,
  );
  return AiProgramResult(program, newEx);
}

List<int> _defaultWeekdays(int n) => switch (n) {
      1 => [3],
      2 => [2, 5],
      3 => [1, 3, 5],
      4 => [1, 2, 4, 5],
      5 => [1, 2, 3, 5, 6],
      _ => [1, 2, 3, 4, 5, 6],
    };

/// Сохранить сгенерированную программу и сделать активной.
void saveAiProgram(AppStore store, AiProgramResult r) {
  for (final e in r.newExercises) {
    store.life.addExercise(e);
  }
  store.life.saveProgram(r.program);
  store.life.setActiveProgram(r.program.id);
}
