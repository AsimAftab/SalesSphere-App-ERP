import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/visit_notes/domain/visit_note.dart';
import 'package:sales_sphere_erp/features/visit_notes/presentation/providers/visit_notes_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_filter_bar.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/refreshable_list.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Per-link-type icon + colour. Mirrors the hub's identity so a row's
/// link badge reads consistently with where the user picked it from.
const _linkPalette = <VisitNoteLinkType, ({IconData icon, Color accent})>{
  VisitNoteLinkType.party: (
    icon: Icons.storefront_outlined,
    accent: AppColors.secondary,
  ),
  VisitNoteLinkType.prospect: (
    icon: Icons.person_search_outlined,
    accent: AppColors.warning,
  ),
  VisitNoteLinkType.site: (
    icon: Icons.location_city_outlined,
    accent: AppColors.green500,
  ),
};

class VisitNotesListPage extends ConsumerStatefulWidget {
  const VisitNotesListPage({super.key});

  @override
  ConsumerState<VisitNotesListPage> createState() =>
      _VisitNotesListPageState();
}

class _VisitNotesListPageState extends ConsumerState<VisitNotesListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  /// `null` means "All" — no link-type filter applied. Otherwise the
  /// list is narrowed to notes whose [VisitNote.linkType] matches.
  VisitNoteLinkType? _linkFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilter => _query.trim().isNotEmpty || _linkFilter != null;

  List<VisitNote> _applyFilters(List<VisitNote> source) {
    final byType = _linkFilter == null
        ? source
        : source.where((n) => n.linkType == _linkFilter);
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return byType.toList(growable: false);
    return byType
        .where(
          (n) =>
              n.title.toLowerCase().contains(q) ||
              n.description.toLowerCase().contains(q) ||
              n.linkDisplayName.toLowerCase().contains(q),
        )
        .toList(growable: false);
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
    final notesAsync = ref.watch(visitNotesListProvider);

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        floatingActionButton: PrimaryFabButton(
          label: 'Add Note',
          onPressed: () => context.push(Routes.addVisitNote),
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
                    child: PrimaryFilterBar<VisitNoteLinkType?>(
                      selected: _linkFilter,
                      onChanged: (next) =>
                          setState(() => _linkFilter = next),
                      options: <FilterBarOption<VisitNoteLinkType?>>[
                        const FilterBarOption<VisitNoteLinkType?>(
                          value: null,
                          label: 'All Notes',
                          icon: Icons.list_alt_rounded,
                        ),
                        for (final entry in _linkPalette.entries)
                          FilterBarOption<VisitNoteLinkType?>(
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
                        'Visit Notes',
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
                    child: RefreshableList<VisitNote>(
                      async: notesAsync,
                      filter: _applyFilters,
                      onRefresh: () async {
                        ref.invalidate(visitNotesListProvider);
                        await ref.read(visitNotesListProvider.future);
                      },
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 140.h),
                      itemBuilder: (context, note) => _VisitNoteCard(
                        note: note,
                        onTap: () => context.push(
                          Routes.visitNoteDetailPath(note.id),
                          extra: note,
                        ),
                      ),
                      skeletonItemBuilder: (_, __) => _VisitNoteCard(
                        note: _placeholderNote,
                        onTap: () {},
                      ),
                      emptyBuilder: (_) =>
                          _EmptyState(hasActiveFilter: _hasActiveFilter),
                      errorBuilder: (_, __, ___) => const _ErrorState(),
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
            'Visit Notes',
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

class _VisitNoteCard extends StatelessWidget {
  const _VisitNoteCard({required this.note, required this.onTap});

  final VisitNote note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _linkPalette[note.linkType]!;
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
                      DateFormat('dd MMM').format(note.createdAt),
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
                  label: note.linkDisplayName,
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
              color: accent,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sample visit-note fed to [_VisitNoteCard] when the list is loading.
/// Skeletonizer paints text bones over the rendered title/desc.
final _placeholderNote = VisitNote(
  id: '',
  title: 'Loading visit-note title',
  linkType: VisitNoteLinkType.party,
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
              ? 'No visit notes match the current filters.'
              : 'No visit notes yet — tap "Add Note" to log your first visit.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}

String _filterLabel(VisitNoteLinkType type) => switch (type) {
      VisitNoteLinkType.party => 'Parties',
      VisitNoteLinkType.prospect => 'Prospects',
      VisitNoteLinkType.site => 'Sites',
    };

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Text(
          "Couldn't load visit notes. Pull to retry.",
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      ),
    );
  }
}
