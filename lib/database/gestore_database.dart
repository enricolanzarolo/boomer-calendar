import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mamma_calendar.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 2, onCreate: _createDB, onUpgrade: _upgradeDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id    INTEGER PRIMARY KEY AUTOINCREMENT,
        name  TEXT    NOT NULL,
        color INTEGER NOT NULL,
        icon  TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE events (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        title                 TEXT    NOT NULL,
        description           TEXT,
        start_time            INTEGER NOT NULL,
        duration_minutes      INTEGER NOT NULL DEFAULT 60,
        category_id           INTEGER NOT NULL,
        notify_flags          INTEGER NOT NULL DEFAULT 2,
        custom_notify_minutes INTEGER NOT NULL DEFAULT 30,
        is_recurring          INTEGER NOT NULL DEFAULT 0,
        recurrence_rule       TEXT,
        is_done               INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');
    for (final cat in Category.defaults()) {
      await db.insert('categories', cat.toMap()..remove('id'));
    }
  }

  Future _upgradeDB(Database db, int oldVersion, int newVersion) async {
    final cols = <String>[];
    try {
      final info = await db.rawQuery("PRAGMA table_info(events)");
      cols.addAll(info.map((r) => r['name'].toString()));
    } catch (_) {}

    Future<void> addCol(String sql) async {
      try { await db.execute(sql); } catch (_) {}
    }

    if (!cols.contains('notify_flags'))
      await addCol('ALTER TABLE events ADD COLUMN notify_flags INTEGER NOT NULL DEFAULT 2');
    if (!cols.contains('custom_notify_minutes'))
      await addCol('ALTER TABLE events ADD COLUMN custom_notify_minutes INTEGER NOT NULL DEFAULT 30');
    if (!cols.contains('is_done'))
      await addCol('ALTER TABLE events ADD COLUMN is_done INTEGER NOT NULL DEFAULT 0');
    if (!cols.contains('duration_minutes'))
      await addCol('ALTER TABLE events ADD COLUMN duration_minutes INTEGER NOT NULL DEFAULT 60');
  }

  // ─── CATEGORIES ───────────────────────────────────
  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'id ASC');
    return maps.map(Category.fromMap).toList();
  }

  Future<Category> insertCategory(Category cat) async {
    final db = await database;
    final map = cat.toMap()..remove('id');
    final id = await db.insert('categories', map);
    return cat.copyWith(id: id);
  }

  Future<void> updateCategory(Category cat) async {
    final db = await database;
    await db.update('categories', cat.toMap(), where: 'id = ?', whereArgs: [cat.id]);
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ─── EVENTS ───────────────────────────────────────
  Future<List<Event>> getEventsForDay(DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end   = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;

    // 1. Eventi diretti del giorno
    final maps = await db.query('events',
        where: 'start_time BETWEEN ? AND ?',
        whereArgs: [start, end],
        orderBy: 'start_time ASC');
    final direct = maps.map(Event.fromMap).toList();

    // 2. Aggiungi occorrenze ricorrenti da eventi passati
    final recurring = await _getRecurringOccurrences(db, day);

    // Evita duplicati (se l'evento originale cade già in quel giorno)
    final directIds = direct.map((e) => e.id).toSet();
    final extras = recurring.where((e) => !directIds.contains(e.id)).toList();

    final all = [...direct, ...extras];
    all.sort((a, b) => a.startTime.compareTo(b.startTime));
    return all;
  }

  /// Trova eventi ricorrenti il cui pattern include `day`
  Future<List<Event>> _getRecurringOccurrences(Database db, DateTime day) async {
    final maps = await db.query('events',
        where: 'is_recurring = 1 AND recurrence_rule IS NOT NULL');
    final results = <Event>[];

    for (final map in maps) {
      final event = Event.fromMap(map);
      final origin = DateTime(
          event.startTime.year, event.startTime.month, event.startTime.day);
      final target = DateTime(day.year, day.month, day.day);

      // Non includere se il giorno target è prima o uguale all'origine
      if (!target.isAfter(origin)) continue;

      bool matches = false;
      switch (event.recurrenceRule) {
        case 'daily':
          matches = true; // ogni giorno
          break;
        case 'weekly':
          matches = target.weekday == origin.weekday;
          break;
        case 'monthly':
          matches = target.day == origin.day;
          break;
        case 'yearly':
          matches = target.day == origin.day && target.month == origin.month;
          break;
      }

      if (matches) {
        final newStart = DateTime(day.year, day.month, day.day, event.startTime.hour, event.startTime.minute);
        results.add(event.copyWith(startTime: newStart, isDone: false));
      }
    }
    return results;
  }

  Future<List<Event>> getEventsForRange(DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query('events',
        where: 'start_time BETWEEN ? AND ?',
        whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
        orderBy: 'start_time ASC');
    final direct = maps.map(Event.fromMap).toList();

    // Aggiungi ricorrenti per ogni giorno del range
    final days = <DateTime>[];
    var cur = DateTime(from.year, from.month, from.day);
    final end = DateTime(to.year, to.month, to.day);
    while (!cur.isAfter(end)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }

    final directIds = direct.map((e) => e.id).toSet();
    final extras = <Event>[];
    for (final day in days) {
      final occ = await _getRecurringOccurrences(db, day);
      extras.addAll(occ.where((e) => !directIds.contains(e.id)));
    }

    final all = [...direct, ...extras];
    all.sort((a, b) => a.startTime.compareTo(b.startTime));
    return all;
  }

  Future<List<Event>> getAllEvents() async {
    final db = await database;
    final maps = await db.query('events', orderBy: 'start_time ASC');
    return maps.map(Event.fromMap).toList();
  }

  Future<Event> insertEvent(Event event) async {
    final db = await database;
    final map = event.toMap()..remove('id');
    final id = await db.insert('events', map);
    return event.copyWith(id: id);
  }

  Future<void> updateEvent(Event event) async {
    final db = await database;
    await db.update('events', event.toMap(), where: 'id = ?', whereArgs: [event.id]);
  }

  Future<void> deleteEvent(int id) async {
    final db = await database;
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> markDone(int id, bool done) async {
    final db = await database;
    await db.update('events', {'is_done': done ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }


  Future<Map<String, dynamic>> exportAll() async {
    final events = await getAllEvents();
    final categories = await getCategories();
    return {
      'version': 2,
      'exported_at': DateTime.now().toIso8601String(),
      'categories': categories.map((c) => c.toMap()).toList(),
      'events': events.map((e) => e.toMap()).toList(),
    };
  }

  Future<void> importAll(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('events');
      await txn.delete('categories');
      for (final c in (data['categories'] as List)) {
        await txn.insert('categories', Map<String, dynamic>.from(c));
      }
      for (final e in (data['events'] as List)) {
        await txn.insert('events', Map<String, dynamic>.from(e));
      }
    });
  }
}
