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
    if (!medication.isActive || medication.id == null) return;

    final DateTime today = DateTime.now();
    final bool todayLogsExist = await _checkIfTodayLogsExist(medication.id!, today);

    // Bugün için zaten log varsa yeniden OLUŞTURMA; mevcut gelecekteki loglar için bildirimler zaten planlı.
    if (!todayLogsExist) {
      await _createLogsForDate(
        medication,
        today,
        medicationTimeText: medicationTimeText,
        onEmptyStomachText: onEmptyStomachText,
        withFoodText: withFoodText,
      );
    }

    // Yarın için de hazırlık sadece yoksa oluştur
    final DateTime tomorrow = today.add(const Duration(days: 1));
    final bool tomorrowLogsExist = await _checkIfTodayLogsExist(medication.id!, tomorrow);
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

  /// Re-create today's logs for the given medication using its latest definition.
  /// This keeps past taken/skipped logs intact by removing only pending logs first.
  Future<void> resyncTodaysLogsForMedication(Medication medication, {
    String? medicationTimeText,
    String? onEmptyStomachText,
    String? withFoodText,
  }) async {
    if (medication.id == null) return;
    final DateTime today = DateTime.now();

    // 1) Fetch today's logs and separate completed vs pending
    final List<MedicationLog> todaysLogs = await _dbHelper.getLogsForMedicationOnDate(medication.id!, today);
    final List<MedicationLog> completedLogs = todaysLogs.where((l) => l.isTaken || l.isSkipped).toList();
    final List<MedicationLog> pendingLogs = todaysLogs.where((l) => !l.isTaken && !l.isSkipped).toList();

    // 1.a) Remap completed logs' scheduled times to the closest new times so UI reflects new schedule
    if (completedLogs.isNotEmpty && medication.times.isNotEmpty) {
      // Build candidate DateTimes for today from new times
      final List<DateTime> newSlots = medication.times.map((t) {
        final parts = t.split(':');
        return DateTime(today.year, today.month, today.day, int.parse(parts[0]), int.parse(parts[1]));
      }).toList()
        ..sort((a, b) => a.compareTo(b));

      // Greedy matching by nearest time
      final Set<int> usedIndices = {};
      for (final log in completedLogs) {
        int? bestIdx;
        Duration bestDiff = const Duration(days: 365);
        for (int i = 0; i < newSlots.length; i++) {
          if (usedIndices.contains(i)) continue;
          final diff = (newSlots[i].difference(log.scheduledTime)).abs();
          if (diff < bestDiff) {
            bestDiff = diff;
            bestIdx = i;
          }
        }
        if (bestIdx != null) {
          usedIndices.add(bestIdx);
          final desiredTime = newSlots[bestIdx];
          if (desiredTime != log.scheduledTime) {
            final updated = log.copyWith(scheduledTime: desiredTime);
            await _dbHelper.updateMedicationLog(updated);
          }
        }
      }
    }

    // 2) Cancel notifications for pending logs and delete them
    for (final log in pendingLogs) {
      if (log.id != null) {
        await _notifications.cancel(log.id!);
      }
    }
    await _dbHelper.deletePendingLogsForMedicationOnDate(medication.id!, today);

    // 3) Determine how many logs should exist today according to new definition
    final int desiredCount = medication.times.length;
    final int completedCount = completedLogs.length;

    // 4) If today already has enough completed logs, don't create more
    final int toCreate = (desiredCount - completedCount).clamp(0, desiredCount);
    if (toCreate == 0) {
      return;
    }

    // Create logs only for time slots not already completed (up to toCreate)
    final Set<String> completedTimeStrings = completedLogs
        .map((l) => _formatHm(l.scheduledTime))
        .toSet();

    int created = 0;
    for (final timeStr in medication.times) {
      if (created >= toCreate) break;
      if (completedTimeStrings.contains(timeStr)) continue;

      // Build scheduled time for today
      final parts = timeStr.split(':');
      final int hour = int.parse(parts[0]);
      final int minute = int.parse(parts[1]);
      final DateTime scheduledTime = DateTime(today.year, today.month, today.day, hour, minute);

      final MedicationLog newLog = MedicationLog(
        medicationId: medication.id!,
        scheduledTime: scheduledTime,
      );
      final int newId = await _dbHelper.insertMedicationLog(newLog);

      // Schedule notification only for future times
      if (scheduledTime.isAfter(DateTime.now())) {
        await _scheduleNotificationForLog(
          medication,
          newLog.copyWith(id: newId),
          medicationTimeText: medicationTimeText,
          onEmptyStomachText: onEmptyStomachText,
          withFoodText: withFoodText,
        );
      }
      created++;
    }
  }

  String _formatHm(DateTime dt) {
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  // Hızlı tek seferlik hatırlatıcı (yalnızca bildirim gösterir)
  Future<void> scheduleQuickReminder({
    required DateTime scheduledTime,
    String title = 'Hatırlatıcı',
    String body = 'İlaç hatırlatıcısı',
  }) async {
    final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
    await _notifications.zonedSchedule(
      tzTime.millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      tzTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'quick_reminders',
          'Quick Reminders',
          channelDescription: 'Single-shot reminders',
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
  }
}
