import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';

/// One entry in a [PrimarySearchFilter]'s dropdown. The generic [T] is the
/// filter "value" — typically an enum or a nullable enum (when one of
/// the options means "no filter"). The widget keeps no state of its
/// own; it just renders the icon + label and forwards the value back
/// via the bar's `onChanged`.
@immutable
class SearchFilterOption<T> {
  const SearchFilterOption({
    required this.value,
    required this.label,
    required this.icon,
    this.iconColor,
  });

  final T value;
  final String label;
  final IconData icon;

  /// Tint for [icon]. Defaults to [AppColors.primary] when null. Use
  /// per-option colours to mirror module identity (parties=blue,
  /// prospects=orange, sites=green, etc.) so the dropdown reads at a
  /// glance.
  final Color? iconColor;
}

/// Search-bar-shaped filter dropdown that opens an anchored menu of
/// [SearchFilterOption]s on tap. The bar's body shows the currently
/// selected option's label + chevron, so the user always sees what's
/// active without opening the menu.
///
/// Generic over the filter value type, so the same widget handles any
/// single-select filter — a link-type enum on the notes list, a
/// status enum on a tickets list, a category model on a catalogue
/// page, etc. Each consumer supplies its own [options] list.
///
/// Example:
/// ```dart
/// PrimarySearchFilter<NoteLinkType?>(
///   selected: _linkFilter,
///   onChanged: (next) => setState(() => _linkFilter = next),
///   options: const <SearchFilterOption<NoteLinkType?>>[
///     SearchFilterOption(
///       value: null,
///       label: 'All Notes',
///       icon: Icons.list_alt_rounded,
///     ),
///     SearchFilterOption(
///       value: NoteLinkType.party,
///       label: 'Parties',
///       icon: Icons.storefront_outlined,
///       iconColor: AppColors.secondary,
///     ),
///     ...
///   ],
/// )
/// ```
///
/// Chrome matches `PrimaryTextField` (12.r corner radius, 1.5px
/// border, 16.w / 14.h padding, surface fill) so a filter bar placed
/// directly under a search field reads as a sibling control rather
/// than a different component.
class PrimarySearchFilter<T> extends StatefulWidget {
  const PrimarySearchFilter({
    required this.options,
    required this.selected,
    required this.onChanged,
    this.leadingIcon = Icons.filter_list_rounded,
    super.key,
  });

  /// All selectable options. Must be non-empty. Order is preserved in
  /// the dropdown — put the "all"/default option first.
  final List<SearchFilterOption<T>> options;

  /// The currently active value. Compared against each option's
  /// `value` with `==` to highlight the active row in the dropdown
  /// and to render the bar's body label.
  final T selected;

  /// Fired when the user picks a different option. Not fired when the
  /// dropdown is dismissed without picking, or when the user re-picks
  /// the already-selected option.
  final ValueChanged<T> onChanged;

  /// Icon shown on the left of the bar. Defaults to a filter-funnel
  /// glyph; override for visual variety when stacking multiple filter
  /// bars on the same page.
  final IconData leadingIcon;

  @override
  State<PrimarySearchFilter<T>> createState() => _PrimarySearchFilterState<T>();
}

class _PrimarySearchFilterState<T> extends State<PrimarySearchFilter<T>> {
  /// Anchors the dropdown to the bar's screen rect — without a key
  /// we can't read the rendered geometry to position the menu.
  final GlobalKey _barKey = GlobalKey();

  Future<void> _open() async {
    final barContext = _barKey.currentContext;
    if (barContext == null) return;
    final box = barContext.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final bottomRight = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final position = RelativeRect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      overlay.size.width - bottomRight.dx,
      overlay.size.height - bottomRight.dy,
    );

    // Use the option object as the menu's return type rather than
    // `T` — that way a `null` return unambiguously means "dismissed",
    // even when `T` itself is nullable (e.g. an `All` option whose
    // value is `null`). Otherwise we'd conflate the two.
    final picked = await showMenu<SearchFilterOption<T>>(
      context: context,
      position: position,
      color: AppColors.surface,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
      items: widget.options
          .map(
            (o) => PopupMenuItem<SearchFilterOption<T>>(
              value: o,
              padding: EdgeInsets.zero,
              child: _OptionRow<T>(
                option: o,
                isSelected: o.value == widget.selected,
              ),
            ),
          )
          .toList(growable: false),
    );

    if (!mounted || picked == null) return;
    if (picked.value != widget.selected) {
      widget.onChanged(picked.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Resolve the active option for the bar's body. Fall back to the
    // first option if `selected` doesn't match any — that way the bar
    // never renders blank, even if the caller's state and options
    // briefly drift out of sync (e.g. during a flag flip).
    final selectedOption = widget.options.firstWhere(
      (o) => o.value == widget.selected,
      orElse: () => widget.options.first,
    );
    final accent = selectedOption.iconColor ?? AppColors.primary;
    return Material(
      key: _barKey,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        onTap: _open,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
          child: Row(
            children: <Widget>[
              Icon(widget.leadingIcon, color: AppColors.primary, size: 20.sp),
              SizedBox(width: 10.w),
              // Sticky "Filter" prefix — always visible regardless of
              // selection so the user reads the bar's purpose at a
              // glance instead of having to infer it from the icon.
              Text(
                'Filter',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15.sp,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 8.w),
              // Vertical hairline separates the sticky label from the
              // dynamic value. More compact than a colon and reads as
              // a deliberate divider rather than punctuation.
              Container(height: 14.h, width: 1, color: AppColors.border),
              SizedBox(width: 10.w),
              // Active option's icon shown alongside its label so the
              // bar carries the same visual identity as the dropdown
              // row that produced it — the user sees "this is what's
              // selected" without opening the menu.
              Icon(selectedOption.icon, color: accent, size: 18.sp),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  selectedOption.label,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.sp,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
                size: 20.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionRow<T> extends StatelessWidget {
  const _OptionRow({required this.option, required this.isSelected});

  final SearchFilterOption<T> option;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final accent = option.iconColor ?? AppColors.primary;
    return Container(
      width: double.infinity,
      // Soft wash on the selected row tints with the option's own
      // accent — pairs with the trailing check below for a layered
      // selected-state read (background hint + explicit indicator).
      color: isSelected ? accent.withValues(alpha: 0.10) : null,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: <Widget>[
          Icon(option.icon, color: accent, size: 20.sp),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              option.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.sp,
                fontFamily: 'Poppins',
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // Always reserve the check's footprint — only its opacity
          // changes — so every row contributes the same intrinsic
          // width to the menu. Without this the menu re-measures
          // wider whenever a longer option becomes selected (since
          // the check is then drawn on a longer row).
          Opacity(
            opacity: isSelected ? 1 : 0,
            child: Icon(Icons.check_rounded, color: accent, size: 18.sp),
          ),
        ],
      ),
    );
  }
}
