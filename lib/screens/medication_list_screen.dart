import 'package:flutter/material.dart';
import '../models/medication.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import 'add_medication_screen.dart';
import 'home_screen.dart';
import '../services/localization_service.dart';

class MedicationListScreen extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onBackToHome;
  final VoidCallback? onMedicationUpdated;
  const MedicationListScreen({
    super.key,
    this.isEmbedded = false,
    this.onBackToHome,
    this.onMedicationUpdated,
  });

  @override
  State<MedicationListScreen> createState() => _MedicationListScreenState();
}

class _MedicationListScreenState extends State<MedicationListScreen>
    with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final NotificationService _notificationService = NotificationService();
  List<Medication> _medications = [];
  bool _isLoading = true;

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

    _loadMedications();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMedications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Sadece aktif ilaçları yükle
      final medications = await _dbHelper.getActiveMedications();
      // Ana ekrana haber ver
      widget.onMedicationUpdated?.call();
      setState(() {
        _medications = medications;
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
            content: Text('Veriler yüklenirken hata oluştu: $e'),
            backgroundColor: const Color(0xFF00A8E8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<void> _toggleMedicationStatus(Medication medication) async {
    try {
      final updatedMedication = medication.copyWith(
        isActive: !medication.isActive,
      );
      await _dbHelper.updateMedication(updatedMedication);

      if (updatedMedication.isActive) {
        await _notificationService.scheduleNotificationForMedication(
          updatedMedication,
        );
      } else {
        await _notificationService.cancelNotificationsForMedication(
          medication.id!,
        );
      }

      await _loadMedications();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedMedication.isActive
                  ? 'İlaç aktif edildi'
                  : 'İlaç devre dışı bırakıldı',
            ),
            backgroundColor: updatedMedication.isActive
                ? const Color(0xFF00A8E8)
                : const Color(0xFF0077BE),
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
            content: Text(
              AppLocalizations.of(context)!.translate('error_occurred') +
                  ': $e',
            ),
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

  Future<void> _deleteMedication(Medication medication) async {
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete, color: Colors.red),
            ),
            const SizedBox(width: 12),
            const Text('İlaç Sil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${medication.name} ilacını silmek istediğinize emin misiniz?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Silme seçenekleri:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Geçici Sil: İlaç gizlenir, geçmiş veriler korunur',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const Text(
              '• Kalıcı Sil: İlaç ve tüm veriler tamamen silinir',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('İptal'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.orange, Colors.orangeAccent],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, 'temporary'),
              child: const Text(
                'Geçici Sil',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.red, Colors.redAccent],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, 'permanent'),
              child: const Text(
                'Kalıcı Sil',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );

    if (action == null || action == 'cancel') return;

    try {
      await _notificationService.cancelNotificationsForMedication(
        medication.id!,
      );

      if (action == 'temporary') {
        // Geçici silme - sadece deaktif et
        await _dbHelper.deleteMedication(medication.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'İlaç geçici olarak silindi (geçmiş veriler korundu)',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } else if (action == 'permanent') {
        // Kalıcı silme - tüm verileri sil
        await _dbHelper.permanentlyDeleteMedication(medication.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('İlaç kalıcı olarak silindi'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }

      await _loadMedications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
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

  String _getFrequencyText(String frequency) {
    final l = AppLocalizations.of(context)!;
    final labels = {
      'daily': l.translate('once_a_day'),
      'twice_daily': l.translate('twice_a_day'),
      'three_times_daily': l.translate('three_times_a_day'),
      'weekly': l.translate('several_times_a_week'),
      'custom': l.translate('custom'),
    };
    return labels[frequency] ?? frequency;
  }

  String _getStomachText(String condition) {
    final l = AppLocalizations.of(context)!;
    final labels = {
      'either': l.translate('does_not_matter'),
      'empty': l.translate('empty_stomach'),
      'full': l.translate('full_stomach'),
    };
    return labels[condition] ?? condition;
  }

  Color _getMedicationColor(Medication medication) {
    if (!medication.isActive) return Colors.grey;

    // Different colors based on frequency
    switch (medication.frequency) {
      case 'daily':
        return const Color(0xFF2E7D32);
      case 'twice_daily':
        return const Color(0xFF1976D2);
      case 'three_times_daily':
        return const Color(0xFF7B1FA2);
      case 'weekly':
        return const Color(0xFFD84315);
      default:
        return const Color(0xFF455A64);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context)!.translate('medication_list'),
          ),
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
        body: _buildEmbeddedBody(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.translate('medication_list')),
      ),
      body: _buildEmbeddedBody(),
    );
  }

  Widget _buildEmbeddedBody() {
    return Column(children: [Expanded(child: _buildContent())]);
  }

  Widget _buildFab() {
    return FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddMedicationScreen()),
        ).then((_) => _loadMedications());
      },
      child: const Icon(Icons.add),
      tooltip: 'Yeni İlaç Ekle',
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.translate('medication_list'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_medications.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _loadMedications,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _medications.length,
          itemBuilder: (context, index) {
            final medication = _medications[index];
            return _buildMedicationCard(medication, index);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF6A1B9A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.medication_outlined,
              size: 80,
              color: Color(0xFF6A1B9A),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.translate('no_medications_added_yet'),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(
              context,
            )!.translate('click_plus_button_to_add_new_medication'),
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6A1B9A).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddMedicationScreen(),
                    ),
                  ).then((_) => _loadMedications());
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.translate('add_my_first_medication'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(Medication medication, int index) {
    final color = _getMedicationColor(medication);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AddMedicationScreen(medication: medication),
              ),
            ).then((_) {
              _loadMedications();
              widget.onMedicationUpdated?.call();
              HomeScreen.homeKey.currentState?.reloadToday();
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.7)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.medication,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            medication.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: medication.isActive
                                  ? Colors.black87
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context)!.translate('dosage') +
                                ': ${medication.dosage}',
                            style: TextStyle(
                              fontSize: 14,
                              color: medication.isActive
                                  ? Colors.grey[600]
                                  : Colors.grey[400],
                            ),
                          ),
                          Text(
                            _getFrequencyText(medication.frequency),
                            style: TextStyle(
                              fontSize: 14,
                              color: medication.isActive
                                  ? color
                                  : Colors.grey[400],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.inventory,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                AppLocalizations.of(
                                      context,
                                    )!.translate('stock') +
                                    ': ${medication.stock}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: medication.isActive
                                      ? Colors.grey[600]
                                      : Colors.grey[400],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.more_vert, color: Colors.grey[600]),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AddMedicationScreen(medication: medication),
                              ),
                            ).then((_) {
                              _loadMedications();
                              widget.onMedicationUpdated?.call();
                              // Force HomeScreen to reload today data
                              HomeScreen.homeKey.currentState?.reloadToday();
                            });
                            break;
                          case 'toggle':
                            _toggleMedicationStatus(medication);
                            break;
                          case 'delete':
                            _deleteMedication(medication);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                AppLocalizations.of(context)!.translate('edit'),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color:
                                      (medication.isActive
                                              ? Colors.orange
                                              : Colors.green)
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  medication.isActive
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: medication.isActive
                                      ? Colors.orange
                                      : Colors.green,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                AppLocalizations.of(context)!.translate(
                                  medication.isActive
                                      ? 'deactivate'
                                      : 'activate',
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.translate('delete'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (!medication.isActive) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.pause_circle_outline,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context)!.translate('disabled'),
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (medication.times.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.translate('usage_times'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: medication.times.map((time) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.8), color],
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          time,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.restaurant, color: Colors.grey[600], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _getStomachText(medication.stomachCondition),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const Spacer(),
                    if (medication.startDate != null ||
                        medication.endDate != null) ...[
                      Icon(
                        Icons.calendar_today,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${medication.startDate != null ? '${medication.startDate!.day}/${medication.startDate!.month}' : ''}'
                        '${medication.startDate != null && medication.endDate != null ? ' - ' : ''}'
                        '${medication.endDate != null ? '${medication.endDate!.day}/${medication.endDate!.month}' : ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),

                if (medication.notes != null &&
                    medication.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.note, color: Colors.grey[600], size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            medication.notes!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
