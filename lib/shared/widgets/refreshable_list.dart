import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/no_glow_scroll_behavior.dart';

/// Reusable list view that:
///   * watches an [AsyncValue] of a list
///   * renders a skeleton placeholder list while data is loading
///   * supports pull-to-refresh via [RefreshIndicator]
///   * routes through caller-provided empty / error builders.
///
/// Drop this in on any list-style page so the pull-to-refresh + skeleton +
/// empty/error UX stays consistent across the app.
class RefreshableList<T> extends StatelessWidget {
  const RefreshableList({
    required this.async,
    required this.onRefresh,
    required this.itemBuilder,
    required this.skeletonItemBuilder,
    super.key,
    this.filter,
    this.skeletonItemCount = 5,
    this.separator,
    this.padding,
    this.emptyBuilder,
    this.errorBuilder,
  });

  final AsyncValue<List<T>> async;
  final Future<void> Function() onRefresh;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget Function(BuildContext, int) skeletonItemBuilder;

  /// Optional client-side transform applied to the data list (e.g. a search
  /// filter). Applied *inside* the `data` builder so the previous value is
  /// preserved during pull-to-refresh.
  final List<T> Function(List<T>)? filter;

  final int skeletonItemCount;
  final Widget? separator;
  final EdgeInsetsGeometry? padding;
  final WidgetBuilder? emptyBuilder;
  final Widget Function(BuildContext, Object, StackTrace)? errorBuilder;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ScrollConfiguration(
        // Suppress the Android overscroll glow — it paints a coloured
        // rectangle behind the cards on edge bounces.
        behavior: const NoGlowScrollBehavior(),
        child: async.when(
          // Force the skeleton to show on pull-to-refresh too. Without this,
          // Riverpod's default (`skipLoadingOnRefresh: true`) keeps the
          // previous list visible while the new data is fetching.
          skipLoadingOnRefresh: false,
          loading: () => _buildSkeleton(context),
          error: (error, stack) => _buildSingleChildScroll(
            errorBuilder?.call(context, error, stack) ??
                _DefaultErrorState(error: error),
          ),
          data: (rawItems) {
            final items = filter?.call(rawItems) ?? rawItems;
            if (items.isEmpty) {
              return _buildSingleChildScroll(
                emptyBuilder?.call(context) ?? const _DefaultEmptyState(),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: padding ?? EdgeInsets.zero,
              itemCount: items.length,
              separatorBuilder: (_, __) =>
                  separator ?? SizedBox(height: 12.h),
              itemBuilder: (context, index) =>
                  itemBuilder(context, items[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: padding ?? EdgeInsets.zero,
      itemCount: skeletonItemCount,
      separatorBuilder: (_, __) => separator ?? SizedBox(height: 12.h),
      itemBuilder: skeletonItemBuilder,
    );
  }

  Widget _buildSingleChildScroll(Widget child) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: ClampingScrollPhysics(),
      ),
      padding: padding,
      children: <Widget>[
        SizedBox(height: 80.h),
        child,
      ],
    );
  }
}

class _DefaultEmptyState extends StatelessWidget {
  const _DefaultEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          'Nothing to show yet.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }
}

class _DefaultErrorState extends StatelessWidget {
  const _DefaultErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          "Couldn't load. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
          ),
        ),
      ),
    );
  }
}
