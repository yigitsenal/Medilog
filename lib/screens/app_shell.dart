import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'home_screen.dart';
import 'medication_list_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'add_medication_screen.dart';
import 'statistics_screen.dart';
import '../services/notification_service.dart';
import '../services/database_helper.dart';
import '../services/localization_service.dart';
import '../widgets/banner_ad_widget.dart';

class AppShell extends StatefulWidget {
  final VoidCallback? onSettingsChanged;
  const AppShell({super.key, this.onSettingsChanged});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  final PageStorageBucket _bucket = PageStorageBucket();
  late List<Widget> _pages;
  int _pendingToday = 0;
  final GlobalKey<_AppShellState> _appShellKey = GlobalKey<_AppShellState>();

  @override
  void initState() {
    super.initState();
    _buildPages();
    _loadPendingCount();
  }

  void reloadHomeScreen() {
    // HomeScreen'i yeniden yüklemek için sayfayı yeniden oluştur
    if (_index == 0) {
      setState(() {
        _buildPages();
      });
    }
  }

  Future<void> _loadPendingCount() async {
    try {
      final db = DatabaseHelper();
      final logs = await db.getTodayLogs();
      final pending = logs.where((l) => !l.isTaken && !l.isSkipped).length;
      if (mounted) setState(() => _pendingToday = pending);
    } catch (_) {}
  }

  void _buildPages() {
    _pages = [
      HomeScreen(
        isEmbedded: true,
        onNavigateTab: (i) => setState(() => _index = i),
      ),
      MedicationListScreen(
        isEmbedded: true, 
        onBackToHome: () => setState(() => _index = 0),
        onMedicationUpdated: () {
          reloadHomeScreen();
          _loadPendingCount();
          setState(() {});
        },
      ),
      HistoryScreen(isEmbedded: true, onBackToHome: () => setState(() => _index = 0)),
      StatisticsScreen(isEmbedded: true, onBackToHome: () => setState(() => _index = 0)),
      SettingsScreen(onSettingsChanged: widget.onSettingsChanged, isEmbedded: true, onBackToHome: () => setState(() => _index = 0)),
    ];
  }

  Future<void> _onFabPressed() async {
    await _showFabMenu();
  }

  Future<void> _showFabMenu() async {
    final theme = Theme.of(context);
    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outlineVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Text(
                  AppLocalizations.of(context)!.translate('quick_operations'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildMenuOption(
                  context: context,
                  icon: Icons.add_circle_rounded,
                  title: AppLocalizations.of(context)!.translate('add_medication_title'),
                  subtitle: AppLocalizations.of(context)!.translate('add_new_medication_record'),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AddMedicationScreen()),
                    );
                    if (result == true && mounted) {
                      reloadHomeScreen();
                      await _loadPendingCount();
                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuOption(
                  context: context,
                  icon: Icons.alarm_add_rounded,
                  title: AppLocalizations.of(context)!.translate('quick_reminder_1min'),
                  subtitle: AppLocalizations.of(context)!.translate('reminder_in_1_minute'),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF56CCF2), Color(0xFF2F80ED)],
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final now = DateTime.now().add(const Duration(minutes: 1));
                    await NotificationService().scheduleQuickReminder(
                      scheduledTime: now,
                      title: AppLocalizations.of(context)!.translate('quick_reminder'),
                      body: AppLocalizations.of(context)!.translate('reminder_in_1_minute'),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white),
                              const SizedBox(width: 12),
                              Text(AppLocalizations.of(context)!.translate('reminder_set_for_1_minute')),
                            ],
                          ),
                          backgroundColor: const Color(0xFF2F80ED),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildMenuOption(
                  context: context,
                  icon: Icons.local_hospital_rounded,
                  title: AppLocalizations.of(context)!.translate('emergency_info'),
                  subtitle: AppLocalizations.of(context)!.translate('emergency_contact_numbers'),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(AppLocalizations.of(context)!.translate('emergency_112')),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.7),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navIcon(IconData icon, bool selected, {int badge = 0}) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: color),
        if (badge > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
              child: Text(
                badge > 9 ? '9+' : badge.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final destinations = [
      NavigationDestination(
        icon: _navIcon(Icons.home_outlined, _index == 0, badge: _pendingToday),
        selectedIcon: _navIcon(Icons.home_rounded, true, badge: _pendingToday),
        label: AppLocalizations.of(context)!.translate('home'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.medication_outlined),
        selectedIcon: const Icon(Icons.medication_rounded),
        label: AppLocalizations.of(context)!.translate('medications'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.history_outlined),
        selectedIcon: const Icon(Icons.history_rounded),
        label: AppLocalizations.of(context)!.translate('history'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.bar_chart_outlined),
        selectedIcon: const Icon(Icons.bar_chart_rounded),
        label: AppLocalizations.of(context)!.translate('statistics'),
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings_rounded),
        label: AppLocalizations.of(context)!.translate('settings'),
      ),
    ];

    final showFab = _index == 0 || _index == 1;

    return WillPopScope(
      onWillPop: () async {
        if (_index != 0) {
          setState(() => _index = 0);
          return false;
        }
        return true;
      },
      child: Scaffold(
        extendBody: true,
        body: SafeArea(
          child: PageStorage(
            bucket: _bucket,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: IndexedStack(key: ValueKey(_index), index: _index, children: _pages),
            ),
          ),
        ),
        floatingActionButton: showFab
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: FloatingActionButton.extended(
                  onPressed: _onFabPressed,
                  icon: const Icon(Icons.add_rounded, size: 26),
                  label: Text(
                    AppLocalizations.of(context)!.translate('add'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  elevation: 0,
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Banner reklam
              const BannerAdWidget(
                height: 50,
                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                showBorder: false,
              ),
              NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: colorScheme.surface,
                  indicatorColor: colorScheme.primary.withOpacity(0.15),
                  height: 70,
                  labelTextStyle: WidgetStateProperty.resolveWith(
                    (states) => TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: states.contains(WidgetState.selected)
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  iconTheme: WidgetStateProperty.resolveWith(
                    (states) => IconThemeData(
                      size: 26,
                      color: states.contains(WidgetState.selected)
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  destinations: destinations,
                  animationDuration: const Duration(milliseconds: 500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 