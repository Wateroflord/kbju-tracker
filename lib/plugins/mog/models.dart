import 'package:flutter/material.dart';

/// Что оцениваем.
enum Kind { looks, style, synergy }

extension KindX on Kind {
  String get title => switch (this) {
        Kind.looks => 'Внешность',
        Kind.style => 'Стиль',
        Kind.synergy => 'Синергия',
      };

  String get hint => switch (this) {
        Kind.looks => 'Лицо крупно, при дневном свете, без фильтров. Можно по пояс.',
        Kind.style => 'Фото в полный рост, чтобы был виден весь образ и обувь.',
        Kind.synergy => 'Фото в полный рост, но чтобы лицо было хорошо видно.',
      };

  String get about => switch (this) {
        Kind.looks => 'Кожа, волосы, черты лица, гармония, ухоженность, подача на фото.',
        Kind.style => 'Цвета, посадка, силуэт, обувь, аксессуары, цельность образа.',
        Kind.synergy => 'Как одежда сочетается с тобой: цветотип, черты лица, фигура, общий вайб.',
      };

  IconData get icon => switch (this) {
        Kind.looks => Icons.face_retouching_natural,
        Kind.style => Icons.checkroom,
        Kind.synergy => Icons.auto_awesome,
      };

  static Kind parse(String? s) => Kind.values.firstWhere((k) => k.name == s, orElse: () => Kind.looks);
}

double? _d(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.'));
}

double _clamp(double? v) => v == null ? 0 : (v.clamp(0, 10) * 10).round() / 10;
double? _clampN(double? v) => v == null ? null : _clamp(v);

String _s(dynamic v) => v == null ? '' : v.toString().trim();

List<String> _list(dynamic v) =>
    v is List ? v.map((e) => _s(e)).where((e) => e.isNotEmpty).toList() : <String>[];

class Category {
  final String name;
  final double? score;
  final String comment;
  const Category(this.name, this.score, this.comment);

  factory Category.fromJson(Map j) => Category(_s(j['name']), _clampN(_d(j['score'])), _s(j['comment']));
  Map<String, dynamic> toJson() => {'name': name, 'score': score, 'comment': comment};
}

class Tip {
  final String title;
  final String text;
  final String impact; // high / medium / low
  const Tip(this.title, this.text, this.impact);

  factory Tip.fromJson(Map j) {
    final imp = _s(j['impact']).toLowerCase();
    return Tip(_s(j['title']), _s(j['text']), ['high', 'medium', 'low'].contains(imp) ? imp : 'medium');
  }
  Map<String, dynamic> toJson() => {'title': title, 'text': text, 'impact': impact};
}

List<Tip> _tips(dynamic v) => v is List
    ? v.whereType<Map>().map(Tip.fromJson).where((t) => t.title.isNotEmpty || t.text.isNotEmpty).toList()
    : <Tip>[];

List<Category> _cats(dynamic v) => v is List
    ? v.whereType<Map>().map(Category.fromJson).where((c) => c.name.isNotEmpty).toList()
    : <Category>[];

/// Оценка одного фото.
class SoloResult {
  final double overall;
  final double? potential;
  final String summary;
  final List<Category> subScores; // для синергии: внешность / стиль / синергия
  final List<Category> categories;
  final List<String> strengths;
  final List<String> weaknesses;
  final List<Tip> tips;
  final String photoNote;

  const SoloResult({
    required this.overall,
    required this.potential,
    required this.summary,
    required this.subScores,
    required this.categories,
    required this.strengths,
    required this.weaknesses,
    required this.tips,
    required this.photoNote,
  });

  factory SoloResult.fromJson(Map j) => SoloResult(
        overall: _clamp(_d(j['overall'])),
        potential: _clampN(_d(j['potential'])),
        summary: _s(j['summary']),
        subScores: _cats(j['subScores']),
        categories: _cats(j['categories']),
        strengths: _list(j['strengths']),
        weaknesses: _list(j['weaknesses']),
        tips: _tips(j['tips']),
        photoNote: _s(j['photoNote']),
      );

  Map<String, dynamic> toJson() => {
        'overall': overall,
        'potential': potential,
        'summary': summary,
        'subScores': subScores.map((e) => e.toJson()).toList(),
        'categories': categories.map((e) => e.toJson()).toList(),
        'strengths': strengths,
        'weaknesses': weaknesses,
        'tips': tips.map((e) => e.toJson()).toList(),
        'photoNote': photoNote,
      };
}

class DuelCategory {
  final String name;
  final double? a;
  final double? b;
  final String winner; // a / b / draw
  final String comment;
  const DuelCategory(this.name, this.a, this.b, this.winner, this.comment);

  factory DuelCategory.fromJson(Map j) {
    final a = _clampN(_d(j['a'])), b = _clampN(_d(j['b']));
    var w = _s(j['winner']).toLowerCase();
    if (!['a', 'b', 'draw'].contains(w)) {
      w = (a == null || b == null || (a - b).abs() < 0.05) ? 'draw' : (a > b ? 'a' : 'b');
    }
    return DuelCategory(_s(j['name']), a, b, w, _s(j['comment']));
  }
  Map<String, dynamic> toJson() => {'name': name, 'a': a, 'b': b, 'winner': winner, 'comment': comment};
}

/// Батл двух фото.
class BattleResult {
  final double aScore;
  final double bScore;
  final String aSummary;
  final String bSummary;
  final String winner; // a / b / draw
  final String verdict;
  final List<DuelCategory> categories;
  final List<String> aEdges;
  final List<String> bEdges;
  final List<Tip> tips;
  final String photoNote;

  const BattleResult({
    required this.aScore,
    required this.bScore,
    required this.aSummary,
    required this.bSummary,
    required this.winner,
    required this.verdict,
    required this.categories,
    required this.aEdges,
    required this.bEdges,
    required this.tips,
    required this.photoNote,
  });

  factory BattleResult.fromJson(Map j) {
    final a = j['a'] is Map ? j['a'] as Map : const {};
    final b = j['b'] is Map ? j['b'] as Map : const {};
    final sa = _clamp(_d(a['overall'])), sb = _clamp(_d(b['overall']));
    var w = _s(j['winner']).toLowerCase();
    if (!['a', 'b', 'draw'].contains(w)) w = (sa - sb).abs() < 0.05 ? 'draw' : (sa > sb ? 'a' : 'b');
    return BattleResult(
      aScore: sa,
      bScore: sb,
      aSummary: _s(a['summary']),
      bSummary: _s(b['summary']),
      winner: w,
      verdict: _s(j['verdict']),
      categories: j['categories'] is List
          ? (j['categories'] as List).whereType<Map>().map(DuelCategory.fromJson).where((c) => c.name.isNotEmpty).toList()
          : <DuelCategory>[],
      aEdges: _list(j['aEdges']),
      bEdges: _list(j['bEdges']),
      tips: _tips(j['tips']),
      photoNote: _s(j['photoNote']),
    );
  }

  Map<String, dynamic> toJson() => {
        'a': {'overall': aScore, 'summary': aSummary},
        'b': {'overall': bScore, 'summary': bSummary},
        'winner': winner,
        'verdict': verdict,
        'categories': categories.map((e) => e.toJson()).toList(),
        'aEdges': aEdges,
        'bEdges': bEdges,
        'tips': tips.map((e) => e.toJson()).toList(),
        'photoNote': photoNote,
      };
}

/// Запись в истории.
class HistoryEntry {
  final String id;
  final DateTime date;
  final Kind kind;
  final bool battle;
  final String thumbA; // base64 jpeg
  final String? thumbB;
  final String opponent;
  final Map<String, dynamic> result;

  const HistoryEntry({
    required this.id,
    required this.date,
    required this.kind,
    required this.battle,
    required this.thumbA,
    required this.thumbB,
    required this.opponent,
    required this.result,
  });

  SoloResult get solo => SoloResult.fromJson(result);
  BattleResult get duel => BattleResult.fromJson(result);

  factory HistoryEntry.fromJson(Map j) => HistoryEntry(
        id: _s(j['id']),
        date: DateTime.tryParse(_s(j['date'])) ?? DateTime.now(),
        kind: KindX.parse(j['kind']?.toString()),
        battle: j['battle'] == true,
        thumbA: _s(j['thumbA']),
        thumbB: j['thumbB']?.toString(),
        opponent: _s(j['opponent']),
        result: j['result'] is Map ? Map<String, dynamic>.from(j['result'] as Map) : <String, dynamic>{},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'kind': kind.name,
        'battle': battle,
        'thumbA': thumbA,
        'thumbB': thumbB,
        'opponent': opponent,
        'result': result,
      };
}

/// Название уровня по оценке.
String tierName(double s) {
  if (s >= 9) return 'Легенда';
  if (s >= 8) return 'Топ';
  if (s >= 7) return 'Выше среднего';
  if (s >= 5.5) return 'Средний уровень';
  if (s >= 4) return 'Есть потенциал';
  return 'Много точек роста';
}

String fmtScore(double? s) => s == null ? '—' : s.toStringAsFixed(1);
