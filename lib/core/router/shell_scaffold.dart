import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
// Biometric setup gate is temporarily disabled — see body comment below.
// import 'package:sales_sphere_erp/features/auth/presentation/widgets/biometric_setup_gate.dart';

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
      label: 'Order',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      route: Routes.order,
    ),
    _ShellTab(
      label: 'Field Ops',
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      route: Routes.fieldOps,
    ),
    _ShellTab(
      label: 'More',
      icon: Icons.menu_outlined,
      activeIcon: Icons.menu,
      route: Routes.more,
    ),
  ];

  int _indexFor(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    // /profile and /settings are pushed from the More hub, so keep the
    // More tab highlighted while the user is on either detail screen.
    if (location.startsWith(Routes.profile) ||
        location.startsWith(Routes.settings)) {
      return _tabs.indexWhere((t) => t.route == Routes.more);
    }
    final index = _tabs.indexWhere((t) => location.startsWith(t.route));
    return index < 0 ? 0 : index;
  }

  void _onTap(BuildContext context, int index) {
    context.go(_tabs[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _indexFor(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: AppColors.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
      child: Scaffold(
        // Biometric login is temporarily disabled pending a new plan.
        // The post-first-login setup prompt would offer to enable a
        // feature that currently does nothing, so we render the child
        // directly. Re-wrap with `BiometricSetupGate(child: child)` (and
        // re-add its import above) when biometric returns.
        body: child,
        bottomNavigationBar: _GlassBottomNav(
          tabs: _tabs,
          selectedIndex: selected,
          onTap: (i) => _onTap(context, i),
        ),
      ),
    );
  }
}

/// Frosted-glass bottom nav. Translucent surface backed by a runtime
/// gaussian blur (`BackdropFilter`), a rim-light border, and a sliding
/// indicator pill behind the active tab. Pure-icon design — labels are
/// surfaced via tooltip + `Semantics` so the layout never overflows.
class _GlassBottomNav extends StatelessWidget {
  const _GlassBottomNav({
    required this.tabs,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<_ShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.8),
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60.h,
          child: Row(
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
    final iconColor = selected
        ? AppColors.secondary
        : AppColors.textPrimary.withValues(alpha: 0.7);
    final textColor = selected
        ? AppColors.textPrimary
        : AppColors.textPrimary.withValues(alpha: 0.7);
    return Semantics(
      label: tab.label,
      selected: selected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.r),
          splashColor: AppColors.secondary.withValues(alpha: 0.14),
          highlightColor: AppColors.secondary.withValues(alpha: 0.06),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // LinkedIn-style top indicator line
              Positioned(
                top: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: selected ? 1.0 : 0.0,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: 3.h,
                    width: selected ? 52.w : 20.w,
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(3.r),
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: Icon(
                        selected ? tab.activeIcon : tab.icon,
                        key: ValueKey<bool>(selected),
                        color: iconColor,
                        size: 22.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10.sp,
                        height: 1.1,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.w500,
                        letterSpacing: 0.1,
                      ),
                      child: Text(
                        tab.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
