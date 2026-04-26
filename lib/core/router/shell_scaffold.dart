import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'routes.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  static const _tabs = <_ShellTab>[
    _ShellTab(label: 'Home', icon: Icons.home_outlined, route: Routes.home),
    _ShellTab(
      label: 'Attendance',
      icon: Icons.access_time_outlined,
      route: Routes.attendance,
    ),
    _ShellTab(
      label: 'Profile',
      icon: Icons.person_outline,
      route: Routes.profile,
    ),
  ];

  int _indexFor(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _tabs.indexWhere((t) => location.startsWith(t.route));
    return index < 0 ? 0 : index;
  }

  void _onTap(BuildContext context, int index) {
    context.go(_tabs[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _indexFor(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: _tabs
            .map(
              (t) => NavigationDestination(
                icon: Icon(t.icon),
                label: t.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}
