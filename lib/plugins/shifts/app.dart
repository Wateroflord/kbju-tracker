import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../common/backup_io.dart';
import '../common/notify.dart';
import '../common/ui.dart';
import 'models.dart';

const _accent = Color(0xFF6EE7B7);
const _months = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
const _wd = ['пн', 'вт', 'ср', 'чт', 'пт', 'сб', 'вс'];

class ShiftsApp extends StatelessWidget {
  const ShiftsApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Смены и зарплата',
        debugShowCheckedModeBanner: false,
        theme: winterTheme(_accent),
        home: const ShiftsHome(),
      );
}

/// Хранилище: смены, ставка, вычеты, напоминания, шаблоны.
class ShiftStore extends ChangeNotifier {
  static final I = ShiftStore._();
  ShiftStore._();

  final _file = JsonStore('shifts.json');
  bool loaded = false;
  List<Shift> shifts = [];
  List<ShiftTemplate> templates = [];
  double rate = 0, deduction = 0;
  String currency = 'zł';
  bool remind = false;
  int remindMin = 60;

  Future<void> load() async {
    if (loaded) return;
    fromJson(await _file.read());
    loaded = true;
  }

  void fromJson(Map<String, dynamic> j) {
    shifts = (j['shifts'] as List? ?? []).map(Shift.fromJson).whereType<Shift>().toList();
    templates = (j['templates'] as List? ?? []).map(ShiftTemplate.fromJson).whereType<ShiftTemplate>().toList();
    if (j['templates'] == null) {
      templates = const [ShiftTemplate('Утро', 6 * 60, 14 * 60), ShiftTemplate('Вечер', 14 * 60, 22 * 60)];
    }
    rate = (j['rate'] as num?)?.toDouble() ?? 0;
    deduction = (j['deduction'] as num?)?.toDouble() ?? 0;
    currency = j['currency']?.toString() ?? 'zł';
    remind = j['remind'] == true;
    remindMin = (j['remindMin'] as num?)?.toInt() ?? 60;
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'shifts': [for (final s in shifts) s.toJson()],
        'templates': [for (final t in templates) t.toJson()],
        'rate': rate,
        'deduction': deduction,
        'currency': currency,
        'remind': remind,
        'remindMin': remindMin,
      };

  Future<void> save({bool reschedule = true}) async {
    shifts.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    notifyListeners();
    await _file.write(toJson());
    if (reschedule) await this.reschedule();
  }

  static const _notifyFrom = 200000, _notifyTo = 300000;

  /// Напоминания перед ближайшими сменами (до 60 штук вперёд).
  Future<void> reschedule() async {
    await PluginNotify.cancelRange(_notifyFrom, _notifyTo);
    if (!remind) return;
    final now = DateTime.now();
    final upcoming = shifts.where((s) => s.startsAt.subtract(Duration(minutes: remindMin)).isAfter(now)).take(60).toList();
    for (var i = 0; i < upcoming.length; i++) {
      final s = upcoming[i];
      await PluginNotify.schedule(
        _notifyFrom + i,
        remindMin >= 60 && remindMin % 60 == 0 ? 'Смена через ${remindMin ~/ 60} ч' : 'Смена через $remindMin мин',
        '${hm(s.start)}–${hm(s.end)}${s.note.isEmpty ? '' : ' · ${s.note}'}',
        s.startsAt.subtract(Duration(minutes: remindMin)),
        channel: 'shifts',
        channelName: 'Смены',
      );
    }
  }

  String id() => '${DateTime.now().microsecondsSinceEpoch}';
}

String _money(double v) => '${money(v)} ${ShiftStore.I.currency}';

class ShiftsHome extends StatefulWidget {
  const ShiftsHome({super.key});

  @override
  State<ShiftsHome> createState() => _ShiftsHomeState();
}

class _ShiftsHomeState extends State<ShiftsHome> {
  final st = ShiftStore.I;
  late DateTime month;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    month = DateTime(n.year, n.month);
    st.addListener(_changed);
    st.load().then((_) {
      if (mounted) setState(() {});
      st.reschedule();
    });
  }

  @override
  void dispose() {
    st.removeListener(_changed);
    super.dispose();
  }

  void _changed() => mounted ? setState(() {}) : null;

  Future<void> _edit({Shift? shift, DateTime? day}) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ShiftEditor(shift: shift, day: day ?? _defaultDay())),
      );

  DateTime _defaultDay() {
    final n = DateTime.now();
    return (n.year == month.year && n.month == month.month) ? DateTime(n.year, n.month, n.day) : month;
  }

  @override
  Widget build(BuildContext context) {
    if (!st.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final sum = summarize(st.shifts, month.year, month.month, st.rate, st.deduction);
    final inMonth = st.shifts.where((s) {
      final d = parseDay(s.day);
      return d.year == month.year && d.month == month.month;
    }).toList();
    final now = DateTime.now();
    final next = nextShift(st.shifts, now);
    final prevSum = summarize(st.shifts, month.month == 1 ? month.year - 1 : month.year, month.month == 1 ? 12 : month.month - 1, st.rate, st.deduction);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Смены и зарплата'),
        actions: [
          IconButton(
            tooltip: 'Настройки',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShiftSettings())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Смена'),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 96), children: [
        if (st.rate <= 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: WCard(
              borderColor: W.warn,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ShiftSettings())),
              child: const Row(children: [
                Icon(Icons.info_outline, color: W.warn),
                SizedBox(width: 10),
                Expanded(child: Text('Укажи ставку за час — тогда посчитаю заработок. Нажми сюда.', style: W.body)),
              ]),
            ),
          ),
        if (next != null)
          WCard(
            borderColor: W.accent.withValues(alpha: 0.6),
            onTap: () => _edit(shift: next),
            child: Row(children: [
              Icon(Icons.work_outline, color: W.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Следующая смена — ${untilText(next.startsAt, now, endsAt: next.endsAt)}', style: W.h2),
                  const SizedBox(height: 2),
                  Text(
                    '${_dayTitle(parseDay(next.day))}, ${hm(next.start)}–${hm(next.end)} · ${hoursText(next.minutes)}'
                    '${st.rate > 0 || next.rate != null ? ' · ${_money(next.pay(st.rate))}' : ''}',
                    style: W.small,
                  ),
                ]),
              ),
            ]),
          ),
        const SizedBox(height: 8),
        Row(children: [
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text('${_months[month.month - 1]} ${month.year}', style: W.h2, textAlign: TextAlign.center)),
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
        ]),
        WCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _stat('Смен', '${sum.shifts}'),
              _stat('Часов', _hoursShort(sum.minutes)),
              _stat('Брутто', money(sum.brutto)),
            ]),
            if (st.deduction > 0) ...[
              const Divider(height: 22, color: W.border),
              Row(children: [
                const Expanded(child: Text('На руки ≈', style: W.body)),
                Text(_money(sum.netto), style: W.h2.copyWith(color: W.accent)),
              ]),
              Text('Вычеты ${_pct(st.deduction)}% — как ты указал в настройках', style: W.small),
            ],
            if (prevSum.shifts > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Прошлый месяц: ${_hoursShort(prevSum.minutes)} ч · ${_money(st.deduction > 0 ? prevSum.netto : prevSum.brutto)}',
                style: W.small,
              ),
            ],
          ]),
        ),
        const SizedBox(height: 10),
        _MonthGrid(month: month, shifts: inMonth, onDay: (d) {
          final s = inMonth.where((x) => x.day == dayKey(d)).toList();
          s.isEmpty ? _edit(day: d) : _edit(shift: s.first);
        }),
        if (inMonth.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: Text('В этом месяце смен нет.\nНажми на день или «+ Смена».', style: W.small, textAlign: TextAlign.center)),
          )
        else ...[
          const Section('Смены'),
          for (final s in inMonth)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey(s.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(color: W.bad.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.delete_outline, color: W.bad),
                ),
                onDismissed: (_) {
                  st.shifts.removeWhere((x) => x.id == s.id);
                  st.save();
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(
                      content: const Text('Смена удалена'),
                      action: SnackBarAction(label: 'Вернуть', onPressed: () {
                        st.shifts.add(s);
                        st.save();
                      }),
                    ));
                },
                child: WCard(
                  onTap: () => _edit(shift: s),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    SizedBox(
                      width: 44,
                      child: Column(children: [
                        Text('${parseDay(s.day).day}', style: W.h2),
                        Text(_wd[parseDay(s.day).weekday - 1], style: W.small),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${hm(s.start)}–${hm(s.end)}', style: W.body),
                        Text(
                          [
                            hoursText(s.minutes),
                            if (s.breakMin > 0) 'перерыв ${s.breakMin} мин',
                            if (s.rate != null) 'ставка ${money(s.rate!)}',
                            if (s.note.isNotEmpty) s.note,
                          ].join(' · '),
                          style: W.small,
                        ),
                      ]),
                    ),
                    if (st.rate > 0 || s.rate != null) Text(money(s.pay(st.rate)), style: W.body.copyWith(color: W.accent)),
                  ]),
                ),
              ),
            ),
        ],
      ]),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Column(children: [
          Text(value, style: W.h2.copyWith(fontSize: 19)),
          const SizedBox(height: 2),
          Text(label, style: W.small),
        ]),
      );
}

String _hoursShort(int minutes) {
  final h = minutes / 60;
  return h == h.roundToDouble() ? h.toStringAsFixed(0) : h.toStringAsFixed(1).replaceAll('.', ',');
}

String _pct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');

String _dayTitle(DateTime d) {
  final n = DateTime.now();
  final t = DateTime(n.year, n.month, n.day);
  final diff = DateTime.utc(d.year, d.month, d.day).difference(DateTime.utc(t.year, t.month, t.day)).inDays;
  if (diff == 0) return 'сегодня';
  if (diff == 1) return 'завтра';
  return '${_wd[d.weekday - 1]}, ${d.day}.${d.month.toString().padLeft(2, '0')}';
}

/// Календарь месяца: дни со сменами подсвечены.
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final List<Shift> shifts;
  final void Function(DateTime day) onDay;
  final Set<String>? selected;
  const _MonthGrid({required this.month, required this.shifts, required this.onDay, this.selected});

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    final busy = {for (final s in shifts) s.day};
    final n = DateTime.now();
    final todayKey = dayKey(DateTime(n.year, n.month, n.day));
    return Column(children: [
      Row(children: [for (final w in _wd) Expanded(child: Center(child: Text(w, style: W.small)))]),
      const SizedBox(height: 4),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: [
          for (var i = 0; i < offset; i++) const SizedBox(),
          for (var d = 1; d <= days; d++)
            Builder(builder: (_) {
              final date = DateTime(month.year, month.month, d);
              final k = dayKey(date);
              final isSel = selected?.contains(k) ?? false;
              final has = busy.contains(k);
              return Material(
                color: isSel ? W.accent : (has ? W.accent.withValues(alpha: 0.2) : W.surface),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onDay(date),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: k == todayKey ? W.text : W.border),
                    ),
                    child: Text('$d', style: W.body.copyWith(color: isSel ? W.bg : W.text, fontWeight: has || isSel ? FontWeight.w700 : null)),
                  ),
                ),
              );
            }),
        ],
      ),
    ]);
  }
}

// ───────────────────────────── Добавление / изменение смены ─────────────────────────────

class ShiftEditor extends StatefulWidget {
  final Shift? shift;
  final DateTime day;
  const ShiftEditor({super.key, this.shift, required this.day});

  @override
  State<ShiftEditor> createState() => _ShiftEditorState();
}

class _ShiftEditorState extends State<ShiftEditor> {
  final st = ShiftStore.I;
  late int start, end, breakMin;
  late DateTime month;
  final Set<String> days = {};
  bool ownRate = false;
  final rateCtl = TextEditingController();
  final noteCtl = TextEditingController();

  bool get isNew => widget.shift == null;

  @override
  void initState() {
    super.initState();
    final s = widget.shift;
    final t = st.templates.isNotEmpty ? st.templates.first : const ShiftTemplate('', 8 * 60, 16 * 60);
    start = s?.start ?? t.start;
    end = s?.end ?? t.end;
    breakMin = s?.breakMin ?? t.breakMin;
    days.add(s?.day ?? dayKey(widget.day));
    final d = parseDay(days.first);
    month = DateTime(d.year, d.month);
    ownRate = s?.rate != null;
    rateCtl.text = s?.rate != null ? _num(s!.rate!) : '';
    noteCtl.text = s?.note ?? '';
  }

  @override
  void dispose() {
    rateCtl.dispose();
    noteCtl.dispose();
    super.dispose();
  }

  Future<void> _time(bool isStart) async {
    final v = isStart ? start : end;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: (v ~/ 60) % 24, minute: v % 60),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    setState(() => isStart ? start = t.hour * 60 + t.minute : end = t.hour * 60 + t.minute);
  }

  Shift _draft(String day, String id) => Shift(
        id: id,
        day: day,
        start: start,
        end: end,
        breakMin: breakMin,
        rate: ownRate ? double.tryParse(rateCtl.text.replaceAll(',', '.')) : null,
        note: noteCtl.text.trim(),
      );

  Future<void> _save() async {
    if (days.isEmpty) {
      toast(context, 'Выбери хотя бы один день');
      return;
    }
    if (start == end) {
      toast(context, 'Начало и конец совпадают');
      return;
    }
    if (isNew) {
      for (final d in days) {
        st.shifts.add(_draft(d, '${st.id()}-$d'));
      }
    } else {
      final i = st.shifts.indexWhere((x) => x.id == widget.shift!.id);
      final s = _draft(days.first, widget.shift!.id);
      if (i >= 0) {
        st.shifts[i] = s;
      } else {
        st.shifts.add(s);
      }
    }
    if (st.remind) await PluginNotify.requestPermission();
    await st.save();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirmDialog(context, 'Удалить смену?', 'Смена ${widget.shift!.day} пропадёт из подсчёта.', ok: 'Удалить')) return;
    st.shifts.removeWhere((x) => x.id == widget.shift!.id);
    await st.save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final preview = _draft(days.isEmpty ? dayKey(widget.day) : days.first, 'p');
    final pay = preview.pay(st.rate);
    return Scaffold(
      appBar: AppBar(
        title: Text(isNew ? 'Новая смена' : 'Смена'),
        actions: [if (!isNew) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline))],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
        if (st.templates.isNotEmpty) ...[
          const Text('Быстро', style: W.small),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in st.templates)
              Chip2(t.label, selected: t.start == start && t.end == end && t.breakMin == breakMin, onTap: () {
                setState(() {
                  start = t.start;
                  end = t.end;
                  breakMin = t.breakMin;
                });
              }),
          ]),
          const SizedBox(height: 14),
        ],
        Row(children: [
          Expanded(child: _timeBox('Начало', start, () => _time(true))),
          const SizedBox(width: 10),
          Expanded(child: _timeBox('Конец', end, () => _time(false))),
        ]),
        if (end <= start)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Смена через полночь — конец на следующий день.', style: W.small),
          ),
        const SizedBox(height: 14),
        const Text('Неоплачиваемый перерыв', style: W.small),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final b in [0, 15, 30, 45, 60]) Chip2(b == 0 ? 'нет' : '$b мин', selected: breakMin == b, onTap: () => setState(() => breakMin = b)),
        ]),
        const SizedBox(height: 14),
        WCard(
          child: Row(children: [
            Expanded(child: Text('${hoursText(preview.minutes)} оплачиваемых', style: W.body)),
            if (st.rate > 0 || preview.rate != null) Text(_money(pay), style: W.h2.copyWith(color: W.accent)),
          ]),
        ),
        const SizedBox(height: 16),
        Text(isNew ? 'Дни (можно выбрать несколько — весь график сразу)' : 'День', style: W.small),
        const SizedBox(height: 6),
        Row(children: [
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text('${_months[month.month - 1]} ${month.year}', style: W.body, textAlign: TextAlign.center)),
          IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
        ]),
        _MonthGrid(
          month: month,
          shifts: st.shifts.where((s) => s.id != widget.shift?.id).toList(),
          selected: days,
          onDay: (d) {
            HapticFeedback.selectionClick();
            final k = dayKey(d);
            setState(() {
              if (!isNew) {
                days
                  ..clear()
                  ..add(k);
              } else if (!days.remove(k)) {
                days.add(k);
              }
            });
          },
        ),
        if (isNew && days.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Выбрано дней: ${days.length}', style: W.small),
          ),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: ownRate,
          onChanged: (v) => setState(() => ownRate = v),
          title: const Text('Другая ставка за эту смену', style: W.body),
          subtitle: const Text('Например, праздник или подмена', style: W.small),
        ),
        if (ownRate)
          TextField(
            controller: rateCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Ставка за час, ${st.currency}', border: const OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: noteCtl,
          decoration: const InputDecoration(labelText: 'Заметка (магазин, касса…)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: _save,
            child: Text(isNew && days.length > 1 ? 'Добавить ${days.length} смен' : 'Сохранить'),
          ),
        ),
      ]),
    );
  }

  Widget _timeBox(String label, int v, VoidCallback onTap) => WCard(
        onTap: onTap,
        child: Column(children: [
          Text(label, style: W.small),
          const SizedBox(height: 4),
          Text(hm(v), style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: W.text)),
        ]),
      );
}

String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');

// ───────────────────────────── Настройки ─────────────────────────────

class ShiftSettings extends StatefulWidget {
  const ShiftSettings({super.key});

  @override
  State<ShiftSettings> createState() => _ShiftSettingsState();
}

class _ShiftSettingsState extends State<ShiftSettings> {
  final st = ShiftStore.I;
  late final rateCtl = TextEditingController(text: st.rate > 0 ? _num(st.rate) : '');
  late final dedCtl = TextEditingController(text: st.deduction > 0 ? _num(st.deduction) : '');
  late final curCtl = TextEditingController(text: st.currency);

  @override
  void dispose() {
    rateCtl.dispose();
    dedCtl.dispose();
    curCtl.dispose();
    super.dispose();
  }

  void _apply() {
    st.rate = (double.tryParse(rateCtl.text.replaceAll(',', '.').trim()) ?? 0).clamp(0, 100000).toDouble();
    st.deduction = (double.tryParse(dedCtl.text.replaceAll(',', '.').trim()) ?? 0).clamp(0, 100).toDouble();
    st.currency = curCtl.text.trim().isEmpty ? 'zł' : curCtl.text.trim();
    st.save(reschedule: false);
  }

  Future<void> _addTemplate() async {
    var s = 6 * 60, e = 14 * 60, b = 0;
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          Future<void> pick(bool isStart) async {
            final v = isStart ? s : e;
            final t = await showTimePicker(
              context: c,
              initialTime: TimeOfDay(hour: v ~/ 60 % 24, minute: v % 60),
              builder: (c2, child) => MediaQuery(data: MediaQuery.of(c2).copyWith(alwaysUse24HourFormat: true), child: child!),
            );
            if (t != null) set(() => isStart ? s = t.hour * 60 + t.minute : e = t.hour * 60 + t.minute);
          }

          return AlertDialog(
            title: const Text('Шаблон смены'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Название (Утро, Ночь…)')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => pick(true), child: Text('с ${hm(s)}'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton(onPressed: () => pick(false), child: Text('до ${hm(e)}'))),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final x in [0, 15, 30, 60]) Chip2(x == 0 ? 'без перерыва' : '$x мин', selected: b == x, onTap: () => set(() => b = x)),
              ]),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Добавить')),
            ],
          );
        },
      ),
    );
    if (ok == true) {
      setState(() => st.templates = [...st.templates, ShiftTemplate(name.text.trim(), s, e, b)]);
      st.save(reschedule: false);
    }
  }

  Future<void> _exportCsv() async {
    final b = StringBuffer('Дата;Начало;Конец;Перерыв, мин;Часы;Ставка;Сумма;Заметка\n');
    for (final s in st.shifts) {
      b.writeln([
        s.day,
        hm(s.start),
        hm(s.end),
        s.breakMin,
        (s.minutes / 60).toStringAsFixed(2).replaceAll('.', ','),
        (s.rate ?? st.rate).toStringAsFixed(2).replaceAll('.', ','),
        s.pay(st.rate).toStringAsFixed(2).replaceAll('.', ','),
        s.note.replaceAll(';', ','),
      ].join(';'));
    }
    // BOM — чтобы Excel открыл кириллицу правильно.
    final path = await BackupIO.save('smeny.csv', '﻿$b');
    if (path != null && mounted) toast(context, 'Сохранено: $path');
  }

  Future<void> _backup() async {
    final path = await BackupIO.save('winter_smeny_backup.json', jsonEncode(st.toJson()));
    if (path != null && mounted) toast(context, 'Копия сохранена');
  }

  Future<void> _restore() async {
    final text = await BackupIO.open();
    if (text == null) return;
    try {
      final j = jsonDecode(text);
      if (j is! Map<String, dynamic> || j['shifts'] is! List) throw const FormatException();
      if (!mounted) return;
      if (!await confirmDialog(context, 'Восстановить?', 'Текущие смены заменятся сменами из файла (${(j['shifts'] as List).length} шт.).', ok: 'Восстановить')) {
        return;
      }
      st.fromJson(j);
      await st.save();
      if (!mounted) return;
      rateCtl.text = st.rate > 0 ? _num(st.rate) : '';
      dedCtl.text = st.deduction > 0 ? _num(st.deduction) : '';
      curCtl.text = st.currency;
      setState(() {});
      toast(context, 'Восстановлено');
    } catch (_) {
      if (mounted) toast(context, 'Это не копия «Смен»');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Настройки')),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          const Section('Деньги'),
          Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: rateCtl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Ставка за час (брутто)', border: OutlineInputBorder()),
                onChanged: (_) => _apply(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: curCtl,
                decoration: const InputDecoration(labelText: 'Валюта', border: OutlineInputBorder()),
                onChanged: (_) => _apply(),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: dedCtl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Вычеты, % (необязательно)', border: OutlineInputBorder(), suffixText: '%'),
            onChanged: (_) => _apply(),
          ),
          const SizedBox(height: 6),
          const Text(
            'Налоги и взносы у всех разные (возраст, учёба, вид договора), поэтому приложение их не угадывает. '
            'Посмотри в расчётном листе (pasek): сколько процентов от брутто ушло — и впиши сюда. '
            'Тогда будет видно «на руки». Оставь пустым — покажу только брутто.',
            style: W.small,
          ),
          const Section('Напоминания'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: st.remind,
            onChanged: (v) async {
              setState(() => st.remind = v);
              if (v) await PluginNotify.requestPermission();
              st.save();
            },
            title: const Text('Напоминать перед сменой', style: W.body),
          ),
          if (st.remind)
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final m in [30, 60, 90, 120, 180])
                Chip2(m < 60 ? 'за $m мин' : (m % 60 == 0 ? 'за ${m ~/ 60} ч' : 'за ${_num(m / 60)} ч'), selected: st.remindMin == m, onTap: () {
                  setState(() => st.remindMin = m);
                  st.save();
                }),
            ]),
          const Section('Шаблоны смен'),
          for (var i = 0; i < st.templates.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(st.templates[i].label, style: W.body),
              subtitle: st.templates[i].breakMin > 0 ? Text('перерыв ${st.templates[i].breakMin} мин', style: W.small) : null,
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() => st.templates = [...st.templates]..removeAt(i));
                  st.save(reschedule: false);
                },
              ),
            ),
          OutlinedButton.icon(onPressed: _addTemplate, icon: const Icon(Icons.add), label: const Text('Добавить шаблон')),
          const Section('Файлы'),
          OutlinedButton.icon(onPressed: _exportCsv, icon: const Icon(Icons.table_chart_outlined), label: const Text('Таблица смен (CSV для Excel)')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _backup, icon: const Icon(Icons.save_alt), label: const Text('Резервная копия')),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _restore, icon: const Icon(Icons.restore), label: const Text('Восстановить из копии')),
        ]),
      );
}
