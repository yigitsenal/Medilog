import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

class SettingsService {
  static const String _userNameKey = 'userName';
  static const String _userAvatarKey = 'userAvatar';
  static const String _notificationsEnabledKey = 'notificationsEnabled';
  static const String _reminderToneKey = 'reminderTone';
  static const String _snoozeMinutesKey = 'snoozeMinutes';
  static const String _darkModeKey = 'darkMode';
  static const String _languageKey = 'language';
  static const String _biometricAuthKey = 'biometricAuth';
  static const String _showMedicationImagesKey = 'showMedicationImages';
  static const String _dailyGoalComplianceKey = 'dailyGoalCompliance';
  static const String _weeklyReportsKey = 'weeklyReports';
  static const String _monthlyReportsKey = 'monthlyReports';
  static const String _backupFrequencyKey = 'backupFrequency';

  // Singleton pattern
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<UserPreferences> getUserPreferences() async {
    await initialize();

    return UserPreferences(
      userName: _prefs!.getString(_userNameKey) ?? 'Lay',
      userAvatar: _prefs!.getString(_userAvatarKey) ?? '',
      notificationsEnabled: _prefs!.getBool(_notificationsEnabledKey) ?? true,
      reminderTone: _prefs!.getString(_reminderToneKey) ?? 'default',
      snoozeMinutes: _prefs!.getInt(_snoozeMinutesKey) ?? 5,
      darkMode: _prefs!.getBool(_darkModeKey) ?? false,
      language: _prefs!.getString(_languageKey) ?? 'tr',
      biometricAuth: _prefs!.getBool(_biometricAuthKey) ?? false,
      showMedicationImages: _prefs!.getBool(_showMedicationImagesKey) ?? true,
      dailyGoalCompliance: _prefs!.getInt(_dailyGoalComplianceKey) ?? 80,
      weeklyReports: _prefs!.getBool(_weeklyReportsKey) ?? true,
      monthlyReports: _prefs!.getBool(_monthlyReportsKey) ?? true,
      backupFrequency: _prefs!.getString(_backupFrequencyKey) ?? 'weekly',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> saveUserPreferences(UserPreferences preferences) async {
    await initialize();

    await _prefs!.setString(_userNameKey, preferences.userName);
    await _prefs!.setString(_userAvatarKey, preferences.userAvatar);
    await _prefs!.setBool(
      _notificationsEnabledKey,
      preferences.notificationsEnabled,
    );
    await _prefs!.setString(_reminderToneKey, preferences.reminderTone);
    await _prefs!.setInt(_snoozeMinutesKey, preferences.snoozeMinutes);
    await _prefs!.setBool(_darkModeKey, preferences.darkMode);
    await _prefs!.setString(_languageKey, preferences.language);
    await _prefs!.setBool(_biometricAuthKey, preferences.biometricAuth);
    await _prefs!.setBool(
      _showMedicationImagesKey,
      preferences.showMedicationImages,
    );
    await _prefs!.setInt(
      _dailyGoalComplianceKey,
      preferences.dailyGoalCompliance,
    );
    await _prefs!.setBool(_weeklyReportsKey, preferences.weeklyReports);
    await _prefs!.setBool(_monthlyReportsKey, preferences.monthlyReports);
    await _prefs!.setString(_backupFrequencyKey, preferences.backupFrequency);
  }

  Future<void> updateUserName(String userName) async {
    await initialize();
    await _prefs!.setString(_userNameKey, userName);
  }

  Future<void> updateUserAvatar(String avatarPath) async {
    await initialize();
    await _prefs!.setString(_userAvatarKey, avatarPath);
  }

  Future<void> toggleNotifications(bool enabled) async {
    await initialize();
    await _prefs!.setBool(_notificationsEnabledKey, enabled);
  }

  Future<void> updateReminderTone(String tone) async {
    await initialize();
    await _prefs!.setString(_reminderToneKey, tone);
  }

  Future<void> updateSnoozeMinutes(int minutes) async {
    await initialize();
    await _prefs!.setInt(_snoozeMinutesKey, minutes);
  }

  Future<void> toggleDarkMode(bool enabled) async {
    await initialize();
    await _prefs!.setBool(_darkModeKey, enabled);
  }

  Future<void> updateLanguage(String language) async {
    await initialize();
    await _prefs!.setString(_languageKey, language);
  }

  Future<void> toggleBiometricAuth(bool enabled) async {
    await initialize();
    await _prefs!.setBool(_biometricAuthKey, enabled);
  }

  Future<void> updateDailyGoalCompliance(int percentage) async {
    await initialize();
    await _prefs!.setInt(_dailyGoalComplianceKey, percentage);
  }

  Future<void> updateBackupFrequency(String frequency) async {
    await initialize();
    await _prefs!.setString(_backupFrequencyKey, frequency);
  }

  Future<void> resetToDefaults() async {
    await initialize();
    await _prefs!.clear();
  }

  // Getter methods for quick access
  Future<bool> get isDarkModeEnabled async {
    await initialize();
    return _prefs!.getBool(_darkModeKey) ?? false;
  }

  Future<bool> get areNotificationsEnabled async {
    await initialize();
    return _prefs!.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<String> get currentLanguage async {
    await initialize();
    return _prefs!.getString(_languageKey) ?? 'tr';
  }

  Future<String> get userName async {
    await initialize();
    return _prefs!.getString(_userNameKey) ?? 'Lay';
  }
}
