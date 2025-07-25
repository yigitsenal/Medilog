import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/medication.dart';
import '../models/medication_log.dart';
import 'database_helper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
  }

  void _onNotificationTapped(NotificationResponse response) async {
    // Handle notification tap - mark medication as taken
    String? payload = response.payload;
    if (payload != null) {
      try {
        int logId = int.parse(payload);
        await markMedicationAsTaken(logId);
      } catch (e) {
        // Error parsing notification payload
      }
    }
  }

  Future<void> scheduleNotificationForMedication(
    Medication medication, {
    String? medicationTimeText,
    String? onEmptyStomachText,
    String? withFoodText,
  }) async {
    if (!medication.isActive) return;

    DateTime today = DateTime.now();
    await _createLogsForDate(
      medication,
      today,
      medicationTimeText: medicationTimeText,
      onEmptyStomachText: onEmptyStomachText,
      withFoodText: withFoodText,
    );

    // Yarın için de hazırlık
    DateTime tomorrow = today.add(const Duration(days: 1));
    await _createLogsForDate(
      medication,
      tomorrow,
      medicationTimeText: medicationTimeText,
      onEmptyStomachText: onEmptyStomachText,
      withFoodText: withFoodText,
    );
  }

  // Yeni metod: Sürekli döngü için günlük ilaç loglarını oluştur
  Future<void> createDailyMedicationLogs({
    String? medicationTimeText,
    String? onEmptyStomachText,
    String? withFoodText,
  }) async {
    List<Medication> activeMedications = await _dbHelper.getActiveMedications();
    DateTime today = DateTime.now();

    for (Medication medication in activeMedications) {
      if (medication.id == null) continue; // Null ID kontrolü

      // Bugün için zaten log var mı kontrol et
      bool todayLogsExist = await _checkIfTodayLogsExist(medication.id!, today);

      if (!todayLogsExist) {
        // Bugün için logları oluştur
        await _createLogsForDate(
          medication,
          today,
          medicationTimeText: medicationTimeText,
          onEmptyStomachText: onEmptyStomachText,
          withFoodText: withFoodText,
        );
      }

      // Yarın için de logları oluştur (önceden hazırlık)
      DateTime tomorrow = today.add(const Duration(days: 1));
      bool tomorrowLogsExist = await _checkIfTodayLogsExist(
        medication.id!,
        tomorrow,
      );

      if (!tomorrowLogsExist) {
        await _createLogsForDate(
          medication,
          tomorrow,
          medicationTimeText: medicationTimeText,
          onEmptyStomachText: onEmptyStomachText,
          withFoodText: withFoodText,
        );
      }
    }
  }

  Future<bool> _checkIfTodayLogsExist(int medicationId, DateTime date) async {
    DateTime startOfDay = DateTime(date.year, date.month, date.day);
    DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    List<MedicationLog> logs = await _dbHelper.getLogsByDateRange(
      startOfDay,
      endOfDay,
    );
    return logs.any((log) => log.medicationId == medicationId);
  }

  Future<void> _createLogsForDate(
    Medication medication,
    DateTime date, {
    String? medicationTimeText,
    String? onEmptyStomachText,
    String? withFoodText,
  }) async {
    if (medication.id == null) return; // Null ID kontrolü

    for (String timeStr in medication.times) {
      // Parse time string (assuming format like "08:00")
      List<String> timeParts = timeStr.split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);

      DateTime scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );

      // İlaç bitiş tarihini kontrol et
      if (medication.endDate != null &&
          scheduledTime.isAfter(medication.endDate!)) {
        continue;
      }

      // Log oluştur
      MedicationLog log = MedicationLog(
        medicationId: medication.id!,
        scheduledTime: scheduledTime,
      );

      int logId = await _dbHelper.insertMedicationLog(log);

      // Sadece gelecekteki zamanlar için bildirim programla
      if (scheduledTime.isAfter(DateTime.now())) {
        await _scheduleNotificationForLog(
          medication,
          log.copyWith(id: logId),
          medicationTimeText: medicationTimeText,
          onEmptyStomachText: onEmptyStomachText,
          withFoodText: withFoodText,
        );
      }
    }
  }

  Future<void> _scheduleNotificationForLog(
    Medication medication,
    MedicationLog log, {
    String? medicationTimeText,
    String? onEmptyStomachText,
    String? withFoodText,
  }) async {
    if (log.id == null) return; // Null ID kontrolü

    try {
      // Convert to TZDateTime
      tz.TZDateTime scheduledTZ = tz.TZDateTime.from(
        log.scheduledTime,
        tz.local,
      );

      String stomachText = '';
      switch (medication.stomachCondition) {
        case 'empty':
          stomachText = onEmptyStomachText ?? ' - Aç karına';
          break;
        case 'full':
          stomachText = withFoodText ?? ' - Tok karına';
          break;
        default:
          stomachText = '';
      }

      await _notifications.zonedSchedule(
        log.id!,
        medicationTimeText ?? 'İlaç Zamanı',
        '${medication.name} - ${medication.dosage}$stomachText',
        scheduledTZ,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'medication_reminders',
            'Medication Reminders',
            channelDescription: 'Notifications for medication reminders',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: log.id.toString(),
      );
    } catch (e) {
      // Error scheduling notification
    }
  }

  Future<void> cancelNotificationsForMedication(int medicationId) async {
    // Get all pending logs for this medication and cancel their notifications
    List<MedicationLog> logs = await _dbHelper.getMedicationLogs(medicationId);
    for (MedicationLog log in logs) {
      if (log.id != null && !log.isTaken && !log.isSkipped) {
        await _notifications.cancel(log.id!);
      }
    }
  }

  Future<void> markMedicationAsTaken(int logId) async {
    MedicationLog? log = await _dbHelper.getLogById(logId);
    if (log != null) {
      MedicationLog updatedLog = log.copyWith(
        isTaken: true,
        takenTime: DateTime.now(),
      );
      await _dbHelper.updateMedicationLog(updatedLog);
      await _notifications.cancel(logId);
    }
  }
}
