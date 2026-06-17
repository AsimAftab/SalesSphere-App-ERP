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
import 'package:sales_sphere_erp/features/unplanned_visits/domain/visit_target.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Opens a 3-tab bottom sheet (Customers / Prospects / Sites) and returns the
/// [VisitTarget] the rep selects — carrying its coordinates so the start flow
/// can run the geofence gate. Mirrors the notes link picker. Returns `null`
/// when dismissed without a pick.
Future<VisitTarget?> showVisitTargetPicker(BuildContext context) {
  return showModalBottomSheet<VisitTarget>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VisitTargetPickerSheet(),
  );
}

const Color _customerAccent = AppColors.secondary;
const Color _prospectAccent = AppColors.warning;
const Color _siteAccent = AppColors.green500;

/// Name+address contains-filter shared by the three tab lists.
List<T> _filter<T>(
  List<T> source,
  String query,
  String Function(T) name,
  String Function(T) address,
) {
  if (query.isEmpty) return source;
  return source
      .where(
        (item) =>
            name(item).toLowerCase().contains(query) ||
            address(item).toLowerCase().contains(query),
      )
      .toList(growable: false);
}

class _VisitTargetPickerSheet extends StatelessWidget {
  const _VisitTargetPickerSheet();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
                    Icon(Icons.pin_drop_rounded,
                        color: AppColors.primary, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'Who are you visiting?',
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
                labelStyle:
                    TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
                tabs: const <Widget>[
                  Tab(text: 'Customers'),
                  Tab(text: 'Prospects'),
                  Tab(text: 'Sites'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: <Widget>[
                    _CustomersTab(),
                    _ProspectsTab(),
                    _SitesTab(),
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

/// Search bar + list shell shared by the three tabs.
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
                    icon: Icon(Icons.close,
                        color: AppColors.textSecondary, size: 18.sp),
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
          ),
        ),
        Expanded(child: widget.builder(context, _query.trim().toLowerCase())),
      ],
    );
  }
}

class _CustomersTab extends ConsumerWidget {
  const _CustomersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabShell(
      searchHint: 'Search customers',
      builder: (context, query) {
        final asyncList = ref.watch(partiesListVisibleProvider);
        return asyncList.when(
          loading: () => const _LoadingList(),
          error: (_, __) =>
              const _MessageList(message: "Couldn't load customers."),
          data: (all) {
            final filtered =
                _filter(all, query, (Party p) => p.name, (p) => p.address);
            if (filtered.isEmpty) {
              return _MessageList(
                message: query.isEmpty
                    ? 'No customers yet.'
                    : 'No customers match your search.',
              );
            }
            return _list(
              filtered.length,
              (i) {
                final p = filtered[i];
                return _TargetRow(
                  icon: Icons.storefront_outlined,
                  accent: _customerAccent,
                  title: p.name,
                  subtitle: p.address,
                  hasLocation: p.latitude != null && p.longitude != null,
                  onTap: () => Navigator.of(context).pop<VisitTarget>(
                    VisitTarget(
                      type: VisitTargetType.customer,
                      id: p.id,
                      displayName: p.name,
                      address: p.address,
                      latitude: p.latitude,
                      longitude: p.longitude,
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
}

class _ProspectsTab extends ConsumerWidget {
  const _ProspectsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabShell(
      searchHint: 'Search prospects',
      builder: (context, query) {
        final asyncList = ref.watch(prospectsListProvider);
        return asyncList.when(
          loading: () => const _LoadingList(),
          error: (_, __) =>
              const _MessageList(message: "Couldn't load prospects."),
          data: (all) {
            final filtered = _filter(
                all, query, (Prospect p) => p.name, (p) => p.address);
            if (filtered.isEmpty) {
              return _MessageList(
                message: query.isEmpty
                    ? 'No prospects yet.'
                    : 'No prospects match your search.',
              );
            }
            return _list(
              filtered.length,
              (i) {
                final p = filtered[i];
                return _TargetRow(
                  icon: Icons.person_search_outlined,
                  accent: _prospectAccent,
                  title: p.name,
                  subtitle: p.address,
                  hasLocation: p.latitude != null && p.longitude != null,
                  onTap: () => Navigator.of(context).pop<VisitTarget>(
                    VisitTarget(
                      type: VisitTargetType.prospect,
                      id: p.id,
                      displayName: p.name,
                      address: p.address,
                      latitude: p.latitude,
                      longitude: p.longitude,
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
}

class _SitesTab extends ConsumerWidget {
  const _SitesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TabShell(
      searchHint: 'Search sites',
      builder: (context, query) {
        final asyncList = ref.watch(sitesListProvider);
        return asyncList.when(
          loading: () => const _LoadingList(),
          error: (_, __) => const _MessageList(message: "Couldn't load sites."),
          data: (all) {
            final filtered =
                _filter(all, query, (Site s) => s.name, (s) => s.address);
            if (filtered.isEmpty) {
              return _MessageList(
                message: query.isEmpty
                    ? 'No sites yet.'
                    : 'No sites match your search.',
              );
            }
            return _list(
              filtered.length,
              (i) {
                final s = filtered[i];
                return _TargetRow(
                  icon: Icons.location_city_outlined,
                  accent: _siteAccent,
                  title: s.name,
                  subtitle: s.address,
                  hasLocation: s.latitude != null && s.longitude != null,
                  onTap: () => Navigator.of(context).pop<VisitTarget>(
                    VisitTarget(
                      type: VisitTargetType.site,
                      id: s.id,
                      displayName: s.name,
                      address: s.address,
                      latitude: s.latitude,
                      longitude: s.longitude,
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
}

ListView _list(int count, Widget Function(int) itemBuilder) {
  return ListView.separated(
    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
    itemCount: count,
    separatorBuilder: (_, __) => SizedBox(height: 6.h),
    itemBuilder: (_, i) => itemBuilder(i),
  );
}

class _TargetRow extends StatelessWidget {
  const _TargetRow({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.hasLocation,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final bool hasLocation;
  final VoidCallback onTap;

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
                        fontWeight: FontWeight.w600,
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
              // A small hint when the entity has no coordinates — the geofence
              // gate will be skipped for it.
              if (!hasLocation) ...<Widget>[
                SizedBox(width: 8.w),
                Icon(Icons.location_off_outlined,
                    color: AppColors.textHint, size: 16.sp),
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

class _MessageList extends StatelessWidget {
  const _MessageList({required this.message});

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
