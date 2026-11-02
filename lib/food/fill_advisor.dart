import '../gemini.dart';
import '../models.dart';
import '../store.dart';
import '../util.dart';
import 'food_models.dart';
import '../i18n/i18n.dart';

/// Вариант «что съесть, чтобы добрать норму».
class FillIdea {
  final AiFoodItem item;
  final String why;
  final bool ai;
  const FillIdea(this.item, this.why, {this.ai = false});
}

/// Сколько осталось до нормы за день.
class Remaining {
  final double kcal, protein, fat, carbs;
  const Remaining(this.kcal, this.protein, this.fat, this.carbs);

  static Remaining of(AppStore s, String key) {
    final t = s.targetsFor(key);
    final tot = s.totalsFor(key);
    double left(int target, double eaten) => target - eaten < 0 ? 0.0 : target - eaten;
    return Remaining(left(t.kcal, tot.kcal), left(t.protein, tot.protein), left(t.fat, tot.fat), left(t.carbs, tot.carbs));
  }

  bool get done => kcal < 80;
}

class FillAdvisor {
  /// Подбор из своих продуктов: избранное, недавнее, рецепты. Работает без интернета.
  static List<FillIdea> local(AppStore s, String key, {int max = 4}) {
    final rem = Remaining.of(s, key);
    if (rem.done) return const [];
    final seen = <String>{};
    final cands = <AiFoodItem>[];
    void addFav(FavFood f) {
      if (f.kcal <= 0 || !seen.add(f.norm)) return;
      cands.add(AiFoodItem(
          name: f.name, grams: f.grams, kcal: f.kcal, protein: f.protein, fat: f.fat, carbs: f.carbs, fiber: f.fiber, salt: f.salt));
    }

    s.food.favorites.forEach(addFav);
    s.recentFoods(limit: 80).forEach(addFav);
    for (final r in s.food.recipes) {
      if (r.weight <= 0 || !seen.add(r.name.trim().toLowerCase())) continue;
      final k = r.factor(r.portionGrams);
      cands.add(AiFoodItem(
        name: r.name,
        grams: (r.portionGrams * 10).round() / 10,
        kcal: r.kcal * k,
        protein: r.protein * k,
        fat: r.fat * k,
        carbs: r.carbs * k,
        fiber: r.fiber * k,
        salt: r.salt * k,
      ));
    }

    final scored = <(double, AiFoodItem)>[];
    for (var c in cands) {
      // Порция больше остатка — уменьшаем вес (но не меньше трети).
      if (c.kcal > rem.kcal * 1.1 && c.grams > 0) {
        final g = c.grams * rem.kcal / c.kcal;
        if (g < c.grams / 3) continue;
        c = c.scaled((g / 5).round() * 5.0);
      }
      if (c.kcal < 40) continue;
      var score = c.kcal / rem.kcal; // насколько закрывает калории
      if (rem.protein > 5) score += 2 * (c.protein < rem.protein ? c.protein : rem.protein) / rem.protein;
      if (c.fat > rem.fat + 5) score -= 1;
      if (c.carbs > rem.carbs + 15) score -= 0.5;
      scored.add((score, c));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [
      for (final x in scored.take(max))
        FillIdea(x.$2, trf('+{0} г белка, закроет {1}% остатка калорий', [fmt1(x.$2.protein), (x.$2.kcal / rem.kcal * 100).round().clamp(1, 100)])),
    ];
  }

  /// Варианты от ИИ с учётом того, что человек обычно ест.
  static Future<(List<FillIdea>, String)> ai(AppStore s, String key) async {
    final rem = Remaining.of(s, key);
    final known = <String>{
      ...s.food.favorites.map((f) => f.name),
      ...s.food.recipes.map((r) => r.name),
      ...s.recentFoods(limit: 40).map((f) => f.name),
    }.take(50).join('; ');
    final now = DateTime.now();
    final meal = sameDay(parseKey(key), now) ? MealX.byTime(now).name : 'snack';
    final goal = s.profile?.goal.name ?? 'maintain';
    final prompt = StringBuffer()
      ..writeln('You are a practical nutritionist. The user tracks calories and macros.')
      ..writeln('Goal: $goal. Time now: ${two(now.hour)}:${two(now.minute)}, next meal: $meal.')
      ..writeln('Still left for today: ${rem.kcal.round()} kcal, protein ${rem.protein.round()} g, '
          'fat ${rem.fat.round()} g, carbs ${rem.carbs.round()} g.')
      ..writeln('Foods the user usually eats: $known')
      ..writeln('Suggest 4 simple options (a single dish or a small combo) that fit the remaining budget, '
          'close the protein gap first, and suit the time of day. Prefer the user\'s usual foods; '
          'at least one option should need no cooking. Each option must not exceed the remaining calories.')
      ..writeln('Write names and reasons in ${GeminiService.outLang}. Reason: one short sentence.')
      ..writeln('Answer with exactly one JSON object, no markdown:')
      ..writeln('{"ideas":[{"name":"Greek yogurt with berries","grams":250,"kcal":200,"protein":22,"fat":5,'
          '"carbs":18,"fiber":2,"salt":0.2,"why":"short reason"}],"note":"one short tip"}');
    final text = await GeminiService.generate(apiKey: s.apiKey, model: s.model, prompt: prompt.toString(), json: true);
    final j = GeminiService.parseJsonObject(text);
    final out = <FillIdea>[];
    final raw = j['ideas'];
    if (raw is List) {
      for (final m in raw.whereType<Map>()) {
        final name = (m['name'] ?? '').toString().trim();
        final kcal = asDouble(m['kcal']);
        if (name.isEmpty || kcal <= 0) continue;
        double r(dynamic v) => (asDouble(v) * 10).round() / 10;
        out.add(FillIdea(
          AiFoodItem(
            name: name,
            grams: r(m['grams']),
            kcal: r(kcal),
            protein: r(m['protein']),
            fat: r(m['fat']),
            carbs: r(m['carbs']),
            fiber: r(m['fiber']),
            salt: (asDouble(m['salt']) * 100).round() / 100,
          ),
          (m['why'] ?? '').toString().trim(),
          ai: true,
        ));
      }
    }
    return (out, (j['note'] ?? '').toString().trim());
  }
}
