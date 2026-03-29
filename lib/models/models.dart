import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// CATEGORY MODEL
// ─────────────────────────────────────────────
class Category {
  final int? id;
  final String name;
  final int colorValue;
  final String? icon;

  const Category({
    this.id,
    required this.name,
    required this.colorValue,
    this.icon,
  });

  Color get color => Color(colorValue);

  Category copyWith({int? id, String? name, int? colorValue, String? icon}) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      icon: icon ?? this.icon,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'color': colorValue,
    'icon': icon,
  };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
    id: map['id'] as int?,
    name: map['name'] as String,
    colorValue: map['color'] as int,
    icon: map['icon'] as String?,
  );

  static List<Category> defaults() => [
    const Category(name: 'Famiglia',  colorValue: 0xFF4FC3F7, icon: '👨‍👩‍👧'),
    const Category(name: 'Personale', colorValue: 0xFFBA68C8, icon: '🌸'),
    const Category(name: 'Salute',    colorValue: 0xFF81C784, icon: '💊'),
    const Category(name: 'Lavoro',    colorValue: 0xFFFFB74D, icon: '💼'),
    const Category(name: 'Amici',     colorValue: 0xFFFF8A65, icon: '🤝'),
    const Category(name: 'Varie',     colorValue: 0xFF90A4AE, icon: '📌'),
  ];
}

// ─────────────────────────────────────────────
// NOTIFY FLAGS — bitmask per checkbox multipli
// ─────────────────────────────────────────────
// Ogni flag è una potenza di 2 così si possono combinare
class NotifyFlags {
  static const int none       = 0;
  static const int fiveMin    = 1;   // 5 minuti prima
  static const int thirtyMin  = 2;   // 30 minuti prima
  static const int oneHour    = 4;   // 1 ora prima
  static const int oneDay     = 8;   // 1 giorno prima
  static const int twoDays    = 16;  // 2 giorni prima
  static const int custom     = 32;  // personalizzato

  static bool has(int flags, int flag) => (flags & flag) != 0;
  static int add(int flags, int flag) => flags | flag;
  static int remove(int flags, int flag) => flags & ~flag;
  static int toggle(int flags, int flag) =>
      has(flags, flag) ? remove(flags, flag) : add(flags, flag);

  static String label(int flag) {
    switch (flag) {
      case fiveMin:   return '5 minuti prima';
      case thirtyMin: return '30 minuti prima';
      case oneHour:   return '1 ora prima';
      case oneDay:    return '1 giorno prima';
      case twoDays:   return '2 giorni prima';
      case custom:    return 'Personalizzato';
      default:        return '';
    }
  }

  static String emoji(int flag) {
    switch (flag) {
      case fiveMin:   return '⏱️';
      case thirtyMin: return '🔔';
      case oneHour:   return '⏰';
      case oneDay:    return '📅';
      case twoDays:   return '📆';
      case custom:    return '✏️';
      default:        return '';
    }
  }

  static List<int> get all => [fiveMin, thirtyMin, oneHour, oneDay, twoDays, custom];

  // Restituisce lista di Duration da schedulare
  static List<Duration> toOffsets(int flags, {int customMinutes = 30}) {
    final offsets = <Duration>[];
    if (has(flags, fiveMin))   offsets.add(const Duration(minutes: 5));
    if (has(flags, thirtyMin)) offsets.add(const Duration(minutes: 30));
    if (has(flags, oneHour))   offsets.add(const Duration(hours: 1));
    if (has(flags, oneDay))    offsets.add(const Duration(days: 1));
    if (has(flags, twoDays))   offsets.add(const Duration(days: 2));
    if (has(flags, custom))    offsets.add(Duration(minutes: customMinutes));
    return offsets;
  }
}

// ─────────────────────────────────────────────
// EVENT MODEL
// ─────────────────────────────────────────────
class Event {
  final int? id;
  final String title;
  final String? description;
  final DateTime startTime;
  final int durationMinutes;
  final int categoryId;
  final int notifyFlags;          // bitmask NotifyFlags
  final int customNotifyMinutes;  // usato se NotifyFlags.custom è attivo
  final bool isRecurring;
  final String? recurrenceRule;
  final bool isDone;              // segnato come completato

  const Event({
    this.id,
    required this.title,
    this.description,
    required this.startTime,
    this.durationMinutes = 60,
    required this.categoryId,
    this.notifyFlags = NotifyFlags.thirtyMin,
    this.customNotifyMinutes = 30,
    this.isRecurring = false,
    this.recurrenceRule,
    this.isDone = false,
  });

  DateTime get endTime => startTime.add(Duration(minutes: durationMinutes));

  Event copyWith({
    int? id,
    String? title,
    String? description,
    DateTime? startTime,
    int? durationMinutes,
    int? categoryId,
    int? notifyFlags,
    int? customNotifyMinutes,
    bool? isRecurring,
    String? recurrenceRule,
    bool? isDone,
  }) {
    return Event(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      categoryId: categoryId ?? this.categoryId,
      notifyFlags: notifyFlags ?? this.notifyFlags,
      customNotifyMinutes: customNotifyMinutes ?? this.customNotifyMinutes,
      isRecurring: isRecurring ?? this.isRecurring,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      isDone: isDone ?? this.isDone,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'start_time': startTime.millisecondsSinceEpoch,
    'duration_minutes': durationMinutes,
    'category_id': categoryId,
    'notify_flags': notifyFlags,
    'custom_notify_minutes': customNotifyMinutes,
    'is_recurring': isRecurring ? 1 : 0,
    'recurrence_rule': recurrenceRule,
    'is_done': isDone ? 1 : 0,
  };

  factory Event.fromMap(Map<String, dynamic> map) {
    int safeInt(String key, int def) {
      final v = map[key];
      if (v == null) return def;
      if (v is int) return v;
      return int.tryParse(v.toString()) ?? def;
    }
    return Event(
      id: map['id'] as int?,
      title: (map['title'] ?? '').toString(),
      description: map['description'] as String?,
      startTime: DateTime.fromMillisecondsSinceEpoch(safeInt('start_time', 0)),
      durationMinutes: safeInt('duration_minutes', 60),
      categoryId: safeInt('category_id', 1),
      notifyFlags: safeInt('notify_flags', NotifyFlags.thirtyMin),
      customNotifyMinutes: safeInt('custom_notify_minutes', 30),
      isRecurring: safeInt('is_recurring', 0) == 1,
      recurrenceRule: map['recurrence_rule'] as String?,
      isDone: safeInt('is_done', 0) == 1,
    );
  }
}
