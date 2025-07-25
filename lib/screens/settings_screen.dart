import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../models/user_preferences.dart';
import '../services/settings_service.dart';
import '../services/location_service.dart'; // Konum servisini ekleyin

import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  
  const SettingsScreen({super.key, this.onSettingsChanged});

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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF00A8E8), Color(0xFF0077BE), Color(0xFF003459)],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildMainContent(),
                ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildUserProfileCard(),
                const SizedBox(height: 20),
                _buildSettingsGroups(),
                const SizedBox(height: 100), // Space for bottom navigation
              ],
            ),
          ),
        ),
      ],
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
        title: const Text(
          'Ayarlar',
          style: TextStyle(
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
                  'Medilog Kullanıcısı',
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
                    'Profili Düzenle',
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
        _buildSettingsGroup('Bildirimler', Icons.notifications, [
          _buildSwitchTile(
            'Bildirimler',
            'İlaç hatırlatıcıları al',
            _userPreferences?.notificationsEnabled ?? true,
            (value) => _updatePreferences(
              _userPreferences!.copyWith(notificationsEnabled: value),
            ),
          ),
          _buildListTile(
            'Erteleme Süresi',
            '${_userPreferences?.snoozeMinutes ?? 5} dakika',
            Icons.snooze,
            () => _showSnoozeDialog(),
          ),
          _buildListTile(
            'Bildirim Sesi',
            _userPreferences?.reminderTone ?? 'Varsayılan',
            Icons.music_note,
            () => _showReminderToneDialog(),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup('Görünüm', Icons.palette, [
          _buildSwitchTile(
            'Karanlık Mod',
            'Koyu tema kullan',
            _userPreferences?.darkMode ?? false,
            (value) =>
                _updatePreferences(_userPreferences!.copyWith(darkMode: value)),
          ),
          _buildListTile(
            'Dil',
            _getLanguageName(_userPreferences?.language ?? 'tr'),
            Icons.language,
            () => _showLanguageDialog(),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup('Konum', Icons.location_on, [
          _buildSwitchTile(
            'Evden Ayrılırken Hatırlat',
            'Konum tabanlı hatırlatıcıları etkinleştir',
            _isGeofenceEnabled,
            _toggleGeofence,
          ),
          _buildListTile(
            'Ev Konumunu Ayarla',
            'Hatırlatıcı için evinizi kaydedin',
            Icons.home,
            _setHomeLocation,
            isDestructive: _isSettingHome, // Butonun durumunu belirtmek için
          ),
          // --- TEST BUTONU ---
          _buildListTile(
            'Test Bildirimi Gönder',
            'Evden çıkış bildirimini test et',
            Icons.notification_important,
            () async {
              await _locationService.sendTestNotification();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Test bildirimi gönderildi.'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup('Veri ve Yedekleme', Icons.backup, [
          _buildListTile(
            'Yedekleme Sıklığı',
            _getBackupFrequencyName(
              _userPreferences?.backupFrequency ?? 'weekly',
            ),
            Icons.cloud_upload,
            () => _showBackupFrequencyDialog(),
          ),
          _buildListTile(
            'Verileri Dışa Aktar',
            'İlaç verilerini CSV olarak kaydet',
            Icons.file_download,
            () => _exportData(),
          ),
          _buildListTile(
            'Verileri İçe Aktar',
            'Yedek dosyasından geri yükle',
            Icons.file_upload,
            () => _importData(),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup('Raporlar', Icons.analytics, [
          _buildSwitchTile(
            'Haftalık Raporlar',
            'Haftalık uyum raporları al',
            _userPreferences?.weeklyReports ?? true,
            (value) => _updatePreferences(
              _userPreferences!.copyWith(weeklyReports: value),
            ),
          ),
          _buildSwitchTile(
            'Aylık Raporlar',
            'Aylık analiz raporları al',
            _userPreferences?.monthlyReports ?? true,
            (value) => _updatePreferences(
              _userPreferences!.copyWith(monthlyReports: value),
            ),
          ),
          _buildListTile(
            'Günlük Hedef',
            '%${_userPreferences?.dailyGoalCompliance ?? 80} uyum',
            Icons.track_changes,
            () => _showDailyGoalDialog(),
          ),
        ]),
        const SizedBox(height: 16),
        _buildSettingsGroup('Diğer', Icons.more_horiz, [
          _buildListTile(
            'Hakkında',
            'Uygulama bilgileri ve sürüm',
            Icons.info,
            () => _showAboutDialog(),
          ),
          _buildListTile(
            'Gizlilik Politikası',
            'Veri kullanım politikamızı görüntüle',
            Icons.privacy_tip,
            () => _showPrivacyPolicy(),
          ),
          _buildListTile(
            'Ayarları Sıfırla',
            'Tüm ayarları varsayılana döndür',
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
        return 'Türkçe';
      case 'en':
        return 'English';
      default:
        return 'Türkçe';
    }
  }

  String _getBackupFrequencyName(String frequency) {
    switch (frequency) {
      case 'never':
        return 'Hiçbir zaman';
      case 'daily':
        return 'Günlük';
      case 'weekly':
        return 'Haftalık';
      case 'monthly':
        return 'Aylık';
      default:
        return 'Haftalık';
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
        title: const Text('Profili Düzenle'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'İsim',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              _updatePreferences(
                _userPreferences!.copyWith(userName: nameController.text),
              );
              Navigator.pop(context);
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showSnoozeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Erteleme Süresi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int minutes in [1, 5, 10, 15, 30])
              ListTile(
                title: Text('$minutes dakika'),
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
    final toneNames = ['Varsayılan', 'Yumuşak', 'Alarm', 'Bildirim'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bildirim Sesi'),
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
        title: const Text('Dil Seçimi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Türkçe'),
              leading: Radio<String>(
                value: 'tr',
                groupValue: _userPreferences?.language,
                onChanged: (value) {
                  _updatePreferences(
                    _userPreferences!.copyWith(language: value),
                  );
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: const Text('English'),
              leading: Radio<String>(
                value: 'en',
                groupValue: _userPreferences?.language,
                onChanged: (value) {
                  _updatePreferences(
                    _userPreferences!.copyWith(language: value),
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

  void _showBackupFrequencyDialog() {
    final frequencies = ['never', 'daily', 'weekly', 'monthly'];
    final frequencyNames = ['Hiçbir zaman', 'Günlük', 'Haftalık', 'Aylık'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedekleme Sıklığı'),
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
        title: const Text('Günlük Uyum Hedefi'),
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
      applicationName: 'Medilog',
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
        const Text(
          'Medilog, ilaç takibi ve sağlık yönetimi için geliştirilmiş modern bir uygulamadır.',
        ),
        const SizedBox(height: 16),
        const Text('© 2024 Medilog Ekibi'),
      ],
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gizlilik Politikası'),
        content: const SingleChildScrollView(
          child: Text(
            'Medilog uygulaması, kullanıcıların gizliliğini korumayı taahhüt eder. '
            'Verileriniz yalnızca ilaç takibi amacıyla kullanılır ve üçüncü taraflarla paylaşılmaz. '
            'Tüm veriler cihazınızda güvenli şekilde saklanır.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ayarları Sıfırla'),
        content: const Text(
          'Tüm ayarları varsayılan değerlere döndürmek istediğinizden emin misiniz? '
          'Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _settingsService.resetToDefaults();
              await _loadUserPreferences();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ayarlar başarıyla sıfırlandı'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Sıfırla', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Veri dışa aktarma özelliği yakında eklenecek'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _importData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Veri içe aktarma özelliği yakında eklenecek'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}