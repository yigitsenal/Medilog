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
import 'services/localization_service.dart';

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

  runApp(MedilogApp(key: MedilogApp.appKey));
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
  static final GlobalKey<_MedilogAppState> appKey = GlobalKey<_MedilogAppState>();

  static void setLocale(BuildContext context, Locale newLocale) {
    appKey.currentState?._setLocale(newLocale);
  }

  @override
  State<MedilogApp> createState() => _MedilogAppState();
}

class _MedilogAppState extends State<MedilogApp> {
  final SettingsService _settingsService = SettingsService();
  bool _darkMode = false;
  Locale _locale = const Locale('tr', 'TR');

  @override
  void initState() {
    super.initState();
    _loadTheme();
    _loadLocale();
  }

  Future<void> _loadTheme() async {
    final isDark = await _settingsService.isDarkModeEnabled;
    if (mounted) {
      setState(() {
        _darkMode = isDark;
      });
    }
  }

  Future<void> _loadLocale() async {
    try {
      final lang = await _settingsService.currentLanguage; // 'tr' | 'en'
      if (mounted) {
        setState(() {
          _locale = lang == 'en' ? const Locale('en', '') : const Locale('tr', 'TR');
        });
      }
    } catch (_) {}
  }

  void _handleSettingsChanged() async {
    await _loadTheme();
    await _loadLocale();
  }

  void _setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medilog',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', '')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppShell(onSettingsChanged: _handleSettingsChanged),
    );
  }
}
