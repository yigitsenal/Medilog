import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medication_log.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';

class StatisticsScreen extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onBackToHome;
  const StatisticsScreen({super.key, this.isEmbedded = false, this.onBackToHome});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  List<MedicationLog> _allLogs = [];
  bool _isLoading = true;
  String _selectedPeriod = 'week'; // 'week', 'month', 'year'

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadStatistics();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final DateTime now = DateTime.now();
      DateTime startDate;

      switch (_selectedPeriod) {
        case 'week':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime(now.year, now.month - 1, now.day);
          break;
        case 'year':
          startDate = DateTime(now.year - 1, now.month, now.day);
          break;
        default:
          startDate = now.subtract(const Duration(days: 7));
      }

      final logs = await _dbHelper.getLogsByDateRange(startDate, now);

      setState(() {
        _allLogs = logs;
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
            content: Text(AppLocalizations.of(context)!.translate('error_loading_statistics') + ': $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEmbedded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('İstatistikler'),
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
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(opacity: _fadeAnimation, child: _buildMainContent()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('İstatistikler'), scrolledUnderElevation: 0),
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
          _buildPeriodSelector(),
          const SizedBox(height: 20),
          _buildOverviewCards(),
          const SizedBox(height: 20),
          _buildComplianceChart(),
          const SizedBox(height: 20),
          _buildDailyBreakdown(),
          const SizedBox(height: 20),
          _buildMedicationBreakdown(),
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
          AppLocalizations.of(context)!.translate('statistics'),
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

  Widget _buildPeriodSelector() {
    final loc = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildPeriodButton(loc?.translate('last_7_days') ?? 'Son 7 Gün', 'week'),
          _buildPeriodButton(loc?.translate('last_month') ?? 'Son Ay', 'month'),
          _buildPeriodButton(loc?.translate('last_year') ?? 'Son Yıl', 'year'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String title, String period) {
    final isSelected = _selectedPeriod == period;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPeriod = period;
          });
          _loadStatistics();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2D5E3E) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    final totalLogs = _allLogs.length;
    final takenLogs = _allLogs.where((log) => log.isTaken).length;
    final complianceRate = totalLogs > 0
        ? (takenLogs / totalLogs * 100).round()
        : 0;

    return Row(
      children: [
        Expanded(
          child: _buildOverviewCard(
            AppLocalizations.of(context)!.translate('total'),
            totalLogs.toString(),
            Icons.medication,
            const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            AppLocalizations.of(context)!.translate('taken'),
            takenLogs.toString(),
            Icons.check_circle,
            const Color(0xFF4CAF50),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildOverviewCard(
            AppLocalizations.of(context)!.translate('compliance'),
            '%$complianceRate',
            Icons.trending_up,
            const Color(0xFF9C27B0),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
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
    );
  }

  Widget _buildComplianceChart() {
    final totalLogs = _allLogs.length;
    final takenLogs = _allLogs.where((log) => log.isTaken).length;
    final skippedLogs = _allLogs.where((log) => log.isSkipped).length;
    final pendingLogs = totalLogs - takenLogs - skippedLogs;

    final takenPercentage = totalLogs > 0 ? takenLogs / totalLogs : 0.0;
    final skippedPercentage = totalLogs > 0 ? skippedLogs / totalLogs : 0.0;
    final pendingPercentage = totalLogs > 0 ? pendingLogs / totalLogs : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            AppLocalizations.of(context)!.translate('compliance_analysis'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          // Simple progress bars instead of pie chart
          _buildProgressBar(
            AppLocalizations.of(context)!.translate('taken'),
            takenPercentage,
            const Color(0xFF4CAF50),
            takenLogs,
          ),
          const SizedBox(height: 12),
          _buildProgressBar(
            AppLocalizations.of(context)!.translate('skipped'),
            skippedPercentage,
            const Color(0xFFFF9800),
            skippedLogs,
          ),
          const SizedBox(height: 12),
          _buildProgressBar(
            AppLocalizations.of(context)!.translate('pending'),
            pendingPercentage,
            const Color(0xFF2196F3),
            pendingLogs,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(
    String label,
    double percentage,
    Color color,
    int count,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              '$count (${(percentage * 100).toStringAsFixed(1)}%)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percentage,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyBreakdown() {
    // Group logs by day
    final Map<DateTime, List<MedicationLog>> dailyLogs = {};

    for (final log in _allLogs) {
      final day = DateTime(
        log.scheduledTime.year,
        log.scheduledTime.month,
        log.scheduledTime.day,
      );
      dailyLogs[day] ??= [];
      dailyLogs[day]!.add(log);
    }

    final sortedDays = dailyLogs.keys.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            AppLocalizations.of(context)!.translate('daily_detail'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (sortedDays.isEmpty)
            Center(
              child: Text(
                AppLocalizations.of(context)!.translate('no_data_found_for_this_period'),
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...sortedDays.take(7).map((day) {
              final logs = dailyLogs[day]!;
              final taken = logs.where((log) => log.isTaken).length;
              final total = logs.length;
              final percentage = total > 0 ? taken / total : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        DateFormat('dd MMM').format(day),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage,
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$taken/$total',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMedicationBreakdown() {
    // Group logs by medication ID
    final Map<int, List<MedicationLog>> medicationLogs = {};

    for (final log in _allLogs) {
      medicationLogs[log.medicationId] ??= [];
      medicationLogs[log.medicationId]!.add(log);
    }

    return Container(
      padding: const EdgeInsets.all(20),
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
          Text(
            AppLocalizations.of(context)!.translate('medication_analysis'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (medicationLogs.isEmpty)
            Center(
              child: Text(
                AppLocalizations.of(context)!.translate('no_data_found_for_this_period'),
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...medicationLogs.entries.map((entry) {
              final logs = entry.value;
              final taken = logs.where((log) => log.isTaken).length;
              final total = logs.length;
              final percentage = total > 0 ? taken / total : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D5E3E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.medication,
                        size: 16,
                        color: Color(0xFF2D5E3E),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)!.translate('medication') + ' #${entry.key}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: percentage,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$taken/$total',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}
