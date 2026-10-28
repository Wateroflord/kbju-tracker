import 'package:flutter/material.dart';

import '../learn/dialogues.dart';
import '../learn/learn_logic.dart';
import '../learn/tts.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/nav.dart';
import '../i18n/i18n.dart';
import 'learn_screen.dart' show topicIcon;

/// Список диалогов.
class DialoguesScreen extends StatelessWidget {
  final String lang;
  const DialoguesScreen({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
    final life = StoreScope.of(context).life;
    final native = life.nativeFor(lang);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(tr('Диалоги')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            tr('Короткие сцены из жизни. Слушай, повторяй вслух, а потом играй свою роль — подсказка спрятана.'),
            style: Txt.small,
          ),
          const SizedBox(height: 12),
          for (final d in dialogues)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DialogueView(dialogue: d, lang: lang))),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    Icon(topicIcon(d.icon), color: AppColors.accent, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.title.inLang(lang), style: Txt.body.copyWith(fontWeight: FontWeight.w700)),
                          Text(d.title.inLang(native), style: Txt.small),
                        ],
                      ),
                    ),
                    Text(trf('{0} реплик', [d.lines.length]), style: Txt.small),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Один диалог: прослушивание и тренировка своей роли.
class DialogueView extends StatefulWidget {
  final Dialogue dialogue;
  final String lang;
  const DialogueView({super.key, required this.dialogue, required this.lang});

  @override
  State<DialogueView> createState() => _DialogueViewState();
}

class _DialogueViewState extends State<DialogueView> with WidgetsBindingObserver {
  bool translation = true;
  bool practice = false;
  final Set<int> revealed = {};
  int playing = -1;
  int _playToken = 0;

  final Stopwatch _watch = Stopwatch()..start();
  int _saved = 0;
  late final AppStore _store;

  @override
  void initState() {
    super.initState();
    _store = StoreScope.read(context);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _playToken++;
    _saveTime();
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
    _store.life.addLearnSeconds(widget.lang, delta);
  }

  Future<void> _say(int i) async {
    final ok = await Tts.speak(widget.dialogue.lines[i].t.inLang(widget.lang), widget.lang);
    if (!ok && mounted) {
      showToast(context, tr('Нет голоса для этого языка. Установи его: Настройки → Синтез речи.'));
    }
  }

  /// Озвучить весь диалог по очереди. Длительность реплики оцениваем по числу слов.
  Future<void> _playAll() async {
    final token = ++_playToken;
    final lines = widget.dialogue.lines;
    for (var i = 0; i < lines.length; i++) {
      if (!mounted || token != _playToken) return;
      setState(() => playing = i);
      await _say(i);
      final words = lines[i].t.inLang(widget.lang).split(' ').length;
      await Future<void>.delayed(Duration(milliseconds: 900 + words * 480));
    }
    if (mounted && token == _playToken) setState(() => playing = -1);
  }

  void _stop() {
    _playToken++;
    Tts.stop();
    setState(() => playing = -1);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dialogue;
    final native = _store.life.nativeFor(widget.lang);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: subAppBar(d.title.inLang(widget.lang)),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Pill(tr('Перевод'),
                      icon: translation ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: translation ? AppColors.accent : AppColors.accent2,
                      onTap: () => setState(() => translation = !translation)),
                  const SizedBox(width: 6),
                  Pill(tr('Моя роль'),
                      icon: Icons.record_voice_over_outlined,
                      color: practice ? AppColors.accent : AppColors.accent2,
                      onTap: () => setState(() {
                            practice = !practice;
                            revealed.clear();
                          })),
                ],
              ),
            ),
            if (practice)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(tr('Твои реплики спрятаны: скажи их вслух по переводу, потом нажми, чтобы проверить.'),
                    style: Txt.small),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                itemCount: d.lines.length,
                itemBuilder: (_, i) => _bubble(i, d.lines[i], native),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: playing >= 0
                  ? GhostButton(tr('Остановить'), icon: Icons.stop, onPressed: _stop)
                  : PrimaryButton(tr('Слушать весь диалог'), icon: Icons.play_arrow, onPressed: _playAll),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(int i, DLine l, String native) {
    final me = l.me;
    final hidden = practice && me && !revealed.contains(i);
    final active = playing == i;
    final text = l.t.inLang(widget.lang);
    return Align(
      alignment: me ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: me ? AppColors.accent.withValues(alpha: active ? 0.28 : 0.14) : (active ? AppColors.surface2 : AppColors.surface),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: Radius.circular(me ? 12 : 3),
              bottomRight: Radius.circular(me ? 3 : 12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                if (hidden) {
                  setState(() => revealed.add(i));
                }
                _say(i);
              },
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: active ? AppColors.accent : (me ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hidden ? tr('••• нажми, чтобы проверить') : text,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: hidden ? AppColors.muted : AppColors.text,
                      ),
                    ),
                    if (translation || hidden) ...[
                      const SizedBox(height: 4),
                      Text(l.t.inLang(native), style: Txt.small),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
