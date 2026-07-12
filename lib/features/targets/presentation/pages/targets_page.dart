import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_enums.dart';
import 'package:sales_sphere_erp/features/targets/domain/target_item.dart';
import 'package:sales_sphere_erp/features/targets/presentation/pages/target_drill_down_page.dart';
import 'package:sales_sphere_erp/features/targets/presentation/providers/targets_providers.dart';
import 'package:sales_sphere_erp/features/targets/presentation/widgets/target_card.dart';
import 'package:sales_sphere_erp/features/targets/presentation/widgets/target_day_nav_header.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_search_filter.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Dedicated "My Targets" page showing assigned daily and monthly targets.
/// Reached from the More tab tile.
///
/// Features:
/// - Header titled "Targets" with corner bubble accent
/// - Search Bar to filter targets instantly by rule name or period
/// - Interval Filter Chips (`All Intervals`, `Daily`, `Monthly`)
/// - Day Navigation Header ([TargetDayNavHeader]) driving the server's
///   `?date=` param — DAILY targets are scored for that day, MONTHLY for the
///   month containing it
/// - Clean scrollable list of [TargetCard]s with server period labels
class TargetsPage extends ConsumerStatefulWidget {
  const TargetsPage({super.key});

  @override
  ConsumerState<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends ConsumerState<TargetsPage> {
  /// Placeholder for the loading skeleton. `static final`, not const —
  /// DateTime has no const constructor.
  static final TargetItem _skeletonTarget = TargetItem(
    id: 'skeleton',
    rule: 'No. of Orders Assigned',
    metric: TargetMetric.orderCount,
    interval: TargetInterval.daily,
    targetValue: 100,
    actualValue: 65,
    status: TargetStatus.active,
    isCurrency: false,
    periodStart: DateTime(2026),
    periodEnd: DateTime(2026),
    periodLabel: 'Jul 12, 2026',
    periodStatus: TargetPeriodStatus.inProgress,
  );

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  /// Null = all intervals.
  TargetInterval? _intervalFilter;

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
        final dateMatch = item.periodLabel.toLowerCase().contains(query);
        if (!ruleMatch && !dateMatch) {
          return false;
        }
      }
      if (_intervalFilter != null && item.interval != _intervalFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final targetsAsync = ref.watch(myTargetsProvider);
    final selectedDate = ref.watch(selectedTargetDateProvider);

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
                  // 1. Search Bar right below App Bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimaryTextField(
                      controller: _searchController,
                      hintText: 'Search by rule name or date',
                      prefixIcon: Icons.search_rounded,
                      onChanged: (query) {
                        setState(() => _searchQuery = query.trim());
                      },
                      suffixWidget: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: AppColors.textSecondary,
                                size: 18.sp,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  // 2. Filter dropdown exactly like Attendance page
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimarySearchFilter<TargetInterval?>(
                      selected: _intervalFilter,
                      onChanged: (next) =>
                          setState(() => _intervalFilter = next),
                      options: const <SearchFilterOption<TargetInterval?>>[
                        SearchFilterOption<TargetInterval?>(
                          value: null,
                          label: 'All Intervals',
                          icon: Icons.filter_list_rounded,
                        ),
                        SearchFilterOption<TargetInterval?>(
                          value: TargetInterval.daily,
                          label: 'Daily Targets',
                          icon: Icons.today_rounded,
                          iconColor: AppColors.info,
                        ),
                        SearchFilterOption<TargetInterval?>(
                          value: TargetInterval.monthly,
                          label: 'Monthly Targets',
                          icon: Icons.calendar_month_rounded,
                          iconColor: AppColors.purple500,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // 3. Day Navigation Header — drives the `?date=` param
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: TargetDayNavHeader(
                      selectedDate: selectedDate,
                      onPrevious: () => ref
                          .read(selectedTargetDateProvider.notifier)
                          .previousDay(),
                      onNext: () =>
                          ref.read(selectedTargetDateProvider.notifier).nextDay(),
                      onSelectDate: (d) => ref
                          .read(selectedTargetDateProvider.notifier)
                          .select(d),
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
                        data: (snapshot) {
                          final filtered = _applyFilters(snapshot.items);

                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: ClampingScrollPhysics(),
                            ),
                            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
                            children: <Widget>[
                              if (snapshot.fromCache) ...<Widget>[
                                const _OfflineBanner(),
                                SizedBox(height: 12.h),
                              ],
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
                                EmptyStateView(
                                  icon: snapshot.items.isEmpty
                                      ? Icons.track_changes_outlined
                                      : Icons.search_off_rounded,
                                  title: snapshot.items.isEmpty
                                      ? 'No Targets Assigned'
                                      : 'No Matching Targets',
                                  message: snapshot.items.isEmpty
                                      ? 'Targets assigned to you for this period will appear here.'
                                      : 'Try adjusting your search query or interval filter.',
                                )
                              else
                                ...filtered.map(
                                  (target) => Padding(
                                    padding: EdgeInsets.only(bottom: 14.h),
                                    child: TargetCard(
                                      target: target,
                                      periodLabel: target.periodLabel,
                                      onTap: () => context.push(
                                        Routes.targetDrillDown,
                                        extra:
                                            TargetDrillDownArgs(target: target),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                        loading: () {
                          return Skeletonizer(
                            child: ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: ClampingScrollPhysics(),
                              ),
                              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
                              itemCount: 5,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: 14.h),
                              itemBuilder: (_, __) => TargetCard(
                                target: _skeletonTarget,
                                periodLabel: _skeletonTarget.periodLabel,
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

/// Shown when the list is served from the drift cache because the network
/// was unreachable — the numbers are last-synced, not live.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 18.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Offline — showing last-synced data',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
          'Targets',
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
