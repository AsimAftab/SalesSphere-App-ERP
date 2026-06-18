import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_category.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_party.dart';
import 'package:sales_sphere_erp/features/expenses/presentation/controllers/expenses_controller.dart';
import 'package:sales_sphere_erp/features/expenses/presentation/providers/expenses_providers.dart';
import 'package:sales_sphere_erp/features/expenses/presentation/widgets/expense_category_field.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/party_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Per-status accent. Mirrors the list page so the inline status banner
/// reads as the same component family.
Color _statusColor(ExpenseClaimStatus s) => switch (s) {
  ExpenseClaimStatus.pending => AppColors.warning,
  ExpenseClaimStatus.approved => AppColors.green500,
  ExpenseClaimStatus.rejected => AppColors.error,
};

class EditExpenseClaimDetailPage extends ConsumerStatefulWidget {
  const EditExpenseClaimDetailPage({required this.id, this.initial, super.key});

  final String id;

  /// Optional starting record passed via `extra` when navigating from
  /// the list — saves a re-read on first paint.
  final ExpenseClaim? initial;

  @override
  ConsumerState<EditExpenseClaimDetailPage> createState() =>
      _EditExpenseClaimDetailPageState();
}

class _EditExpenseClaimDetailPageState
    extends ConsumerState<EditExpenseClaimDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _createdAtController = TextEditingController();

  static const _maxImages = 2;

  ExpenseCategory? _category;
  ExpenseParty? _party;
  DateTime? _date;
  ExpenseClaimStatus _status = ExpenseClaimStatus.pending;
  DateTime? _createdAt;
  String? _rejectionReason;
  final List<String> _imagePaths = <String>[];

  bool _editing = false;
  bool _saving = false;
  bool _notFound = false;

  /// Only pending claims are user-mutable. Once the approver has
  /// decided (approved / rejected) the claim locks to read-only and the
  /// edit affordance is hidden entirely.
  bool get _isMutable => _status == ExpenseClaimStatus.pending;

  @override
  void initState() {
    super.initState();
    final claim = widget.initial ?? ref.read(expenseClaimByIdProvider(widget.id));
    if (claim != null) {
      _populate(claim);
    } else {
      _notFound = true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    _createdAtController.dispose();
    super.dispose();
  }

  void _populate(ExpenseClaim c) {
    _titleController.text = c.title;
    _amountController.text = _trimAmount(c.amount);
    _date = c.date;
    _dateController.text = DateFormat('dd MMM yyyy').format(c.date);
    _category = c.category;
    _party = c.party;
    _status = c.status;
    _createdAt = c.createdAt;
    _rejectionReason = c.rejectionReason;
    _createdAtController.text =
        DateFormat('dd MMM yyyy, hh:mm a').format(c.createdAt);
    _imagePaths
      ..clear()
      ..addAll(c.imagePaths);
  }

  /// Renders the stored amount without a trailing `.0` for whole
  /// numbers so the edit field shows `850`, not `850.0`.
  String _trimAmount(double amount) =>
      amount == amount.roundToDouble()
          ? amount.toInt().toString()
          : amount.toString();

  void _toggleEdit() {
    if (!_isMutable) return;
    setState(() => _editing = !_editing);
  }

  void _cancelEdit() {
    final saved =
        ref.read(expenseClaimByIdProvider(widget.id)) ?? widget.initial;
    if (saved != null) _populate(saved);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _editing = false);
  }

  Future<void> _pickImage() async {
    if (!_editing || _imagePaths.length >= _maxImages) return;
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (file == null) return;
      setState(() => _imagePaths.add(file.path));
    } on Exception catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Could not load image.');
    }
  }

  void _removeImageAt(int index) {
    if (!_editing) return;
    setState(() => _imagePaths.removeAt(index));
  }

  String? _validateAmount(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Amount is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than 0';
    return null;
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    final category = _category;
    final date = _date;
    if (category == null) {
      SnackbarUtils.showError(context, 'Please choose an expense category.');
      return;
    }
    if (!formValid || date == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final updated = ExpenseClaim(
        id: widget.id,
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        date: date,
        category: category,
        status: _status,
        party: _party,
        description: _descriptionController.text.trim(),
        imagePaths: List<String>.unmodifiable(_imagePaths),
        rejectionReason: _rejectionReason,
        createdAt: _createdAt ?? DateTime.now(),
      );
      await ref.read(expensesControllerProvider.notifier).updateClaim(updated);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
      SnackbarUtils.showSuccess(context, 'Expense claim updated.');
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    }
  }

  void _back() {
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_notFound) return const _NotFoundScaffold();
    // Keep the provider warm so cancelEdit reads the saved snapshot.
    ref.watch(expenseClaimByIdProvider(widget.id));

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: _isMutable
            ? _SubmitBar(
                editing: _editing,
                isLoading: _saving,
                onPressed: _editing ? _save : _toggleEdit,
              )
            : null,
        body: Stack(
          children: <Widget>[
            const _CurvedHeader(),
            SafeArea(
              child: Column(
                children: <Widget>[
                  _DetailAppBar(
                    onBack: _back,
                    editing: _editing,
                    onCancel: _cancelEdit,
                  ),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _StatusBanner(
                              status: _status,
                              rejectionReason: _rejectionReason,
                            ),
                            SizedBox(height: 12.h),
                            SectionCard(
                              children: <Widget>[
                                PrimaryTextField(
                                  controller: _titleController,
                                  label: 'Title',
                                  hintText: 'Enter expense title',
                                  prefixIcon: Icons.title_rounded,
                                  minLines: 1,
                                  maxLines: 2,
                                  enabled: _editing,
                                  validator: (v) =>
                                      Validators.requiredField(v, 'Title'),
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _amountController,
                                  label: 'Amount',
                                  hintText: 'Enter amount (Rs)',
                                  prefixIcon: Icons.payments_outlined,
                                  enabled: _editing,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d*\.?\d*'),
                                    ),
                                  ],
                                  validator: _validateAmount,
                                ),
                                SizedBox(height: 12.h),
                                CustomDatePicker(
                                  controller: _dateController,
                                  label: 'Date',
                                  hintText: 'When was it spent',
                                  prefixIcon: Icons.event_outlined,
                                  enabled: _editing,
                                  initialDate: _date,
                                  lastDate: DateTime.now(),
                                  validator: (v) =>
                                      Validators.requiredField(v, 'Date'),
                                  onDateSelected: (picked) =>
                                      setState(() => _date = picked),
                                ),
                                SizedBox(height: 12.h),
                                ExpenseCategoryField(
                                  value: _category,
                                  enabled: _editing,
                                  onChanged: (next) =>
                                      setState(() => _category = next),
                                ),
                                SizedBox(height: 12.h),
                                PartyPickerField<ExpenseParty>(
                                  value: _party,
                                  enabled: _editing,
                                  onChanged: (next) =>
                                      setState(() => _party = next),
                                  items: ref.watch(expensePartiesProvider),
                                  titleOf: (p) => p.name,
                                  subtitleOf: (p) => p.address,
                                  searchTextOf: (p) => '${p.name} ${p.address}',
                                  label: 'Party (Optional)',
                                  hintText: 'Tap to link a party',
                                  sheetTitle: 'Select party',
                                  searchHint: 'Search parties',
                                  emptyText: 'No parties yet.',
                                  noMatchText: 'No parties match your search.',
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _descriptionController,
                                  label: 'Description (Optional)',
                                  hintText: 'Add any details',
                                  prefixIcon: Icons.notes_outlined,
                                  minLines: 1,
                                  maxLines: 6,
                                  enabled: _editing,
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _createdAtController,
                                  label: 'Created On',
                                  prefixIcon: Icons.access_time_rounded,
                                  enabled: false,
                                  readOnly: true,
                                ),
                                SizedBox(height: 18.h),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      'Receipts (Optional)',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${_imagePaths.length}/$_maxImages',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 10.h),
                                PrimaryImagePicker(
                                  imagePaths: _imagePaths,
                                  maxImages: _maxImages,
                                  enabled: _editing,
                                  showLabel: false,
                                  onPick: _pickImage,
                                  onRemove: _removeImageAt,
                                ),
                              ],
                            ),
                            SizedBox(height: 8.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, this.rejectionReason});

  final ExpenseClaimStatus status;
  final String? rejectionReason;

  @override
  Widget build(BuildContext context) {
    final accent = _statusColor(status);
    final icon = switch (status) {
      ExpenseClaimStatus.pending => Icons.hourglass_empty_rounded,
      ExpenseClaimStatus.approved => Icons.check_circle_outline_rounded,
      ExpenseClaimStatus.rejected => Icons.cancel_outlined,
    };
    final note = switch (status) {
      ExpenseClaimStatus.pending =>
        'Awaiting approver review. You can still edit.',
      ExpenseClaimStatus.approved =>
        'Approved by your approver. No changes allowed.',
      ExpenseClaimStatus.rejected =>
        'Rejected by your approver. No changes allowed.',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: accent, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  expenseClaimStatusLabel(status),
                  style: TextStyle(
                    color: accent,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  note,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (status == ExpenseClaimStatus.rejected &&
                    (rejectionReason?.isNotEmpty ?? false)) ...<Widget>[
                  SizedBox(height: 8.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Reason: $rejectionReason',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurvedHeader extends StatelessWidget {
  const _CurvedHeader();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SvgPicture.asset(
        'assets/images/corner_bubble.svg',
        fit: BoxFit.cover,
        height: 180.h,
      ),
    );
  }
}

class _DetailAppBar extends StatelessWidget {
  const _DetailAppBar({
    required this.onBack,
    required this.editing,
    required this.onCancel,
  });

  final VoidCallback onBack;
  final bool editing;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 4.h),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textdark,
              size: 20.sp,
            ),
            tooltip: 'Back',
            onPressed: onBack,
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Text(
              'Expense Claim Details',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (editing)
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.editing,
    required this.isLoading,
    required this.onPressed,
  });

  final bool editing;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
          child: PrimaryButton(
            label: editing ? 'Save Changes' : 'Edit Detail',
            leadingIcon: editing ? Icons.check : Icons.edit,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}

class _NotFoundScaffold extends StatelessWidget {
  const _NotFoundScaffold();

  @override
  Widget build(BuildContext context) {
    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.primary,
          title: const Text('Expense Claim Details'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              "Couldn't load this expense claim — it may have been removed.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            ),
          ),
        ),
      ),
    );
  }
}
