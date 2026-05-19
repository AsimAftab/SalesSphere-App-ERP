import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/leaves/domain/leave.dart';

/// Result of the picker. Outer `null` means the user dismissed the
/// sheet without picking. When `cleared` is true the caller should
/// reset its selection to null. Otherwise `value` holds the user's
/// pick. Mirrors the shape `note_link_picker` uses so callers handle
/// dismiss / pick / clear with the same three-branch switch.
typedef LeaveCategoryPickerResult = ({LeaveCategory? value, bool cleared});

/// Opens the leave-category bottom sheet. Returns the picker result,
/// or `null` when the user dismisses the sheet without picking.
Future<LeaveCategoryPickerResult?> showLeaveCategoryPicker(
  BuildContext context, {
  LeaveCategory? current,
}) {
  return showModalBottomSheet<LeaveCategoryPickerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LeaveCategorySheet(current: current),
  );
}

/// Per-category icon. Matches the visual reference: medical bag,
/// baby face, baby head, heart-in-hand, church, group of people, and
/// three dots for misc. Colour is intentionally uniform across rows
/// (textPrimary) — the row icon is a glyph, not a category accent.
const Map<LeaveCategory, IconData> _categoryIcons = <LeaveCategory, IconData>{
  LeaveCategory.sick: Icons.medical_services_outlined,
  LeaveCategory.maternity: Icons.child_care_outlined,
  LeaveCategory.paternity: Icons.face_outlined,
  LeaveCategory.compassionate: Icons.volunteer_activism_outlined,
  LeaveCategory.religious: Icons.church_outlined,
  LeaveCategory.familyResponsibility: Icons.groups_outlined,
  LeaveCategory.others: Icons.more_horiz_rounded,
};

IconData leaveCategoryIcon(LeaveCategory c) => _categoryIcons[c]!;

class _LeaveCategorySheet extends StatelessWidget {
  const _LeaveCategorySheet({this.current});

  final LeaveCategory? current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 16.h),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.event_busy_outlined,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Select Category',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: LeaveCategory.values.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) {
                  final category = LeaveCategory.values[index];
                  final isSelected = category == current;
                  return _CategoryRow(
                    icon: _categoryIcons[category]!,
                    label: leaveCategoryLabel(category),
                    selected: isSelected,
                    onTap: () => Navigator.of(context).pop(
                      (value: category, cleared: false),
                    ),
                  );
                },
              ),
            ),
            // Mirrors the "Clear selection" affordance on the
            // CustomOptionPicker sheet — only shown when there's
            // something to clear, so first-time picks don't see a
            // useless tile.
            if (current != null) ...<Widget>[
              Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
              ListTile(
                contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
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
                onTap: () => Navigator.of(context).pop(
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

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
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
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 10.h),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 38.r,
                height: 38.r,
                child: Icon(icon, color: AppColors.textPrimary, size: 22.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
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
