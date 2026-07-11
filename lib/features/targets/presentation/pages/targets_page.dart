import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/attendance/presentation/widgets/month_nav_header.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';
import 'package:sales_sphere_erp/features/targets/presentation/pages/target_drill_down_page.dart';
import 'package:sales_sphere_erp/features/targets/presentation/providers/targets_providers.dart';
import 'package:sales_sphere_erp/features/targets/presentation/widgets/target_card.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_search_filter.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Dedicated "My Targets" page showing assigned daily and monthly targets.
/// Reached from the More tab tile.
///
/// Features:
/// - Header titled "My Targets" with corner bubble accent
/// - Month Navigation Header ([MonthNavHeader]) to browse targets by month
/// - Search Bar placed below Month Nav to search targets instantly by rule name
/// - Interval Filter Chips (`All Intervals`, `Daily`, `Monthly`) placed below Search Bar
/// - Clean scrollable list of [TargetCard]s showing explicit dates & interval badges
class TargetsPage extends ConsumerStatefulWidget {
  const TargetsPage({super.key});

  @override
  ConsumerState<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends ConsumerState<TargetsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _intervalFilter = 'All'; // 'All', 'Daily', 'Monthly'
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.more);
    }
  }

  List<TargetItem> _applyFilters(List<TargetItem> allTargets) {
    return allTargets.where((item) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final ruleMatch = item.rule.toLowerCase().contains(query);
        final dateMatch =
            _getCardPeriodLabel(item).toLowerCase().contains(query);
        if (!ruleMatch && !dateMatch) {
          return false;
        }
      }
      if (_intervalFilter != 'All' &&
          item.interval.toLowerCase() != _intervalFilter.toLowerCase()) {
        return false;
      }
      return true;
    }).toList();
  }

  String _getCardPeriodLabel(TargetItem target) {
    if (target.interval.toLowerCase() == 'daily') {
      final now = DateTime.now();
      return DateFormat('dd MMM yyyy').format(now);
    }
    return DateFormat('MMMM yyyy').format(_selectedMonth);
  }

  @override
  Widget build(BuildContext context) {
    final targetsAsync = ref.watch(myTargetsProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SvgPicture.asset(
                'assets/images/corner_bubble.svg',
                fit: BoxFit.cover,
                height: 180.h,
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.fromLTRB(12.w, 4.h, 20.w, 0),
                    child: _AppBar(onBack: () => _back(context)),
                  ),
                  SizedBox(height: 14.h),
                  // 1. Month Navigation Header
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: MonthNavHeader(
                      displayedMonth: _selectedMonth,
                      onMonthChange: (m) => setState(() => _selectedMonth = m),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // 2. Search Bar right below Month Nav Bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: _SearchBar(
                      controller: _searchController,
                      onChanged: (query) {
                        setState(() => _searchQuery = query.trim());
                      },
                      onClear: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
                  ),
                  SizedBox(height: 10.h),
                  // 3. Filter dropdown exactly like Attendance page
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimarySearchFilter<String>(
                      selected: _intervalFilter,
                      onChanged: (next) =>
                          setState(() => _intervalFilter = next),
                      options: const <SearchFilterOption<String>>[
                        SearchFilterOption<String>(
                          value: 'All',
                          label: 'All Intervals',
                          icon: Icons.filter_list_rounded,
                        ),
                        SearchFilterOption<String>(
                          value: 'Daily',
                          label: 'Daily Targets',
                          icon: Icons.today_rounded,
                          iconColor: AppColors.info,
                        ),
                        SearchFilterOption<String>(
                          value: 'Monthly',
                          label: 'Monthly Targets',
                          icon: Icons.calendar_month_rounded,
                          iconColor: AppColors.purple500,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(myTargetsProvider);
                        await ref.read(myTargetsProvider.future);
                      },
                      child: targetsAsync.when(
                        data: (allTargets) {
                          final filtered = _applyFilters(allTargets);

                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
                            children: <Widget>[
                              // Section title & count
                              Row(
                                children: <Widget>[
                                  Text(
                                    'Assigned Targets',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${filtered.length} Targets',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              if (filtered.isEmpty)
                                const _EmptyTargetsView()
                              else
                                ...filtered.map(
                                  (target) => Padding(
                                    padding: EdgeInsets.only(bottom: 14.h),
                                    child: TargetCard(
                                      target: target,
                                      periodLabel: _getCardPeriodLabel(target),
                                      onTap: () => context.push(
                                        Routes.targetDrillDown,
                                        extra: TargetDrillDownArgs(
                                          target: target,
                                          periodLabel:
                                              _getCardPeriodLabel(target),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () {
                          const placeholderTarget = TargetItem(
                            id: 'skeleton',
                            rule: 'No. of Orders Assigned',
                            interval: 'Daily',
                            targetValue: 100,
                            actualValue: 65,
                            status: 'Active',
                          );

                          return Skeletonizer(
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: ClampingScrollPhysics(),
                              ),
                              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
                              itemCount: 5,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: 14.h),
                              itemBuilder: (_, __) => const TargetCard(
                                target: placeholderTarget,
                                periodLabel: '11 Jul 2026',
                              ),
                            ),
                          );
                        },
                        error: (err, _) => Center(
                          child: Padding(
                            padding: EdgeInsets.all(24.r),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.error_outline,
                                  color: AppColors.error,
                                  size: 40.sp,
                                ),
                                SizedBox(height: 12.h),
                                Text(
                                  'Failed to load targets',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                ElevatedButton(
                                  onPressed: () =>
                                      ref.invalidate(myTargetsProvider),
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textdark, size: 20.sp),
          onPressed: onBack,
          tooltip: 'Back',
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
        ),
        SizedBox(width: 12.w),
        Text(
          'My Targets',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.sp,
        ),
        decoration: InputDecoration(
          hintText: 'Search by rule name or date',
          hintStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20.sp,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: AppColors.textSecondary,
                    size: 18.sp,
                  ),
                  onPressed: onClear,
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
      ),
    );
  }
}

class _EmptyTargetsView extends StatelessWidget {
  const _EmptyTargetsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.search_off_rounded,
              size: 56.sp,
              color: AppColors.iconsColorSecondary.withValues(alpha: 0.5),
            ),
            SizedBox(height: 16.h),
            Text(
              'No Matching Targets',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'Try adjusting your search query or interval filter.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
