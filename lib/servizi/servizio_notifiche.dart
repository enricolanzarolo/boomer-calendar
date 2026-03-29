import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/models.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _plugin.initialize(settings);
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _initialized = true;
    } catch (_) {}
  }

  Future<void> scheduleForEvent(Event event, String categoryName) async {
    if (!_initialized) return;
    try {
      await cancelForEvent(event.id!);
      if (event.notifyFlags == NotifyFlags.none) return;

      final offsets = NotifyFlags.toOffsets(
        event.notifyFlags,
        customMinutes: event.customNotifyMinutes,
      );

      int slotIndex = 0;
      for (final offset in offsets) {
        final notifyTime = event.startTime.subtract(offset);
        if (notifyTime.isBefore(DateTime.now())) {
          slotIndex++;
          continue;
        }
        await _schedule(
          id: event.id! * 20 + slotIndex,
          title: '📅 ${event.title}',
          body: _body(offset, categoryName),
          scheduledDate: notifyTime,
        );
        slotIndex++;
      }
    } catch (_) {}
  }

  String _body(Duration offset, String cat) {
    if (offset.inDays >= 2) return '$cat · dopodomani';
    if (offset.inDays >= 1) return '$cat · domani';
    if (offset.inHours >= 1) return '$cat · tra ${offset.inHours}h';
    return '$cat · tra ${offset.inMinutes} minuti';
  }

  Future<void> _schedule({
    required int id, required String title,
    required String body, required DateTime scheduledDate,
  }) async {
    try {
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'mamma_calendar_channel', 'Promemoria eventi',
          channelDescription: 'Notifiche per gli eventi del calendario',
          importance: Importance.high, priority: Priority.high,
        ),
      );
      await _plugin.zonedSchedule(
        id, title, body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> cancelForEvent(int eventId) async {
    try {
      for (int i = 0; i < 20; i++) {
        await _plugin.cancel(eventId * 20 + i);
      }
    } catch (_) {}
  }

  Future<void> scheduleDailySummary({required bool enabled}) async {
    try {
      await _plugin.cancel(9999);
      if (!enabled) return;

      final now = DateTime.now();
      var next8am = DateTime(now.year, now.month, now.day, 8, 0);
      if (next8am.isBefore(now)) next8am = next8am.add(const Duration(days: 1));

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'mamma_daily_summary', 'Riepilogo mattutino',
          channelDescription: 'Riepilogo degli eventi del giorno',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      );
      await _plugin.zonedSchedule(
        9999, '☀️ Buongiorno!',
        'Tocca per vedere cosa hai in programma oggi.',
        tz.TZDateTime.from(next8am, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }
}
