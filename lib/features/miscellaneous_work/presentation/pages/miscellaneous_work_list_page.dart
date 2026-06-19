import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/presentation/providers/miscellaneous_work_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Pixel buffer above `maxScrollExtent` at which we kick off the next
/// page. 300px ≈ a couple of card heights — gives the network call a
/// head start before the user actually hits the bottom.
const double _kLoadMoreTriggerPx = 300;

class MiscellaneousWorkListPage extends ConsumerStatefulWidget {
  const MiscellaneousWorkListPage({super.key});

  @override
  ConsumerState<MiscellaneousWorkListPage> createState() =>
      _MiscellaneousWorkListPageState();
}

class _MiscellaneousWorkListPageState
    extends ConsumerState<MiscellaneousWorkListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';
  bool _hasUserAdvanced = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels < pos.maxScrollExtent - _kLoadMoreTriggerPx) return;
    final state = ref.read(miscellaneousWorkListProvider).value;
    if (state == null || !state.hasMore || state.isLoadingMore) return;
    _hasUserAdvanced = true;
    ref.read(miscellaneousWorkListProvider.notifier).loadMore();
  }

  Future<void> _onRefresh() async {
    _hasUserAdvanced = false;
    await ref.read(miscellaneousWorkListProvider.notifier).refresh();
  }

  /// Apply the in-page search query against the loaded items. Search
  /// is client-side; the backend's filter knobs aren't wired yet.
  List<MiscellaneousWork> _applySearch(List<MiscellaneousWork> source) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source
        .where(
          (w) =>
              w.natureOfWork.toLowerCase().contains(q) ||
              w.address.toLowerCase().contains(q) ||
              w.assignedBy.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.fieldOps);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(miscellaneousWorkListProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: PrimaryFabButton(
          label: 'Add Work',
          onPressed: () => context.push(Routes.addMiscellaneousWork),
        ),
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
                  _AppBar(onBack: _back),
                  SizedBox(height: 46.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimaryTextField(
                      controller: _searchController,
                      hintText: 'Search',
                      prefixIcon: Icons.search,
                      onChanged: (v) => setState(() => _query = v),
                      suffixWidget: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 20.sp,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                                FocusManager.instance.primaryFocus?.unfocus();
                              },
                              tooltip: 'Clear search',
                            ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Work Items',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Expanded(
                    child: _WorkBody(
                      listAsync: listAsync,
                      scrollController: _scrollController,
                      applySearch: _applySearch,
                      hasActiveFilter: _query.trim().isNotEmpty,
                      hasUserAdvanced: _hasUserAdvanced,
                      onRefresh: _onRefresh,
                      onRetryLoadMore: () => ref
                          .read(miscellaneousWorkListProvider.notifier)
                          .loadMore(),
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

class _WorkBody extends StatelessWidget {
  const _WorkBody({
    required this.listAsync,
    required this.scrollController,
    required this.applySearch,
    required this.hasActiveFilter,
    required this.hasUserAdvanced,
    required this.onRefresh,
    required this.onRetryLoadMore,
  });

  final AsyncValue<MiscellaneousWorkListState> listAsync;
  final ScrollController scrollController;
  final List<MiscellaneousWork> Function(List<MiscellaneousWork>) applySearch;
  final bool hasActiveFilter;
  final bool hasUserAdvanced;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetryLoadMore;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h);

    if (listAsync.isLoading && !listAsync.hasValue) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: _SkeletonList(padding: padding),
      );
    }

    if (listAsync.hasError && !listAsync.hasValue) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: _SingleScroll(
          padding: padding,
          child: const _ErrorState(),
        ),
      );
    }

    final state = listAsync.requireValue;
    final items = applySearch(state.items);

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: _SingleScroll(
          padding: padding,
          child: _EmptyState(hasActiveFilter: hasActiveFilter),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: padding,
        itemCount: items.length + 1,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          if (index == items.length) {
            return _LoadMoreFooter(
              hasMore: state.hasMore,
              isLoadingMore: state.isLoadingMore,
              loadMoreError: state.loadMoreError,
              hasUserAdvanced: hasUserAdvanced,
              onRetry: onRetryLoadMore,
            );
          }
          final work = items[index];
          return _WorkCard(
            work: work,
            onTap: () => context.push(
              Routes.miscellaneousWorkDetailPath(work.id),
              extra: work,
            ),
          );
        },
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList({required this.padding});

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        padding: padding,
        itemCount: 5,
        separatorBuilder: (_, __) => SizedBox(height: 12.h),
        itemBuilder: (_, __) =>
            _WorkCard(work: _placeholderWork, onTap: () {}),
      ),
    );
  }
}

class _SingleScroll extends StatelessWidget {
  const _SingleScroll({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: padding,
      children: <Widget>[SizedBox(height: 80.h), child],
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  const _LoadMoreFooter({
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.hasUserAdvanced,
    required this.onRetry,
  });

  final bool hasMore;
  final bool isLoadingMore;
  final Object? loadMoreError;
  final bool hasUserAdvanced;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loadMoreError != null) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 16.h),
        child: InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.refresh, color: AppColors.primary, size: 18.sp),
                SizedBox(width: 8.w),
                Text(
                  "Couldn't load more — tap to retry",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (isLoadingMore) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 20.h),
        child: Center(
          child: SizedBox(
            width: 22.r,
            height: 22.r,
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (hasMore) {
      return SizedBox(height: 8.h);
    }
    if (!hasUserAdvanced) return SizedBox(height: 8.h);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: Text(
          "You've reached the end",
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textdark,
              size: 20.sp,
            ),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          SizedBox(width: 12.w),
          Text(
            'Miscellaneous Work',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.work, required this.onTap});

  final MiscellaneousWork work;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            child: Row(
              children: <Widget>[
                // `Skeleton.replace` swaps the filled navy circle for a
                // bone-circle in loading state so the placeholder reads
                // as a skeleton instead of a solid coloured dot. Mirrors
                // `_SiteCard` / `_PartyCard`.
                Skeleton.replace(
                  replacement: Bone.circle(size: 52.r),
                  child: CircleAvatar(
                    radius: 26.r,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.work_outline_rounded,
                      color: AppColors.textWhite,
                      size: 26.sp,
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        work.natureOfWork,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        work.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Skeleton.replace(
                  replacement: Bone.circle(size: 36.r),
                  child: CircleAvatar(
                    radius: 18.r,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.chevron_right,
                      color: AppColors.textWhite,
                      size: 22.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Sample work fed to [_WorkCard] when the list is loading.
/// Skeletonizer paints text bones over the rendered title/address.
final _placeholderWork = MiscellaneousWork(
  id: '',
  natureOfWork: 'Loading nature of work',
  assignedBy: 'Loading',
  workDate: DateTime(2026),
  address: 'Loading address line',
  latitude: 0,
  longitude: 0,
  createdAt: DateTime(2026),
);

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilter});

  /// True when the empty result is the consequence of an active
  /// search query rather than the source list being genuinely empty.
  /// Drives the copy: the "tap Add Work" prompt only makes sense for
  /// the latter.
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          hasActiveFilter
              ? 'No work items match your search.'
              : 'No work logged yet — tap "Add Work" to log your first task.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          "Couldn't load work items. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}
