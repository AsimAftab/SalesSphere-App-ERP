import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';
import 'package:sales_sphere_erp/features/parties/presentation/providers/parties_providers.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/features/prospects/presentation/providers/prospects_providers.dart';
import 'package:sales_sphere_erp/features/sites/domain/site.dart';
import 'package:sales_sphere_erp/features/sites/presentation/providers/sites_providers.dart';
import 'package:sales_sphere_erp/features/visit_notes/domain/visit_note.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// One pick from the bottom-sheet picker. The form stores all three
/// fields on the visit note so the list page can render without
/// resolving cross-feature lookups per row.
@immutable
class VisitLinkSelection {
  const VisitLinkSelection({
    required this.type,
    required this.id,
    required this.displayName,
  });

  final VisitNoteLinkType type;
  final String id;
  final String displayName;
}

/// Result of the picker. Outer `null` means the user dismissed the
/// sheet (no change). When `cleared` is true the caller should reset
/// its selection to null. Otherwise `value` holds the user's pick.
typedef VisitLinkPickerResult = ({VisitLinkSelection? value, bool cleared});

/// Opens a 3-tab bottom sheet (Parties / Prospects / Sites). Each
/// tab has its own search bar that filters the active list. Pass
/// [current] to (a) open the picker on the matching tab and (b)
/// mark the row with a check icon. The bottom of the sheet shows a
/// "Clear selection" tile when [current] is non-null.
Future<VisitLinkPickerResult?> showVisitLinkPicker(
  BuildContext context, {
  VisitLinkSelection? current,
}) {
  return showModalBottomSheet<VisitLinkPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VisitLinkPickerSheet(current: current),
  );
}

/// Module-colour palette for the picker's tab + row icon. Mirrors the
/// hub's per-module identity so the user picks "the blue one" if
/// they're after a party, etc.
const Color _partyAccent = AppColors.secondary;
const Color _prospectAccent = AppColors.warning;
const Color _siteAccent = AppColors.green500;

class _VisitLinkPickerSheet extends StatelessWidget {
  const _VisitLinkPickerSheet({this.current});

  final VisitLinkSelection? current;

  int get _initialTabIndex {
    final c = current;
    if (c == null) return 0;
    return switch (c.type) {
      VisitNoteLinkType.party => 0,
      VisitNoteLinkType.prospect => 1,
      VisitNoteLinkType.site => 2,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = current;
    final partySelectedId =
        c != null && c.type == VisitNoteLinkType.party ? c.id : null;
    final prospectSelectedId =
        c != null && c.type == VisitNoteLinkType.prospect ? c.id : null;
    final siteSelectedId =
        c != null && c.type == VisitNoteLinkType.site ? c.id : null;

    return DefaultTabController(
      length: 3,
      initialIndex: _initialTabIndex,
      child: SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(0, 12.h, 0, 0),
          child: Column(
            children: <Widget>[
              // Drag handle.
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 12.h),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.link_rounded,
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Linked to',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              TabBar(
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.secondary,
                indicatorWeight: 2.5,
                labelStyle: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const <Widget>[
                  Tab(text: 'Parties'),
                  Tab(text: 'Prospects'),
                  Tab(text: 'Sites'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _PartiesTab(selectedId: partySelectedId),
                    _ProspectsTab(selectedId: prospectSelectedId),
                    _SitesTab(selectedId: siteSelectedId),
                  ],
                ),
              ),
              if (c != null) ...<Widget>[
                Divider(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
                ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
                  leading: Icon(
                    Icons.close,
                    color: AppColors.error,
                    size: 22.sp,
                  ),
                  title: Text(
                    'Clear selection',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop<VisitLinkPickerResult>(
                    (value: null, cleared: true),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Common shell for each tab — a search bar at the top and a list
/// area below. The list itself is supplied by the tab subclass since
/// each one talks to a different provider + entity type.
class _TabShell extends StatefulWidget {
  const _TabShell({required this.builder, required this.searchHint});

  final String searchHint;
  final Widget Function(BuildContext context, String query) builder;

  @override
  State<_TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<_TabShell> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 8.h),
          child: PrimaryTextField(
            controller: _searchController,
            hintText: widget.searchHint,
            prefixIcon: Icons.search,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v),
            suffixWidget: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 18.sp,
                    ),
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                    ),
          ),
        ),
        Expanded(
          child: widget.builder(context, _query.trim().toLowerCase()),
        ),
      ],
    );
  }
}

class _PartiesTab extends ConsumerWidget {
  const _PartiesTab({this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabShell(
      searchHint: 'Search parties',
      builder: (context, query) {
        final asyncList = ref.watch(partiesListProvider);
        return asyncList.when(
          loading: () => const _LoadingList(),
          error: (_, __) => const _ErrorList(message: "Couldn't load parties."),
          data: (all) {
            final filtered = _filterParties(all, query);
            if (filtered.isEmpty) {
              return _EmptyList(
                hasQuery: query.isNotEmpty,
                emptyText: 'No parties yet.',
                noMatchText: 'No parties match your search.',
              );
            }
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => SizedBox(height: 6.h),
              itemBuilder: (context, i) {
                final party = filtered[i];
                return _LinkRow(
                  icon: Icons.storefront_outlined,
                  accent: _partyAccent,
                  title: party.name,
                  subtitle: party.address,
                  selected: party.id == selectedId,
                  onTap: () => Navigator.of(context).pop<VisitLinkPickerResult>(
                    (
                      value: VisitLinkSelection(
                        type: VisitNoteLinkType.party,
                        id: party.id,
                        displayName: party.name,
                      ),
                      cleared: false,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<Party> _filterParties(List<Party> source, String q) {
    if (q.isEmpty) return source;
    return source
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.address.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }
}

class _ProspectsTab extends ConsumerWidget {
  const _ProspectsTab({this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabShell(
      searchHint: 'Search prospects',
      builder: (context, query) {
        final asyncList = ref.watch(prospectsListProvider);
        return asyncList.when(
          loading: () => const _LoadingList(),
          error: (_, __) =>
              const _ErrorList(message: "Couldn't load prospects."),
          data: (all) {
            final filtered = _filterProspects(all, query);
            if (filtered.isEmpty) {
              return _EmptyList(
                hasQuery: query.isNotEmpty,
                emptyText: 'No prospects yet.',
                noMatchText: 'No prospects match your search.',
              );
            }
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => SizedBox(height: 6.h),
              itemBuilder: (context, i) {
                final prospect = filtered[i];
                return _LinkRow(
                  icon: Icons.person_search_outlined,
                  accent: _prospectAccent,
                  title: prospect.name,
                  subtitle: prospect.address,
                  selected: prospect.id == selectedId,
                  onTap: () => Navigator.of(context).pop<VisitLinkPickerResult>(
                    (
                      value: VisitLinkSelection(
                        type: VisitNoteLinkType.prospect,
                        id: prospect.id,
                        displayName: prospect.name,
                      ),
                      cleared: false,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<Prospect> _filterProspects(List<Prospect> source, String q) {
    if (q.isEmpty) return source;
    return source
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.address.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }
}

class _SitesTab extends ConsumerWidget {
  const _SitesTab({this.selectedId});

  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabShell(
      searchHint: 'Search sites',
      builder: (context, query) {
        final asyncList = ref.watch(sitesListProvider);
        return asyncList.when(
          loading: () => const _LoadingList(),
          error: (_, __) => const _ErrorList(message: "Couldn't load sites."),
          data: (all) {
            final filtered = _filterSites(all, query);
            if (filtered.isEmpty) {
              return _EmptyList(
                hasQuery: query.isNotEmpty,
                emptyText: 'No sites yet.',
                noMatchText: 'No sites match your search.',
              );
            }
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => SizedBox(height: 6.h),
              itemBuilder: (context, i) {
                final site = filtered[i];
                return _LinkRow(
                  icon: Icons.location_city_outlined,
                  accent: _siteAccent,
                  title: site.name,
                  subtitle: site.address,
                  selected: site.id == selectedId,
                  onTap: () => Navigator.of(context).pop<VisitLinkPickerResult>(
                    (
                      value: VisitLinkSelection(
                        type: VisitNoteLinkType.site,
                        id: site.id,
                        displayName: site.name,
                      ),
                      cleared: false,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  List<Site> _filterSites(List<Site> source, String q) {
    if (q.isEmpty) return source;
    return source
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.address.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            children: <Widget>[
              Container(
                width: 38.r,
                height: 38.r,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 18.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (selected) ...<Widget>[
                SizedBox(width: 8.w),
                Icon(Icons.check_circle, color: accent, size: 22.sp),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({
    required this.hasQuery,
    required this.emptyText,
    required this.noMatchText,
  });

  final bool hasQuery;
  final String emptyText;
  final String noMatchText;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Text(
          hasQuery ? noMatchText : emptyText,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
        ),
      ),
    );
  }
}
