import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/visit_notes/domain/visit_note.dart';
import 'package:sales_sphere_erp/features/visit_notes/presentation/widgets/visit_link_picker.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Field-shaped tappable that opens [showVisitLinkPicker] on tap and
/// forwards the user's pick (or clear) back via [onChanged]. Built on
/// top of `PrimaryTextField` (read-only + onTap) so the height +
/// decoration match every other field on the form pixel-for-pixel —
/// the user can't type into it but it inherits the rest of the
/// field's behaviour for free.
///
/// The suffix renders a small uppercase type label (PARTY / PROSPECT /
/// SITE) when something is linked — saves a separate "Type" field
/// while still surfacing the link kind at a glance.
class VisitLinkField extends StatefulWidget {
  const VisitLinkField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final VisitLinkSelection? value;

  /// Fired with the picked selection, or `null` when the user clears
  /// from inside the bottom sheet.
  final ValueChanged<VisitLinkSelection?> onChanged;
  final bool enabled;

  @override
  State<VisitLinkField> createState() => _VisitLinkFieldState();
}

class _VisitLinkFieldState extends State<VisitLinkField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncControllerToValue();
  }

  @override
  void didUpdateWidget(VisitLinkField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _syncControllerToValue();
    }
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
    final result = await showVisitLinkPicker(context, current: widget.value);
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
    final typeLabel =
        selection == null ? null : _typeLabel(selection.type);
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
                fontSize: 11.sp,
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

String _typeLabel(VisitNoteLinkType type) => switch (type) {
      VisitNoteLinkType.party => 'PARTY',
      VisitNoteLinkType.prospect => 'PROSPECT',
      VisitNoteLinkType.site => 'SITE',
    };
