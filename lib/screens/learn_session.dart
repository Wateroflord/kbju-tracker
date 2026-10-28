import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../learn/learn_logic.dart';
import '../learn/tts.dart';
import '../learn/words.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum LearnMode { learn, review, quiz, listen, type }

String learnModeTitle(LearnMode m) => switch (m) {
      LearnMode.learn => tr('Новые слова'),
      LearnMode.review => tr('Повторение'),
      LearnMode.quiz => tr('Тест'),
      LearnMode.listen => tr('Аудирование'),
      LearnMode.type => tr('Напиши слово'),
    };

/// Сравнение ответа: регистр, знаки препинания и подсказки в скобках не важны.
String _norm(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'\([^)]*\)'), '')
    .replaceAll('’', "'")
    .replaceAll(RegExp(r'[!?.,…¡¿:;«»"]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

const _plainMap = {
  'ą': 'a', 'ć': 'c', 'ę': 'e', 'ł': 'l', 'ń': 'n', 'ó': 'o', 'ś': 's', 'ź': 'z', 'ż': 'z',
  'ä': 'a', 'ö': 'o', 'ü': 'u', 'ß': 'ss', 'é': 'e', 'è': 'e',
};

/// Без диакритики и артиклей/частиц: «żółty» ≈ «zolty», «der Tag» ≈ «tag», «to go» ≈ «go».
String _plain(String s) {
  var t = _norm(s);
  final b = StringBuffer();
  for (final ch in t.split('')) {
    b.write(_plainMap[ch] ?? ch);
  }
  t = b.toString();
  t = t.replaceFirst(RegExp(r'^(der|die|das|to|the|a|an) '), '');
  return t;
}

/// 2 — верно, 1 — почти (опечатка в диакритике, нет артикля), 0 — неверно.
int checkTyped(String typed, String answer) {
  final a = _norm(typed);
  if (a.isEmpty) return 0;
  if (a == _norm(answer)) return 2;
  if (_plain(typed) == _plain(answer)) return 1;
  return 0;
}

class _Item {
  final W word;
  final bool reverse; // показываем перевод, вспоминаем слово на изучаемом языке
  const _Item(this.word, this.reverse);
}

/// Сессия занятий. Время на экране засчитывается в «20 часов».
class LearnSessionScreen extends StatefulWidget {
  final LearnMode mode;
  final String lang;
  final String? topic;
  const LearnSessionScreen({super.key, required this.mode, required this.lang, this.topic});

  @override
  State<LearnSessionScreen> createState() => _LearnSessionScreenState();
}

class _LearnSessionScreenState extends State<LearnSessionScreen> with WidgetsBindingObserver {
  final _rnd = math.Random();
  final List<_Item> queue = [];
  int index = 0;
  int right = 0;
  int wrong = 0;
  bool revealed = false;
  int? chosen; // выбранный вариант в тесте
  List<W> options = [];
  final Set<String> requeued = {};
  final typed = TextEditingController();
  int? typeResult; // результат проверки в режиме «напиши»

  // учёт времени
  final Stopwatch _watch = Stopwatch();
  int _saved = 0;
  Timer? _flush;

  String get lang => widget.lang;
  late final AppStore _store;

  @override
  void initState() {
    super.initState();
    _store = StoreScope.read(context);
    WidgetsBinding.instance.addObserver(this);
    _build();
    _watch.start();
    _flush = Timer.periodic(const Duration(seconds: 30), (_) => _saveTime());
    WidgetsBinding.instance.addPostFrameCallback((_) => _onShow());
  }

  @override
  void dispose() {
    _saveTime();
    _flush?.cancel();
    typed.dispose();
    WidgetsBinding.instance.removeObserver(this);
    Tts.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _watch.start();
    } else {
      _watch.stop();
      _saveTime();
    }
  }

  void _saveTime() {
    final total = _watch.elapsed.inSeconds;
    final delta = total - _saved;
    if (delta <= 0) return;
    _saved = total;
    _store.life.addLearnSeconds(lang, delta);
  }

  void _build() {
    final life = _store.life;
    List<W> list;
    switch (widget.mode) {
      case LearnMode.learn:
        list = life.newWords(lang, 10, topic: widget.topic);
      case LearnMode.review:
        list = life.dueWords(lang).take(20).toList();
      case LearnMode.quiz:
      case LearnMode.listen:
      case LearnMode.type:
        final pool = widget.topic != null
            ? wordsOf(widget.topic!)
            : words.where((w) => life.cardOf(lang, w) != null).toList();
        final src = pool.length >= 4 ? pool : wordsOf(topics.first.id);
        list = [...src]..shuffle(_rnd);
        list = list.take(widget.mode == LearnMode.type ? 10 : 12).toList();
    }
    for (final w in list) {
      final rev = widget.mode == LearnMode.type ||
          widget.mode == LearnMode.review && _rnd.nextBool() ||
          widget.mode == LearnMode.quiz && _rnd.nextInt(3) == 0;
      queue.add(_Item(w, rev));
    }
    _prepare();
  }

  String _target(W w) => w.inLang(lang);
  String _native(W w) => w.inLang(_store.life.nativeFor(lang));

  void _prepare() {
    revealed = false;
    chosen = null;
    typeResult = null;
    typed.clear();
    if (index >= queue.length) return;
    if (widget.mode == LearnMode.quiz || widget.mode == LearnMode.listen) {
      final w = queue[index].word;
      final same = words.where((x) => x.topic == w.topic && x.id != w.id).toList()..shuffle(_rnd);
      final others = <W>[];
      final seen = <String>{_native(w), _target(w)};
      for (final x in [...same, ...(words.toList()..shuffle(_rnd))]) {
        if (others.length >= 3) break;
        if (seen.add(_native(x)) && seen.add(_target(x))) others.add(x);
      }
      options = [w, ...others]..shuffle(_rnd);
    }
  }

  void _onShow() {
    if (index >= queue.length) return;
    final item = queue[index];
    final speakTarget = widget.mode == LearnMode.listen || (!item.reverse && widget.mode != LearnMode.quiz);
    if (speakTarget) _speak(item.word);
  }

  Future<void> _speak(W w) async {
    final ok = await Tts.speak(_target(w), lang);
    if (!ok && mounted) {
      showToast(context, tr('Нет голоса для этого языка. Установи его: Настройки → Синтез речи.'));
    }
  }

  void _answer(bool ok) {
    final item = queue[index];
    _store.life.recordAnswer(lang, item.word, ok);
    if (ok) {
      right++;
    } else {
      wrong++;
      // Ошибся — слово вернётся в конце сессии ещё раз.
      if (requeued.add(item.word.id)) queue.add(_Item(item.word, item.reverse));
    }
    setState(() {
      index++;
      _prepare();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _onShow());
  }

  void _choose(int i) {
    if (chosen != null) return;
    setState(() => chosen = i);
    final w = queue[index].word;
    if (options[i].id != w.id) _speak(w);
  }

  @override
  Widget build(BuildContext context) {
    final done = index >= queue.length;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(learnModeTitle(widget.mode), style: Txt.h2),
        actions: [
          if (!done && queue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: Text('${index + 1}/${queue.length}', style: Txt.num(14, color: AppColors.muted))),
            ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: queue.isEmpty ? _empty() : (done ? _summary() : _card()),
        ),
      ),
    );
  }

  Widget _empty() {
    final msg = switch (widget.mode) {
      LearnMode.review => tr('Сейчас нечего повторять — всё повторено. Возьми новые слова.'),
      LearnMode.learn => tr('В этой теме ты уже видел все слова. Переходи к повторению и тесту.'),
      _ => tr('Сначала выучи несколько слов.'),
    };
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.good, size: 48),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: Txt.body),
          const SizedBox(height: 20),
          PrimaryButton(tr('Готово'), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _summary() {
    final total = right + wrong;
    final pct = total == 0 ? 0 : (right * 100 / total).round();
    final mins = (_watch.elapsed.inSeconds / 60).ceil();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(pct >= 70 ? Icons.emoji_events_outlined : Icons.trending_up, color: AppColors.accent, size: 52),
        const SizedBox(height: 12),
        Text(pct >= 70 ? tr('Отлично!') : tr('Хорошая работа!'), style: Txt.h1),
        const SizedBox(height: 8),
        Text(trf('Верно {0} из {1} · {2} мин', [right, total, mins]), style: Txt.body),
        const SizedBox(height: 6),
        Text(tr('Ошибки — это нормально: так и происходит обучение.'), textAlign: TextAlign.center, style: Txt.small),
        const SizedBox(height: 24),
        PrimaryButton(tr('Ещё раунд'), icon: Icons.replay, onPressed: () {
          setState(() {
            queue.clear();
            requeued.clear();
            index = 0;
            right = 0;
            wrong = 0;
            _build();
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _onShow());
        }),
        const SizedBox(height: 10),
        GhostButton(tr('Закончить'), onPressed: () => Navigator.pop(context)),
      ],
    );
  }

  Widget _card() {
    final item = queue[index];
    final w = item.word;
    final quiz = widget.mode == LearnMode.quiz || widget.mode == LearnMode.listen;
    final type = widget.mode == LearnMode.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProgressLine(ratio: index / queue.length, color: AppColors.accent, height: 4, overIsBad: false),
        const SizedBox(height: 18),
        Expanded(
          child: type ? _typeBody(item) : (quiz ? _quizBody(item) : _flashBody(item)),
        ),
        if (type) ..._typeButtons(item),
        if (!quiz && !type) ..._flashButtons(),
        if (quiz && chosen != null)
          PrimaryButton(tr('Дальше'), icon: Icons.arrow_forward, onPressed: () => _answer(options[chosen!].id == w.id)),
      ],
    );
  }

  Widget _wordCard(String text, {required bool speak, W? w, String? sub}) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 20),
      child: Column(
        children: [
          Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: AppColors.text)),
          if (sub != null) ...[
            const SizedBox(height: 10),
            Text(sub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, color: AppColors.accent2)),
          ],
          if (speak && w != null) ...[
            const SizedBox(height: 14),
            IconButton.filledTonal(
              onPressed: () => _speak(w),
              icon: const Icon(Icons.volume_up),
              tooltip: tr('Произношение'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _flashBody(_Item item) {
    final w = item.word;
    final front = item.reverse ? _native(w) : _target(w);
    final back = item.reverse ? _target(w) : _native(w);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item.reverse ? tr('Как это сказать?') : tr('Что это значит?'),
            textAlign: TextAlign.center,
            style: Txt.small,
          ),
          const SizedBox(height: 10),
          _wordCard(
            front,
            speak: !item.reverse || revealed,
            w: w,
            sub: revealed ? back : null,
          ),
          const SizedBox(height: 14),
          if (!revealed)
            GhostButton(tr('Показать ответ'), icon: Icons.visibility_outlined, onPressed: () {
              setState(() => revealed = true);
              if (item.reverse) _speak(w);
            }),
          if (revealed)
            Text(
              tr('Честно оцени: вспомнил сам или нет?'),
              textAlign: TextAlign.center,
              style: Txt.small,
            ),
        ],
      ),
    );
  }

  List<Widget> _flashButtons() {
    if (!revealed) return const [];
    return [
      Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.over,
                  side: const BorderSide(color: AppColors.over),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _answer(false),
                child: Text(tr('Не помню'), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.good,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _answer(true),
                child: Text(tr('Помню'), style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  void _check(_Item item) {
    final r = checkTyped(typed.text, _target(item.word));
    setState(() => typeResult = r);
    _speak(item.word);
  }

  Widget _typeBody(_Item item) {
    final w = item.word;
    final answer = _target(w);
    final r = typeResult;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Напиши на изучаемом языке'), textAlign: TextAlign.center, style: Txt.small),
          const SizedBox(height: 10),
          _wordCard(_native(w), speak: false),
          const SizedBox(height: 14),
          TextField(
            controller: typed,
            autofocus: true,
            enabled: r == null,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              if (r == null && typed.text.trim().isNotEmpty) _check(item);
            },
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.text),
            decoration: fieldDeco(tr('Твой ответ')),
          ),
          if (r != null) ...[
            const SizedBox(height: 14),
            AppCard(
              borderColor: r == 2 ? AppColors.good : (r == 1 ? AppColors.fat : AppColors.over),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r == 2 ? tr('Верно!') : (r == 1 ? tr('Почти! Обрати внимание на написание:') : tr('Правильный ответ:')),
                    style: Txt.small.copyWith(color: r == 2 ? AppColors.good : (r == 1 ? AppColors.fat : AppColors.over)),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(answer, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text)),
                      ),
                      IconButton(onPressed: () => _speak(w), icon: const Icon(Icons.volume_up, color: AppColors.accent)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _typeButtons(_Item item) {
    if (typeResult != null) {
      return [PrimaryButton(tr('Дальше'), icon: Icons.arrow_forward, onPressed: () => _answer(typeResult! > 0))];
    }
    return [
      Row(
        children: [
          GhostButton(tr('Не знаю'), onPressed: () {
            setState(() => typeResult = 0);
            _speak(item.word);
          }),
          const SizedBox(width: 10),
          Expanded(child: PrimaryButton(tr('Проверить'), icon: Icons.check, onPressed: () => _check(item))),
        ],
      ),
    ];
  }

  Widget _quizBody(_Item item) {
    final w = item.word;
    final listen = widget.mode == LearnMode.listen;
    // В тесте: обычно показываем слово на изучаемом языке и выбираем перевод,
    // иногда наоборот. В аудировании слово только звучит.
    final reverse = !listen && item.reverse;
    final prompt = reverse ? _native(w) : _target(w);
    String optText(W o) => reverse ? _target(o) : _native(o);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            listen ? tr('Послушай и выбери перевод') : (reverse ? tr('Выбери слово') : tr('Выбери перевод')),
            textAlign: TextAlign.center,
            style: Txt.small,
          ),
          const SizedBox(height: 10),
          if (listen)
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: 26),
              child: Column(
                children: [
                  IconButton.filled(
                    iconSize: 40,
                    onPressed: () => _speak(w),
                    icon: const Icon(Icons.volume_up),
                    style: IconButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                  ),
                  if (chosen != null) ...[
                    const SizedBox(height: 12),
                    Text(_target(w), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text)),
                  ],
                ],
              ),
            )
          else
            _wordCard(prompt, speak: !reverse, w: w),
          const SizedBox(height: 14),
          for (var i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _option(i, optText(options[i]), options[i].id == w.id),
            ),
        ],
      ),
    );
  }

  Widget _option(int i, String text, bool correct) {
    Color border = AppColors.border;
    Color bg = AppColors.surface;
    if (chosen != null) {
      if (correct) {
        border = AppColors.good;
        bg = AppColors.good.withValues(alpha: 0.12);
      } else if (chosen == i) {
        border = AppColors.over;
        bg = AppColors.over.withValues(alpha: 0.12);
      }
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _choose(i),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: chosen != null && (correct || chosen == i) ? 2 : 1),
          ),
          child: Text(text, style: Txt.body.copyWith(fontSize: 16, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}
