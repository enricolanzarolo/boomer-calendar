import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../stato/provider.dart';
import '../database/gestore_database.dart';
import '../servizi/servizio_notifiche.dart';

class EventFormScreen extends ConsumerStatefulWidget {
  final Event? event;
  final DateTime initialDate;

  const EventFormScreen({super.key, this.event, required this.initialDate});

  @override
  ConsumerState<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends ConsumerState<EventFormScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  late DateTime _startTime;
  late int _durationMinutes;
  int? _selectedCategoryId;
  int _notifyFlags = NotifyFlags.thirtyMin;
  int _customNotifyMinutes = 30;
  bool _isRecurring = false;
  String? _recurrenceRule;
  bool _saving = false; // ← impedisce doppio salvataggio

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _titleCtrl.text = e?.title ?? '';
    _descCtrl.text  = e?.description ?? '';
    _startTime = e?.startTime ?? widget.initialDate;
    _durationMinutes = e?.durationMinutes ?? 60;
    _selectedCategoryId = e?.categoryId;
    _notifyFlags = e?.notifyFlags ?? NotifyFlags.thirtyMin;
    _customNotifyMinutes = e?.customNotifyMinutes ?? 30;
    _isRecurring = e?.isRecurring ?? false;
    _recurrenceRule = e?.recurrenceRule;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return; // blocca doppio tap
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scrivi il nome dell\'evento! ✏️')));
      return;
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scegli una categoria! 🎨')));
      return;
    }

    setState(() => _saving = true);

    try {
      final categories = ref.read(categoriesProvider).valueOrNull ?? [];
      final cat = categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
        orElse: () => categories.first,
      );

      final event = Event(
        id: widget.event?.id,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        startTime: _startTime,
        durationMinutes: _durationMinutes,
        categoryId: _selectedCategoryId!,
        notifyFlags: _notifyFlags,
        customNotifyMinutes: _customNotifyMinutes,
        isRecurring: _isRecurring,
        recurrenceRule: _isRecurring ? _recurrenceRule : null,
      );

      Event saved;
      if (_isEditing) {
        await DatabaseHelper.instance.updateEvent(event);
        saved = event;
      } else {
        saved = await DatabaseHelper.instance.insertEvent(event);
      }

      // Notifiche
      await NotificationService.instance.scheduleForEvent(saved, cat.name);

      // Invalida il provider del giorno così la lista si aggiorna
      final day = DateTime(_startTime.year, _startTime.month, _startTime.day);
      ref.invalidate(eventsForDayProvider(day));

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifica evento' : 'Nuovo evento'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 26),
              onPressed: _confirmDelete,
            ),
          if (!_isEditing)
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)))
                : TextButton(
                    onPressed: _save,
                    child: Text('Salva',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        )),
                  ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Titolo ──────────────────────────────
          _Label('✏️ Nome evento'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleCtrl,
            style: const TextStyle(fontSize: 18),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Es. Visita medica...'),
          ),

          const SizedBox(height: 24),

          // ── Note ────────────────────────────────
          _Label('📝 Note (opzionale)'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descCtrl,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'Aggiungi dettagli...'),
          ),

          const SizedBox(height: 24),

          // ── Data e ora ──────────────────────────
          _Label('📅 Quando'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _TapTile(
              icon: Icons.calendar_today_outlined,
              label: 'Data',
              value: DateFormat('EEE d MMM', 'it_IT').format(_startTime),
              onTap: _pickDate,
            )),
            const SizedBox(width: 12),
            Expanded(child: _TapTile(
              icon: Icons.access_time_outlined,
              label: 'Ora',
              value: DateFormat('HH:mm').format(_startTime),
              onTap: _pickTime,
            )),
          ]),

          const SizedBox(height: 24),

          // ── Durata ──────────────────────────────
          _Label('⏱️ Durata'),
          const SizedBox(height: 8),
          _DurationPicker(
            value: _durationMinutes,
            onChanged: (v) => setState(() => _durationMinutes = v),
          ),

          const SizedBox(height: 24),

          // ── Categoria ───────────────────────────
          _Label('🎨 Categoria'),
          const SizedBox(height: 8),
          categoriesAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Errore: $e'),
            data: (cats) => _CategoryPicker(
              categories: cats,
              selectedId: _selectedCategoryId,
              onSelected: (id) => setState(() => _selectedCategoryId = id),
            ),
          ),

          const SizedBox(height: 24),

          // ── Notifiche (checkbox) ─────────────────
          _Label('🔔 Avvisami (puoi scegliere più opzioni)'),
          const SizedBox(height: 8),
          _NotifyCheckboxes(
            flags: _notifyFlags,
            customMinutes: _customNotifyMinutes,
            onChanged: (flags, custom) => setState(() {
              _notifyFlags = flags;
              _customNotifyMinutes = custom;
            }),
          ),

          const SizedBox(height: 24),

          // ── Ricorrenza ──────────────────────────
          _Label('🔁 Evento ricorrente'),
          const SizedBox(height: 8),
          _RecurrencePicker(
            isRecurring: _isRecurring,
            rule: _recurrenceRule,
            onChanged: (r, rule) => setState(() {
              _isRecurring = r;
              _recurrenceRule = rule;
            }),
          ),

          const SizedBox(height: 40),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _isEditing ? '✅ Salva modifiche' : '✅ Aggiungi evento',
                      style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Elimina evento?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('Vuoi eliminare "${_titleCtrl.text}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sì, elimina'),
          ),
        ],
      ),
    );
    if (ok == true && widget.event?.id != null) {
      await DatabaseHelper.instance.deleteEvent(widget.event!.id!);
      await NotificationService.instance.cancelForEvent(widget.event!.id!);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('it', 'IT'),
    );
    if (picked != null) {
      setState(() {
        _startTime = DateTime(picked.year, picked.month, picked.day,
            _startTime.hour, _startTime.minute);
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (picked != null) {
      setState(() {
        _startTime = DateTime(_startTime.year, _startTime.month, _startTime.day,
            picked.hour, picked.minute);
      });
    }
  }
}

// ─── WIDGETS INTERNI ─────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700));
}

class _TapTile extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final VoidCallback onTap;
  const _TapTile({required this.icon, required this.label,
      required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

// ── Durata: 4 opzioni + Personalizza ────────────
class _DurationPicker extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _DurationPicker({required this.value, required this.onChanged});
  @override
  State<_DurationPicker> createState() => _DurationPickerState();
}

class _DurationPickerState extends State<_DurationPicker> {
  static const _preset = [
    (30,  '30 min'),
    (60,  '1 ora'),
    (120, '2 ore'),
    (480, 'Tutto il giorno'),
  ];

  bool get _isCustom => !_preset.any((p) => p.$1 == widget.value);
  final _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        ..._preset.map((opt) {
          final sel = widget.value == opt.$1 && !_isCustom;
          return GestureDetector(
            onTap: () => widget.onChanged(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              decoration: BoxDecoration(
                color: sel ? theme.colorScheme.primary
                           : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(opt.$2, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: sel ? Colors.white : theme.colorScheme.onSurface,
              )),
            ),
          );
        }),
        // Bottone Personalizza
        GestureDetector(
          onTap: () => _showCustomDialog(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              color: _isCustom ? theme.colorScheme.primary
                               : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _isCustom ? '${widget.value} min' : 'Personalizza ✏️',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: _isCustom ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ]),
    ]);
  }

  Future<void> _showCustomDialog(BuildContext context) async {
    _ctrl.text = widget.value.toString();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Durata personalizzata'),
        content: TextField(
          controller: _ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Minuti',
            suffixText: 'min',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(_ctrl.text);
              if (v != null && v > 0) widget.onChanged(v);
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Categoria picker ─────────────────────────────
class _CategoryPicker extends ConsumerStatefulWidget {
  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int> onSelected;
  const _CategoryPicker({required this.categories,
      required this.selectedId, required this.onSelected});
  @override
  ConsumerState<_CategoryPicker> createState() => _CategoryPickerState();
}

class _CategoryPickerState extends ConsumerState<_CategoryPicker> {
  Future<void> _addCategory() async {
    final result = await showDialog<Category>(
      context: context,
      builder: (_) => const _AddCategoryDialog(),
    );
    if (result != null) await ref.read(categoriesProvider.notifier).add(result);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      ...widget.categories.map((cat) {
        final sel = cat.id == widget.selectedId;
        return GestureDetector(
          onTap: () => widget.onSelected(cat.id!),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? cat.color : cat.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: sel ? Border.all(color: cat.color, width: 2) : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (cat.icon != null) ...[
                Text(cat.icon!, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
              ],
              Text(cat.name, style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: sel ? Colors.white : cat.color,
              )),
            ]),
          ),
        );
      }),
      GestureDetector(
        onTap: _addCategory,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Text('Nuova categoria', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            )),
          ]),
        ),
      ),
    ]);
  }
}

// ── Dialogo nuova categoria ──────────────────────
class _AddCategoryDialog extends StatefulWidget {
  const _AddCategoryDialog();
  @override
  State<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<_AddCategoryDialog> {
  final _nameCtrl = TextEditingController();
  Color _color = Colors.blue;
  String _icon = '📌';

  static const _icons = [
    '📌','❤️','⭐','🌸','🏠','🚗','✈️','🎉','🎂','💊',
    '💼','📚','🏋️','🎵','🛒','💰','🌿','🐾','⚽','🎨',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Nuova categoria', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _nameCtrl,
            decoration: const InputDecoration(hintText: 'Nome categoria',
                prefixIcon: Icon(Icons.label_outline))),
        const SizedBox(height: 16),
        const Align(alignment: Alignment.centerLeft,
            child: Text('Icona:', style: TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: _icons.map((ic) =>
          GestureDetector(
            onTap: () => setState(() => _icon = ic),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _icon == ic ? _color.withOpacity(0.3) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(ic, style: const TextStyle(fontSize: 20))),
            ),
          )).toList()),
        const SizedBox(height: 16),
        const Align(alignment: Alignment.centerLeft,
            child: Text('Colore:', style: TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(height: 8),
        BlockPicker(pickerColor: _color, onColorChanged: (c) => setState(() => _color = c)),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, Category(
              name: _nameCtrl.text.trim(), colorValue: _color.value, icon: _icon));
          },
          child: const Text('Aggiungi'),
        ),
      ],
    );
  }
}

// ── Notifiche: checkbox multipli ─────────────────
class _NotifyCheckboxes extends StatelessWidget {
  final int flags;
  final int customMinutes;
  final void Function(int flags, int customMinutes) onChanged;

  const _NotifyCheckboxes({
    required this.flags,
    required this.customMinutes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: [
        // Nessuna notifica
        CheckboxListTile(
          value: flags == NotifyFlags.none,
          onChanged: (_) => onChanged(NotifyFlags.none, customMinutes),
          title: const Text('🔕 Nessuna notifica'),
          contentPadding: EdgeInsets.zero,
          activeColor: theme.colorScheme.primary,
        ),
        const Divider(height: 8),
        ...NotifyFlags.all.map((flag) => Column(children: [
          CheckboxListTile(
            value: NotifyFlags.has(flags, flag),
            onChanged: (_) => onChanged(
              NotifyFlags.toggle(flags, flag),
              customMinutes,
            ),
            title: Text('${NotifyFlags.emoji(flag)} ${NotifyFlags.label(flag)}'),
            contentPadding: EdgeInsets.zero,
            activeColor: theme.colorScheme.primary,
          ),
          // Campo minuti personalizzati
          if (flag == NotifyFlags.custom && NotifyFlags.has(flags, flag))
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Row(children: [
                const Text('Minuti prima: ', style: TextStyle(fontSize: 15)),
                SizedBox(
                  width: 80,
                  child: TextFormField(
                    initialValue: '$customMinutes',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => onChanged(flags, int.tryParse(v) ?? 30),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
              ]),
            ),
        ])),
      ]),
    );
  }
}

// ── Ricorrenza ───────────────────────────────────
class _RecurrencePicker extends StatelessWidget {
  final bool isRecurring;
  final String? rule;
  final void Function(bool, String?) onChanged;
  const _RecurrencePicker({required this.isRecurring, required this.rule,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(
        value: isRecurring,
        onChanged: (v) => onChanged(v, rule),
        title: const Text('Ripeti questo evento'),
        contentPadding: EdgeInsets.zero,
      ),
      if (isRecurring)
        Wrap(spacing: 8, children: [
          ('Ogni giorno', 'daily'),
          ('Ogni settimana', 'weekly'),
          ('Ogni mese', 'monthly'),
          ('Ogni anno', 'yearly'),
        ].map((opt) => ChoiceChip(
          label: Text(opt.$1),
          selected: rule == opt.$2,
          onSelected: (v) => onChanged(isRecurring, v ? opt.$2 : null),
        )).toList()),
    ]);
  }
}
