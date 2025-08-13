import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../models/medication_log.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../widgets/banner_ad_widget.dart';
import 'add_medication_screen.dart';
import 'medication_list_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'statistics_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/localization_service.dart';
import 'stock_details_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  final bool isEmbedded;
  final ValueChanged<int>? onNavigateTab;
  static final GlobalKey<_HomeScreenState> homeKey = GlobalKey<_HomeScreenState>();
  
  const HomeScreen({
    super.key,
    this.onSettingsChanged,
    this.isEmbedded = false,
    this.onNavigateTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();
  List<MedicationLog> _todayLogs = [];
  List<Medication> _medications = [];
  bool _isLoading = true;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // Public method to reload today's data from outside
  void reloadToday() {
    _loadTodayData();
  }

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _loadTodayData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _loadTodayData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Günlük ilaç loglarını oluştur (eksik olanları)
      await _notificationService.createDailyMedicationLogs();

      final logs = await _dbHelper.getTodayLogs();
      final medications = await _dbHelper.getActiveMedications();

      // Sadece aktif ilaçlara ait logları filtrele
      final activeMedicationIds = medications.map((med) => med.id).toSet();
      final filteredLogs = logs
          .where((log) => activeMedicationIds.contains(log.medicationId))
          .toList();

      setState(() {
        _todayLogs = filteredLogs;
        _medications = medications;
        _isLoading = false;
      });

      _fadeController.forward();
      _scaleController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veri yüklenirken hata oluştu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _markAsTaken(MedicationLog log) async {
    try {
      final updatedLog = log.copyWith(isTaken: true, takenTime: DateTime.now());
      await _dbHelper.updateMedicationLog(updatedLog);
      
      // İlaç içildiğinde stoktan düş
      await DatabaseHelper().decrementStock(log.medicationId);
      
      await _loadTodayData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('İlaç alındı olarak işaretlendi ✓ (Stok -1)'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _markAsSkipped(MedicationLog log) async {
    try {
      final updatedLog = log.copyWith(
        isSkipped: true,
        takenTime: DateTime.now(),
      );
      await _dbHelper.updateMedicationLog(updatedLog);
      await _loadTodayData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('İlaç atlandı olarak işaretlendi'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF00A8E8), Color(0xFF0077BE), Color(0xFF003459)],
      ),
    );

    final body = SafeArea(
      child: _isLoading
          ? _buildLoadingScreen()
          : FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: _buildMainContent(),
              ),
            ),
    );

    if (widget.isEmbedded) {
      return Scaffold(body: body);
    }

    return Scaffold(
      body: Container(
        decoration: gradient,
        child: body,
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildLoadingScreen() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            'Yükleniyor...',
            style: TextStyle(
              color: onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: _loadTodayData,
      color: Colors.white,
      backgroundColor: const Color(0xFF1E88E5),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            FutureBuilder<int>(
              future: DatabaseHelper().getLowStockCount(threshold: 3),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                if (count <= 0) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('Düşük stok uyarısı: $count ilaç kritik seviyede',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      TextButton(
                        onPressed: () => _openStockDetails(),
                        child: const Text('Detay'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            _buildTodaysSchedule(),
            const SizedBox(height: 30),
            _buildQuickStats(),
            const SizedBox(height: 30),
            _buildQuickActions(),
            const SizedBox(height: 20),
            // Banner reklam ekle
            const BannerAdWidget(
              height: 60,
              margin: EdgeInsets.symmetric(horizontal: 8),
              showBorder: true,
            ),
            const SizedBox(height: 100), // Space for FAB
          ],
        ),
      ),
    );
  }

  void _openStockDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockDetailsScreen()),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).languageCode == 'tr' ? 'tr_TR' : 'en_US';
    final formatter = DateFormat('d MMMM yyyy, EEEE', locale);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.medical_services,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.translate('medilog'),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context)!.translate('your_health_companion'),
                      style: TextStyle(
                        fontSize: 14,
                        color: onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(
                  formatter.format(now),
                  style: TextStyle(
                    fontSize: 16,
                    color: onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final takenCount = _todayLogs.where((log) => log.isTaken).length;
    final skippedCount = _todayLogs.where((log) => log.isSkipped).length;
    final pendingCount = _todayLogs
        .where((log) => !log.isTaken && !log.isSkipped)
        .length;

    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.translate('todays_status'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                AppLocalizations.of(context)!.translate('taken_status'),
                takenCount,
                Colors.green,
                Icons.check_circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                AppLocalizations.of(context)!.translate('skipped_status'),
                skippedCount,
                Colors.orange,
                Icons.cancel,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                AppLocalizations.of(context)!.translate('pending'),
                pendingCount,
                Colors.blue,
                Icons.access_time,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return AnimatedScale(
      duration: const Duration(milliseconds: 200),
      scale: 1.0,
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.translate('quick_actions'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                AppLocalizations.of(context)!.translate('send_test_notification'),
                Icons.alarm_add,
                Colors.teal,
                () => _showQuickReminderSheet(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                'Stock +1 / -1',
                Icons.inventory_2,
                Colors.indigo,
                () => _showStockQuickActions(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                AppLocalizations.of(context)!.translate('details'),
                Icons.local_hospital,
                Colors.purple,
                () => _openNearestPharmacy(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                AppLocalizations.of(context)!.translate('notifications_muted_hours').replaceFirst('{hours}', '1'),
                Icons.notifications_off,
                Colors.orange,
                () => _muteNotificationsFor(Duration(hours: 1)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showQuickReminderSheet() async {
    final theme = Theme.of(context);
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            runSpacing: 8,
            children: [
              Text(AppLocalizations.of(context)!.translate('send_test_notification'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final minutes in [1, 5, 10, 15])
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final now = DateTime.now().add(Duration(minutes: minutes));
                        await NotificationService().scheduleQuickReminder(
                          scheduledTime: now,
                          title: AppLocalizations.of(context)!.translate('send_test_notification'),
                          body: '$minutes dakika sonra hatırlatma',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$minutes dk sonraya hatırlatıcı kuruldu')),
                          );
                        }
                      },
                      child: Text('+$minutes dk'),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showStockQuickActions() async {
    if (_medications.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppLocalizations.of(context)!.translate('no_active_medication'))),
      );
      return;
    }

    // İlaç seçme dialog'u
    final selectedMedication = await showDialog<Medication>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.translate('select_medication')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _medications.length,
            itemBuilder: (context, index) {
              final med = _medications[index];
              return ListTile(
                leading: const Icon(Icons.medication),
                title: Text(med.name),
                subtitle: Text('Mevcut stok: ${med.stock}'),
                onTap: () => Navigator.pop(context, med),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
        ],
      ),
    );

    if (selectedMedication == null) return;

    // Stok güncelleme dialog'u (kapanmadan sayı güncellensin)
    await showDialog(
      context: context,
      builder: (dialogContext) {
        int current = selectedMedication.stock;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text('${selectedMedication.name} - ${AppLocalizations.of(context)!.translate('update_stock')}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(context)!.translate('current_stock').replaceFirst('{count}', current.toString())), 
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await DatabaseHelper().decrementStock(selectedMedication.id!);
                        if (mounted) {
                          setState(() => current = (current - 1).clamp(0, 1 << 31));
                          _loadTodayData();
                        }
                      },
                      icon: const Icon(Icons.remove),
                      label: const Text('-1'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await DatabaseHelper().incrementStock(selectedMedication.id!);
                        if (mounted) {
                          setState(() => current = current + 1);
                          _loadTodayData();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('+1'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(AppLocalizations.of(context)!.translate('close')),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openNearestPharmacy() async {
    final query = Uri.encodeComponent('eczane');
    final url = Uri.parse('https://www.google.com/maps/search/$query');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harita açılamadı')),
      );
    }
  }

  Future<void> _muteNotificationsFor(Duration duration) async {
    // Basit: kullanıcıya bilgi mesajı göster
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.translate('notifications_muted_hours').replaceFirst('{hours}', duration.inHours.toString()))),
    );
    // Not: Kalıcı uygulama sessize alma için OS-uyumlu ayarlar veya app içi flag kullanılabilir.
  }

  Widget _buildTodaysSchedule() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         Text(
          AppLocalizations.of(context)!.translate('todays_medications'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 15),
        if (_todayLogs.isEmpty)
          _buildEmptyState()
        else
          ..._todayLogs.map((log) => _buildMedicationCard(log)).toList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(
              Icons.medical_services_outlined,
              size: 60,
              color: Colors.blue[400],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Bugün İlaç Yok',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Henüz bugün için planlanmış ilaç bulunmuyor. İlaç eklemek için + butonuna dokunun.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(MedicationLog log) {
    // Aktif ilaçlar arasından bul (filtrelenmiş listede olduğu için bulunması garanti)
    final medication = _medications.firstWhere(
      (med) => med.id == log.medicationId,
    );

    Color cardColor = Colors.white;
    Color accentColor = Colors.blue;
    IconData statusIcon = Icons.schedule;
    String statusText = 'Bekliyor';

    if (log.isTaken) {
      accentColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'İçildi';
    } else if (log.isSkipped) {
      accentColor = Colors.orange;
      statusIcon = Icons.cancel;
      statusText = 'Atlandı';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Medication details can be shown here
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.medication,
                        color: accentColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medication.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          if (medication.dosage.isNotEmpty)
                            Text(
                              medication.dosage,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.inventory, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Text(
                                'Stok: ${medication.stock}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 16, color: accentColor),
                          const SizedBox(width: 6),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 18, color: Colors.grey[500]),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(log.scheduledTime),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(width: 20),
                    if (medication.stomachCondition != 'either')
                      Row(
                        children: [
                          Icon(
                            medication.stomachCondition == 'full'
                                ? Icons.restaurant
                                : Icons.no_meals,
                            size: 18,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            medication.stomachCondition == 'full'
                                ? 'Yemekle'
                                : 'Aç karnına',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (!log.isTaken && !log.isSkipped) ...[
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _markAsTaken(log),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('İçtim'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _markAsSkipped(log),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Atla'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.orange,
                            side: const BorderSide(color: Colors.orange),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddMedicationScreen(),
            ),
          );
          if (result == true) {
            _loadTodayData();
          }
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomAppBar(
        height: 85,
        color: Colors.transparent,
        elevation: 0,
        notchMargin: 8,
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Ana Sayfa', true, () {}),
            _buildNavItem(Icons.list_alt, 'İlaçlarım', false, () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MedicationListScreen(),
                ),
              ).then((_) => _loadTodayData());
            }),
            const SizedBox(width: 40), // Space for FAB
            _buildNavItem(Icons.history, 'Geçmiş', false, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            }),
            _buildNavItem(Icons.settings, 'Ayarlar', false, () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen(onSettingsChanged: widget.onSettingsChanged)),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return Flexible(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF1E88E5).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isActive ? const Color(0xFF1E88E5) : Colors.grey[600],
                size: 20,
              ),
              const SizedBox(height: 3),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFF1E88E5)
                        : Colors.grey[600],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
