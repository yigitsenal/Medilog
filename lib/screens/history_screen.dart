import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../models/medication_log.dart';
import '../services/database_helper.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<MedicationLog> _logs = [];
  Map<int, Medication> _medicationMap = {};
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  DateTimeRange? _selectedDateRange;

  late AnimationController _animationController;
  late AnimationController _statsAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _statsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _statsAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _statsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Tüm ilaçları yükle (geçmiş için aktif/pasif ayrımı yapmama)
      final medications = await _dbHelper.getAllMedications();
      _medicationMap = {for (var med in medications) med.id!: med};

      await _loadLogsForDate(_selectedDate);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Veriler yüklenirken hata oluştu: $e'),
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

  Future<void> _loadLogsForDate(DateTime date) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final logs = await _dbHelper.getLogsByDateRange(startOfDay, endOfDay);
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
      _animationController.forward();
      _statsAnimationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLogsForDateRange(DateTimeRange range) async {
    try {
      final logs = await _dbHelper.getLogsByDateRange(range.start, range.end);
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
      _animationController.forward();
      _statsAnimationController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
       
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _selectedDateRange = null;
        _isLoading = true;
      });
      _animationController.reset();
      _statsAnimationController.reset();
      await _loadLogsForDate(picked);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange:
          _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
       
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _isLoading = true;
      });
      _animationController.reset();
      _statsAnimationController.reset();
      await _loadLogsForDateRange(picked);
    }
  }

  void _clearDateRange() {
    setState(() {
      _selectedDateRange = null;
      _selectedDate = DateTime.now();
      _isLoading = true;
    });
    _animationController.reset();
    _statsAnimationController.reset();
    _loadLogsForDate(DateTime.now());
  }

  Map<String, List<MedicationLog>> _groupLogsByDate() {
    final Map<String, List<MedicationLog>> grouped = {};

    for (final log in _logs) {
      final dateKey = DateFormat('yyyy-MM-dd').format(log.scheduledTime);
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(log);
    }

    // Sort logs within each date group
    for (final dateKey in grouped.keys) {
      grouped[dateKey]!.sort(
        (a, b) => a.scheduledTime.compareTo(b.scheduledTime),
      );
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedLogs = _groupLogsByDate();
    final totalLogs = _logs.length;
    final takenLogs = _logs.where((log) => log.isTaken).length;
    final skippedLogs = _logs.where((log) => log.isSkipped).length;
    final pendingLogs = _logs
        .where((log) => !log.isTaken && !log.isSkipped)
        .length;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primary,
              Theme.of(context).colorScheme.secondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _buildContent(
                    groupedLogs,
                    totalLogs,
                    takenLogs,
                    skippedLogs,
                    pendingLogs,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'İlaç Geçmişi',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'İlaç kullanım kayıtlarınız',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.calendar_today,
                        color: Colors.white,
                      ),
                      onPressed: _selectDate,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.date_range, color: Colors.white),
                      onPressed: _selectDateRange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    Map<String, List<MedicationLog>> groupedLogs,
    int totalLogs,
    int takenLogs,
    int skippedLogs,
    int pendingLogs,
  ) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
            ),
            SizedBox(height: 16),
            Text(
              'Geçmiş yükleniyor...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildDateFilter(),
        if (totalLogs > 0)
          _buildStatistics(totalLogs, takenLogs, skippedLogs, pendingLogs),
        Expanded(child: _buildLogsList(groupedLogs)),
      ],
    );
  }

  Widget _buildDateFilter() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.calendar_today,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Görüntülenen Tarih',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedDateRange != null
                      ? '${DateFormat('d MMM y').format(_selectedDateRange!.start)} - ${DateFormat('d MMM y').format(_selectedDateRange!.end)}'
                      : DateFormat(
                          'd MMMM yyyy EEEE',
                          'tr_TR',
                        ).format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (_selectedDateRange != null)
            Container(
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: const Icon(Icons.clear, color: Colors.orange),
                onPressed: _clearDateRange,
                tooltip: 'Filtreyi Temizle',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatistics(
    int totalLogs,
    int takenLogs,
    int skippedLogs,
    int pendingLogs,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _slideAnimation.value,
            child: Row(
              children: [
                _buildStatCard(
                  'İçildi',
                  takenLogs,
                  Icons.check_circle,
                  Colors.green,
                  totalLogs > 0 ? (takenLogs / totalLogs) : 0,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Atlandı',
                  skippedLogs,
                  Icons.schedule,
                  Colors.orange,
                  totalLogs > 0 ? (skippedLogs / totalLogs) : 0,
                ),
                const SizedBox(width: 12),
                _buildStatCard(
                  'Bekliyor',
                  pendingLogs,
                  Icons.pending,
                  Colors.grey,
                  totalLogs > 0 ? (pendingLogs / totalLogs) : 0,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    int count,
    IconData icon,
    Color color,
    double percentage,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
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
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              count.toString(),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${(percentage * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 10,
                color: color.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList(Map<String, List<MedicationLog>> groupedLogs) {
    if (_logs.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: groupedLogs.keys.length,
        itemBuilder: (context, index) {
          final dateKey = groupedLogs.keys.elementAt(index);
          final logsForDate = groupedLogs[dateKey]!;
          final date = DateTime.parse(dateKey);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectedDateRange != null) ...[
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    DateFormat('d MMMM yyyy EEEE', 'tr_TR').format(date),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              ...logsForDate.map((log) => _buildLogItem(log)),
              const SizedBox(height: 16),
            ],
          );
        },
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
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.history,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Bu tarih için kayıt bulunamadı',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Farklı bir tarih seçerek geçmiş kayıtlarınızı görüntüleyebilirsiniz',
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLogItem(MedicationLog log) {
    final medication = _medicationMap[log.medicationId];
    if (medication == null) return const SizedBox.shrink();

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (log.isTaken) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'İçildi';
    } else if (log.isSkipped) {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
      statusText = 'Atlandı';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.pending;
      statusText = 'Bekliyor';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [statusColor, statusColor.withOpacity(0.7)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(statusIcon, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 16),
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
                  const SizedBox(height: 4),
                  Text(
                    'Doz: ${medication.dosage}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  Text(
                    'Saat: ${DateFormat('HH:mm').format(log.scheduledTime)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  if (medication.stomachCondition != 'either')
                    Text(
                      medication.stomachCondition == 'empty'
                          ? 'Aç karına'
                          : 'Tok karına',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (log.isTaken && log.takenTime != null)
                    Text(
                      'İçilme zamanı: ${DateFormat('HH:mm').format(log.takenTime!)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
