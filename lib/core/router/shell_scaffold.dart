import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  static const _tabs = <_ShellTab>[
    _ShellTab(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      route: Routes.home,
    ),
    _ShellTab(
      label: 'Catalog',
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      route: Routes.catalog,
    ),
    _ShellTab(
      label: 'Billing',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      route: Routes.billing,
    ),
    _ShellTab(
      label: 'Customers',
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups,
      route: Routes.customers,
    ),
    _ShellTab(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
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
      extendBody: true,
      body: child,
      bottomNavigationBar: _FloatingPillNav(
        tabs: _tabs,
        selectedIndex: selected,
        onTap: (i) => _onTap(context, i),
      ),
    );
  }
}

/// Floating bottom nav with a sliding indicator pill. Icon-only design —
/// the pill is the only visual cue for the active tab, so the layout
/// scales gracefully from 3 to 6 tabs without horizontal overflow at
/// 360dp. Labels are exposed via tooltip + accessibility semantics.
class _FloatingPillNav extends StatelessWidget {
  const _FloatingPillNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<_ShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
        child: Container(
          height: 64.h,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(32.r),
            // Two-layer shadow: a wide soft glow below + a tighter accent
            // up top, so the bar reads as floating rather than pasted-on.
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: EdgeInsets.all(8.h),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / tabs.length;
              return Stack(
                children: <Widget>[
                  // Sliding indicator pill — sits behind the icons and
                  // animates between slots when selectedIndex changes.
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    left: tabWidth * selectedIndex,
                    top: 0,
                    bottom: 0,
                    width: tabWidth,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              AppColors.secondary.withValues(alpha: 0.16),
                              AppColors.secondary.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18.r),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      for (var i = 0; i < tabs.length; i++)
                        Expanded(
                          child: _NavItem(
                            tab: tabs[i],
                            selected: i == selectedIndex,
                            onTap: () {
                              if (i == selectedIndex) return;
                              HapticFeedback.selectionClick();
                              onTap(i);
                            },
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _ShellTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tab.label,
      selected: selected,
      button: true,
      child: Tooltip(
        message: tab.label,
        waitDuration: const Duration(milliseconds: 600),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18.r),
            splashColor: AppColors.secondary.withValues(alpha: 0.12),
            highlightColor: AppColors.secondary.withValues(alpha: 0.06),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              scale: selected ? 1.08 : 1,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Icon(
                    selected ? tab.activeIcon : tab.icon,
                    key: ValueKey<bool>(selected),
                    color: selected
                        ? AppColors.secondary
                        : AppColors.textSecondary,
                    size: 24.sp,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;
}
