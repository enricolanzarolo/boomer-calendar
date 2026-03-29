import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/gestore_database.dart';
import '../models/models.dart';

// ─── TEMA ─────────────────────────────────────────
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) { _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getBool('dark_mode') ?? false) ? ThemeMode.dark : ThemeMode.light;
  }
  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    state = state == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await prefs.setBool('dark_mode', state == ThemeMode.dark);
  }
}

// ─── DATA SELEZIONATA ─────────────────────────────
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

// ─── CATEGORIE ────────────────────────────────────
final categoriesProvider =
    StateNotifierProvider<CategoriesNotifier, AsyncValue<List<Category>>>(
  (ref) => CategoriesNotifier(),
);
class CategoriesNotifier extends StateNotifier<AsyncValue<List<Category>>> {
  CategoriesNotifier() : super(const AsyncValue.loading()) { load(); }
  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final cats = await DatabaseHelper.instance.getCategories();
      state = AsyncValue.data(cats);
    } catch (e, st) { state = AsyncValue.error(e, st); }
  }
  Future<void> add(Category cat) async {
    final saved = await DatabaseHelper.instance.insertCategory(cat);
    state.whenData((list) => state = AsyncValue.data([...list, saved]));
  }
  Future<void> update(Category cat) async {
    await DatabaseHelper.instance.updateCategory(cat);
    state.whenData((list) =>
        state = AsyncValue.data(list.map((c) => c.id == cat.id ? cat : c).toList()));
  }
  Future<void> remove(int id) async {
    await DatabaseHelper.instance.deleteCategory(id);
    state.whenData((list) =>
        state = AsyncValue.data(list.where((c) => c.id != id).toList()));
  }
}

// ─── EVENTI PER GIORNO ────────────────────────────
// Usiamo un semplice StateNotifier con chiave DateTime
final eventsForDayProvider = StateNotifierProvider.family<EventsDayNotifier,
    AsyncValue<List<Event>>, DateTime>(
  (ref, day) => EventsDayNotifier(day),
);

class EventsDayNotifier extends StateNotifier<AsyncValue<List<Event>>> {
  final DateTime day;
  EventsDayNotifier(this.day) : super(const AsyncValue.loading()) { load(); }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final events = await DatabaseHelper.instance.getEventsForDay(day);
      if (mounted) state = AsyncValue.data(events);
    } catch (e, st) {
      if (mounted) state = AsyncValue.error(e, st);
    }
  }

  Future<void> add(Event event) async {
    final saved = await DatabaseHelper.instance.insertEvent(event);
    state.whenData((list) {
      final updated = [...list, saved]
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      state = AsyncValue.data(updated);
    });
  }

  Future<void> update(Event event) async {
    await DatabaseHelper.instance.updateEvent(event);
    state.whenData((list) =>
        state = AsyncValue.data(
            list.map((e) => e.id == event.id ? event : e).toList()));
  }

  Future<void> remove(int id) async {
    await DatabaseHelper.instance.deleteEvent(id);
    state.whenData((list) =>
        state = AsyncValue.data(list.where((e) => e.id != id).toList()));
  }

  Future<void> toggleDone(int id) async {
    state.whenData((list) async {
      final event = list.firstWhere((e) => e.id == id);
      final updated = event.copyWith(isDone: !event.isDone);
      await DatabaseHelper.instance.markDone(id, updated.isDone);
      if (mounted) {
        state = AsyncValue.data(
            list.map((e) => e.id == id ? updated : e).toList());
      }
    });
  }
}

// ─── VISTA CALENDARIO ────────────────────────────
enum CalendarView { week, month }
final calendarViewProvider = StateProvider<CalendarView>(
    (ref) => CalendarView.month);

// ─── RIEPILOGO MATTUTINO ─────────────────────────
final dailySummaryProvider = StateNotifierProvider<DailySummaryNotifier, bool>(
  (ref) => DailySummaryNotifier(),
);
class DailySummaryNotifier extends StateNotifier<bool> {
  DailySummaryNotifier() : super(false) { _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool('daily_summary') ?? false;
  }
  Future<void> set(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('daily_summary', value);
    state = value;
  }
}
