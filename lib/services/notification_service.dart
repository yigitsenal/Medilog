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

  Future<void> scheduleNotificationForMedication(Medication medication) async {
    if (!medication.isActive) return;

    for (String timeStr in medication.times) {
      await _scheduleRepeatingNotification(medication, timeStr);
    }
  }

  // İlaca ait tüm bildirimleri iptal et
  Future<void> cancelMedicationNotifications(int medicationId) async {
    // Bu ilaca ait tüm gelecekteki logları al
    final now = DateTime.now();
    final futureLogs = await _dbHelper.getLogsByMedicationId(medicationId);
    
    // Her log için bildirimi iptal et
    for (var log in futureLogs) {
      if (log.id != null && log.scheduledTime.isAfter(now)) {
        await _notifications.cancel(log.id!);
      }
    }
  }

  // Yeni metod: Sürekli döngü için günlük ilaç loglarını oluştur
  Future<void> createDailyMedicationLogs({
    String medicationTimeText = 'İlaç Zamanı',
    String onEmptyStomachText = ' - Aç karına',
    String withFoodText = ' - Tok karına',
  }) async {
    List<Medication> activeMedications = await _dbHelper.getActiveMedications();
    DateTime today = DateTime.now();

    for (Medication medication in activeMedications) {
      if (medication.id == null) continue; // Null ID kontrolü

      // Bugün için zaten log var mı kontrol et
      bool todayLogsExist = await _checkIfTodayLogsExist(medication.id!, today);

      if (!todayLogsExist) {
        // Bugün için logları oluştur
        await _createLogsForDate(medication, today);
      }

      // Yarın için de logları oluştur (önceden hazırlık)
      DateTime tomorrow = today.add(const Duration(days: 1));
      bool tomorrowLogsExist = await _checkIfTodayLogsExist(
        medication.id!,
        tomorrow,
      );

      if (!tomorrowLogsExist) {
        await _createLogsForDate(medication, tomorrow);
      }
    }
  }

  // Belirli bir ilaç için bugün ve yarın için logları oluştur (güncelleme sonrası)
  Future<void> createLogsForMedication(Medication medication) async {
    final DateTime today = DateTime.now();
    final DateTime tomorrow = today.add(const Duration(days: 1));
    
    // Bugün için logları oluştur
    await _createLogsForDate(medication, today);
    
    // Yarın için logları oluştur
    await _createLogsForDate(medication, tomorrow);
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

  Future<void> _createLogsForDate(Medication medication, DateTime date) async {
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

      // Bu saatte zaten log var mı kontrol et
      final existingLogs = await _dbHelper.getLogsByDateRange(
        scheduledTime,
        scheduledTime,
      );
      
      // Aynı ilaç ve aynı saat için log varsa skip et
      final duplicateExists = existingLogs.any((log) => 
          log.medicationId == medication.id && 
          log.scheduledTime == scheduledTime);
      
      if (duplicateExists) {
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
        await _scheduleNotificationForLog(medication, log.copyWith(id: logId));
      }
    }
  }

  Future<void> _scheduleNotificationForLog(
    Medication medication,
    MedicationLog log,
  ) async {
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
          stomachText = ' - Aç karına';
          break;
        case 'full':
          stomachText = ' - Tok karına';
          break;
        default:
          stomachText = '';
      }

      await _notifications.zonedSchedule(
        log.id!,
        'İlaç Zamanı',
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

  Future<void> _scheduleRepeatingNotification(
    Medication medication,
    String timeStr,
  ) async {
    // Bu metod artık sadece yeni eklenen ilaçlar için kullanılacak
    // Günlük döngü için createDailyMedicationLogs metodunu kullanacağız
    DateTime today = DateTime.now();
    await _createLogsForDate(medication, today);

    // Yarın için de hazırlık
    DateTime tomorrow = today.add(const Duration(days: 1));
    await _createLogsForDate(medication, tomorrow);
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

  // Schedule a quick reminder notification
  Future<void> scheduleQuickReminder({
    required DateTime scheduledTime,
    required String title,
    required String body,
  }) async {
    try {
      // Convert to TZDateTime
      tz.TZDateTime scheduledTZ = tz.TZDateTime.from(
        scheduledTime,
        tz.local,
      );

      // Use a unique ID based on timestamp to avoid conflicts
      int notificationId = scheduledTime.millisecondsSinceEpoch % 100000000;

      await _notifications.zonedSchedule(
        notificationId,
        title,
        body,
        scheduledTZ,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'quick_reminders',
            'Quick Reminders',
            channelDescription: 'Quick reminder notifications',
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
      );
    } catch (e) {
      // Error scheduling quick reminder
      rethrow;
    }
  }
}
