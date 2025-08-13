import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/localization_service.dart';
import 'screens/app_shell.dart';
 
 void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone data
  tz.initializeTimeZones();

  // Initialize date formatting for Turkish locale
  await initializeDateFormatting('tr_TR', null);

  // Request notification permissions
  await _requestNotificationPermissions();

  // Initialize notifications
  NotificationService notificationService = NotificationService();
  await notificationService.initialize();

  // Günlük ilaç loglarını oluştur (sürekli döngü için)
  // Use default Turkish values here as localization is not available yet
  await notificationService.createDailyMedicationLogs(
    medicationTimeText: 'İlaç Zamanı', // Will be updated when home screen loads
    onEmptyStomachText: ' - Aç karına',
    withFoodText: ' - Tok karına',
  );

  runApp(const MedilogApp());
}

Future<void> _requestNotificationPermissions() async {
  // Request notification permission
  PermissionStatus status = await Permission.notification.request();

  if (status != PermissionStatus.granted) {
    // User denied notification permission
    // App will still work but without notifications
  }

  // For Android 13+ (API 33+), also request exact alarm permission
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }
}

class MedilogApp extends StatefulWidget {
  const MedilogApp({super.key});

  static void setLocale(BuildContext context, Locale newLocale) {
    _MedilogAppState? state = context
        .findAncestorStateOfType<_MedilogAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<MedilogApp> createState() => _MedilogAppState();
}

class _MedilogAppState extends State<MedilogApp> {
  Locale? _locale;

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeLocale();
  }

  Future<void> _initializeLocale() async {
    final settingsService = SettingsService();
    await settingsService.initialize();
    final languageCode = await settingsService.currentLanguage;

    if (mounted) {
      setLocale(Locale(languageCode, ''));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medilog',
      theme: AppTheme.light(),
darkTheme: AppTheme.dark(),
themeMode: ThemeMode.light,
      locale: _locale,
      home: AppShell(),
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [const Locale('en', ''), const Locale('tr', '')],
      debugShowCheckedModeBanner: false,
    );
  }
}
