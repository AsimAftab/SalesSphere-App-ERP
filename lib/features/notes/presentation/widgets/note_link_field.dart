import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/notes/domain/note.dart';
import 'package:sales_sphere_erp/features/notes/presentation/widgets/note_link_picker.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Field-shaped tappable that opens [showNoteLinkPicker] on tap and
/// forwards the user's pick (or clear) back via [onChanged]. Built on
/// top of `PrimaryTextField` (read-only + onTap) so the height +
/// decoration match every other field on the form pixel-for-pixel —
/// the user can't type into it but it inherits the rest of the
/// field's behaviour for free.
///
/// The suffix renders a small uppercase type label (PARTY / PROSPECT /
/// SITE) when something is linked — saves a separate "Type" field
/// while still surfacing the link kind at a glance.
class NoteLinkField extends StatefulWidget {
  const NoteLinkField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final NoteLinkSelection? value;

  /// Fired with the picked selection, or `null` when the user clears
  /// from inside the bottom sheet.
  final ValueChanged<NoteLinkSelection?> onChanged;
  final bool enabled;

  @override
  State<NoteLinkField> createState() => _NoteLinkFieldState();
}

class _NoteLinkFieldState extends State<NoteLinkField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncControllerToValue();
  }

  @override
  void didUpdateWidget(NoteLinkField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final next = widget.value?.displayName ?? '';
    if (_controller.text == next) return;
    // didUpdateWidget runs *during* the parent's rebuild. Setting
    // `controller.text` synchronously fires TextFormField's listener
    // which calls Form.setState — that trips Flutter's build-phase
    // assertion. Defer to the next frame so the controller mutates
    // outside the build window. (initState stays synchronous because
    // no Form is mounting at that point.)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.text == next) return;
      _controller.text = next;
    });
  }

  void _syncControllerToValue() {
    _controller.text = widget.value?.displayName ?? '';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final result = await showNoteLinkPicker(context, current: widget.value);
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
      label: 'Linked to',
      hintText: 'Tap to pick a party, prospect, or site',
      prefixIcon: Icons.link_rounded,
      enabled: widget.enabled,
      readOnly: true,
      onTap: _open,
      // The controller is kept in sync with `widget.value?.displayName`,
      // so an empty controller text == no selection. Routes through
      // the shared validator to keep all form-validation logic in one
      // place — `requiredFieldCustom` lets us surface the verbose
      // user-friendly message instead of the default `"$label is
      // required"` shape.
      validator: (v) => Validators.requiredFieldCustom(
        v,
        'Please link this note to a party, prospect, or site',
      ),
      suffixWidget: _buildSuffix(),
    );
  }

  /// Renders the type label (when something is linked) and the
  /// chevron (when the field is editable). When neither applies
  /// returns null so PrimaryTextField doesn't reserve suffix space.
  Widget? _buildSuffix() {
    final selection = widget.value;
    final showChevron = widget.enabled;
    final typeLabel = selection == null ? null : _typeLabel(selection.type);
    if (typeLabel == null && !showChevron) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (typeLabel != null)
          Padding(
            padding: EdgeInsets.only(right: 4.w),
            child: Text(
              typeLabel,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
        if (showChevron)
          Padding(
            padding: EdgeInsets.only(right: 8.w),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: AppColors.textSecondary,
              size: 20.sp,
            ),
          ),
      ],
    );
  }
}

String _typeLabel(NoteLinkType type) => switch (type) {
  NoteLinkType.party => 'PARTY',
  NoteLinkType.prospect => 'PROSPECT',
  NoteLinkType.site => 'SITE',
};
