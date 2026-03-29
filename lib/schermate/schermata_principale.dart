import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../stato/provider.dart';
import '../models/models.dart';
import '../database/gestore_database.dart';
import 'modulo_evento.dart';
import 'impostazioni.dart';
import 'ricerca.dart';

bool _sd(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

final refreshProvider = StateProvider<int>((ref) => 0);
final todayResetProvider = StateProvider<int>((ref) => 0);

// Provider per conteggio attività oggi
final todayStatsProvider = FutureProvider.autoDispose<(int, int)>((ref) async {
  ref.watch(refreshProvider);
  final today = DateTime.now();
  final events = await DatabaseHelper.instance.getEventsForDay(today);
  final done = events.where((e) => e.isDone).length;
  return (done, events.length);
});

// ═══════════════════════════════════════════════
// HOME
// ═══════════════════════════════════════════════
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(calendarViewProvider);
    final sel = ref.watch(selectedDateProvider);
    final stats = ref.watch(todayStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _title(sel),
        leading: stats.when(
          data: (s) {
            final done = s.$1;
            final total = s.$2;
            if (total == 0) return null;
            return Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$done/$total',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: done == total
                                ? Colors.green.shade400
                                : theme.colorScheme.primary)),
                    Text('svolte',
                        style: TextStyle(
                            fontSize: 9,
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.5))),
                  ]),
            );
          },
          loading: () => null,
          error: (_, __) => null,
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.search_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SearchScreen()))),
          TextButton(
              onPressed: () {
                ref.read(selectedDateProvider.notifier).state = DateTime.now();
                ref.read(todayResetProvider.notifier).state++;
              },
              child: Text('Oggi',
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16))),
          IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()))),
        ],
      ),
      body: Column(children: [
        _ViewSel(view: view),
        const SizedBox(height: 4),
        Expanded(
            child: view == CalendarView.month
                ? MonthView(key: ValueKey(ref.watch(todayResetProvider)))
                : const WeekView()),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final day = ref.read(selectedDateProvider);
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EventFormScreen(initialDate: day)));
          ref.read(refreshProvider.notifier).state++;
        },
        child: const Icon(Icons.add, size: 30),
      ),
    );
  }

  Widget _title(DateTime d) {
    final t = DateFormat('MMMM yyyy', 'it_IT').format(d);
    return Text(t[0].toUpperCase() + t.substring(1));
  }
}

// ── Selettore vista ──────────────────────────────
class _ViewSel extends ConsumerWidget {
  final CalendarView view;
  const _ViewSel({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        _Tab('Settimana', Icons.view_week_outlined, CalendarView.week, view,
            ref),
        _Tab('Mese', Icons.calendar_month_outlined, CalendarView.month, view,
            ref),
      ]),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final CalendarView target, current;
  final WidgetRef ref;
  const _Tab(this.label, this.icon, this.target, this.current, this.ref);

  @override
  Widget build(BuildContext context) {
    final sel = current == target;
    final theme = Theme.of(context);
    return Expanded(
        child: GestureDetector(
      onTap: () => ref.read(calendarViewProvider.notifier).state = target,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
            color: sel ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              size: 18,
              color: sel ? Colors.white : theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                  color:
                      sel ? Colors.white : theme.colorScheme.onSurfaceVariant)),
        ]),
      ),
    ));
  }
}

// ═══════════════════════════════════════════════
// WEEK VIEW — swipe orizzontale su tutta la lista
// ═══════════════════════════════════════════════
class WeekView extends ConsumerWidget {
  const WeekView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedDateProvider);
    final theme = Theme.of(context);
    final days = List.generate(7, (i) => sel.add(Duration(days: i - 3)));
    const lbl = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];

    return Column(children: [
      // Barra giorni con swipe
      GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 300) return;
          if (v < 0)
            ref.read(selectedDateProvider.notifier).state =
                sel.add(const Duration(days: 1));
          else
            ref.read(selectedDateProvider.notifier).state =
                sel.subtract(const Duration(days: 1));
        },
        child: Container(
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
              children: days.map((day) {
            final isSel = _sd(day, sel);
            final isToday = _sd(day, DateTime.now());
            return Expanded(
                child: GestureDetector(
              onTap: () => ref.read(selectedDateProvider.notifier).state = day,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: isSel
                        ? theme.colorScheme.primary
                        : isToday
                            ? theme.colorScheme.primary.withOpacity(0.1)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  Text(lbl[day.weekday - 1],
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSel
                              ? Colors.white
                              : theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('${day.day}',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isSel
                              ? Colors.white
                              : isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  _Dots(day: day, isSel: isSel),
                ]),
              ),
            ));
          }).toList()),
        ),
      ),

      const Divider(height: 1),

      Container(
        color: theme.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_dayLabel(sel),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary))),
      ),

      // Lista con swipe + fade
      Expanded(
          child: _SwipeWrapper(
        onSwipeLeft: () => ref.read(selectedDateProvider.notifier).state =
            sel.add(const Duration(days: 1)),
        onSwipeRight: () => ref.read(selectedDateProvider.notifier).state =
            sel.subtract(const Duration(days: 1)),
        child: _AnimatedDayList(
          selectedDay: sel,
          key: const ValueKey('animated_list'),
        ),
      )),
    ]);
  }

  String _dayLabel(DateTime d) {
    if (_sd(d, DateTime.now())) return '📅 Oggi';
    if (_sd(d, DateTime.now().add(const Duration(days: 1)))) return '📅 Domani';
    if (_sd(d, DateTime.now().subtract(const Duration(days: 1))))
      return '📅 Ieri';
    final f = DateFormat('EEEE d MMMM', 'it_IT').format(d);
    return '📅 ${f[0].toUpperCase()}${f.substring(1)}';
  }
}

// ── Lista giorni con animazione slide + flash tema-aware ──
class _AnimatedDayList extends ConsumerStatefulWidget {
  final DateTime selectedDay;
  const _AnimatedDayList({super.key, required this.selectedDay});

  @override
  ConsumerState<_AnimatedDayList> createState() => _AnimatedDayListState();
}

class _AnimatedDayListState extends ConsumerState<_AnimatedDayList>
    with SingleTickerProviderStateMixin {
  late DateTime _currentDay;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  bool _goingRight = true; // true = giorno dopo, false = giorno prima

  @override
  void initState() {
    super.initState();
    _currentDay = widget.selectedDay;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_AnimatedDayList old) {
    super.didUpdateWidget(old);
    if (!_sd(old.selectedDay, widget.selectedDay)) {
      _goingRight = widget.selectedDay.isAfter(old.selectedDay);
      _animateToDay(widget.selectedDay);
    }
  }

  Future<void> _animateToDay(DateTime newDay) async {
    // Fade out
    await _ctrl.reverse();
    setState(() => _currentDay = newDay);
    // Fade in
    await _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: _EventList(
        key: ValueKey(_currentDay),
        day: _currentDay,
      ),
    );
  }
}

// ── Widget swipe — GestureDetector con priorità orizzontale ──
class _SwipeWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  const _SwipeWrapper(
      {required this.child,
      required this.onSwipeLeft,
      required this.onSwipeRight});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // onHorizontalDragEnd ha priorità sul ListView verticale
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v.abs() < 150) return;
        if (v < 0)
          onSwipeLeft();
        else
          onSwipeRight();
      },
      // Comportamento: questo GestureDetector "vince" sullo scroll verticale
      // perché onHorizontalDrag è mutuamente esclusivo con lo scroll verticale
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

class _Dots extends ConsumerWidget {
  final DateTime day;
  final bool isSel;
  const _Dots({required this.day, required this.isSel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(refreshProvider);
    final theme = Theme.of(context);
    return FutureBuilder<List<Event>>(
      future: DatabaseHelper.instance.getEventsForDay(day),
      builder: (_, snap) {
        final events = snap.data ?? [];
        if (events.isEmpty) return const SizedBox(height: 6);
        return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: events
                .take(3)
                .map((_) => Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                          color: isSel
                              ? Colors.white.withOpacity(0.8)
                              : theme.colorScheme.secondary,
                          shape: BoxShape.circle),
                    ))
                .toList());
      },
    );
  }
}

// ═══════════════════════════════════════════════
// MONTH VIEW
// ═══════════════════════════════════════════════
class MonthView extends ConsumerStatefulWidget {
  const MonthView({super.key});
  @override
  ConsumerState<MonthView> createState() => _MonthViewState();
}

class _MonthViewState extends ConsumerState<MonthView> {
  Map<DateTime, List<Event>> _evMap = {};
  DateTime _focused = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    final s = DateTime(_focused.year, _focused.month, 1);
    final e = DateTime(_focused.year, _focused.month + 1, 0, 23, 59);
    final evs = await DatabaseHelper.instance.getEventsForRange(s, e);
    final m = <DateTime, List<Event>>{};
    for (final ev in evs) {
      final k =
          DateTime(ev.startTime.year, ev.startTime.month, ev.startTime.day);
      m.putIfAbsent(k, () => []).add(ev);
    }
    if (mounted) setState(() => _evMap = m);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshProvider, (_, __) => _loadMonth());
    final sel = ref.watch(selectedDateProvider);
    final catsA = ref.watch(categoriesProvider);
    final theme = Theme.of(context);

    return Column(children: [
      TableCalendar<Event>(
        locale: 'it_IT',
        firstDay: DateTime(2020),
        lastDay: DateTime(2035),
        focusedDay: _focused,
        selectedDayPredicate: (d) => _sd(d, sel),
        eventLoader: (d) => _evMap[DateTime(d.year, d.month, d.day)] ?? [],
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          selectedDecoration: BoxDecoration(
              color: theme.colorScheme.primary, shape: BoxShape.circle),
          todayDecoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.2),
              shape: BoxShape.circle),
          todayTextStyle: TextStyle(
              color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
          markersMaxCount: 3,
          cellMargin: const EdgeInsets.all(4),
          defaultTextStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface),
          leftChevronIcon:
              Icon(Icons.chevron_left, color: theme.colorScheme.primary),
          rightChevronIcon:
              Icon(Icons.chevron_right, color: theme.colorScheme.primary),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 12),
          weekendStyle: TextStyle(
              color: theme.colorScheme.secondary,
              fontWeight: FontWeight.w600,
              fontSize: 12),
        ),
        onDaySelected: (selected, focused) {
          ref.read(selectedDateProvider.notifier).state = selected;
          setState(() => _focused = focused);
        },
        onPageChanged: (f) {
          _focused = f;
          _loadMonth();
        },
        calendarBuilders: CalendarBuilders(
          markerBuilder: (ctx, day, events) {
            if (events.isEmpty) return null;
            return catsA.when(
              data: (cats) {
                final colors = events.take(3).map((e) {
                  final c = cats.firstWhere((c) => c.id == e.categoryId,
                      orElse: () => cats.first);
                  return c.color;
                }).toList();
                return Positioned(
                    bottom: 4,
                    child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: colors
                            .map((c) => Container(
                                  width: 6,
                                  height: 6,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                      color: c, shape: BoxShape.circle),
                                ))
                            .toList()));
              },
              loading: () => null,
              error: (_, __) => null,
            );
          },
        ),
      ),
      Container(
        color: theme.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_dayHdr(sel),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary))),
      ),
      Expanded(
          child: _EventList(
        key: ValueKey('${sel.year}-${sel.month}-${sel.day}'),
        day: DateTime(sel.year, sel.month, sel.day),
      )),
    ]);
  }

  String _dayHdr(DateTime d) {
    if (_sd(d, DateTime.now())) return '📅 Oggi';
    final f = DateFormat('EEEE d MMMM', 'it_IT').format(d);
    return '📅 ${f[0].toUpperCase()}${f.substring(1)}';
  }
}

// ═══════════════════════════════════════════════
// LISTA EVENTI
// ═══════════════════════════════════════════════
class _EventList extends ConsumerStatefulWidget {
  final DateTime day;
  const _EventList({super.key, required this.day});

  @override
  ConsumerState<_EventList> createState() => _EventListState();
}

class _EventListState extends ConsumerState<_EventList> {
  List<Event> _events = [];
  List<Category> _cats = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final evs = await DatabaseHelper.instance.getEventsForDay(widget.day);
      final cats = await DatabaseHelper.instance.getCategories();
      if (mounted)
        setState(() {
          _events = evs;
          _cats = cats;
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _loading = false;
          _err = e.toString();
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshProvider, (_, __) => _load());

    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_err != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 40),
        const SizedBox(height: 8),
        Text(_err!,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: _load, child: const Text('Riprova')),
      ]));
    }

    if (_events.isEmpty) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('🌸', style: TextStyle(fontSize: 46)),
        const SizedBox(height: 10),
        Text('Niente in programma',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w500,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
        const SizedBox(height: 4),
        Text('Tocca + per aggiungere un evento',
            style: TextStyle(
                fontSize: 13,
                color:
                    Theme.of(context).colorScheme.onSurface.withOpacity(0.3))),
      ]));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: _events.length,
      itemBuilder: (_, i) {
        final ev = _events[i];
        final cat = _cats.firstWhere((c) => c.id == ev.categoryId,
            orElse: () => _cats.isNotEmpty
                ? _cats.first
                : const Category(name: 'Varie', colorValue: 0xFF90A4AE));
        return _Tile(
          key: ValueKey(ev.id),
          event: ev,
          category: cat,
          onDone: () async {
            await DatabaseHelper.instance.markDone(ev.id!, !ev.isDone);
            _load();
            ref.read(refreshProvider.notifier).state++;
          },
          onDelete: () async {
            final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      title: const Text('Elimina evento?',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      content: Text('Eliminare "${ev.title}"?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('No')),
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade400),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Sì, elimina')),
                      ],
                    ));
            if (ok == true) {
              await DatabaseHelper.instance.deleteEvent(ev.id!);
              _load();
              ref.read(refreshProvider.notifier).state++;
            }
          },
          onEdit: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        EventFormScreen(event: ev, initialDate: ev.startTime)));
            _load();
            ref.read(refreshProvider.notifier).state++;
          },
        );
      },
    );
  }
}

// ─── Card evento con sfondo colorato ─────────────
class _Tile extends StatelessWidget {
  final Event event;
  final Category category;
  final VoidCallback onDone, onDelete, onEdit;
  const _Tile(
      {super.key,
      required this.event,
      required this.category,
      required this.onDone,
      required this.onDelete,
      required this.onEdit});

  // Colore chiaro per sfondo (più leggibile)
  Color _bgColor(Color base, bool isDark) {
    if (event.isDone) {
      return isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade100;
    }
    // Sfondo molto chiaro del colore categoria
    return Color.lerp(base, Colors.white, isDark ? 0.75 : 0.82)!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final col = category.color;
    final bgCol = _bgColor(col, isDark);
    final tf = DateFormat('HH:mm');

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: bgCol,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: col.withOpacity(0.3), width: 1.5),
          boxShadow: event.isDone
              ? []
              : [
                  BoxShadow(
                      color: col.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3)),
                ],
        ),
        child: IntrinsicHeight(
            child: Row(children: [
          Expanded(
              child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // Titolo + badge categoria
                    Row(children: [
                      Expanded(
                          child: Text(event.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                decoration: event.isDone
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: event.isDone
                                    ? theme.colorScheme.onSurface
                                        .withOpacity(0.4)
                                    : col.withOpacity(0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                            color: col.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: col.withOpacity(0.4), width: 1)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (category.icon != null) ...[
                            Text(category.icon!,
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(width: 4),
                          ],
                          Text(category.name,
                              style: TextStyle(
                                  color: col,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ]),

                    if (event.description != null &&
                        event.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(event.description!,
                          style: TextStyle(
                              fontSize: 13, color: col.withOpacity(0.65)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],

                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.access_time,
                          size: 12, color: col.withOpacity(0.55)),
                      const SizedBox(width: 4),
                      Text(
                          '${tf.format(event.startTime)} → ${tf.format(event.endTime)}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: col.withOpacity(0.75))),
                      const SizedBox(width: 8),
                      Text(_dur(event.durationMinutes),
                          style: TextStyle(
                              fontSize: 12, color: col.withOpacity(0.5))),
                      const Spacer(),
                      if (event.notifyFlags != NotifyFlags.none)
                        const Text('🔔', style: TextStyle(fontSize: 12)),
                      if (event.isRecurring) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.repeat,
                            size: 12, color: col.withOpacity(0.5)),
                      ],
                    ]),
                  ])),

              // Checkbox completato
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onDone,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: event.isDone ? col : Colors.transparent,
                    border: Border.all(
                        color: event.isDone ? col : col.withOpacity(0.4),
                        width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: event.isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              ),
            ]),
          )),
        ])),
      ),
    );
  }

  String _dur(int m) {
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    final r = m % 60;
    return r == 0 ? '${h}h' : '${h}h ${r}min';
  }
}
