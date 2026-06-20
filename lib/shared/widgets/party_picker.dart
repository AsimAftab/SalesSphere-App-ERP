import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Result of [showPartyPicker]. Outer `null` means the user dismissed the
/// sheet (no change). When `cleared` is true the caller should reset its
/// selection to null. Otherwise `value` holds the user's pick.
typedef PartyPickerResult<T> = ({T? value, bool cleared});

/// Generic single-select bottom sheet with a search bar — the shared
/// implementation behind the various "select a thing" pickers (party,
/// etc.). Presentational: it filters and renders the [items] you pass and
/// returns the user's pick. Equality of [T] is used to mark the current
/// row (both party models override `==` by id), so no id extractor is
/// needed.
Future<PartyPickerResult<T>?> showPartyPicker<T>(
  BuildContext context, {
  required List<T> items,
  required String Function(T) titleOf,
  T? current,
  String Function(T)? subtitleOf,
  String Function(T)? searchTextOf,
  String sheetTitle = 'Select',
  IconData headerIcon = Icons.storefront_outlined,
  IconData rowIcon = Icons.storefront_outlined,
  String searchHint = 'Search',
  String emptyText = 'Nothing here yet.',
  String noMatchText = 'No matches found.',
  bool clearable = true,
}) {
  return showModalBottomSheet<PartyPickerResult<T>>(
    context: context,
    isScrollControlled: true,
    // Use the root navigator so the sheet (and its scrim) render above the
    // shell's bottom nav bar instead of being clipped to the page body.
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PartyPickerSheet<T>(
      items: items,
      titleOf: titleOf,
      current: current,
      subtitleOf: subtitleOf,
      searchTextOf: searchTextOf,
      sheetTitle: sheetTitle,
      headerIcon: headerIcon,
      rowIcon: rowIcon,
      searchHint: searchHint,
      emptyText: emptyText,
      noMatchText: noMatchText,
      clearable: clearable,
    ),
  );
}

class _PartyPickerSheet<T> extends StatefulWidget {
  const _PartyPickerSheet({
    required this.items,
    required this.titleOf,
    required this.current,
    required this.subtitleOf,
    required this.searchTextOf,
    required this.sheetTitle,
    required this.headerIcon,
    required this.rowIcon,
    required this.searchHint,
    required this.emptyText,
    required this.noMatchText,
    required this.clearable,
  });

  final List<T> items;
  final String Function(T) titleOf;
  final T? current;
  final String Function(T)? subtitleOf;
  final String Function(T)? searchTextOf;
  final String sheetTitle;
  final IconData headerIcon;
  final IconData rowIcon;
  final String searchHint;
  final String emptyText;
  final String noMatchText;
  final bool clearable;

  @override
  State<_PartyPickerSheet<T>> createState() => _PartyPickerSheetState<T>();
}

class _PartyPickerSheetState<T> extends State<_PartyPickerSheet<T>> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _searchText(T item) =>
      (widget.searchTextOf ?? widget.titleOf)(item).toLowerCase();

  List<T> _filter() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items
        .where((item) => _searchText(item).contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
    final filtered = _filter();
    return SafeArea(
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
                  Icon(
                    widget.headerIcon,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    widget.sheetTitle,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
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
              child: filtered.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Text(
                          _query.isEmpty ? widget.emptyText : widget.noMatchText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => SizedBox(height: 6.h),
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        return _PartyRow<T>(
                          title: widget.titleOf(item),
                          subtitle: widget.subtitleOf?.call(item),
                          icon: widget.rowIcon,
                          selected: item == current,
                          onTap: () =>
                              Navigator.of(context).pop<PartyPickerResult<T>>(
                            (value: item, cleared: false),
                          ),
                        );
                      },
                    ),
            ),
            if (current != null && widget.clearable) ...<Widget>[
              Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 20.w),
                leading: Icon(Icons.close, color: AppColors.error, size: 22.sp),
                title: Text(
                  'Clear selection',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(context).pop<PartyPickerResult<T>>(
                  (value: null, cleared: true),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PartyRow<T> extends StatelessWidget {
  const _PartyRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool selected;
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
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.secondary, size: 18.sp),
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
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                      SizedBox(height: 2.h),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (selected) ...<Widget>[
                SizedBox(width: 8.w),
                Icon(Icons.check_circle, color: AppColors.secondary, size: 22.sp),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Field-shaped tappable that opens [showPartyPicker] and forwards the
/// user's pick (or clear) via [onChanged]. Built on `PrimaryTextField`
/// (read-only + onTap) so it matches every other field on a form. The
/// shared replacement for the per-feature "party field" widgets.
class PartyPickerField<T> extends StatefulWidget {
  const PartyPickerField({
    required this.value,
    required this.onChanged,
    required this.items,
    required this.titleOf,
    required this.label,
    required this.hintText,
    this.subtitleOf,
    this.searchTextOf,
    this.prefixIcon = Icons.storefront_outlined,
    this.rowIcon = Icons.storefront_outlined,
    this.sheetTitle = 'Select',
    this.searchHint = 'Search',
    this.emptyText = 'Nothing here yet.',
    this.noMatchText = 'No matches found.',
    this.enabled = true,
    super.key,
  });

  final T? value;
  final ValueChanged<T?> onChanged;
  final List<T> items;
  final String Function(T) titleOf;
  final String Function(T)? subtitleOf;
  final String Function(T)? searchTextOf;
  final String label;
  final String hintText;
  final IconData prefixIcon;
  final IconData rowIcon;
  final String sheetTitle;
  final String searchHint;
  final String emptyText;
  final String noMatchText;
  final bool enabled;

  @override
  State<PartyPickerField<T>> createState() => _PartyPickerFieldState<T>();
}

class _PartyPickerFieldState<T> extends State<PartyPickerField<T>> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final value = widget.value;
    _controller.text = value == null ? '' : widget.titleOf(value);
  }

  @override
  void didUpdateWidget(PartyPickerField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final value = widget.value;
    final next = value == null ? '' : widget.titleOf(value);
    if (_controller.text == next) return;
    // Defer the controller mutation out of the parent's build window —
    // setting `.text` synchronously trips Flutter's build-phase assertion.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.text == next) return;
      _controller.text = next;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final result = await showPartyPicker<T>(
      context,
      items: widget.items,
      titleOf: widget.titleOf,
      current: widget.value,
      subtitleOf: widget.subtitleOf,
      searchTextOf: widget.searchTextOf,
      sheetTitle: widget.sheetTitle,
      headerIcon: widget.prefixIcon,
      rowIcon: widget.rowIcon,
      searchHint: widget.searchHint,
      emptyText: widget.emptyText,
      noMatchText: widget.noMatchText,
    );
    if (!mounted || result == null) return;
    if (result.cleared) {
      widget.onChanged(null);
    } else if (result.value != null) {
      widget.onChanged(result.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrimaryTextField(
      controller: _controller,
      label: widget.label,
      hintText: widget.hintText,
      prefixIcon: widget.prefixIcon,
      enabled: widget.enabled,
      readOnly: true,
      onTap: _open,
      suffixWidget: widget.enabled
          ? Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.textSecondary,
                size: 20.sp,
              ),
            )
          : null,
    );
  }
}
