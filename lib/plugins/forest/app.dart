import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';

import 'content.dart';
import '../common/ui.dart';

const _green = Color(0xFF6ED28C);

class Prefs {
  static final _s = JsonStore('forest.json');
  static Map<String, dynamic> d = {};
  static Future<void> load() async => d = await _s.read();
  static Future<void> save() => _s.write(d);
  static Set<String> get favs => {...((d['favs'] as List?) ?? const []).map((e) => '$e')};
  static Set<String> get kit => {...((d['kit'] as List?) ?? const []).map((e) => '$e')};
  static Set<String> get read => {...((d['read'] as List?) ?? const []).map((e) => '$e')};
  static Future<void> setList(String k, Set<String> v) {
    d[k] = v.toList();
    return save();
  }
}

class ForestApp extends StatelessWidget {
  const ForestApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Выживание в лесу',
        debugShowCheckedModeBanner: false,
        theme: winterTheme(_green),
        home: const Home(),
      );
}

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;

  @override
  void initState() {
    super.initState();
    Prefs.load().then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final pages = [const GuideTab(), const ToolsTab(), const QuizTab()];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        backgroundColor: W.surface,
        indicatorColor: _green.withValues(alpha: 0.25),
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Гайд'),
          NavigationDestination(icon: Icon(Icons.handyman_outlined), label: 'Инструменты'),
          NavigationDestination(icon: Icon(Icons.quiz_outlined), label: 'Проверь себя'),
        ],
      ),
    );
  }
}

// ---------------- Гайд ----------------

class GuideTab extends StatefulWidget {
  const GuideTab({super.key});

  @override
  State<GuideTab> createState() => _GuideTabState();
}

class _GuideTabState extends State<GuideTab> {
  final q = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final query = q.text.trim().toLowerCase();
    final found = query.isEmpty
        ? const <Article>[]
        : articles.where((a) => '${a.title} ${a.summary} ${a.blocks.map((b) => b.$2).join(' ')}'.toLowerCase().contains(query)).toList();
    final favs = Prefs.favs;
    final read = Prefs.read;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text('Выживание в лесу', style: W.h1),
            const Text('Работает без интернета. Прочитай заранее — в беде будет не до чтения.', style: W.small),
            const SizedBox(height: 12),
            WCard(
              color: W.bad.withValues(alpha: 0.12),
              borderColor: W.bad.withValues(alpha: 0.5),
              onTap: () => _call(context, '112'),
              child: const Row(children: [
                Icon(Icons.call, color: W.bad),
                SizedBox(width: 12),
                Expanded(child: Text('Экстренный вызов 112\nРаботает без денег на счёте, через любую сеть', style: W.body)),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: q,
              onChanged: (_) => setState(() {}),
              style: W.body,
              decoration: InputDecoration(
                hintText: 'Поиск: вода, клещ, медведь…',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: W.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: W.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: W.border)),
              ),
            ),
            if (query.isNotEmpty) ...[
              Section('Найдено: ${found.length}'),
              for (final a in found) _ArticleTile(a, read: read.contains(a.id), onBack: () => setState(() {})),
            ] else ...[
              if (favs.isNotEmpty) ...[
                const Section('Избранное'),
                for (final a in articles.where((a) => favs.contains(a.id))) _ArticleTile(a, read: read.contains(a.id), onBack: () => setState(() {})),
              ],
              for (final c in categories) ...[
                Section('${c.icon}  ${c.title}'),
                for (final a in articles.where((a) => a.cat == c.id)) _ArticleTile(a, read: read.contains(a.id), onBack: () => setState(() {})),
              ],
              const SizedBox(height: 12),
              Text('Прочитано ${read.length} из ${articles.length}', textAlign: TextAlign.center, style: W.small),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> _call(BuildContext context, String number) async {
  final ok = await launchUrl(Uri.parse('tel:$number')).catchError((_) => false);
  if (!ok && context.mounted) toast(context, 'Набери $number на телефоне');
}

class _ArticleTile extends StatelessWidget {
  final Article a;
  final bool read;
  final VoidCallback onBack;
  const _ArticleTile(this.a, {required this.read, required this.onBack});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: WCard(
          padding: const EdgeInsets.all(12),
          onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArticleScreen(a)));
            onBack();
          },
          child: Row(children: [
            Text(a.icon, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.title, style: W.body.copyWith(fontWeight: FontWeight.w700)),
                Text(a.summary, style: W.small),
              ]),
            ),
            if (read) const Icon(Icons.check_circle, size: 18, color: _green),
          ]),
        ),
      );
}

class ArticleScreen extends StatefulWidget {
  final Article a;
  const ArticleScreen(this.a, {super.key});

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  @override
  void initState() {
    super.initState();
    final r = Prefs.read..add(widget.a.id);
    Prefs.setList('read', r);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a;
    final fav = Prefs.favs.contains(a.id);
    var step = 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(a.title),
        actions: [
          IconButton(
            icon: Icon(fav ? Icons.bookmark : Icons.bookmark_border, color: fav ? _green : null),
            onPressed: () {
              final f = Prefs.favs;
              fav ? f.remove(a.id) : f.add(a.id);
              Prefs.setList('favs', f).then((_) => setState(() {}));
            },
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
            children: [
              Text(a.icon, style: const TextStyle(fontSize: 44)),
              const SizedBox(height: 6),
              Text(a.summary, style: W.small),
              const SizedBox(height: 10),
              for (final b in a.blocks)
                switch (b.$1) {
                  'h' => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(b.$2, style: W.h2.copyWith(color: _green))),
                  'li' => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Padding(padding: EdgeInsets.only(top: 7, right: 10), child: Icon(Icons.circle, size: 6, color: _green)),
                        Expanded(child: Text(b.$2, style: W.body)),
                      ]),
                    ),
                  'n' => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 10, top: 1),
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                          child: Text('${++step}', style: const TextStyle(color: W.bg, fontWeight: FontWeight.w800, fontSize: 12)),
                        ),
                        Expanded(child: Text(b.$2, style: W.body)),
                      ]),
                    ),
                  'w' => Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: W.bad.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: W.bad.withValues(alpha: 0.5)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.warning_amber_rounded, color: W.bad),
                        const SizedBox(width: 10),
                        Expanded(child: Text(b.$2, style: W.body)),
                      ]),
                    ),
                  't' => Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _green.withValues(alpha: 0.4)),
                      ),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.lightbulb_outline, color: _green),
                        const SizedBox(width: 10),
                        Expanded(child: Text(b.$2, style: W.body)),
                      ]),
                    ),
                  _ => Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(b.$2, style: W.body)),
                },
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- Инструменты ----------------

class ToolsTab extends StatelessWidget {
  const ToolsTab({super.key});

  @override
  Widget build(BuildContext context) {
    void go(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    Widget tile(String icon, String title, String sub, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: WCard(
            onTap: onTap,
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: W.h2), Text(sub, style: W.small)])),
              const Icon(Icons.chevron_right, color: W.muted),
            ]),
          ),
        );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text('Инструменты', style: W.h1),
            const SizedBox(height: 12),
            if (Platform.isAndroid) tile('🧭', 'Компас', 'Стороны света и направление движения', () => go(const CompassScreen())),
            tile('🆘', 'Сигнал SOS', 'Вспышки фонарика и экрана азбукой Морзе', () => go(const SosScreen())),
            tile('🎒', 'Чек-лист снаряжения', 'Что взять с собой в лес', () => go(const KitScreen())),
            tile('📞', 'Экстренные номера', '112 и номера служб', () => go(const NumbersScreen())),
            tile('🌅', 'Сколько до заката', 'Чтобы успеть приготовить ночлег', () => go(const SunsetScreen())),
          ],
        ),
      ),
    );
  }
}

class CompassScreen extends StatelessWidget {
  const CompassScreen({super.key});

  static const _names = ['С', 'СВ', 'В', 'ЮВ', 'Ю', 'ЮЗ', 'З', 'СЗ'];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Компас')),
        body: StreamBuilder<CompassEvent>(
          stream: FlutterCompass.events,
          builder: (context, snap) {
            final h = snap.data?.heading;
            if (FlutterCompass.events == null || (snap.hasData && h == null)) {
              return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('В телефоне нет датчика компаса', style: W.body)));
            }
            if (h == null) return const Center(child: CircularProgressIndicator());
            final deg = (h + 360) % 360;
            return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${deg.round()}°  ${_names[((deg + 22.5) ~/ 45) % 8]}', style: W.h1.copyWith(fontSize: 34)),
              const SizedBox(height: 24),
              Transform.rotate(
                angle: -deg * math.pi / 180,
                child: SizedBox(width: 280, height: 280, child: CustomPaint(painter: _DialPainter())),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text('Держи телефон горизонтально, подальше от металла и магнитов. Если стрелка врёт — покрути телефон восьмёркой.',
                    textAlign: TextAlign.center, style: W.small),
              ),
            ]);
          },
        ),
      );
}

class _DialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2;
    canvas.drawCircle(c, r, Paint()..color = W.surface);
    canvas.drawCircle(c, r, Paint()
      ..color = W.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    final tick = Paint()..color = W.muted;
    for (var i = 0; i < 72; i++) {
      final a = i * 5 * math.pi / 180;
      final l = i % 18 == 0 ? 18.0 : (i % 6 == 0 ? 11.0 : 6.0);
      tick.strokeWidth = i % 6 == 0 ? 2 : 1;
      canvas.drawLine(c + Offset(math.sin(a), -math.cos(a)) * (r - 4), c + Offset(math.sin(a), -math.cos(a)) * (r - 4 - l), tick);
    }
    const labels = ['С', 'В', 'Ю', 'З'];
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2;
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: TextStyle(color: i == 0 ? W.bad : W.text, fontSize: 22, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = c + Offset(math.sin(a), -math.cos(a)) * (r - 40);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
    final north = Path()
      ..moveTo(c.dx, c.dy - r + 50)
      ..lineTo(c.dx - 12, c.dy)
      ..lineTo(c.dx + 12, c.dy)
      ..close();
    final south = Path()
      ..moveTo(c.dx, c.dy + r - 50)
      ..lineTo(c.dx - 12, c.dy)
      ..lineTo(c.dx + 12, c.dy)
      ..close();
    canvas.drawPath(north, Paint()..color = W.bad);
    canvas.drawPath(south, Paint()..color = W.text);
    canvas.drawCircle(c, 6, Paint()..color = W.bg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool running = false;
  bool lit = false;
  bool torch = Platform.isAndroid;
  int _gen = 0;

  // SOS: ··· ––– ··· (точка 1, тире 3, пауза между знаками 1, между буквами 3, между словами 7)
  static const _unit = Duration(milliseconds: 250);
  static const _pattern = [1, 1, 1, 0, 3, 3, 3, 0, 1, 1, 1];

  Future<void> _set(bool on) async {
    if (!mounted) return;
    setState(() => lit = on);
    if (torch) {
      try {
        on ? await TorchLight.enableTorch() : await TorchLight.disableTorch();
      } catch (_) {
        torch = false;
      }
    }
  }

  Future<void> _loop(int gen) async {
    while (running && gen == _gen && mounted) {
      for (final p in _pattern) {
        if (!running || gen != _gen) break;
        if (p == 0) {
          await Future<void>.delayed(_unit * 2); // + 1 после знака = 3
          continue;
        }
        await _set(true);
        await Future<void>.delayed(_unit * p);
        await _set(false);
        await Future<void>.delayed(_unit);
      }
      await Future<void>.delayed(_unit * 6);
    }
    await _set(false);
  }

  void _toggle() {
    running = !running;
    _gen++;
    if (running) {
      HapticFeedback.heavyImpact();
      _loop(_gen);
    }
    setState(() {});
  }

  @override
  void dispose() {
    running = false;
    _gen++;
    if (torch) TorchLight.disableTorch().catchError((_) {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: lit ? Colors.white : W.bg,
        appBar: lit ? null : AppBar(title: const Text('Сигнал SOS')),
        body: GestureDetector(
          onTap: _toggle,
          child: Container(
            color: lit ? Colors.white : W.bg,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: lit
                ? const SizedBox.expand()
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 180,
                      height: 180,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: running ? W.bad : W.surface2, border: Border.all(color: W.bad, width: 3)),
                      child: Text(running ? 'СТОП' : 'SOS', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: W.text)),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      running
                          ? 'Подаю сигнал ··· ––– ···\nНажми на экран, чтобы остановить.'
                          : torch
                              ? 'Фонарик и экран будут мигать азбукой Морзе: ··· ––– ···. Направляй свет на вертолёт, людей, в сторону дороги.'
                              : 'Экран будет мигать азбукой Морзе: ··· ––– ···. Сделай яркость максимальной.',
                      textAlign: TextAlign.center,
                      style: W.body,
                    ),
                  ]),
          ),
        ),
      );
}

class KitScreen extends StatefulWidget {
  const KitScreen({super.key});

  @override
  State<KitScreen> createState() => _KitScreenState();
}

class _KitScreenState extends State<KitScreen> {
  @override
  Widget build(BuildContext context) {
    final done = Prefs.kit;
    return Scaffold(
      appBar: AppBar(
        title: Text('Снаряжение ${done.length}/${kitItems.length}'),
        actions: [
          TextButton(onPressed: () => Prefs.setList('kit', {}).then((_) => setState(() {})), child: const Text('Сбросить')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 32),
        children: [
          for (final k in kitItems)
            CheckboxListTile(
              activeColor: _green,
              value: done.contains(k),
              title: Text(k, style: W.body),
              onChanged: (v) {
                v == true ? done.add(k) : done.remove(k);
                Prefs.setList('kit', done).then((_) => setState(() {}));
              },
            ),
        ],
      ),
    );
  }
}

class NumbersScreen extends StatelessWidget {
  const NumbersScreen({super.key});

  static const nums = [
    ('112', 'Единый номер экстренных служб', 'Европа, Украина, Польша, Россия, Казахстан и многие другие страны'),
    ('101', 'Пожарные / спасатели', 'Украина, Россия'),
    ('103', 'Скорая помощь', 'Украина, Россия'),
    ('102', 'Полиция', 'Украина, Россия'),
    ('999', 'Скорая помощь', 'Польша'),
    ('997', 'Полиция', 'Польша'),
    ('985', 'Горные и водные спасатели (GOPR/WOPR)', 'Польша'),
    ('911', 'Экстренные службы', 'США, Канада'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Экстренные номера')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            const Text('Если не знаешь, куда звонить, — звони 112. Говори спокойно: что случилось, где ты, сколько людей, есть ли раненые.', style: W.small),
            const SizedBox(height: 12),
            for (final n in nums)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WCard(
                  onTap: () => _call(context, n.$1),
                  child: Row(children: [
                    SizedBox(width: 64, child: Text(n.$1, style: W.h1.copyWith(color: n.$1 == '112' ? W.bad : _green))),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n.$2, style: W.body), Text(n.$3, style: W.small)])),
                    const Icon(Icons.call, color: W.muted),
                  ]),
                ),
              ),
          ],
        ),
      );
}

/// Примерное время заката по дате и широте (без интернета и GPS — широту выбирает пользователь).
class SunsetScreen extends StatefulWidget {
  const SunsetScreen({super.key});

  @override
  State<SunsetScreen> createState() => _SunsetScreenState();
}

class _SunsetScreenState extends State<SunsetScreen> {
  double lat = (Prefs.d['lat'] as num?)?.toDouble() ?? 52;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  /// Длина светового дня в часах (приближённая формула).
  double _dayLength(DateTime d, double lat) {
    final n = d.difference(DateTime(d.year, 1, 1)).inDays + 1;
    final decl = 23.44 * math.sin(2 * math.pi * (284 + n) / 365) * math.pi / 180;
    final phi = lat * math.pi / 180;
    final x = (-math.tan(phi) * math.tan(decl)).clamp(-1.0, 1.0);
    return 2 * math.acos(x) * 180 / math.pi / 15;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final len = _dayLength(now, lat);
    // Солнечный полдень ≈ 12:00 по поясному времени + поправка на летнее время (по смещению пояса).
    final noon = 12.0 + (now.timeZoneOffset.inMinutes % 60 == 0 && _isSummer(now) ? 1 : 0);
    final sunset = noon + len / 2;
    final sunsetTime = DateTime(now.year, now.month, now.day).add(Duration(minutes: (sunset * 60).round()));
    final left = sunsetTime.difference(now);
    String hm(Duration d) => '${d.inHours} ч ${d.inMinutes % 60} мин';
    return Scaffold(
      appBar: AppBar(title: const Text('Сколько до заката')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          WCard(
            child: Column(children: [
              Text('Закат примерно в ${sunsetTime.hour}:${sunsetTime.minute.toString().padLeft(2, '0')}', style: W.h1),
              const SizedBox(height: 6),
              Text(left.isNegative ? 'Солнце уже село' : 'Осталось ${hm(left)} светлого времени', style: W.h2.copyWith(color: left.inMinutes < 90 ? W.warn : _green)),
              const SizedBox(height: 6),
              Text('Световой день: ${len.toStringAsFixed(1)} ч', style: W.small),
            ]),
          ),
          const Section('Твоя широта'),
          Slider(
            value: lat,
            min: 35,
            max: 70,
            divisions: 35,
            label: '${lat.round()}°',
            onChanged: (v) {
              setState(() => lat = v);
              Prefs.d['lat'] = v;
              Prefs.save();
            },
          ),
          Text('${lat.round()}° с. ш. — Киев ≈ 50°, Варшава ≈ 52°, Москва ≈ 56°, Санкт-Петербург ≈ 60°', style: W.small),
          const SizedBox(height: 16),
          const Text('Расчёт примерный (±20–30 минут). Начинай готовить ночлег за 1–2 часа до заката: в лесу темнеет раньше, чем в поле.', style: W.small),
        ],
      ),
    );
  }

  bool _isSummer(DateTime d) {
    // Летнее время в Европе: с последнего воскресенья марта по последнее воскресенье октября.
    final jan = DateTime(d.year, 1, 15).timeZoneOffset;
    return d.timeZoneOffset > jan;
  }
}

// ---------------- Проверь себя ----------------

class QuizTab extends StatefulWidget {
  const QuizTab({super.key});

  @override
  State<QuizTab> createState() => _QuizTabState();
}

class _QuizTabState extends State<QuizTab> {
  int i = 0, score = 0;
  int? picked;

  @override
  Widget build(BuildContext context) {
    final done = i >= quiz.length;
    final best = (Prefs.d['quizBest'] as num?)?.toInt() ?? 0;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text('Проверь себя', style: W.h1),
            Text('Рекорд: $best из ${quiz.length}', style: W.small),
            const SizedBox(height: 16),
            if (done) ...[
              WCard(
                child: Column(children: [
                  Text('$score из ${quiz.length}', style: W.h1.copyWith(fontSize: 40, color: _green)),
                  const SizedBox(height: 8),
                  Text(score == quiz.length ? 'Отлично! Ты готов к лесу.' : 'Перечитай разделы, где ошибся, и попробуй ещё раз.', style: W.body, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => setState(() {
                      i = 0;
                      score = 0;
                      picked = null;
                    }),
                    child: const Text('Пройти ещё раз'),
                  ),
                ]),
              ),
            ] else ...[
              Text('Вопрос ${i + 1} из ${quiz.length}', style: W.small),
              const SizedBox(height: 6),
              Text(quiz[i].$1, style: W.h2),
              const SizedBox(height: 12),
              for (var k = 0; k < quiz[i].$2.length; k++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: WCard(
                    borderColor: picked == null
                        ? null
                        : k == quiz[i].$3
                            ? _green
                            : (k == picked ? W.bad : null),
                    onTap: picked != null
                        ? null
                        : () => setState(() {
                              picked = k;
                              if (k == quiz[i].$3) score++;
                            }),
                    child: Text(quiz[i].$2[k], style: W.body),
                  ),
                ),
              if (picked != null) ...[
                const SizedBox(height: 6),
                Text(quiz[i].$4, style: W.body.copyWith(color: picked == quiz[i].$3 ? _green : W.warn)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => setState(() {
                    i++;
                    picked = null;
                    if (i >= quiz.length && score > best) {
                      Prefs.d['quizBest'] = score;
                      Prefs.save();
                    }
                  }),
                  child: Text(i + 1 >= quiz.length ? 'Результат' : 'Дальше'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
