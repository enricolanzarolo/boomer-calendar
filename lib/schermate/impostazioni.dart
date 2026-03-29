import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../stato/provider.dart';
import '../servizi/servizio_backup.dart';
import '../servizi/servizio_notifiche.dart';
import 'tutorial.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final dailySummary = ref.watch(dailySummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ─── ASPETTO ──────────────────────────
          _Section(icon: '🎨', title: 'Aspetto', children: [
            SwitchListTile(
              value: isDark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              title: const Text('Tema scuro',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              subtitle: const Text('Cambia tra chiaro e scuro'),
              secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode,
                  color: theme.colorScheme.primary),
            ),
          ]),

          const SizedBox(height: 16),

          // ─── NOTIFICHE ────────────────────────
          _Section(icon: '🔔', title: 'Notifiche', children: [
            SwitchListTile(
              value: dailySummary,
              // Usa onChanged con il valore booleano diretto — fix bug toggle
              onChanged: (value) async {
                await ref.read(dailySummaryProvider.notifier).set(value);
                await NotificationService.instance
                    .scheduleDailySummary(enabled: value);
              },
              title: const Text('Riepilogo mattutino',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              subtitle: const Text('Ogni mattina alle 8:00'),
              secondary: Icon(Icons.wb_sunny_outlined,
                  color: theme.colorScheme.primary),
            ),
          ]),

          const SizedBox(height: 16),

          // ─── BACKUP ───────────────────────────
          _BackupSection(),

          const SizedBox(height: 16),

          // ─── CATEGORIE ────────────────────────
          _Section(icon: '🏷️', title: 'Le tue categorie', children: [
            Consumer(builder: (context, ref, _) {
              final catsAsync = ref.watch(categoriesProvider);
              return catsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Errore: $e'),
                data: (cats) => Column(children: cats.map((cat) =>
                  ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: cat.color, borderRadius: BorderRadius.circular(10)),
                      child: Center(child: Text(cat.icon ?? '●',
                          style: const TextStyle(fontSize: 18))),
                    ),
                    title: Text(cat.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text('Elimina categoria?', style: TextStyle(fontWeight: FontWeight.w700)),
                            content: Text('Eliminare "${cat.name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Sì, elimina'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) ref.read(categoriesProvider.notifier).remove(cat.id!);
                      },
                    ),
                  )).toList()),
              );
            }),
          ]),

          const SizedBox(height: 16),

          // ─── AIUTO ────────────────────────────
          _Section(icon: '❓', title: 'Aiuto', children: [
            ListTile(
              leading: Icon(Icons.help_outline, color: theme.colorScheme.primary),
              title: const Text('Come si usa l\'app?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              subtitle: const Text('Guida semplice passo passo'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const TutorialScreen())),
            ),
          ]),

          const SizedBox(height: 32),
          Center(child: Text('📅 Il Mio Calendario v1.0',
            style: TextStyle(fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.35)))),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Sezione Backup ───────────────────────────────
class _BackupSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<_BackupSection> {
  bool _loading = false;
  String? _status;
  DateTime? _lastBackup;

  @override
  void initState() {
    super.initState();
    _loadLastBackup();
  }

  Future<void> _loadLastBackup() async {
    final t = await BackupService.instance.getLastBackupTime();
    if (mounted) setState(() => _lastBackup = t);
  }

  Future<void> _doBackup() async {
    setState(() { _loading = true; _status = null; });
    if (!BackupService.instance.isSignedIn) {
      final ok = await BackupService.instance.signIn();
      if (!ok) {
        setState(() { _loading = false; _status = '❌ Accesso Google non riuscito'; });
        return;
      }
    }
    final result = await BackupService.instance.backup();
    await _loadLastBackup();
    setState(() {
      _loading = false;
      _status = switch (result) {
        BackupResult.success    => '✅ Backup salvato su Google Drive!',
        BackupResult.notSignedIn => '❌ Devi accedere con Google',
        BackupResult.error      => '❌ Errore durante il backup',
      };
    });
  }

  Future<void> _doRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ripristina backup?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'Attenzione! I dati attuali saranno sostituiti con quelli del backup. Continuare?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Annulla')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade600),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sì, ripristina'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() { _loading = true; _status = null; });
    if (!BackupService.instance.isSignedIn) {
      final ok = await BackupService.instance.signIn();
      if (!ok) {
        setState(() { _loading = false; _status = '❌ Accesso Google non riuscito'; });
        return;
      }
    }
    final result = await BackupService.instance.restore();
    setState(() {
      _loading = false;
      _status = switch (result) {
        RestoreResult.success        => '✅ Dati ripristinati!',
        RestoreResult.notSignedIn    => '❌ Devi accedere con Google',
        RestoreResult.noBackupFound  => '❌ Nessun backup trovato',
        RestoreResult.error          => '❌ Errore durante il ripristino',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Section(icon: '☁️', title: 'Backup Google Drive', children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('I tuoi dati vengono salvati automaticamente ogni mese su Google Drive.',
            style: TextStyle(fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6))),
          if (_lastBackup != null) ...[
            const SizedBox(height: 6),
            Text(
              'Ultimo backup: ${DateFormat('d MMM yyyy HH:mm', 'it_IT').format(_lastBackup!)}',
              style: TextStyle(fontSize: 13,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _doBackup,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('Salva backup'),
              )),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(
                onPressed: _doRestore,
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Ripristina'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              )),
            ]),
          if (_status != null) ...[
            const SizedBox(height: 10),
            Text(_status!,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                  color: _status!.contains('✅') ? Colors.green : Colors.red)),
          ],
          const SizedBox(height: 12),
        ]),
      ),
    ]);
  }
}

// ─── Widget Sezione ───────────────────────────────
class _Section extends StatelessWidget {
  final String icon, title;
  final List<Widget> children;
  const _Section({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text('$icon $title', style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        )),
      ),
      ...children,
    ]));
  }
}
