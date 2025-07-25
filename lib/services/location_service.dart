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
  bool _isServiceRunning = false;
  bool _listenersAdded = false;

  final _geofenceList = <Geofence>[];
  final _controller = StreamController<Geofence>.broadcast();

  // Localized notification texts
  String _notificationTitle = "İlaçlarınızı Unutmayın!";
  String _notificationBody = "Evden ayrılıyorsunuz. İlaçlarınızı yanınıza aldınız mı?";

  Stream<Geofence> get geofenceStream => _controller.stream;

  LocationService._internal() {
    _geofenceService = GeofenceService.instance.setup(
      interval: 5000,
      accuracy: 100,
      loiteringDelayMs: 60000,
      statusChangeDelayMs: 10000,
      useActivityRecognition: true,
      allowMockLocations: false,
      printDevLog: false,
      geofenceRadiusSortType: GeofenceRadiusSortType.DESC,
    );
    _addListeners();
  }

  void _addListeners() {
    if (_listenersAdded) return;
    _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
    _geofenceService.addLocationChangeListener(_onLocationChanged);
    _geofenceService.addLocationServicesStatusChangeListener(_onLocationServicesStatusChanged);
    _geofenceService.addActivityChangeListener(_onActivityChanged);
    _geofenceService.addStreamErrorListener(_onError);
    _listenersAdded = true;
  }

  Future<void> start() async {
    if (_isServiceRunning) {
      print("Geofence service is already running.");
      return;
    }
    
    await _updateGeofence();
    if (_geofenceList.isEmpty) {
      throw ('Ev konumu ayarlanmamış. Lütfen önce ev konumunuzu ayarlayın.');
    }

    try {
      await _geofenceService.start(_geofenceList);
      _isServiceRunning = true;
      print("Geofence service started successfully.");
    } catch (e) {
      print("Error starting geofence service: $e");
      _isServiceRunning = false; // Başlatma başarısız olursa durumu sıfırla
      // Hatanın UI tarafından yakalanabilmesi için tekrar fırlat
      throw e;
    }
  }

  Future<void> stop() async {
    if (!_isServiceRunning) {
      print("Geofence service is not running.");
      return;
    }
    await _geofenceService.stop();
    _isServiceRunning = false;
    print("Geofence service stopped.");
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
    print('geofence: ${geofence.toJson()}');
    print('geofenceStatus: ${geofenceStatus.toString()}');
    _controller.sink.add(geofence);

    if (geofenceStatus == GeofenceStatus.EXIT) {
      await _sendExitNotification();
    }
  }

  // Method to set localized notification texts
  void setNotificationTexts({
    required String title,
    required String body,
  }) {
    _notificationTitle = title;
    _notificationBody = body;
  }
  
  Future<void> _sendExitNotification({
    String? title,
    String? body,
  }) async {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      const androidPlatformChannelSpecifics = AndroidNotificationDetails(
          'geofence_notifications',
          'Geofence Notifications',
          channelDescription: 'Notifications for geofence events',
          importance: Importance.high,
          priority: Priority.high,
      );
      const notificationDetails = NotificationDetails(android: androidPlatformChannelSpecifics);
      await flutterLocalNotificationsPlugin.show(
        123, // Benzersiz bir id
        title ?? _notificationTitle,
        body ?? _notificationBody,
        notificationDetails,
      );
  }

  void _onLocationChanged(Location location) {
    // print('location: ${location.toJson()}');
  }

  void _onLocationServicesStatusChanged(bool status) {
    print('locationServicesStatus: $status');
  }

  void _onActivityChanged(Activity prevActivity, Activity currActivity) {
    print('currActivity: ${currActivity.toJson()}');
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
      throw('Konum servisleri kapalı.');
    }

    permission = await gl.Geolocator.checkPermission();
    if (permission == gl.LocationPermission.denied) {
      permission = await gl.Geolocator.requestPermission();
      if (permission == gl.LocationPermission.denied) {
        throw('Konum izinleri reddedildi.');
      }
    }

    if (permission == gl.LocationPermission.deniedForever) {
      throw('Konum izinleri kalıcı olarak reddedildi.');
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
      _geofenceList.add(Geofence(
        id: 'home',
        latitude: lat,
        longitude: lng,
        radius: [
          GeofenceRadius(id: 'home_radius', length: 200),
        ],
      ));
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