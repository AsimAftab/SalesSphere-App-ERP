import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Sentinel returned from the bottom sheet when the user wants to enter a
/// brand new value via the inline text field below the picker.
const _addNewSentinel = '__custom_option_picker_add_new__';

/// Sentinel returned when the user wants to clear the current selection.
const _clearSentinel = '__custom_option_picker_clear__';

/// Field-shaped picker that opens a bottom sheet with the supplied
/// [options]. Mirrors the visual shape of `PrimaryTextField` so it
/// composes inside `SectionCard`s without breaking the form's rhythm.
///
/// In view mode (`enabled: false`) the field shows a lock icon and is
/// not tappable. In edit mode tap opens the sheet. Pass [onAddNew] to
/// enable an "Add new" entry in the sheet — picking it reveals an
/// inline text field below the picker that fires [onAddNew] on every
/// keystroke (mirrors the party-type behaviour).
class CustomOptionPicker extends StatefulWidget {
  const CustomOptionPicker({
    required this.value,
    required this.options,
    required this.onChanged,
    required this.label,
    this.prefixIcon,
    this.hintText,
    this.sheetTitle,
    this.sheetIcon,
    this.enabled = true,
    this.onAddNew,
    this.addNewLabel,
    this.newItemLabel,
    this.onBeforeOpen,
    super.key,
  });

  /// Currently selected display value. `null` when nothing is picked.
  final String? value;

  /// Choices shown inside the bottom sheet.
  final List<String> options;

  /// Fired with the picked option, or `null` when the user clears.
  final ValueChanged<String?> onChanged;

  /// Field label (floats above when a value is present).
  final String label;

  /// Optional leading icon inside the field.
  final IconData? prefixIcon;

  /// Placeholder shown inside the field when no value is picked.
  /// Defaults to `'Select <label.toLowerCase()>'` when null.
  final String? hintText;

  /// Header title shown at the top of the bottom sheet. Defaults to
  /// `'Select <label>'` when null.
  final String? sheetTitle;

  /// Optional icon next to [sheetTitle].
  final IconData? sheetIcon;

  final bool enabled;

  /// When non-null, the bottom sheet shows an "Add new" tile. Picking
  /// it reveals an inline text field below the picker that calls
  /// [onAddNew] on every keystroke (committed value, trimmed; `null`
  /// when empty).
  final ValueChanged<String?>? onAddNew;

  /// Label for the "Add new" tile inside the bottom sheet. Defaults
  /// to `'Add new <label>'` when null.
  final String? addNewLabel;

  /// Label for the inline text field that appears after the user
  /// chooses "Add new". Defaults to `'New <label>'` when null.
  final String? newItemLabel;

  /// Awaited just before the sheet opens — gives Riverpod-backed
  /// wrappers a chance to load (or refresh) their catalogue so the
  /// sheet always shows populated [options]. Without this, opening the
  /// picker before the provider has resolved would render an empty
  /// sheet and the user couldn't pick anything.
  final Future<void> Function()? onBeforeOpen;

  @override
  State<CustomOptionPicker> createState() => _CustomOptionPickerState();
}

class _CustomOptionPickerState extends State<CustomOptionPicker> {
  bool _addingNew = false;
  bool _focused = false;
  final TextEditingController _newController = TextEditingController();

  @override
  void didUpdateWidget(CustomOptionPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // External update from the parent (e.g. detail page hydrating from
    // the saved entity) cancels the add-new flow.
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

  String get _resolvedHintText =>
      widget.hintText ?? 'Select ${widget.label.toLowerCase()}';

  String get _resolvedSheetTitle =>
      widget.sheetTitle ?? 'Select ${widget.label}';

  String get _resolvedAddNewLabel =>
      widget.addNewLabel ?? 'Add new ${widget.label.toLowerCase()}';

  String get _resolvedNewItemLabel =>
      widget.newItemLabel ?? 'New ${widget.label.toLowerCase()}';

  Future<void> _openSheet() async {
    setState(() => _focused = true);
    // Pre-load the catalogue so the sheet always has options — without
    // this, tapping the field before the provider resolves opens an
    // empty sheet and silently swallows the user's pick.
    if (widget.onBeforeOpen != null) {
      await widget.onBeforeOpen!();
      if (!mounted) return;
    }
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomOptionPickerSheet(
        title: _resolvedSheetTitle,
        titleIcon: widget.sheetIcon,
        options: widget.options,
        selected: widget.value,
        addNewLabel: widget.onAddNew == null ? null : _resolvedAddNewLabel,
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
      widget.onAddNew?.call(null);
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
    widget.onAddNew?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _CustomOptionPickerShell(
          label: widget.label,
          value: _addingNew ? 'Adding new…' : widget.value,
          hintText: _resolvedHintText,
          prefixIcon: widget.prefixIcon,
          enabled: widget.enabled && !_addingNew,
          focused: _focused,
          onTap: widget.enabled && !_addingNew ? _openSheet : null,
        ),
        if (_addingNew) ...<Widget>[
          SizedBox(height: 12.h),
          PrimaryTextField(
            controller: _newController,
            label: _resolvedNewItemLabel,
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
                widget.onAddNew?.call(v.trim().isEmpty ? null : v.trim()),
          ),
        ],
      ],
    );
  }
}

/// Field shell that displays the current selection. Tappable when
/// [onTap] is non-null.
class _CustomOptionPickerShell extends StatelessWidget {
  const _CustomOptionPickerShell({
    required this.label,
    required this.value,
    required this.hintText,
    required this.prefixIcon,
    required this.enabled,
    required this.focused,
    required this.onTap,
  });

  final String label;
  final String? value;
  final String hintText;
  final IconData? prefixIcon;
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
        // `isEmpty: true` lets the label sit inside the field at rest
        // and float up to the border once a value lands. The hint then
        // takes over the inside slot only while the sheet is open
        // (focused), mirroring `interest_picker.dart`.
        isEmpty: !hasValue,
        isFocused: focused,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          labelStyle: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
            fontFamily: 'Poppins',
          ),
          floatingLabelStyle: TextStyle(
            color: isReadOnly ? AppColors.textPrimary : AppColors.secondary,
            fontSize: 13.sp,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: AppColors.textHint,
            fontSize: 14.sp,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: prefixIcon == null
              ? null
              : Icon(
                  prefixIcon,
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

class _CustomOptionPickerSheet extends StatelessWidget {
  const _CustomOptionPickerSheet({
    required this.title,
    required this.titleIcon,
    required this.options,
    required this.selected,
    required this.addNewLabel,
  });

  final String title;
  final IconData? titleIcon;
  final List<String> options;
  final String? selected;
  final String? addNewLabel;

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
                  if (titleIcon != null) ...<Widget>[
                    Icon(
                      titleIcon,
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                  ],
                  Text(
                    title,
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
              child: options.isEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: Text(
                        'No options available.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13.sp,
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const ClampingScrollPhysics(),
                      itemCount: options.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: AppColors.border.withValues(alpha: 0.5),
                      ),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = option == selected;
                        return ListTile(
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 4.w),
                          title: Text(
                            option,
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
                          onTap: () => Navigator.of(context).pop(option),
                        );
                      },
                    ),
            ),
            if (addNewLabel != null) ...<Widget>[
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
                  addNewLabel!,
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(context).pop(_addNewSentinel),
              ),
            ],
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
