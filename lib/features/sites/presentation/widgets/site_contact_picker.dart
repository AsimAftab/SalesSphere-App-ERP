import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/sites/domain/site_contact.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Tile-shaped picker for the site's secondary contacts list. Mirrors
/// the chrome of `InterestPicker` so it sits as a visual sibling on
/// the sites form: same `InputDecorator` shape, same icon slot, same
/// 12.r radius. Tap opens a bottom sheet that lists every saved
/// contact + a name / phone form to add another.
///
/// State is parent-owned via [value] / [onChanged]. The sheet works on
/// a local copy and re-commits on every mutation so the parent stays
/// in sync — closing the sheet without "saving" still keeps every
/// change the user made (matches the live-commit pattern of
/// `InterestPicker`).
class SiteContactPicker extends StatefulWidget {
  const SiteContactPicker({
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.maxContacts = 4,
    this.label = 'Site Contacts (Optional)',
    this.hintText = 'Add site contacts',
    super.key,
  });

  final List<SiteContact> value;
  final ValueChanged<List<SiteContact>> onChanged;
  final bool enabled;

  /// Picker-level cap on number of contacts. Past this count the
  /// "Add Contact" button disables; the cap isn't enforced on the
  /// domain model so legacy / backend-imported records carrying more
  /// than [maxContacts] still load.
  final int maxContacts;
  final String label;
  final String hintText;

  @override
  State<SiteContactPicker> createState() => _SiteContactPickerState();
}

class _SiteContactPickerState extends State<SiteContactPicker> {
  bool _focused = false;

  Future<void> _openSheet() async {
    setState(() => _focused = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SiteContactSheet(
        initial: widget.value,
        maxContacts: widget.maxContacts,
        onCommit: widget.onChanged,
      ),
    );
    if (!mounted) return;
    setState(() => _focused = false);
  }

  void _removeAt(int index) {
    final next = List<SiteContact>.from(widget.value)..removeAt(index);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final isReadOnly = !widget.enabled;
    final hasValue = widget.value.isNotEmpty;
    final count = widget.value.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: widget.enabled ? _openSheet : null,
          borderRadius: BorderRadius.circular(12.r),
          child: InputDecorator(
            // Matches `InterestPicker`: label sits inside the field at
            // rest, floats up only once contacts have been added (via
            // `isEmpty: !hasValue`). Counter badge renders alongside
            // the body text only when there's something to count.
            isEmpty: !hasValue,
            isFocused: _focused,
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hintText,
              floatingLabelBehavior: FloatingLabelBehavior.auto,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
              labelStyle: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14.sp,
                fontFamily: 'Poppins',
              ),
              floatingLabelStyle: TextStyle(
                color:
                    isReadOnly ? AppColors.textSecondary : AppColors.secondary,
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
              prefixIcon: Icon(
                Icons.contacts_outlined,
                color: isReadOnly
                    ? AppColors.textSecondary.withValues(alpha: 0.4)
                    : AppColors.textSecondary,
                size: 20.sp,
              ),
              suffixIcon: isReadOnly
                  ? null
                  : Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textSecondary,
                      size: 20.sp,
                    ),
              filled: true,
              fillColor: isReadOnly ? Colors.grey.shade100 : AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: const BorderSide(
                  color: AppColors.secondary,
                  width: 2,
                ),
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
                ? Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '$count contact${count == 1 ? '' : 's'} added',
                          style: TextStyle(
                            color: isReadOnly
                                ? AppColors.textSecondary
                                    .withValues(alpha: 0.6)
                                : AppColors.textPrimary,
                            fontSize: 15.sp,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(40.r),
                        ),
                        child: Text(
                          '$count/${widget.maxContacts}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12.sp,
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
        ),
        if (hasValue) ...<Widget>[
          SizedBox(height: 10.h),
          Opacity(
            opacity: isReadOnly ? 0.6 : 1,
            child: Column(
              children: <Widget>[
                for (int i = 0; i < widget.value.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == widget.value.length - 1 ? 0 : 8.h,
                    ),
                    child: _ContactCard(
                      contact: widget.value[i],
                      onRemove:
                          widget.enabled ? () => _removeAt(i) : null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Single saved-contact card rendered under the resting tile. Two-line
/// (name + phone) is more legible for phone numbers than a one-line
/// chip — the user actually needs to verify the digits.
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact, required this.onRemove});

  final SiteContact contact;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.25),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        12.w,
        10.h,
        onRemove != null ? 6.w : 12.w,
        10.h,
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32.r,
            height: 32.r,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_outline,
              color: AppColors.secondary,
              size: 16.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  contact.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  contact.phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(6.w),
                child: Icon(
                  Icons.close,
                  size: 16.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bottom sheet: saved-contact list above, name + phone entry form
/// below. The sheet keeps a private working copy and pushes every
/// mutation through `onCommit` so closing the sheet without an
/// explicit save still persists changes (matches `InterestPicker`).
class _SiteContactSheet extends StatefulWidget {
  const _SiteContactSheet({
    required this.initial,
    required this.maxContacts,
    required this.onCommit,
  });

  final List<SiteContact> initial;
  final int maxContacts;
  final ValueChanged<List<SiteContact>> onCommit;

  @override
  State<_SiteContactSheet> createState() => _SiteContactSheetState();
}

class _SiteContactSheetState extends State<_SiteContactSheet> {
  late List<SiteContact> _contacts;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _contacts = List<SiteContact>.from(widget.initial);
    _nameController.addListener(_onTextChanged);
    _phoneController.addListener(_onTextChanged);
  }

  /// Rebuild on every keystroke so the **Add Contact** button's
  /// `isDisabled` state reflects the live `_canAdd` evaluation, and so
  /// inline errors clear as the user fixes the input. Without the
  /// rebuild the button stayed greyed-out even after the phone field
  /// reached 10 digits.
  void _onTextChanged() {
    if (!mounted) return;
    setState(() {
      _nameError = null;
      _phoneError = null;
    });
  }

  @override
  void dispose() {
    _nameController
      ..removeListener(_onTextChanged)
      ..dispose();
    _phoneController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  bool get _isMaxed => _contacts.length >= widget.maxContacts;

  bool get _canAdd =>
      !_isMaxed &&
      _nameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().length == 10;

  void _addContact() {
    final nameErr =
        Validators.requiredField(_nameController.text, 'Name');
    final phoneErr = Validators.phone10(_phoneController.text);
    if (nameErr != null || phoneErr != null) {
      setState(() {
        _nameError = nameErr;
        _phoneError = phoneErr;
      });
      return;
    }
    final next = SiteContact(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    if (_contacts.contains(next)) {
      // Duplicate — silently no-op rather than throw; the chip would
      // be indistinguishable from the existing one anyway. Still
      // reset so the user can type a different contact.
      _resetForm();
      return;
    }
    setState(() {
      _contacts = <SiteContact>[..._contacts, next];
    });
    _resetForm();
    widget.onCommit(List<SiteContact>.unmodifiable(_contacts));
  }

  /// Clears both fields and drops keyboard focus so the form looks
  /// genuinely "reset" after each successful add — without the
  /// unfocus, focus stays on the phone field and the user has to tap
  /// **Name** to start the next contact.
  void _resetForm() {
    _nameController.clear();
    _phoneController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _removeAt(int index) {
    setState(() {
      _contacts = <SiteContact>[..._contacts]..removeAt(index);
    });
    widget.onCommit(List<SiteContact>.unmodifiable(_contacts));
  }

  @override
  Widget build(BuildContext context) {
    // Cap the sheet at 85% of viewport height so it never eats the
    // full screen. The form section stays at a fixed bottom; only the
    // saved-contacts list shrinks (with internal scroll) when the
    // keyboard is up.
    final mq = MediaQuery.of(context);
    final maxSheetHeight = mq.size.height * 0.85 - mq.viewInsets.bottom;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
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
                _header(),
                SizedBox(height: 12.h),
                // `Flexible` lets the saved-list shrink first when the
                // sheet is height-constrained (keyboard up, short
                // device). The list has its own `ListView.separated`
                // inside so it scrolls internally — the form below
                // stays fully visible and at a fixed bottom.
                Flexible(child: _savedList()),
                SizedBox(height: 16.h),
                _addForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
        children: <Widget>[
          Icon(
            Icons.contacts_outlined,
            color: AppColors.primary,
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Text(
            'Site Contacts',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            '${_contacts.length} / ${widget.maxContacts}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );

  Widget _savedList() {
    if (_contacts.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 18.h),
        child: Text(
          'No contacts yet — add one below.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13.sp,
          ),
        ),
      );
    }
    // `shrinkWrap: true` makes the list size to its content (1-2
    // cards don't stretch the sheet). The `maxHeight` cap keeps 4
    // cards from pushing the form off-screen at rest; the outer
    // `Flexible` in the sheet body shrinks this further when the
    // keyboard arrives — the list then scrolls inside the tighter
    // bound while the add-form below stays fully visible.
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: 220.h),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: _contacts.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.h),
        itemBuilder: (context, index) => _ContactCard(
          contact: _contacts[index],
          onRemove: () => _removeAt(index),
        ),
      ),
    );
  }

  Widget _addForm() {
    if (_isMaxed) {
      // Collapse the entire entry form to a single notice once 4 are
      // saved — keeps the sheet from running off-screen when every
      // contact card + the full form would otherwise stack together.
      return Container(
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
        decoration: BoxDecoration(
          color: AppColors.border.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline,
              color: AppColors.textSecondary,
              size: 18.sp,
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Text(
                'Maximum ${widget.maxContacts} contacts reached. Remove one to add another.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 12.h),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Add new contact',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 10.h),
          PrimaryTextField(
            controller: _nameController,
            label: 'Name',
            hintText: 'Enter contact name',
            prefixIcon: Icons.person_outline,
            textInputAction: TextInputAction.next,
            errorText: _nameError,
          ),
          SizedBox(height: 10.h),
          PrimaryTextField(
            controller: _phoneController,
            label: 'Phone Number',
            hintText: 'Enter 10-digit phone',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            maxLength: 10,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            errorText: _phoneError,
            onFieldSubmitted: (_) => _canAdd ? _addContact() : null,
          ),
          SizedBox(height: 12.h),
          PrimaryButton(
            label: 'Add Contact',
            leadingIcon: Icons.add,
            isDisabled: !_canAdd,
            onPressed: _addContact,
          ),
        ],
      ),
    );
  }
}
