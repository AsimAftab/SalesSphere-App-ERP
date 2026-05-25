import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/notes/domain/note.dart';
import 'package:sales_sphere_erp/features/notes/presentation/providers/notes_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_search_filter.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Per-link-type icon + colour. Mirrors the hub's identity so a row's
/// link badge reads consistently with where the user picked it from.
const _linkPalette = <NoteLinkType, ({IconData icon, Color accent})>{
  NoteLinkType.party: (
    icon: Icons.storefront_outlined,
    accent: AppColors.secondary,
  ),
  NoteLinkType.prospect: (
    icon: Icons.person_search_outlined,
    accent: AppColors.warning,
  ),
  NoteLinkType.site: (
    icon: Icons.location_city_outlined,
    accent: AppColors.green500,
  ),
};

/// Pixel buffer above `maxScrollExtent` at which we kick off the next page.
/// 300px ≈ a couple of card heights — gives the network call a head start
/// before the user actually hits the bottom.
const double _kLoadMoreTriggerPx = 300;

class NotesListPage extends ConsumerStatefulWidget {
  const NotesListPage({super.key});

  @override
  ConsumerState<NotesListPage> createState() => _NotesListPageState();
}

class _NotesListPageState extends ConsumerState<NotesListPage> {
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
    final state = ref.read(notesListProvider).value;
    if (state == null || !state.hasMore || state.isLoadingMore) return;
    _hasUserAdvanced = true;
    ref.read(notesListProvider.notifier).loadMore();
  }

  Future<void> _onRefresh() async {
    _hasUserAdvanced = false;
    await ref.read(notesListProvider.notifier).refresh();
  }

  void _onFilterChanged(NoteLinkType? next) {
    _hasUserAdvanced = false;
    ref.read(notesListProvider.notifier).setRelatedTo(_relatedToFor(next));
  }

  /// Apply the in-page search query against the loaded items. Search
  /// is client-side; the backend's filter knob is `relatedTo`.
  List<Note> _applySearch(List<Note> source) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source
        .where(
          (n) =>
              n.title.toLowerCase().contains(q) ||
              n.description.toLowerCase().contains(q) ||
              n.linkDisplayName.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  bool _hasActiveFilter(NotesListState? state) {
    return _query.trim().isNotEmpty || (state?.relatedTo != null);
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
    final listAsync = ref.watch(notesListProvider);
    final selectedFilter = _linkTypeFor(listAsync.value?.relatedTo);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: PrimaryFabButton(
          label: 'Add Note',
          onPressed: () => context.push(Routes.addNote),
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
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: PrimarySearchFilter<NoteLinkType?>(
                      selected: selectedFilter,
                      onChanged: _onFilterChanged,
                      options: <SearchFilterOption<NoteLinkType?>>[
                        const SearchFilterOption<NoteLinkType?>(
                          value: null,
                          label: 'All Notes',
                          icon: Icons.list_alt_rounded,
                        ),
                        for (final entry in _linkPalette.entries)
                          SearchFilterOption<NoteLinkType?>(
                            value: entry.key,
                            label: _filterLabel(entry.key),
                            icon: entry.value.icon,
                            iconColor: entry.value.accent,
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Notes',
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
                    child: _NotesBody(
                      listAsync: listAsync,
                      scrollController: _scrollController,
                      applySearch: _applySearch,
                      hasActiveFilter: _hasActiveFilter(listAsync.value),
                      hasUserAdvanced: _hasUserAdvanced,
                      onRefresh: _onRefresh,
                      onRetryLoadMore: () =>
                          ref.read(notesListProvider.notifier).loadMore(),
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

/// Maps the UI's `NoteLinkType` filter chip to the wire's
/// `relatedTo` query value.
NotesRelatedTo? _relatedToFor(NoteLinkType? type) {
  switch (type) {
    case null:
      return null;
    case NoteLinkType.party:
      return NotesRelatedTo.customer;
    case NoteLinkType.prospect:
      return NotesRelatedTo.prospect;
    case NoteLinkType.site:
      return NotesRelatedTo.site;
  }
}

NoteLinkType? _linkTypeFor(NotesRelatedTo? wire) {
  switch (wire) {
    case null:
      return null;
    case NotesRelatedTo.customer:
      return NoteLinkType.party;
    case NotesRelatedTo.prospect:
      return NoteLinkType.prospect;
    case NotesRelatedTo.site:
      return NoteLinkType.site;
  }
}

class _NotesBody extends StatelessWidget {
  const _NotesBody({
    required this.listAsync,
    required this.scrollController,
    required this.applySearch,
    required this.hasActiveFilter,
    required this.hasUserAdvanced,
    required this.onRefresh,
    required this.onRetryLoadMore,
  });

  final AsyncValue<NotesListState> listAsync;
  final ScrollController scrollController;
  final List<Note> Function(List<Note>) applySearch;
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
          final note = items[index];
          return _NoteCard(
            note: note,
            onTap: () => context.push(
              Routes.noteDetailPath(note.id),
              extra: note,
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
        itemBuilder: (_, __) => _NoteCard(note: _placeholderNote, onTap: () {}),
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
            'Notes',
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

class _NoteCard extends ConsumerWidget {
  const _NoteCard({required this.note, required this.onTap});

  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = _linkPalette[note.linkType]!;
    // Resolve the linked entity's display name from the relevant
    // by-id provider. The wire payload only carries the id, so the
    // repo's fallback ("Customer"/"Prospect"/"Site") is what we get
    // by default — this swap-in pulls the real name once it lands.
    // Empty linkId (e.g. the skeleton placeholder) skips the lookup
    // and just shows the fallback to avoid spinning a useless future.
    final resolvedName = note.linkId.isEmpty
        ? note.linkDisplayName
        : ref
                .watch(noteLinkDisplayNameProvider(note.linkType, note.linkId))
                .value ??
            note.linkDisplayName;
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
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        note.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      DateFormat('dd MMM yyyy').format(note.createdAt.toLocal()),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                _LinkChip(
                  icon: palette.icon,
                  accent: palette.accent,
                  label: resolvedName,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.icon,
    required this.accent,
    required this.label,
  });

  final IconData icon;
  final Color accent;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14.sp, color: accent),
        SizedBox(width: 6.w),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sample note fed to [_NoteCard] when the list is loading.
/// Skeletonizer paints text bones over the rendered title/desc.
final _placeholderNote = Note(
  id: '',
  title: 'Loading note title',
  linkType: NoteLinkType.party,
  linkId: '',
  linkDisplayName: 'Loading',
  description: 'Loading description line one\nLoading description line two',
  createdAt: DateTime(2026),
);

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasActiveFilter});

  /// True when the empty result is the consequence of an active search
  /// query or link-type filter, rather than the source list being
  /// genuinely empty. Drives the copy: the "tap Add Note" prompt only
  /// makes sense for the latter.
  final bool hasActiveFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          hasActiveFilter
              ? 'No notes match the current filters.'
              : 'No notes yet — tap "Add Note" to log your first visit.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}

String _filterLabel(NoteLinkType type) => switch (type) {
  NoteLinkType.party => 'Parties',
  NoteLinkType.prospect => 'Prospects',
  NoteLinkType.site => 'Sites',
};

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          "Couldn't load notes. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}
