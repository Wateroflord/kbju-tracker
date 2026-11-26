import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../store.dart';
import '../theme.dart';
import 'host.dart';
import 'registry.dart';

/// Супер-приложение: открытый плагин + шторка сверху для переключения между плагинами.
///
/// У каждого плагина свой MaterialApp (своя тема и экраны). Открыт всегда один плагин:
/// при переключении предыдущий закрывается, его данные уже сохранены на диск.
class WinterShell extends StatefulWidget {
  const WinterShell({super.key});

  /// Открыть плагин из любого места (например, из вкладки «Учёба» КБЖУ).
  static Future<void> open(BuildContext context, String id) => _ShellBodyState._current?._switch(id) ?? PluginHost.I.open(id);

  /// То же без контекста (кнопки виджета на главном экране телефона).
  static Future<void> switchTo(String id) =>
      PluginHost.I.active == id ? Future.value() : (_ShellBodyState._current?._switch(id) ?? PluginHost.I.open(id));

  @override
  State<WinterShell> createState() => _WinterShellState();
}

class _WinterShellState extends State<WinterShell> {
  final _nav = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'КБЖУ Трекер',
        debugShowCheckedModeBanner: false,
        navigatorKey: _nav,
        theme: _shellTheme(),
        home: _ShellBody(nav: _nav),
      );
}

ThemeData _shellTheme() => ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        onSurface: AppColors.text,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.muted),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.accent : AppColors.surface2),
      ),
    );

class _ShellBody extends StatefulWidget {
  final GlobalKey<NavigatorState> nav;
  const _ShellBody({required this.nav});

  @override
  State<_ShellBody> createState() => _ShellBodyState();
}

class _ShellBodyState extends State<_ShellBody> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static _ShellBodyState? _current;

  final host = PluginHost.I;
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  bool _welcomeShown = false;
  AppStore? _store;

  bool get _open => _anim.value > 0;

  @override
  void initState() {
    super.initState();
    _current = this;
    host.addListener(_rebuild);
    _moveBackHandlerToEnd();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWelcome());
  }

  /// «Назад» на главном экране плагина возвращает в КБЖУ, а не закрывает приложение.
  /// Обработчики «Назад» вызываются по порядку подписки, поэтому наш должен стоять
  /// после MaterialApp плагина — переподписываемся после каждого переключения.
  void _moveBackHandlerToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.removeObserver(this);
      WidgetsBinding.instance.addObserver(this);
    });
  }

  @override
  Future<bool> didPopRoute() async {
    if (_open) {
      _hideDrawer();
      return true;
    }
    if (host.active != 'kbju') {
      await _switch('kbju');
      return true;
    }
    return false;
  }

  void _scheduleWelcome() => WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWelcome());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = StoreScope.read(context);
    if (!identical(s, _store)) {
      _store?.removeListener(_scheduleWelcome);
      _store = s..addListener(_scheduleWelcome);
    }
  }

  @override
  void dispose() {
    if (_current == this) _current = null;
    WidgetsBinding.instance.removeObserver(this);
    host.removeListener(_rebuild);
    _store?.removeListener(_scheduleWelcome);
    _anim.dispose();
    super.dispose();
  }

  String _shown = '';

  void _rebuild() {
    if (!mounted) return;
    setState(() {});
    if (host.active != _shown) {
      _shown = host.active;
      _moveBackHandlerToEnd();
    }
  }

  void _showDrawer() {
    FocusManager.instance.primaryFocus?.unfocus();
    _anim.forward();
  }

  void _hideDrawer() => _anim.reverse();

  Future<void> _switch(String id) async {
    _hideDrawer();
    if (id == host.active && host.isOn(id)) return;
    // КБЖУ сохраняет данные с задержкой — сохранить сразу, перед тем как его закрыть.
    await _store?.flush();
    await host.open(id);
    if (host.active != id && mounted) {
      final m = ScaffoldMessenger.maybeOf(context);
      m?.showSnackBar(SnackBar(content: Text(trf('Плагин не запустился: {0}', [host.error ?? '']))));
    }
  }

  /// Один раз после обновления: спросить, какие плагины включить.
  Future<void> _maybeWelcome() async {
    if (_welcomeShown || host.asked || !mounted) return;
    if (_store?.profile == null) return; // сначала — первая настройка КБЖУ
    final ctx = widget.nav.currentContext;
    if (ctx == null) return;
    _welcomeShown = true;
    final picked = await showDialog<Set<String>>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => const _WelcomeDialog(),
    );
    await host.finishWelcome(picked ?? const {});
    if ((picked ?? const {}).isNotEmpty) _showDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final plugin = pluginById(host.active) ?? winterPlugins.first;
    final top = MediaQuery.paddingOf(context).top;
    // Сам плагин строится только при смене плагина, а не на каждом кадре анимации шторки.
    final pluginView = KeyedSubtree(key: ValueKey('plugin_${plugin.id}'), child: plugin.build());
    return AnimatedBuilder(
      animation: _anim,
      child: pluginView,
      builder: (context, pluginChild) => PopScope(
        canPop: !_open,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _open) _hideDrawer();
        },
        child: Scaffold(
          backgroundColor: AppColors.bg,
          resizeToAvoidBottomInset: false,
          body: Stack(children: [
            // Открытый плагин (его собственное приложение).
            Positioned.fill(
              child: pluginChild!,
            ),
            if (host.preparing != null)
              const Positioned.fill(
                child: ColoredBox(color: Color(0xAA000000), child: Center(child: CircularProgressIndicator())),
              ),
            // Ручка шторки.
            if (!_open)
              Positioned(
                top: top,
                left: 0,
                right: 0,
                child: Center(child: _Handle(onOpen: _showDrawer)),
              ),
            // Затемнение и сама шторка.
            if (_open) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: _hideDrawer,
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.55 * _anim.value)),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FractionalTranslation(
                  translation: Offset(0, Curves.easeOutCubic.transform(_anim.value) - 1),
                  child: _Drawer(
                    host: host,
                    onPick: _switch,
                    onClose: _hideDrawer,
                    onManage: () {
                      _hideDrawer();
                      widget.nav.currentState?.push(MaterialPageRoute(builder: (_) => const PluginsScreen()));
                    },
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Полоска вверху экрана: нажми или потяни вниз — откроется шторка.
class _Handle extends StatelessWidget {
  final VoidCallback onOpen;
  const _Handle({required this.onOpen});

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: tr('Плагины'),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          onVerticalDragUpdate: (d) {
            if (d.delta.dy > 3) onOpen();
          },
          child: SizedBox(
            width: 72,
            height: 18,
            child: Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 4)],
                ),
              ),
            ),
          ),
        ),
      );
}

class _Drawer extends StatelessWidget {
  final PluginHost host;
  final void Function(String id) onPick;
  final VoidCallback onClose;
  final VoidCallback onManage;
  const _Drawer({required this.host, required this.onPick, required this.onClose, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final list = host.visible;
    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (d.delta.dy < -4) onClose();
      },
      child: Material(
        color: AppColors.surface,
        elevation: 12,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(tr('Плагины'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                  const Spacer(),
                  IconButton(
                    tooltip: tr('Включить и выключить'),
                    onPressed: onManage,
                    icon: const Icon(Icons.tune, color: AppColors.text),
                  ),
                  IconButton(
                    tooltip: tr('Закрыть'),
                    onPressed: onClose,
                    icon: const Icon(Icons.keyboard_arrow_up, color: AppColors.text),
                  ),
                ]),
                const SizedBox(height: 6),
                LayoutBuilder(builder: (context, c) {
                  final cols = (c.maxWidth / 92).floor().clamp(3, 8);
                  final w = c.maxWidth / cols;
                  return Wrap(children: [
                    for (final p in list)
                      SizedBox(width: w, child: _Tile(plugin: p, active: p.id == host.active, onTap: () => onPick(p.id))),
                  ]);
                }),
                if (list.length == 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      tr('Других плагинов пока нет. Нажми ⚙ справа вверху, чтобы включить шахматы, сапёр, музыку и другие.'),
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(3)),
                  ),
                ),
                const SizedBox(height: 4),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final WinterPlugin plugin;
  final bool active;
  final VoidCallback onTap;
  const _Tile({required this.plugin, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: active ? plugin.color : Colors.transparent, width: 2),
              ),
              child: PluginIcon(plugin: plugin, size: 52),
            ),
            const SizedBox(height: 6),
            Text(
              tr(plugin.name),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.15,
                color: active ? AppColors.text : AppColors.muted,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ]),
        ),
      );
}

class PluginIcon extends StatelessWidget {
  final WinterPlugin plugin;
  final double size;
  const PluginIcon({super.key, required this.plugin, this.size = 44});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.26),
        child: Image.asset(
          plugin.icon,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            color: plugin.color.withValues(alpha: 0.25),
            alignment: Alignment.center,
            child: Text(plugin.name.characters.first,
                style: TextStyle(color: plugin.color, fontSize: size * 0.45, fontWeight: FontWeight.w800)),
          ),
        ),
      );
}

/// Включение и выключение плагинов.
class PluginsScreen extends StatelessWidget {
  const PluginsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final host = PluginHost.I;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Плагины')), backgroundColor: AppColors.bg),
      body: ListenableBuilder(
        listenable: host,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text(
                tr('Включённые плагины появляются в шторке сверху (полоска вверху экрана). '
                    'Выключенный плагин просто скрывается — его данные сохраняются.'),
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
            for (final p in winterPlugins)
              Card(
                color: AppColors.surface,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: PluginIcon(plugin: p),
                  title: Text(tr(p.name), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(tr(p.tagline), style: const TextStyle(color: AppColors.muted)),
                  trailing: p.core
                      ? Text(tr('Основа'), style: const TextStyle(color: AppColors.muted))
                      : Switch(value: host.isOn(p.id), onChanged: (v) => host.setEnabled(p.id, v)),
                  onTap: p.core ? null : () => host.setEnabled(p.id, !host.isOn(p.id)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Первый запуск после обновления: какие плагины включить.
class _WelcomeDialog extends StatefulWidget {
  const _WelcomeDialog();

  @override
  State<_WelcomeDialog> createState() => _WelcomeDialogState();
}

class _WelcomeDialogState extends State<_WelcomeDialog> {
  final Set<String> picked = {};

  @override
  Widget build(BuildContext context) {
    final list = winterPlugins.where((p) => !p.core).toList();
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(tr('Новое: плагины'), style: const TextStyle(fontWeight: FontWeight.w800)),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              tr('Теперь в КБЖУ есть другие приложения Winter. Отметь, какие нужны — '
                  'переключаться между ними можно шторкой сверху (потяни полоску вверху экрана). '
                  'Потом это можно поменять в шторке → ⚙.'),
              style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 8),
            for (final p in list)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: picked.contains(p.id),
                onChanged: (v) => setState(() => v == true ? picked.add(p.id) : picked.remove(p.id)),
                secondary: PluginIcon(plugin: p, size: 36),
                title: Text(tr(p.name)),
                subtitle: Text(tr(p.tagline), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => setState(() => picked.length == list.length ? picked.clear() : picked.addAll(list.map((p) => p.id))),
          child: Text(picked.length == list.length ? tr('Снять все') : tr('Выбрать все')),
        ),
        FilledButton(onPressed: () => Navigator.pop(context, picked), child: Text(tr('Готово'))),
      ],
    );
  }
}
