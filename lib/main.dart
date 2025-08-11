import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'services/location_service.dart'; // Konum servisini ekleyin
import 'screens/app_shell.dart';
import 'theme/app_theme.dart';

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
  await notificationService.createDailyMedicationLogs();

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

  @override
  State<MedilogApp> createState() => _MedilogAppState();
}

class _MedilogAppState extends State<MedilogApp> {
  final SettingsService _settingsService = SettingsService();
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final isDark = await _settingsService.isDarkModeEnabled;
    if (mounted) {
      setState(() {
        _darkMode = isDark;
      });
    }
  }

  void _handleSettingsChanged() async {
    await _loadTheme();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medilog',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppShell(onSettingsChanged: _handleSettingsChanged),
    );
  }
}
