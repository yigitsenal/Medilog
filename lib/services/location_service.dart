import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:geolocator/geolocator.dart' as gl;
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  // Servisin bir örneğini ve durumunu yönetmek için singleton deseni kullanalım.
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;

  late final GeofenceService _geofenceService;
  late final FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isServiceRunning = false;
  bool _listenersAdded = false;
  bool _notificationsInitialized = false;

  final _geofenceList = <Geofence>[];
  final _controller = StreamController<Geofence>.broadcast();

  // Localized notification texts
  String _notificationTitle = "İlaçlarınızı Unutmayın!";
  String _notificationBody =
      "Evden ayrılıyorsunuz. İlaçlarınızı yanınıza aldınız mı?";

  Stream<Geofence> get geofenceStream => _controller.stream;

  LocationService._internal() {
    _notificationsPlugin = FlutterLocalNotificationsPlugin();
    _geofenceService = GeofenceService.instance.setup(
      interval: 5000,
      accuracy: 100,
      loiteringDelayMs: 60000,
      statusChangeDelayMs: 10000,
      useActivityRecognition: true,
      allowMockLocations: false,
      printDevLog: true, // Debug için true yaptık
      geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
    );
    _initializeNotifications();
    _addListeners();
  }

  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);
    _notificationsInitialized = true;
    print('✅ Location notification service initialized');
  }

  void _addListeners() {
    if (_listenersAdded) return;
    _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
    _geofenceService.addLocationChangeListener(_onLocationChanged);
    _geofenceService.addLocationServicesStatusChangeListener(
      _onLocationServicesStatusChanged,
    );
    _geofenceService.addActivityChangeListener(_onActivityChanged);
    _geofenceService.addStreamErrorListener(_onError);
    _listenersAdded = true;
  }

  Future<void> start() async {
    if (_isServiceRunning) {
      print("⚠️ Geofence servisi zaten çalışıyor.");
      return;
    }

    print('🚀 Geofence servisi başlatılıyor...');

    await _updateGeofence();
    if (_geofenceList.isEmpty) {
      print('❌ Ev konumu ayarlanmamış!');
      throw ('Ev konumu ayarlanmamış. Lütfen önce ev konumunuzu ayarlayın.');
    }

    try {
      await _geofenceService.start(_geofenceList);
      _isServiceRunning = true;
      print("✅ Geofence servisi başarıyla başlatıldı!");
      print("📍 İzlenen bölge sayısı: ${_geofenceList.length}");

      // Mevcut konumu logla
      try {
        final position = await gl.Geolocator.getCurrentPosition();
        print("📍 Mevcut konum: ${position.latitude}, ${position.longitude}");

        // Ev konumuna olan mesafeyi hesapla
        if (_geofenceList.isNotEmpty) {
          final home = _geofenceList.first;
          final distance = gl.Geolocator.distanceBetween(
            home.latitude,
            home.longitude,
            position.latitude,
            position.longitude,
          );
          print("📏 Eve uzaklık: ${distance.toStringAsFixed(0)}m");

          if (distance > 500) {
            print("⚠️ ŞU ANDA EV DIŞINDASINIZ! (>500m)");
          } else {
            print("✅ Şu anda ev içindesiniz (<500m)");
          }
        }
      } catch (e) {
        print("⚠️ Mevcut konum alınamadı: $e");
      }
    } catch (e) {
      print("❌ Geofence servisi başlatma hatası: $e");
      _isServiceRunning = false;
      throw e;
    }
  }

  Future<void> stop() async {
    if (!_isServiceRunning) {
      print("⚠️ Geofence servisi zaten durdurulmuş.");
      return;
    }
    await _geofenceService.stop();
    _isServiceRunning = false;
    print("🛑 Geofence servisi durduruldu.");
  }

  Future<void> toggleGeofence(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('geofence_enabled', value);

    if (value) {
      await start();
    } else {
      await stop();
    }
  }

  Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location,
  ) async {
    print('🌍 Geofence: ${geofence.toJson()}');
    print('📍 Status: ${geofenceStatus.toString()}');
    print('📏 Radius: ${geofenceRadius.id} - ${geofenceRadius.length}m');
    _controller.sink.add(geofence);

    if (geofenceStatus == GeofenceStatus.EXIT) {
      print('🚪 EVDEN ÇIKIŞ TESPİT EDİLDİ! Bildirim gönderiliyor...');
      await _sendExitNotification();
    } else if (geofenceStatus == GeofenceStatus.ENTER) {
      print('🏠 EVE GİRİŞ TESPİT EDİLDİ');
    } else if (geofenceStatus == GeofenceStatus.DWELL) {
      print('⏸️ GEOFENCE İÇİNDE BEKLEME');
    }
  }

  // Method to set localized notification texts
  void setNotificationTexts({required String title, required String body}) {
    _notificationTitle = title;
    _notificationBody = body;
  }

  Future<void> _sendExitNotification({String? title, String? body}) async {
    print('📬 Evden çıkış bildirimi gönderiliyor...');

    try {
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'geofence_notifications',
        'Konum Hatırlatıcıları',
        channelDescription: 'Evden ayrılırken ilaç hatırlatması',
        importance: Importance.max,
        priority: Priority.max,
        enableVibration: true,
        playSound: true,
        visibility: NotificationVisibility.public,
      );
      const iosPlatformChannelSpecifics = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );
      const notificationDetails = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iosPlatformChannelSpecifics,
      );

      await _notificationsPlugin.show(
        12345, // Benzersiz bir id
        title ?? _notificationTitle,
        body ?? _notificationBody,
        notificationDetails,
      );

      print('✅ Evden çıkış bildirimi başarıyla gönderildi!');
    } catch (e) {
      print('❌ Bildirim gönderme hatası: $e');
    }
  }

  void _onLocationChanged(Location location) {
    print('📍 Konum güncellendi: ${location.latitude}, ${location.longitude}');
  }

  void _onLocationServicesStatusChanged(bool status) {
    print('🔧 Konum servisleri durumu: ${status ? "AÇIK" : "KAPALI"}');
  }

  void _onActivityChanged(Activity prevActivity, Activity currActivity) {
    print('🏃 Aktivite değişti: ${prevActivity.type} → ${currActivity.type}');
    print('   Güven: ${currActivity.confidence}%');
  }

  void _onError(error) {
    final errorCode = getErrorCodesFromError(error);
    if (errorCode == null) {
      print('Undefined error: $error');
      return;
    }
    print('ErrorCode: $errorCode');
  }

  Future<void> setHomeLocation() async {
    bool serviceEnabled;
    gl.LocationPermission permission;

    serviceEnabled = await gl.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw ('Konum servisleri kapalı.');
    }

    permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        throw ('Konum izinleri reddedildi.');
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      throw ('Konum izinleri kalıcı olarak reddedildi.');
    }

    final position = await gl.Geolocator.getCurrentPosition();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('home_latitude', position.latitude);
    await prefs.setDouble('home_longitude', position.longitude);

    // Eğer servis zaten çalışıyorsa, yeni konumla yeniden başlat
    if (_isServiceRunning) {
      await stop();
      await start();
    }
  }

  Future<void> _updateGeofence() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('home_latitude');
    final lng = prefs.getDouble('home_longitude');

    _geofenceList.clear();
    if (lat != null && lng != null) {
      print('🏠 Ev konumu: $lat, $lng');
      print('📏 Geofence yarıçapı: 500m'); // Test için artırdık

      _geofenceList.add(
        Geofence(
          id: 'home',
          latitude: lat,
          longitude: lng,
          radius: [
            GeofenceRadius(id: 'home_radius_500m', length: 500), // 200m → 500m
          ],
        ),
      );

      print('✅ Geofence güncellendi: ${_geofenceList.length} bölge');
    } else {
      print('⚠️ Ev konumu henüz ayarlanmamış!');
    }
  }

  Future<bool> isGeofenceEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('geofence_enabled') ?? false;
  }

  Future<void> sendTestNotification() async {
    print('Sending test notification for geofence exit...');
    await _sendExitNotification();
    print('Test notification sent.');
  }
}
