import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../l10n/generated/app_localizations.dart';

/// 行程範圍畫面共用的 Scaffold，含底部導覽列（今日 / 全程 / 札記 / 須知 / 搜尋）。
/// 見規格 §5.2。
class TripScaffold extends StatelessWidget {
  const TripScaffold({
    super.key,
    required this.tripId,
    required this.currentTab,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  final String tripId;
  final TripTab currentTab;
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  void _onTap(BuildContext context, int index) {
    final TripTab tab = TripTab.values[index];
    if (tab == currentTab) return;
    switch (tab) {
      case TripTab.today:
        context.go(AppRoutes.tripHome(tripId));
      case TripTab.days:
        context.go(AppRoutes.tripDays(tripId));
      case TripTab.journal:
        context.go(AppRoutes.journal(tripId));
      case TripTab.info:
        context.go(AppRoutes.info(tripId));
      case TripTab.search:
        context.go(AppRoutes.search(tripId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTab.index,
        onDestinationSelected: (int index) => _onTap(context, index),
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: l10n.navToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: l10n.navAll,
          ),
          NavigationDestination(
            icon: const Icon(Icons.edit_note_outlined),
            selectedIcon: const Icon(Icons.edit_note),
            label: l10n.navJournal,
          ),
          NavigationDestination(
            icon: const Icon(Icons.info_outline),
            selectedIcon: const Icon(Icons.info),
            label: l10n.navInfo,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: l10n.navSearch,
          ),
        ],
      ),
    );
  }
}
