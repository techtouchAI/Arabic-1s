import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../state/app_state.dart';
import '../widgets/bayan_emblem.dart';
import 'bookmarks_screen.dart';
import 'home_screen.dart';
import 'index_screen.dart';
import 'quiz_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class LandingShell extends StatelessWidget {
  const LandingShell({super.key});

  static const List<_DestinationSpec> _destinations = <_DestinationSpec>[
    _DestinationSpec(
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _DestinationSpec(
      label: 'الفهرست',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
    ),
    _DestinationSpec(
      label: 'البحث',
      icon: Icons.search_outlined,
      selectedIcon: Icons.search,
    ),
    _DestinationSpec(
      label: 'محفوظاتي',
      icon: Icons.bookmarks_outlined,
      selectedIcon: Icons.bookmarks,
    ),
    _DestinationSpec(
      label: 'الاختبار',
      icon: Icons.quiz_outlined,
      selectedIcon: Icons.quiz,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= AppLayout.railBreakpoint;
    final currentIndex = state.selectedNavIndex;

    const pages = <Widget>[
      HomeScreen(),
      IndexScreen(),
      SearchScreen(),
      BookmarksScreen(),
      QuizScreen(),
    ];

    if (useRail) {
      final scheme = Theme.of(context).colorScheme;
      return Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: currentIndex,
              onDestinationSelected: state.setNavIndex,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  children: <Widget>[
                    const BayanEmblem(size: 40),
                    const SizedBox(height: 4),
                    Text(
                      'بَيَان',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: IconButton(
                      tooltip: 'الإعدادات',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ),
                ),
              ),
              destinations: <NavigationRailDestination>[
                for (final dest in _destinations)
                  NavigationRailDestination(
                    icon: Icon(dest.icon),
                    selectedIcon: Icon(dest.selectedIcon),
                    label: Text(dest.label),
                  ),
              ],
            ),
            VerticalDivider(width: 1, color: scheme.outlineVariant),
            Expanded(child: pages[currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: state.setNavIndex,
        destinations: <NavigationDestination>[
          for (final dest in _destinations)
            NavigationDestination(
              icon: Icon(dest.icon),
              selectedIcon: Icon(dest.selectedIcon),
              label: dest.label,
            ),
        ],
      ),
    );
  }
}

class _DestinationSpec {
  const _DestinationSpec({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
