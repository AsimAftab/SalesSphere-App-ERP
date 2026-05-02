import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/parties/data/parties_repository.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Sentinel returned from the bottom sheet to signal that the user wants to
/// add a brand new party type instead of picking an existing one.
const _addNewSentinel = '__add_new__';

/// Sentinel returned when the user wants to clear the current selection.
const _clearSentinel = '__clear__';

/// Field widget for selecting a party type. In view mode shows the value
/// with a lock icon. In edit mode tap opens a bottom sheet listing types
/// (loaded from [partyTypesProvider]) plus an "Add New Party Type" entry —
/// picking the latter reveals an inline text field for entering a custom
/// value.
class PartyTypePicker extends ConsumerStatefulWidget {
  const PartyTypePicker({
    required this.value,
    required this.onChanged,
    required this.enabled,
    super.key,
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  ConsumerState<PartyTypePicker> createState() => _PartyTypePickerState();
}

class _PartyTypePickerState extends ConsumerState<PartyTypePicker> {
  bool _addingNew = false;
  bool _focused = false;
  final TextEditingController _newController = TextEditingController();

  @override
  void didUpdateWidget(PartyTypePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External update from the parent (e.g. detail page hydrating from the
    // saved party) cancels the add-new flow.
    if (oldWidget.value != widget.value && widget.value != null) {
      _addingNew = false;
      _newController.text = '';
    }
  }

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  Future<void> _openSheet() async {
    setState(() => _focused = true);
    final types = await ref.read(partyTypesProvider.future);
    if (!mounted) {
      return;
    }
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PartyTypeBottomSheet(
        types: types,
        selected: widget.value,
      ),
    );
    if (!mounted) return;
    setState(() => _focused = false);
    if (result == null) return;
    if (result == _addNewSentinel) {
      setState(() {
        _addingNew = true;
        _newController.text = '';
      });
      widget.onChanged(null);
    } else if (result == _clearSentinel) {
      setState(() {
        _addingNew = false;
        _newController.text = '';
      });
      widget.onChanged(null);
    } else {
      setState(() {
        _addingNew = false;
        _newController.text = '';
      });
      widget.onChanged(result);
    }
  }

  void _cancelAddNew() {
    setState(() {
      _addingNew = false;
      _newController.text = '';
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PartyTypeField(
          value: _addingNew ? 'Adding new type…' : widget.value,
          enabled: widget.enabled && !_addingNew,
          focused: _focused,
          onTap: widget.enabled && !_addingNew ? _openSheet : null,
        ),
        if (_addingNew) ...<Widget>[
          SizedBox(height: 12.h),
          PrimaryTextField(
            controller: _newController,
            label: 'New party type',
            prefixIcon: Icons.add_circle_outline,
            textInputAction: TextInputAction.done,
            suffixWidget: IconButton(
              icon: Icon(
                Icons.close,
                size: 20.sp,
                color: AppColors.textSecondary,
              ),
              tooltip: 'Cancel',
              onPressed: _cancelAddNew,
            ),
            onChanged: (v) =>
                widget.onChanged(v.trim().isEmpty ? null : v.trim()),
          ),
        ],
      ],
    );
  }
}

/// The field-shell that displays the current selection. Tappable when
/// [onTap] is non-null.
class _PartyTypeField extends StatelessWidget {
  const _PartyTypeField({
    required this.value,
    required this.enabled,
    required this.focused,
    required this.onTap,
  });

  final String? value;
  final bool enabled;
  final bool focused;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isReadOnly = !enabled;
    final hasValue = value != null && value!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: InputDecorator(
        // `isEmpty: true` lets the label sit inside the field as a
        // placeholder; once a value is chosen it animates up to the border.
        isEmpty: !hasValue,
        isFocused: focused,
        decoration: InputDecoration(
          labelText: 'Party Type',
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          labelStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
            fontFamily: 'Poppins',
          ),
          floatingLabelStyle: TextStyle(
            color: isReadOnly
                ? AppColors.textPrimary
                : AppColors.secondary,
            fontSize: 13.sp,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(
            Icons.category_outlined,
            color: AppColors.textSecondary,
            size: 20.sp,
          ),
          suffixIcon: Icon(
            isReadOnly ? Icons.lock_outline : Icons.keyboard_arrow_down,
            color: AppColors.textSecondary,
            size: 20.sp,
          ),
          filled: true,
          fillColor: isReadOnly ? AppColors.background : AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide:
                const BorderSide(color: AppColors.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide:
                const BorderSide(color: AppColors.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide:
                const BorderSide(color: AppColors.secondary, width: 2),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.r),
            borderSide: BorderSide(
              color: AppColors.border.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
        ),
        child: hasValue
            ? Text(
                value!,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15.sp,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w500,
                ),
              )
            : null,
      ),
    );
  }
}

class _PartyTypeBottomSheet extends StatelessWidget {
  const _PartyTypeBottomSheet({
    required this.types,
    required this.selected,
  });

  final List<String> types;
  final String? selected;

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
                    Icons.category_outlined,
                    color: AppColors.primary,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Select Party Type',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 320.h),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: types.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
                itemBuilder: (context, index) {
                  final type = types[index];
                  final isSelected = type == selected;
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
                    title: Text(
                      type,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: AppColors.secondary,
                            size: 22.sp,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(type),
                  );
                },
              ),
            ),
            Divider(
              height: 1,
              color: AppColors.border.withValues(alpha: 0.5),
            ),
            ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
              leading: Icon(
                Icons.add_circle_outline,
                color: AppColors.secondary,
                size: 22.sp,
              ),
              title: Text(
                'Add New Party Type',
                style: TextStyle(
                  color: AppColors.secondary,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.of(context).pop(_addNewSentinel),
            ),
            if (selected != null && selected!.isNotEmpty) ...<Widget>[
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
                onTap: () => Navigator.of(context).pop(_clearSentinel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
