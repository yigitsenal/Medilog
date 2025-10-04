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
    print('🔄 Günlük ilaç logları oluşturuluyor...');
    List<Medication> activeMedications = await _dbHelper.getActiveMedications();
    DateTime today = DateTime.now();

    for (Medication medication in activeMedications) {
      if (medication.id == null) continue; // Null ID kontrolü

      // Bugün için zaten log var mı kontrol et
      bool todayLogsExist = await _checkIfTodayLogsExist(medication.id!, today);

      if (!todayLogsExist) {
        // Bugün için logları oluştur
        print('📝 ${medication.name} için bugün logları oluşturuluyor...');
        await _createLogsForDate(medication, today);
      }

      // Yarın için de logları oluştur (önceden hazırlık)
      DateTime tomorrow = today.add(const Duration(days: 1));
      bool tomorrowLogsExist = await _checkIfTodayLogsExist(
        medication.id!,
        tomorrow,
      );

      if (!tomorrowLogsExist) {
        print('📝 ${medication.name} için yarın logları oluşturuluyor...');
        await _createLogsForDate(medication, tomorrow);
      }
    }

    // Mevcut loglar için bildirimlerin zamanlanıp zamanlanmadığını kontrol et
    await _verifyScheduledNotifications();

    print('✅ Günlük log oluşturma tamamlandı');
  }

  // Yeni metod: Mevcut loglar için bildirimlerin olup olmadığını kontrol et
  Future<void> _verifyScheduledNotifications() async {
    print('🔍 Bildirimleri doğrulanıyor...');

    // Bugünden itibaren gelecekteki tüm logları al
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 2));
    final logs = await _dbHelper.getLogsByDateRange(now, tomorrow);

    // Bekleyen bildirimleri al
    final pendingNotifications = await _notifications
        .pendingNotificationRequests();
    final pendingIds = pendingNotifications.map((n) => n.id).toSet();

    print('📊 Toplam log sayısı: ${logs.length}');
    print('📊 Bekleyen bildirim sayısı: ${pendingNotifications.length}');

    // Alınmamış ve atlanmamış loglar için bildirimleri kontrol et
    for (var log in logs) {
      if (log.id == null || log.isTaken || log.isSkipped) continue;
      if (log.scheduledTime.isBefore(now)) continue; // Geçmiş logları atla

      // Bu log için bildirim var mı?
      if (!pendingIds.contains(log.id)) {
        print(
          '⚠️ Eksik bildirim bulundu! Log ID: ${log.id}, Zaman: ${log.scheduledTime}',
        );

        // İlacı bul ve bildirimi yeniden zamanla
        final medication = await _dbHelper.getMedication(log.medicationId);
        if (medication != null) {
          await _scheduleNotificationForLog(medication, log);
          print('🔧 Bildirim yeniden zamanlandı: ${medication.name}');
        }
      }
    }

    print('✅ Bildirim doğrulama tamamlandı');
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
      if (timeParts.length != 2) continue; // Geçersiz format

      int hour = int.tryParse(timeParts[0]) ?? 0;
      int minute = int.tryParse(timeParts[1]) ?? 0;

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
      final duplicateExists = existingLogs.any(
        (log) =>
            log.medicationId == medication.id &&
            log.scheduledTime == scheduledTime,
      );

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
        print(
          '📅 Log oluşturuldu ve bildirim zamanlandı: ${medication.name} - $scheduledTime',
        );
      } else {
        print(
          '⏭️ Geçmiş log oluşturuldu (bildirim yok): ${medication.name} - $scheduledTime',
        );
      }
    }
  }

  Future<void> _scheduleNotificationForLog(
    Medication medication,
    MedicationLog log,
  ) async {
    if (log.id == null) return; // Null ID kontrolü

    try {
      // Geçmiş zaman kontrolü - sadece gelecekteki zamanlar için bildirim
      if (log.scheduledTime.isBefore(DateTime.now())) {
        print('⏰ Bildirim zamanlanamadı: Geçmiş zaman (${log.scheduledTime})');
        return;
      }

      // Convert to TZDateTime - local timezone kullan
      final location = tz.local;
      tz.TZDateTime scheduledTZ = tz.TZDateTime(
        location,
        log.scheduledTime.year,
        log.scheduledTime.month,
        log.scheduledTime.day,
        log.scheduledTime.hour,
        log.scheduledTime.minute,
      );

      // Double-check: TZDateTime gelecekte mi?
      if (scheduledTZ.isBefore(tz.TZDateTime.now(location))) {
        print('⏰ Bildirim zamanlanamadı: TZDateTime geçmiş (${scheduledTZ})');
        return;
      }

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
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            playSound: true,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: log.id.toString(),
      );

      print('✅ Bildirim zamanlandı: ${medication.name} - ${scheduledTZ}');
    } catch (e) {
      print('❌ Bildirim zamanlama hatası: $e');
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
      final location = tz.local;
      tz.TZDateTime scheduledTZ = tz.TZDateTime(
        location,
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        scheduledTime.hour,
        scheduledTime.minute,
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
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );

      print('✅ Hızlı hatırlatıcı zamanlandı: $scheduledTZ');
    } catch (e) {
      print('❌ Hızlı hatırlatıcı hatası: $e');
      // Error scheduling quick reminder
      rethrow;
    }
  }

  // Debug metodu: Bekleyen bildirimleri listele
  Future<void> printPendingNotifications() async {
    try {
      final pendingNotifications = await _notifications
          .pendingNotificationRequests();
      print('📋 Bekleyen bildirim sayısı: ${pendingNotifications.length}');
      for (var notification in pendingNotifications) {
        print(
          '   - ID: ${notification.id}, Title: ${notification.title}, Body: ${notification.body}',
        );
      }
    } catch (e) {
      print('❌ Bekleyen bildirimler alınamadı: $e');
    }
  }

  // Test bildirimi gönder (anında)
  Future<void> sendTestNotification() async {
    try {
      await _notifications.show(
        999999,
        'Test Bildirimi',
        'Bildirimler çalışıyor! ✅',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'test_channel',
            'Test Notifications',
            channelDescription: 'Test notifications',
            importance: Importance.max,
            priority: Priority.max,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
      );
      print('✅ Test bildirimi gönderildi');
    } catch (e) {
      print('❌ Test bildirimi hatası: $e');
    }
  }
}
