import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/constants/app_sizes.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/empty_state_view.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Pixel buffer above `maxScrollExtent` at which we kick off the next page.
/// 300px ≈ a couple of card heights — gives the network call a head start
/// before the user actually hits the bottom.
const double _kLoadMoreTriggerPx = 300;

/// Search debounce. Anything between 250 and 400 feels responsive; 300 is
/// the sweet spot in this codebase.
const Duration _kSearchDebounce = Duration(milliseconds: 300);

class PartiesListPage extends ConsumerStatefulWidget {
  const PartiesListPage({super.key});

  @override
  ConsumerState<PartiesListPage> createState() => _PartiesListPageState();
}

class _PartiesListPageState extends ConsumerState<PartiesListPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  bool _hasUserAdvanced = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
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
    final state = ref.read(partiesListProvider).value;
    if (state == null || !state.hasMore || state.isLoadingMore) return;
    _hasUserAdvanced = true;
    ref.read(partiesListProvider.notifier).loadMore();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_kSearchDebounce, () {
      if (!mounted) return;
      _hasUserAdvanced = false;
      ref.read(partiesListProvider.notifier).setSearch(value);
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    setState(() {});
    _hasUserAdvanced = false;
    ref.read(partiesListProvider.notifier).setSearch('');
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _onRefresh() async {
    _hasUserAdvanced = false;
    await ref.read(partiesListProvider.notifier).refresh();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(partiesListProvider);
    final visibleAsync = ref.watch(partiesListVisibleProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: PrimaryFabButton(
          label: 'Add Party',
          onPressed: () => context.push(Routes.addParty),
        ),
        body: Stack(
          children: <Widget>[
            // Decorative corner bubble sits behind everything else.
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
                  _PartiesAppBar(onBack: _back),
                  SizedBox(height: 46.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimaryTextField(
                      controller: _searchController,
                      hintText: 'Search',
                      prefixIcon: Icons.search,
                      onChanged: _onSearchChanged,
                      suffixWidget: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.close,
                                size: 20.sp,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: _clearSearch,
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
                        'Parties',
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
                    child: _PartiesBody(
                      listAsync: listAsync,
                      visibleAsync: visibleAsync,
                      scrollController: _scrollController,
                      hasUserAdvanced: _hasUserAdvanced,
                      onRefresh: _onRefresh,
                      onRetryLoadMore: () =>
                          ref.read(partiesListProvider.notifier).loadMore(),
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

/// Picks the right body based on the cross product of:
///   * notifier state (initial-loading / loaded / errored)
///   * drift stream of visible rows
///
/// Pull-to-refresh is wired at this level so a successful retry from the
/// `_ErrorState` body reuses the same `RefreshIndicator`.
class _PartiesBody extends StatelessWidget {
  const _PartiesBody({
    required this.listAsync,
    required this.visibleAsync,
    required this.scrollController,
    required this.hasUserAdvanced,
    required this.onRefresh,
    required this.onRetryLoadMore,
  });

  final AsyncValue<PartiesListState> listAsync;
  final AsyncValue<List<Party>> visibleAsync;
  final ScrollController scrollController;
  final bool hasUserAdvanced;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetryLoadMore;

  @override
  Widget build(BuildContext context) {
    final padding = EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h);

    // Initial load: notifier hasn't resolved + no prior data → skeleton.
    if (listAsync.isLoading && !listAsync.hasValue) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: _SkeletonList(padding: padding),
      );
    }

    // Initial error: notifier failed and we have no prior page to fall back
    // on. Pull-to-refresh retries.
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
    final items = visibleAsync.value ?? const <Party>[];

    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: _SingleScroll(
          padding: padding,
          child: _EmptyState(searching: state.searchQuery.isNotEmpty),
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
          final party = items[index];
          return _PartyCard(
            party: party,
            onTap: () => context.push(
              Routes.partyDetailPath(party.id),
              extra: party,
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
            _PartyCard(party: _placeholderParty, onTap: () {}),
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
                Icon(
                  Icons.refresh,
                  color: AppColors.primary,
                  size: 18.sp,
                ),
                SizedBox(width: 8.w),
                Text(
                  "Couldn't load more — tap to retry",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14.sp,
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
      // Quietly idle — the scroll listener will trigger loadMore.
      return SizedBox(height: 8.h);
    }
    // No more pages. Only surface the explicit copy after the user has
    // actually advanced past page 1; otherwise it screams "you're done"
    // on every short list, which feels noisy.
    if (!hasUserAdvanced) return SizedBox(height: 8.h);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.h),
      child: Center(
        child: Text(
          "You've reached the end",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
          ),
        ),
      ),
    );
  }
}

class _PartiesAppBar extends StatelessWidget {
  const _PartiesAppBar({required this.onBack});

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
            'Parties',
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

class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.party, required this.onTap});

  final Party party;
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
                // Zero-width spacer that floors the row to the shared
                // card-content height, so every avatar card matches the
                // leaves / tour / notes cards regardless of avatar size.
                SizedBox(height: AppSizes.listCardContentHeight.h),
                Skeleton.replace(
                  replacement: Bone.circle(size: 52.r),
                  child: CircleAvatar(
                    radius: 26.r,
                    backgroundColor: AppColors.primary,
                    child: Icon(
                      Icons.person_outline,
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
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              party.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (party.syncPending) ...<Widget>[
                            SizedBox(width: 6.w),
                            _SyncBadge(
                              hasError: party.syncError != null,
                              errorMessage: party.syncError,
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        party.address,
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

/// Small inline indicator next to the party name when the row's
/// mutation hasn't synced yet. Orange means "queued, still trying";
/// red means "dead-lettered, manual intervention needed". Tooltip
/// carries the error message in the red state so the user can see
/// what failed without leaving the list.
class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.hasError, this.errorMessage});

  final bool hasError;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final color = hasError ? AppColors.error : Colors.orange.shade700;
    final icon = hasError ? Icons.error_outline : Icons.cloud_off_outlined;
    final tooltip = hasError
        ? 'Sync failed: ${errorMessage ?? 'unknown error'}'
        : 'Pending sync';
    return Tooltip(
      message: tooltip,
      child: Icon(icon, size: 16.sp, color: color),
    );
  }
}

/// Sample party fed to [_PartyCard] when the list is loading.
/// Skeletonizer paints text bones over the rendered name/address; the
/// colored avatars are swapped for circular bones via `Skeleton.replace`
/// inside the card itself.
const _placeholderParty = Party(
  id: '',
  name: 'Loading party name',
  address: 'Loading address line for placeholder',
  ownerName: 'Loading owner',
  phone: '0000000000',
  panVat: '000000000',
);

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return EmptyStateView(
      icon: Icons.people_outline,
      title: searching ? 'No matches' : 'No parties yet',
      message: searching
          ? 'No parties match your search.'
          : 'Tap "Add Party" to get started.',
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
          "Couldn't load parties. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}
