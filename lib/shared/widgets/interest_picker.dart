import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// A category + brand pair surfaced by [InterestPicker]. `==` and
/// `hashCode` are overridden so equal interests dedupe in `Set` / `List`
/// operations the picker performs internally.
@immutable
class Interest {
  const Interest({required this.category, required this.brand});

  final String category;
  final String brand;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Interest && other.category == category && other.brand == brand);

  @override
  int get hashCode => Object.hash(category, brand);

  @override
  String toString() => '$category · $brand';
}

/// Multi-select picker that walks the user through categories first and
/// brands second. Designed to be reused across features — the parent
/// owns the catalogue + persistence and decides what happens when the
/// user adds a new category or brand inline.
///
/// Selections are committed live: every toggle calls [onChanged] so the
/// caller can render chips outside the open sheet immediately.
class InterestPicker extends StatefulWidget {
  const InterestPicker({
    required this.value,
    required this.onChanged,
    required this.catalogue,
    required this.onAddCategory,
    required this.onAddBrand,
    required this.enabled,
    this.label = 'Interests',
    this.hintText = 'Select interests',
    super.key,
  });

  final List<Interest> value;
  final ValueChanged<List<Interest>> onChanged;

  /// Source of truth for which categories exist and which brands sit
  /// underneath each. Empty map = nothing pre-defined; the user can
  /// still add new categories from the sheet.
  final Map<String, List<String>> catalogue;
  final ValueChanged<String> onAddCategory;
  final void Function(String category, String brand) onAddBrand;
  final bool enabled;

  /// Field label shown on the resting tile (e.g. 'Prospect Interest').
  final String label;

  /// Placeholder rendered inside the field while it's empty and focused.
  final String hintText;

  @override
  State<InterestPicker> createState() => _InterestPickerState();
}

class _InterestPickerState extends State<InterestPicker> {
  bool _focused = false;

  Future<void> _openSheet() async {
    setState(() => _focused = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InterestSheet(
        initialSelections: widget.value,
        catalogue: widget.catalogue,
        onCommit: widget.onChanged,
        onAddCategory: widget.onAddCategory,
        onAddBrand: widget.onAddBrand,
      ),
    );
    if (!mounted) return;
    setState(() => _focused = false);
  }

  void _removeAt(int index) {
    final next = List<Interest>.from(widget.value)..removeAt(index);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value.isNotEmpty;
    final isReadOnly = !widget.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        InkWell(
          onTap: widget.enabled ? _openSheet : null,
          borderRadius: BorderRadius.circular(12.r),
          child: InputDecorator(
            // `isEmpty: true` lets the label sit inside the field at rest
            // and float up to the border once a value lands.
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
              prefixIcon: Icon(
                Icons.interests_outlined,
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
                ? Text(
                    '${widget.value.length} selected',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                  )
                : null,
          ),
        ),
        if (hasValue) ...<Widget>[
          SizedBox(height: 10.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: <Widget>[
              for (int i = 0; i < widget.value.length; i++)
                _InterestChip(
                  interest: widget.value[i],
                  onRemove: widget.enabled ? () => _removeAt(i) : null,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.interest, required this.onRemove});

  final Interest interest;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12.w,
        6.h,
        onRemove != null ? 4.w : 12.w,
        6.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            '${interest.category} · ${interest.brand}',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.sp,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
          ),
          if (onRemove != null) ...<Widget>[
            SizedBox(width: 4.w),
            InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Icon(
                  Icons.close,
                  size: 14.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The two-step bottom sheet — categories first, brands second. Holds
/// its own working copy of the catalogue so adding a new category or
/// brand stays reactive without round-tripping through the parent.
class _InterestSheet extends StatefulWidget {
  const _InterestSheet({
    required this.initialSelections,
    required this.catalogue,
    required this.onCommit,
    required this.onAddCategory,
    required this.onAddBrand,
  });

  final List<Interest> initialSelections;
  final Map<String, List<String>> catalogue;
  final ValueChanged<List<Interest>> onCommit;
  final ValueChanged<String> onAddCategory;
  final void Function(String category, String brand) onAddBrand;

  @override
  State<_InterestSheet> createState() => _InterestSheetState();
}

class _InterestSheetState extends State<_InterestSheet> {
  late Map<String, List<String>> _catalogue;
  late List<Interest> _selections;
  String? _activeCategory;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _catalogue = <String, List<String>>{
      for (final entry in widget.catalogue.entries)
        entry.key: List<String>.from(entry.value),
    };
    _selections = List<Interest>.from(widget.initialSelections);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _query = _searchController.text);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  bool _isSelected(String category, String brand) =>
      _selections.contains(Interest(category: category, brand: brand));

  void _toggleBrand(String category, String brand) {
    final i = Interest(category: category, brand: brand);
    setState(() {
      if (_selections.contains(i)) {
        _selections.remove(i);
      } else {
        _selections.add(i);
      }
    });
    widget.onCommit(List<Interest>.unmodifiable(_selections));
  }

  Future<void> _promptAddCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddPromptDialog(
        title: 'Add new category',
        fieldLabel: 'Category name',
        fieldHint: 'e.g. Hardware',
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;
    if (_catalogue.containsKey(name)) {
      // Already exists — just drill into it.
      setState(() => _activeCategory = name);
      return;
    }
    setState(() {
      _catalogue[name] = <String>[];
      _activeCategory = name;
    });
    widget.onAddCategory(name);
  }

  Future<void> _promptAddBrand() async {
    final cat = _activeCategory;
    if (cat == null) return;
    final brand = await showDialog<String>(
      context: context,
      builder: (_) => const _AddPromptDialog(
        title: 'Add new brand',
        fieldLabel: 'Brand name',
        fieldHint: 'e.g. Dell',
      ),
    );
    if (brand == null || brand.isEmpty || !mounted) return;
    final list = _catalogue[cat] ?? <String>[];
    if (list.contains(brand)) return;
    setState(() => _catalogue[cat] = <String>[...list, brand]);
    widget.onAddBrand(cat, brand);
  }

  void _clearAll() {
    setState(_selections.clear);
    widget.onCommit(const <Interest>[]);
  }

  void _applyAndClose() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final showingBrands = _activeCategory != null;
    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
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
              if (showingBrands) _brandsHeader() else _categoriesHeader(),
              SizedBox(height: 8.h),
              if (showingBrands) _brandsBody() else _categoriesBody(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoriesHeader() => Padding(
    padding: EdgeInsets.only(left: 4.w, bottom: 4.h),
    child: Row(
      children: <Widget>[
        Icon(Icons.interests_outlined, color: AppColors.primary, size: 20.sp),
        SizedBox(width: 8.w),
        Text(
          'Select Category',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        if (_selections.isNotEmpty) ...<Widget>[
          Text(
            '${_selections.length} selected',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
          ),
          SizedBox(width: 10.w),
          InkWell(
            onTap: _clearAll,
            borderRadius: BorderRadius.circular(8.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 14.sp,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Clear',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _brandsHeader() => Padding(
    padding: EdgeInsets.only(bottom: 4.h),
    child: Row(
      children: <Widget>[
        IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary, size: 20.sp),
          onPressed: () => setState(() {
            _activeCategory = null;
          }),
          tooltip: 'Back',
        ),
        SizedBox(width: 4.w),
        Expanded(
          child: Text(
            _activeCategory!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _categoriesBody() {
    final keys = _catalogue.keys.toList(growable: false);
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? keys
        : keys
              .where((k) => k.toLowerCase().contains(q))
              .toList(growable: false);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(bottom: 12.h),
          child: PrimaryTextField(
            controller: _searchController,
            hintText: 'Search categories',
            prefixIcon: Icons.search,
            textInputAction: TextInputAction.search,
            suffixWidget: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18.sp,
                      color: AppColors.textSecondary,
                    ),
                    tooltip: 'Clear search',
                    onPressed: _searchController.clear,
                  ),
          ),
        ),
        if (keys.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: Text(
              'No categories yet — add one below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
          )
        else if (filtered.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: Text(
              'No matches for "$_query".',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 320.h),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
              itemBuilder: (context, index) {
                final cat = filtered[index];
                final pickedFromCat = _selections
                    .where((i) => i.category == cat)
                    .length;
                return ListTile(
                  contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
                  title: Text(
                    cat,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: pickedFromCat > 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  subtitle: pickedFromCat > 0
                      ? Text(
                          '$pickedFromCat selected',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 12.sp,
                          ),
                        )
                      : null,
                  trailing: Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                    size: 22.sp,
                  ),
                  onTap: () => setState(() => _activeCategory = cat),
                );
              },
            ),
          ),
        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
          leading: Icon(
            Icons.add_circle_outline,
            color: AppColors.secondary,
            size: 22.sp,
          ),
          title: Text(
            'Add New Category',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: _promptAddCategory,
        ),
      ],
    );
  }

  Widget _brandsBody() {
    final cat = _activeCategory!;
    final brands = _catalogue[cat] ?? const <String>[];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (brands.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: Text(
              'No brands yet — add one below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 320.h),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: brands.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: AppColors.border.withValues(alpha: 0.5),
              ),
              itemBuilder: (context, index) {
                final brand = brands[index];
                final isSelected = _isSelected(cat, brand);
                return _BrandRow(
                  brand: brand,
                  isSelected: isSelected,
                  onTap: () => _toggleBrand(cat, brand),
                );
              },
            ),
          ),
        Divider(height: 1, color: AppColors.border.withValues(alpha: 0.5)),
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 4.w),
          leading: Icon(
            Icons.add_circle_outline,
            color: AppColors.secondary,
            size: 22.sp,
          ),
          title: Text(
            'Add New Brand',
            style: TextStyle(
              color: AppColors.secondary,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          onTap: _promptAddBrand,
        ),
        SizedBox(height: 16.h),
        PrimaryButton(
          label: 'Apply Selection',
          leadingIcon: Icons.check_circle_outline,
          onPressed: _applyAndClose,
        ),
      ],
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({
    required this.brand,
    required this.isSelected,
    required this.onTap,
  });

  final String brand;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 14.h),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                brand,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15.sp,
                  fontFamily: 'Poppins',
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22.r,
              height: 22.r,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.secondary : Colors.transparent,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: isSelected ? AppColors.secondary : AppColors.border,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? Icon(Icons.check, color: AppColors.textWhite, size: 14.sp)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal prompt for entering a new category or brand. Floats above the
/// interest sheet so it sizes itself naturally and the keyboard can push
/// it up without fighting the sheet's list area for vertical space.
/// Returns the trimmed entered value via `Navigator.pop`, or `null` when
/// the user cancels / dismisses.
class _AddPromptDialog extends StatefulWidget {
  const _AddPromptDialog({
    required this.title,
    required this.fieldLabel,
    required this.fieldHint,
  });

  final String title;
  final String fieldLabel;
  final String fieldHint;

  @override
  State<_AddPromptDialog> createState() => _AddPromptDialogState();
}

class _AddPromptDialogState extends State<_AddPromptDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = _controller.text.trim().isNotEmpty;
    if (has != _hasText && mounted) {
      setState(() => _hasText = has);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _submit() {
    final v = _controller.text.trim();
    if (v.isEmpty) return;
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.add_circle_outline,
                  color: AppColors.secondary,
                  size: 22.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            PrimaryTextField(
              controller: _controller,
              label: widget.fieldLabel,
              hintText: widget.fieldHint,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
            ),
            SizedBox(height: 18.h),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedCustomButton(
                    label: 'Cancel',
                    size: ButtonSize.small,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: PrimaryButton(
                    label: 'Add',
                    size: ButtonSize.small,
                    leadingIcon: Icons.check,
                    isDisabled: !_hasText,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
