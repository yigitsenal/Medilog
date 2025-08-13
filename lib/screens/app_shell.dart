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

  @override
  void initState() {
    super.initState();
    _buildPages();
    _loadPendingCount();
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
        key: HomeScreen.homeKey,
        isEmbedded: true,
        onNavigateTab: (i) => setState(() => _index = i),
      ),
      MedicationListScreen(
        isEmbedded: true, 
        onBackToHome: () => setState(() => _index = 0),
        onMedicationUpdated: () => setState(() {}),
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
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                  child: Icon(Icons.add, color: theme.colorScheme.primary),
                ),
                title: const Text('İlaç Ekle'),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddMedicationScreen()),
                  );
                  if (result == true) {
                    await _loadPendingCount();
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.secondary.withOpacity(0.12),
                  child: Icon(Icons.schedule, color: theme.colorScheme.secondary),
                ),
                title: const Text('Hızlı Hatırlatıcı (1 dk sonra)'),
                onTap: () async {
                  Navigator.pop(context);
                  final now = DateTime.now().add(const Duration(minutes: 1));
                  await NotificationService().scheduleQuickReminder(
                    scheduledTime: now,
                    title: 'Hızlı Hatırlatıcı',
                    body: '1 dakika sonra hatırlatma',
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('1 dakika sonraya hatırlatıcı ayarlandı')),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
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
        selectedIcon: _navIcon(Icons.home, true, badge: _pendingToday),
        label: AppLocalizations.of(context)!.translate('home'),
      ),
      NavigationDestination(icon: const Icon(Icons.list_alt_outlined), selectedIcon: const Icon(Icons.list_alt), label: AppLocalizations.of(context)!.translate('medications')),
      NavigationDestination(icon: const Icon(Icons.history_outlined), selectedIcon: const Icon(Icons.history), label: AppLocalizations.of(context)!.translate('history')),
      NavigationDestination(icon: const Icon(Icons.analytics_outlined), selectedIcon: const Icon(Icons.analytics), label: AppLocalizations.of(context)!.translate('statistics')),
      NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: AppLocalizations.of(context)!.translate('settings')),
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
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: IndexedStack(key: ValueKey(_index), index: _index, children: _pages),
            ),
          ),
        ),
        floatingActionButton: showFab
            ? Transform.translate(
                offset: const Offset(0, -10),
                child: FloatingActionButton(
                  onPressed: _onFabPressed,
                  child: const Icon(Icons.add),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
        bottomNavigationBar: Column(
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
                indicatorColor: colorScheme.primary.withOpacity(0.14),
                labelTextStyle: WidgetStateProperty.resolveWith(
                  (states) => TextStyle(
                    fontWeight: FontWeight.w600,
                    color: states.contains(WidgetState.selected)
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                iconTheme: WidgetStateProperty.resolveWith(
                  (states) => IconThemeData(
                    color: states.contains(WidgetState.selected)
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: destinations,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 