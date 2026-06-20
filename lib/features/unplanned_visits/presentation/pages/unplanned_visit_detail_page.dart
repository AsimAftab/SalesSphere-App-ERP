import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visits_monthly_report.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/providers/unplanned_visit_providers.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/widgets/visit_detail_card.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/widgets/visit_summary_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Detail view for a day's unplanned visits. Reached with a single visit id —
/// the first visit of a day (from a history day card) or a specific visit
/// (from the home carousel / today's list). It resolves that visit's calendar
/// day, loads the day's sibling visits, and shows one tab per visit, so a day
/// with several visits reads as a single entry with a tab switcher.
class UnplannedVisitDetailPage extends ConsumerWidget {
  const UnplannedVisitDetailPage({
    required this.id,
    this.focused = false,
    super.key,
  });

  final String id;

  /// When true, show only this visit's full card — no day grouping, tabs or
  /// list. The busy-day list drills in with this set so it doesn't re-show
  /// the list.
  final bool focused;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitAsync = ref.watch(unplannedVisitByIdProvider(id));

    return visitAsync.when(
      loading: () => const _DetailSkeleton(),
      error: (_, __) => _StatusScaffold(
        child: Text(
          "Couldn't load this visit",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      data: (visit) {
        if (focused) {
          // Single-visit view — skip sibling resolution entirely.
          return _DayDetail(
            dayVisits: <UnplannedVisit>[visit],
            initialId: visit.id,
          );
        }
        final day = _dayKey(visit);
        if (day == null) {
          // No calendar day → can't resolve siblings; show this visit alone.
          return _DayDetail(
            dayVisits: <UnplannedVisit>[visit],
            initialId: visit.id,
          );
        }
        // Siblings come from the visit's OWN month (possibly a past month).
        // While that report resolves we already have the visit itself, so we
        // degrade to a single-visit view instead of a blank spinner.
        final report = ref
            .watch(unplannedVisitsMonthlyReportProvider(day.year, day.month))
            .asData
            ?.value;
        final dayVisits = report == null
            ? <UnplannedVisit>[visit]
            : _siblingsFor(visit, report);
        return _DayDetail(dayVisits: dayVisits, initialId: visit.id);
      },
    );
  }
}

/// Day bucket key for a visit — mirrors the history page's grouping
/// (`startedAt ?? createdAt`, day precision).
DateTime? _dayKey(UnplannedVisit v) {
  final raw = v.startedAt ?? v.createdAt;
  return raw == null ? null : DateTime(raw.year, raw.month, raw.day);
}

/// All visits sharing [visit]'s calendar day, sorted by start time. [visit]
/// is always included even if a stale [report] omits it.
List<UnplannedVisit> _siblingsFor(
  UnplannedVisit visit,
  UnplannedVisitsMonthlyReport report,
) {
  final key = _dayKey(visit);
  final list = <UnplannedVisit>[
    for (final v in report.records)
      if (_dayKey(v) == key) v,
  ];
  if (!list.any((v) => v.id == visit.id)) list.add(visit);
  list.sort((a, b) {
    final at = a.startedAt ?? a.createdAt;
    final bt = b.startedAt ?? b.createdAt;
    if (at == null || bt == null) return 0;
    return at.compareTo(bt);
  });
  return list;
}

/// The decorative corner bubble behind the header — the app-wide page motif.
/// Returned from a function (not a widget) so the [Positioned] stays a direct
/// child of its [Stack].
Widget _cornerBubble() => Positioned(
  top: 0,
  left: 0,
  right: 0,
  child: SvgPicture.asset(
    'assets/images/corner_bubble.svg',
    fit: BoxFit.cover,
    height: 180.h,
  ),
);

/// Back button + title row sitting over the corner bubble.
class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 20.w, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
              size: 20.sp,
            ),
            onPressed: () => context.pop(),
            tooltip: 'Back',
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 36.w, minHeight: 36.h),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Scaffold shell for the loading / error states, before the day is known.
class _StatusScaffold extends StatelessWidget {
  const _StatusScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            _cornerBubble(),
            SafeArea(
              child: Column(
                children: <Widget>[
                  const _PageHeader(title: 'Visit Details'),
                  Expanded(child: Center(child: child)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Page chrome + shimmer card placeholder shown while the visit loads.
class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            _cornerBubble(),
            SafeArea(
              child: Column(
                children: <Widget>[
                  const _PageHeader(title: 'Visit Details'),
                  Expanded(
                    child: Skeletonizer(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
                        children: const <Widget>[_CardSkeleton()],
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

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Bone.circle(size: 52.r),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Bone(
                      width: 160.w,
                      height: 16.h,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    SizedBox(height: 8.h),
                    Bone(
                      width: 120.w,
                      height: 12.h,
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Map / Directions row.
          Row(
            children: <Widget>[
              Expanded(
                child: Bone(
                  width: double.infinity,
                  height: 40.h,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Bone(
                  width: double.infinity,
                  height: 40.h,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // Times strip.
          Bone(
            width: double.infinity,
            height: 64.h,
            borderRadius: BorderRadius.circular(12.r),
          ),
          SizedBox(height: 16.h),
          // Description (label + value).
          Bone(width: 90.w, height: 12.h, borderRadius: BorderRadius.circular(4.r)),
          SizedBox(height: 8.h),
          Bone(
            width: double.infinity,
            height: 12.h,
            borderRadius: BorderRadius.circular(4.r),
          ),
          SizedBox(height: 16.h),
          // Follow-up (label + value).
          Bone(width: 90.w, height: 12.h, borderRadius: BorderRadius.circular(4.r)),
          SizedBox(height: 8.h),
          Bone(width: 120.w, height: 12.h, borderRadius: BorderRadius.circular(4.r)),
          SizedBox(height: 16.h),
          // Photo (label + image).
          Bone(width: 60.w, height: 12.h, borderRadius: BorderRadius.circular(4.r)),
          SizedBox(height: 10.h),
          Bone(
            width: double.infinity,
            height: 180.h,
            borderRadius: BorderRadius.circular(12.r),
          ),
        ],
      ),
    );
  }
}

/// A day's visits. With a handful (≤ `tabThreshold`) they read as a tab
/// switcher; busy days with more switch to a vertical scrolling list (a tab bar
/// stops scaling past a few), opening at the top.
class _DayDetail extends StatefulWidget {
  const _DayDetail({required this.dayVisits, required this.initialId});

  final List<UnplannedVisit> dayVisits;

  /// The visit the page was opened on — drives the initial tab.
  final String initialId;

  /// Above this many visits per day, tabs give way to a vertical list.
  static const int tabThreshold = 4;

  @override
  State<_DayDetail> createState() => _DayDetailState();
}

class _DayDetailState extends State<_DayDetail>
    with SingleTickerProviderStateMixin {
  TabController? _controller;
  List<String> _ids = const <String>[];

  bool get _useTabs {
    final n = widget.dayVisits.length;
    return n > 1 && n <= _DayDetail.tabThreshold;
  }

  bool get _useList => widget.dayVisits.length > _DayDetail.tabThreshold;

  @override
  void initState() {
    super.initState();
    if (_useTabs) _syncController();
  }

  @override
  void didUpdateWidget(_DayDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_useTabs) {
      _syncController();
    } else {
      _controller?.dispose();
      _controller = null;
      _ids = const <String>[];
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// (Re)builds the tab controller only when the visit-id list changes, keeping
  /// the currently-selected visit selected where possible.
  void _syncController() {
    final newIds = widget.dayVisits.map((v) => v.id).toList(growable: false);
    if (_controller != null && listEquals(newIds, _ids)) return;

    int target;
    if (_controller == null) {
      target = newIds.indexOf(widget.initialId);
    } else {
      final i = _controller!.index;
      final currentId = (i >= 0 && i < _ids.length)
          ? _ids[i]
          : widget.initialId;
      target = newIds.indexOf(currentId);
      if (target < 0) target = i.clamp(0, newIds.length - 1);
    }
    if (target < 0) target = 0;

    _controller?.dispose();
    _controller = TabController(
      length: newIds.length,
      vsync: this,
      initialIndex: target.clamp(0, newIds.length - 1),
    );
    _ids = newIds;
  }

  @override
  Widget build(BuildContext context) {
    final visits = widget.dayVisits;

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: <Widget>[
            _cornerBubble(),
            SafeArea(
              child: Column(
                children: <Widget>[
                  const _PageHeader(title: 'Visit Details'),
                  if (_useTabs) ...<Widget>[
                    SizedBox(height: 4.h),
                    TabBar(
                      controller: _controller,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.secondary,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelStyle: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      tabs: <Widget>[
                        for (var i = 0; i < visits.length; i++)
                          Tab(text: 'Visit ${i + 1}'),
                      ],
                    ),
                  ],
                  if (_useList)
                    _DayDateHeader(
                      date: visits.first.startedAt ?? visits.first.createdAt,
                      count: visits.length,
                    ),
                  Expanded(child: _buildBody(visits)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<UnplannedVisit> visits) {
    if (_useTabs) {
      return TabBarView(
        controller: _controller,
        children: <Widget>[
          for (final v in visits) _VisitDetailBody(visit: v),
        ],
      );
    }
    if (_useList) {
      // Busy day → a scannable list of today's-status-style summary cards,
      // opening at the top. Tapping one drills into that visit's full card via
      // the focused route.
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
        itemCount: visits.length,
        itemBuilder: (context, i) {
          final v = visits[i];
          return Padding(
            padding: EdgeInsets.only(bottom: 14.h),
            child: VisitSummaryCard(
              visit: v,
              number: i + 1,
              onTap: () => context.pushNamed(
                Routes.unplannedVisitDetailName,
                pathParameters: <String, String>{'id': v.id},
                queryParameters: <String, String>{'focus': '1'},
              ),
            ),
          );
        },
      );
    }
    return _VisitDetailBody(visit: visits.first);
  }
}

/// Date + visit count shown above the busy-day list, so the day being viewed
/// is clear at a glance.
class _DayDateHeader extends StatelessWidget {
  const _DayDateHeader({required this.date, required this.count});

  final DateTime? date;
  final int count;

  @override
  Widget build(BuildContext context) {
    final d = date?.toLocal();
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 4.h),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.calendar_today_rounded,
            color: AppColors.primary,
            size: 16.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              d == null ? 'This day' : DateFormat('EEEE, d MMM yyyy').format(d),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            '$count ${count == 1 ? 'visit' : 'visits'}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitDetailBody extends StatelessWidget {
  const _VisitDetailBody({required this.visit});

  final UnplannedVisit visit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
      children: <Widget>[VisitDetailCard(visit: visit)],
    );
  }
}
