import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../stato/provider.dart';
import '../database/gestore_database.dart';
import '../servizi/servizio_notifiche.dart';
import '../schermate/modulo_evento.dart';

class EventCard extends ConsumerWidget {
  final Event event;
  final Category category;
  final VoidCallback onRefresh;

  const EventCard({
    super.key,
    required this.event,
    required this.category,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = category.color;
    final timeFormat = DateFormat('HH:mm');

    return Dismissible(
      key: ValueKey('event_${event.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.delete_outline, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text('Elimina', style: TextStyle(color: Colors.white, fontSize: 12)),
        ]),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Elimina evento?', style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text('Vuoi eliminare "${event.title}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false),
                child: const Text('No')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sì, elimina'),
            ),
          ],
        ),
      ),
      onDismissed: (_) async {
        await DatabaseHelper.instance.deleteEvent(event.id!);
        await NotificationService.instance.cancelForEvent(event.id!);
        onRefresh();
      },
      child: GestureDetector(
        onTap: () async {
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => EventFormScreen(
              event: event,
              initialDate: event.startTime,
            )),
          );
          if (result == true) onRefresh();
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: event.isDone
                ? theme.colorScheme.surfaceContainerHighest
                : theme.cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: event.isDone ? [] : [
              BoxShadow(color: color.withOpacity(0.15),
                  blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // Barra colorata sinistra
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: event.isDone ? Colors.grey.shade300 : color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
            ),

            // Contenuto
            Expanded(child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titolo + badge
                    Row(children: [
                      Expanded(child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          decoration: event.isDone ? TextDecoration.lineThrough : null,
                          color: event.isDone
                              ? theme.colorScheme.onSurface.withOpacity(0.4)
                              : theme.colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (category.icon != null) ...[
                            Text(category.icon!, style: const TextStyle(fontSize: 11)),
                            const SizedBox(width: 3),
                          ],
                          Text(category.name, style: TextStyle(
                            color: color, fontSize: 11, fontWeight: FontWeight.w700,
                          )),
                        ]),
                      ),
                    ]),

                    if (event.description != null && event.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(event.description!,
                        style: TextStyle(fontSize: 13,
                            color: theme.colorScheme.onSurface.withOpacity(0.55)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],

                    const SizedBox(height: 8),

                    // Orario
                    Row(children: [
                      Icon(Icons.access_time, size: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.45)),
                      const SizedBox(width: 4),
                      Text(
                        '${timeFormat.format(event.startTime)} → ${timeFormat.format(event.endTime)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withOpacity(0.65)),
                      ),
                      const SizedBox(width: 10),
                      Text(_durationLabel(event.durationMinutes),
                        style: TextStyle(fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.45))),
                      const Spacer(),
                      if (event.notifyFlags != NotifyFlags.none)
                        const Text('🔔', style: TextStyle(fontSize: 13)),
                      if (event.isRecurring) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.repeat, size: 13,
                            color: theme.colorScheme.onSurface.withOpacity(0.45)),
                      ],
                    ]),
                  ],
                )),

                // Checkbox "fatto"
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final day = DateTime(event.startTime.year,
                        event.startTime.month, event.startTime.day);
                    ref.read(eventsForDayProvider(day).notifier).toggleDone(event.id!);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: event.isDone ? color : Colors.transparent,
                      border: Border.all(
                        color: event.isDone ? color : Colors.grey.shade300,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: event.isDone
                        ? const Icon(Icons.check, color: Colors.white, size: 18)
                        : null,
                  ),
                ),
              ]),
            )),
          ]),
        ),
      ),
    );
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }
}
