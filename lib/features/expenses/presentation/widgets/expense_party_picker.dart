import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_party.dart';
import 'package:sales_sphere_erp/features/expenses/presentation/providers/expenses_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Result of the picker. Outer `null` means the user dismissed the
/// sheet (no change). When `cleared` is true the caller should reset
/// its selection to null. Otherwise `value` holds the user's pick.
///
/// Mirrors the notes link picker's result shape so the field widget
/// reads the same way.
typedef ExpensePartyPickerResult = ({ExpenseParty? value, bool cleared});

/// Accent for the party row icon — matches the notes link picker's
/// party tab colour so the two pickers read as the same family.
const Color _partyAccent = AppColors.secondary;

/// Opens a single-list bottom sheet of parties with a search bar at the
/// top. Pass [current] to mark the matching row with a check icon and
/// surface a "Clear selection" tile at the bottom. Built to match
/// `showNoteLinkPicker`'s look (drag handle, header, search, icon-avatar
/// rows), minus the tabs — expenses link to a party only.
Future<ExpensePartyPickerResult?> showExpensePartyPicker(
  BuildContext context, {
  ExpenseParty? current,
}) {
  return showModalBottomSheet<ExpensePartyPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExpensePartyPickerSheet(current: current),
  );
}

class _ExpensePartyPickerSheet extends StatefulWidget {
  const _ExpensePartyPickerSheet({this.current});

  final ExpenseParty? current;

  @override
  State<_ExpensePartyPickerSheet> createState() =>
      _ExpensePartyPickerSheetState();
}

class _ExpensePartyPickerSheetState extends State<_ExpensePartyPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ExpenseParty> _filter(List<ExpenseParty> source) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.address.toLowerCase().contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.current;
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
                    Icons.storefront_outlined,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Select party',
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
                hintText: 'Search parties',
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
              child: Consumer(
                builder: (context, ref, _) {
                  final parties = ref.watch(expensePartiesProvider);
                  final filtered = _filter(parties);
                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24.w),
                        child: Text(
                          _query.isEmpty
                              ? 'No parties yet.'
                              : 'No parties match your search.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 12.h),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => SizedBox(height: 6.h),
                    itemBuilder: (context, i) {
                      final party = filtered[i];
                      return _PartyRow(
                        party: party,
                        selected: party.id == current?.id,
                        onTap: () =>
                            Navigator.of(context).pop<ExpensePartyPickerResult>(
                          (value: party, cleared: false),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (current != null) ...<Widget>[
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
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(context).pop<ExpensePartyPickerResult>(
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

class _PartyRow extends StatelessWidget {
  const _PartyRow({
    required this.party,
    required this.selected,
    required this.onTap,
  });

  final ExpenseParty party;
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
                  color: _partyAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.storefront_outlined,
                  color: _partyAccent,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      party.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      party.address,
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
                Icon(Icons.check_circle, color: _partyAccent, size: 22.sp),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
