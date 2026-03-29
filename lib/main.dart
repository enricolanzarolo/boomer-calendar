import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'database/gestore_database.dart';
import 'servizi/servizio_notifiche.dart';
import 'servizi/servizio_backup.dart';
import 'stato/provider.dart';
import 'tema/tema_app.dart';
import 'schermate/schermata_principale.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initializeDateFormatting('it_IT', null);
  await DatabaseHelper.instance.database;
  await NotificationService.instance.init();

  // Controlla se serve fare un backup automatico mensile
  BackupService.instance.checkAutoBackup();

  runApp(const ProviderScope(child: MammaCalendarApp()));
}

class MammaCalendarApp extends ConsumerWidget {
  const MammaCalendarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'Il Mio Calendario',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
      locale: const Locale('it', 'IT'),
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
