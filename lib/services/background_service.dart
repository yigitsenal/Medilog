import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'notification_service.dart';
import 'database_helper.dart';

// Top-level callback fonksiyon (static class içinde olamaz)
@pragma('vm:entry-point')
Future<void> dailyMedicationTask() async {
  print('🔔 [Background] Günlük ilaç görev çalışıyor: ${DateTime.now()}');

  try {
    // DatabaseHelper'ı initialize et
    DatabaseHelper();

    final notificationService = NotificationService();
    await notificationService.initialize();

    // Günlük logları oluştur
    await notificationService.createDailyMedicationLogs();

    print('✅ [Background] Günlük görev tamamlandı');
  } catch (e) {
    print('❌ [Background] Hata: $e');
  }
}

class BackgroundService {
  static const int dailyTaskId = 0;

  // Servisi başlat
  static Future<void> initialize() async {
    try {
      await AndroidAlarmManager.initialize();
      print('✅ Alarm Manager başlatıldı');
    } catch (e) {
      print('❌ Alarm Manager başlatma hatası: $e');
    }
  }

  // Günlük tekrarlayan görevi zamanla
  static Future<void> scheduleDailyTask() async {
    try {
      // Her gün saat 00:05'te çalışacak
      final now = DateTime.now();
      final scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        0, // Saat
        5, // Dakika
      );

      // Eğer bugünün saati geçmişse, yarın için zamanla
      final nextRun = scheduledTime.isBefore(now)
          ? scheduledTime.add(const Duration(days: 1))
          : scheduledTime;

      // Günlük tekrarlayan görev
      await AndroidAlarmManager.periodic(
        const Duration(days: 1),
        dailyTaskId,
        dailyMedicationTask,
        startAt: nextRun,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );

      print('✅ Günlük görev zamanlandı: ${nextRun}');

      // İlk görevi hemen çalıştır
      await dailyMedicationTask();
    } catch (e) {
      print('❌ Günlük görev zamanlama hatası: $e');
    }
  }

  // Görevi iptal et
  static Future<void> cancelDailyTask() async {
    try {
      await AndroidAlarmManager.cancel(dailyTaskId);
      print('✅ Günlük görev iptal edildi');
    } catch (e) {
      print('❌ Görev iptal hatası: $e');
    }
  }

  // Ek: Telefon yeniden başlatıldığında bildirimleri yeniden zamanla
  static Future<void> rescheduleAllNotifications() async {
    print('🔄 [Boot] Tüm bildirimler yeniden zamanlanıyor...');

    try {
      final notificationService = NotificationService();
      await notificationService.initialize();

      final dbHelper = DatabaseHelper();
      final medications = await dbHelper.getActiveMedications();

      for (var medication in medications) {
        await notificationService.scheduleNotificationForMedication(medication);
      }

      print(
        '✅ [Boot] ${medications.length} ilaç için bildirimler yeniden zamanlandı',
      );
    } catch (e) {
      print('❌ [Boot] Yeniden zamanlama hatası: $e');
    }
  }
}
