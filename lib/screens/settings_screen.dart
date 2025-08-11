import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/user_preferences.dart';
import '../services/settings_service.dart';
import '../services/location_service.dart'; // Konum servisini ekleyin
import '../services/localization_service.dart';
import '../main.dart';

import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  final bool isEmbedded;
  final VoidCallback? onBackToHome;
  
  const SettingsScreen({super.key, this.onSettingsChanged, this.isEmbedded = false, this.onBackToHome});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  final SettingsService _settingsService = SettingsService();
  final LocationService _locationService = LocationService(); // Konum servisini başlatın
  UserPreferences? _userPreferences;
  bool _isLoading = true;
  bool _isGeofenceEnabled = false;
  bool _isSettingHome = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadUserPreferences();
    _loadLocationSettings();
  }

  Future<void> _loadLocationSettings() async {
    final isEnabled = await _locationService.isGeofenceEnabled();
    setState(() {
      _isGeofenceEnabled = isEnabled;
    });
  }

  Future<void> _toggleGeofence(bool value) async {
    if (value) {
      // Konum iznini kontrol et
      var locationStatus = await Permission.location.status;
      if (locationStatus.isDenied || locationStatus.isPermanentlyDenied) {
        _showPermissionDialog(
          'Konum İzni Gerekiyor',
          'Evden ayrılma hatırlatıcısını kullanmak için lütfen konum izni verin.',
        );
        return;
      }

      // Fiziksel aktivite iznini kontrol et (Android)
      if (Theme.of(context).platform == TargetPlatform.android) {
        var activityStatus = await Permission.activityRecognition.status;
        if (activityStatus.isPermanentlyDenied) {
          _showPermissionDialog(
            'Fiziksel Aktivite İzni',
            'Bu özellik, pil kullanımını optimize etmek için fiziksel aktivite izninize ihtiyaç duyar. Lütfen uygulama ayarlarından bu izni etkinleştirin.',
          );
          return;
        }
      }
    }

    try {
      await _locationService.toggleGeofence(value);
      if (mounted) {
        setState(() {
          _isGeofenceEnabled = value;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value
                ? 'Konum hatırlatıcısı açıldı.'
                : 'Konum hatırlatıcısı kapatıldı.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPermissionDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Ayarları Aç'),
          ),
        ],
      ),
    );
  }

  Future<void> _setHomeLocation() async {
    setState(() {
      _isSettingHome = true;
    });
    try {
      await _locationService.setHomeLocation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ev konumu başarıyla ayarlandı!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Konum ayarlanırken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSettingHome = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final preferences = await _settingsService.getUserPreferences();
      setState(() {
        _userPreferences = preferences;
        _isLoading = false;
      });
      _animationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ayarlar yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updatePreferences(UserPreferences newPreferences) async {
    await _settingsService.saveUserPreferences(newPreferences);
    setState(() {
      _userPreferences = newPreferences;
    });
    if (mounted) {
      widget.onSettingsChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    if (widget.isEmbedded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ayarlar'),
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (widget.onBackToHome != null) {
                widget.onBackToHome!();
              } else {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildMainContent(),
                ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar'), scrolledUnderElevation: 0),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnimation,
              child: _buildMainContent(),
            ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildUserProfileCard(),
          const SizedBox(height: 20),
          _buildSettingsGroups(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      expandedHeight: 100,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.black87),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        title: Text(
          AppLocalizations.of(context)!.translate('settings'),
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00A8E8), Color(0xFF0077BE)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserProfileCard() {
    if (_userPreferences == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2D5E3E).withOpacity(0.1),
              border: Border.all(color: const Color(0xFF2D5E3E), width: 2),
            ),
            child: _userPreferences!.userAvatar.isNotEmpty
                ? ClipOval(
                    child: Image.asset(
                      _userPreferences!.userAvatar,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.person, size: 40, color: Color(0xFF2D5E3E)),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userPreferences!.userName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.translate('medilog_user'),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5E3E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.translate('edit_profile'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D5E3E),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _showEditProfileDialog,
            icon: const Icon(Icons.edit, color: Color(0xFF2D5E3E)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsGroups() {
    return Column(
      children: [
        _buildSettingsGroup(AppLocalizations.of(context)!.translate('notifications'), Icons.notifications, [
          _buildSwitchTile(
            AppLocalizations.of(context)!.translate('notifications'),
            AppLocalizations.of(context)!.translate('receive_medication_reminders'),
            _userPreferences?.notificationsEnabled ?? true,
            (value) => _updatePreferences(
              _userPreferences!.copyWith(notificationsEnabled: value),
            ),
          ),
          _buildListTile(
            AppLocalizations.of(context)!.translate('snooze_duration'),
            '${_userPreferences?.snoozeMinutes ?? 5} ${AppLocalizations.of(context)!.translate('minutes')}',
            Icons.snooze,
            () => _showSnoozeDialog(),
          ),
          _buildListTile(
            AppLocalizations.of(context)!.translate('notification_sound'),
            _userPreferences?.reminderTone ?? AppLocalizations.of(context)!.translate('default'),
            Icons.music_note,
            () => _showReminderToneDialog(),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup(AppLocalizations.of(context)!.translate('appearance'), Icons.palette, [
          _buildSwitchTile(
            AppLocalizations.of(context)!.translate('dark_mode'),
            AppLocalizations.of(context)!.translate('use_dark_theme'),
            _userPreferences?.darkMode ?? false,
            (value) =>
                _updatePreferences(_userPreferences!.copyWith(darkMode: value)),
          ),
          _buildListTile(
            AppLocalizations.of(context)!.translate('language'),
            _getLanguageName(_userPreferences?.language ?? 'tr'),
            Icons.language,
            () => _showLanguageDialog(),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup(AppLocalizations.of(context)!.translate('location'), Icons.location_on, [
          _buildSwitchTile(
            AppLocalizations.of(context)!.translate('remind_when_leaving_home'),
            AppLocalizations.of(context)!.translate('enable_location_based_reminders'),
            _isGeofenceEnabled,
            _toggleGeofence,
          ),
          _buildListTile(
            AppLocalizations.of(context)!.translate('set_home_location'),
            AppLocalizations.of(context)!.translate('save_home_for_reminders'),
            Icons.home,
            _setHomeLocation,
            isDestructive: _isSettingHome, // Butonun durumunu belirtmek için
          ),
          // --- TEST BUTONU ---
          _buildListTile(
            AppLocalizations.of(context)!.translate('send_test_notification'),
            AppLocalizations.of(context)!.translate('test_home_exit_notification'),
            Icons.notification_important,
            () async {
              await _locationService.sendTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.translate('test_notification_sent')),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup(AppLocalizations.of(context)!.translate('data_and_backup'), Icons.backup, [
          _buildListTile(
            AppLocalizations.of(context)!.translate('backup_frequency'),
            _getBackupFrequencyName(
              _userPreferences?.backupFrequency ?? 'weekly',
            ),
            Icons.cloud_upload,
            () => _showBackupFrequencyDialog(),
          ),
          _buildListTile(
            AppLocalizations.of(context)!.translate('export_data'),
            AppLocalizations.of(context)!.translate('save_medication_data_as_csv'),
            Icons.file_download,
            () => _exportData(),
          ),
          _buildListTile(
            AppLocalizations.of(context)!.translate('import_data'),
            AppLocalizations.of(context)!.translate('restore_from_backup_file'),
            Icons.file_upload,
            () => _importData(),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup(AppLocalizations.of(context)!.translate('reports'), Icons.analytics, [
          _buildSwitchTile(
            AppLocalizations.of(context)!.translate('weekly_reports'),
            AppLocalizations.of(context)!.translate('receive_weekly_compliance_reports'),
            _userPreferences?.weeklyReports ?? true,
            (value) => _updatePreferences(
              _userPreferences!.copyWith(weeklyReports: value),
            ),
          ),
          _buildSwitchTile(
            AppLocalizations.of(context)!.translate('monthly_reports'),
            AppLocalizations.of(context)!.translate('receive_monthly_analysis_reports'),
            _userPreferences?.monthlyReports ?? true,
            (value) => _updatePreferences(
              _userPreferences!.copyWith(monthlyReports: value),
            ),
          ),
          _buildListTile(
            AppLocalizations.of(context)!.translate('daily_goal'),
            '%${_userPreferences?.dailyGoalCompliance ?? 80} ${AppLocalizations.of(context)!.translate('compliance')}',
            Icons.track_changes,
            () => _showDailyGoalDialog(),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup(AppLocalizations.of(context)!.translate('other'), Icons.more_horiz, [
          _buildListTile(
            AppLocalizations.of(context)!.translate('about'),
            AppLocalizations.of(context)!.translate('app_information_and_version'),
            Icons.info,
            () => _showAboutDialog(),
          ),
          _buildListTile(
            AppLocalizations.of(context)!.translate('privacy_policy'),
            AppLocalizations.of(context)!.translate('view_our_data_usage_policy'),
            Icons.privacy_tip,
            () => _showPrivacyPolicy(),
          ),
          _buildListTile(
            AppLocalizations.of(context)!.translate('reset_settings'),
            AppLocalizations.of(context)!.translate('reset_all_settings_to_default'),
            Icons.restore,
            () => _showResetDialog(),
            isDestructive: true,
          ),
        ]),
      ],
    );
  }

  Widget _buildSettingsGroup(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D5E3E).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: const Color(0xFF2D5E3E), size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
      trailing: CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: const Color(0xFF2D5E3E),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildListTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDestructive ? Colors.red : Colors.black87,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : const Color(0xFF2D5E3E),
        size: 22,
      ),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'tr':
        return AppLocalizations.of(context)!.translate('turkish');
      case 'en':
        return AppLocalizations.of(context)!.translate('english');
      default:
        return AppLocalizations.of(context)!.translate('turkish');
    }
  }

  String _getBackupFrequencyName(String frequency) {
    switch (frequency) {
      case 'never':
        return AppLocalizations.of(context)!.translate('never');
      case 'daily':
        return AppLocalizations.of(context)!.translate('daily');
      case 'weekly':
        return AppLocalizations.of(context)!.translate('weekly');
      case 'monthly':
        return AppLocalizations.of(context)!.translate('monthly');
      default:
        return AppLocalizations.of(context)!.translate('weekly');
    }
  }

  // Dialog methods
  void _showEditProfileDialog() {
    final nameController = TextEditingController(
      text: _userPreferences?.userName,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('profile_edit')),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.translate('name'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              _updatePreferences(
                _userPreferences!.copyWith(userName: nameController.text),
              );
              Navigator.pop(context);
            },
            child: Text(AppLocalizations.of(context)!.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showSnoozeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('snooze_duration_selection')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int minutes in [1, 5, 10, 15, 30])
              ListTile(
                title: Text('$minutes ${AppLocalizations.of(context)!.translate('minutes')}'),
                leading: Radio<int>(
                  value: minutes,
                  groupValue: _userPreferences?.snoozeMinutes,
                  onChanged: (value) {
                    _updatePreferences(
                      _userPreferences!.copyWith(snoozeMinutes: value),
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showReminderToneDialog() {
    final tones = ['default', 'gentle', 'alarm', 'notification'];
    final toneNames = [AppLocalizations.of(context)!.translate('default'), AppLocalizations.of(context)!.translate('gentle'), AppLocalizations.of(context)!.translate('alarm'), AppLocalizations.of(context)!.translate('notification')];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('notification_sound_selection')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < tones.length; i++)
              ListTile(
                title: Text(toneNames[i]),
                leading: Radio<String>(
                  value: tones[i],
                  groupValue: _userPreferences?.reminderTone,
                  onChanged: (value) {
                    _updatePreferences(
                      _userPreferences!.copyWith(reminderTone: value),
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('language_selection')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(AppLocalizations.of(context)!.translate('turkish')),
              leading: Radio<String>(
                value: 'tr',
                groupValue: _userPreferences?.language,
                onChanged: (value) {
                  _updatePreferences(
                    _userPreferences!.copyWith(language: value),
                  );
                  MedilogApp.setLocale(context, const Locale('tr', ''));
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: Text(AppLocalizations.of(context)!.translate('english')),
              leading: Radio<String>(
                value: 'en',
                groupValue: _userPreferences?.language,
                onChanged: (value) {
                  _updatePreferences(
                    _userPreferences!.copyWith(language: value),
                  );
                  MedilogApp.setLocale(context, const Locale('en', ''));
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupFrequencyDialog() {
    final frequencies = ['never', 'daily', 'weekly', 'monthly'];
    final frequencyNames = [AppLocalizations.of(context)!.translate('never'), AppLocalizations.of(context)!.translate('daily'), AppLocalizations.of(context)!.translate('weekly'), AppLocalizations.of(context)!.translate('monthly')];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('backup_frequency_selection')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < frequencies.length; i++)
              ListTile(
                title: Text(frequencyNames[i]),
                leading: Radio<String>(
                  value: frequencies[i],
                  groupValue: _userPreferences?.backupFrequency,
                  onChanged: (value) {
                    _updatePreferences(
                      _userPreferences!.copyWith(backupFrequency: value),
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showDailyGoalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('daily_compliance_goal')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int percentage in [70, 80, 90, 95])
              ListTile(
                title: Text('%$percentage'),
                leading: Radio<int>(
                  value: percentage,
                  groupValue: _userPreferences?.dailyGoalCompliance,
                  onChanged: (value) {
                    _updatePreferences(
                      _userPreferences!.copyWith(dailyGoalCompliance: value),
                    );
                    Navigator.pop(context);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: AppLocalizations.of(context)!.translate('medilog'),
      applicationVersion: '1.0.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: const Color(0xFF2D5E3E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.medical_services,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        Text(
          AppLocalizations.of(context)!.translate('medilog_is_a_modern_app_for_medication_tracking'),
        ),
        const SizedBox(height: 16),
        Text(AppLocalizations.of(context)!.translate('medilog_team')),
      ],
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('privacy_policy')),
        content: SingleChildScrollView(
          child: Text(
            AppLocalizations.of(context)!.translate('privacy_policy_content'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.translate('ok')),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('reset_settings_confirmation')),
        content: Text(
          AppLocalizations.of(context)!.translate('are_you_sure_you_want_to_reset_all_settings'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _settingsService.resetToDefaults();
              await _loadUserPreferences();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.translate('settings_reset_successfully')),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: Text(AppLocalizations.of(context)!.translate('reset'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.translate('data_export_feature_coming_soon')),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _importData() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.translate('data_import_feature_coming_soon')),
        backgroundColor: Colors.orange,
      ),
    );
  }
}