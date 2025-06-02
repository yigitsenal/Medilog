import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'screens/home_screen.dart';

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

class MedilogApp extends StatelessWidget {
  const MedilogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medilog',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // Medical green
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        cardTheme: const CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
