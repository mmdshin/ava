import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ava_web/core/app_theme.dart';

/// The top-level sections of the app.
class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Destination('خانه', Icons.home_outlined, Icons.home_rounded),
  _Destination(
    'برنامه‌ها',
    Icons.medical_information_outlined,
    Icons.medical_information_rounded,
  ),
  _Destination('آزمون‌ها', Icons.school_outlined, Icons.school_rounded),
  _Destination(
    'ذخیره‌شده‌ها',
    Icons.bookmark_border_rounded,
    Icons.bookmark_rounded,
  ),
];

/// Persistent navigation around the tabs.
///
/// Phones get a bottom [NavigationBar]; tablets, desktop and wide web
/// windows get a side [NavigationRail] (on the right, since the app is
/// RTL). Each tab keeps its own back stack and scroll position
/// (StatefulShellRoute.indexedStack in app/router.dart).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
    index,
    // Tapping the current tab again returns to its first page.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final colors = context.appColors;

    if (width >= 840) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              extended: width >= 1200,
              backgroundColor: colors.dialogSurface,
              indicatorColor: colors.brand.withValues(alpha: 0.18),
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _select,
              labelType: width >= 1200
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon, color: colors.accent),
                    label: Text(d.label),
                  ),
              ],
            ),
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: colors.glass.withValues(alpha: 0.12),
            ),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        backgroundColor: colors.dialogSurface,
        indicatorColor: colors.brand.withValues(alpha: 0.18),
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _select,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon, color: colors.accent),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
