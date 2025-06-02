class UserPreferences {
  final int? id;
  final String userName;
  final String userAvatar;
  final bool notificationsEnabled;
  final String reminderTone;
  final int snoozeMinutes;
  final bool darkMode;
  final String language;
  final bool biometricAuth;
  final bool showMedicationImages;
  final int dailyGoalCompliance;
  final bool weeklyReports;
  final bool monthlyReports;
  final String backupFrequency; // 'never', 'daily', 'weekly', 'monthly'
  final DateTime createdAt;
  final DateTime updatedAt;

  UserPreferences({
    this.id,
    required this.userName,
    this.userAvatar = '',
    this.notificationsEnabled = true,
    this.reminderTone = 'default',
    this.snoozeMinutes = 5,
    this.darkMode = false,
    this.language = 'tr',
    this.biometricAuth = false,
    this.showMedicationImages = true,
    this.dailyGoalCompliance = 80,
    this.weeklyReports = true,
    this.monthlyReports = true,
    this.backupFrequency = 'weekly',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userName': userName,
      'userAvatar': userAvatar,
      'notificationsEnabled': notificationsEnabled ? 1 : 0,
      'reminderTone': reminderTone,
      'snoozeMinutes': snoozeMinutes,
      'darkMode': darkMode ? 1 : 0,
      'language': language,
      'biometricAuth': biometricAuth ? 1 : 0,
      'showMedicationImages': showMedicationImages ? 1 : 0,
      'dailyGoalCompliance': dailyGoalCompliance,
      'weeklyReports': weeklyReports ? 1 : 0,
      'monthlyReports': monthlyReports ? 1 : 0,
      'backupFrequency': backupFrequency,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserPreferences.fromMap(Map<String, dynamic> map) {
    return UserPreferences(
      id: map['id']?.toInt(),
      userName: map['userName'] ?? '',
      userAvatar: map['userAvatar'] ?? '',
      notificationsEnabled: (map['notificationsEnabled'] ?? 1) == 1,
      reminderTone: map['reminderTone'] ?? 'default',
      snoozeMinutes: map['snoozeMinutes']?.toInt() ?? 5,
      darkMode: (map['darkMode'] ?? 0) == 1,
      language: map['language'] ?? 'tr',
      biometricAuth: (map['biometricAuth'] ?? 0) == 1,
      showMedicationImages: (map['showMedicationImages'] ?? 1) == 1,
      dailyGoalCompliance: map['dailyGoalCompliance']?.toInt() ?? 80,
      weeklyReports: (map['weeklyReports'] ?? 1) == 1,
      monthlyReports: (map['monthlyReports'] ?? 1) == 1,
      backupFrequency: map['backupFrequency'] ?? 'weekly',
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
    );
  }

  UserPreferences copyWith({
    int? id,
    String? userName,
    String? userAvatar,
    bool? notificationsEnabled,
    String? reminderTone,
    int? snoozeMinutes,
    bool? darkMode,
    String? language,
    bool? biometricAuth,
    bool? showMedicationImages,
    int? dailyGoalCompliance,
    bool? weeklyReports,
    bool? monthlyReports,
    String? backupFrequency,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderTone: reminderTone ?? this.reminderTone,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
      biometricAuth: biometricAuth ?? this.biometricAuth,
      showMedicationImages: showMedicationImages ?? this.showMedicationImages,
      dailyGoalCompliance: dailyGoalCompliance ?? this.dailyGoalCompliance,
      weeklyReports: weeklyReports ?? this.weeklyReports,
      monthlyReports: monthlyReports ?? this.monthlyReports,
      backupFrequency: backupFrequency ?? this.backupFrequency,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserPreferences(id: $id, userName: $userName, notificationsEnabled: $notificationsEnabled, darkMode: $darkMode)';
  }
}
