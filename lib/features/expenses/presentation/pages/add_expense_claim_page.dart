import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_claim.dart';
import 'package:sales_sphere_erp/features/expenses/domain/expense_party.dart';
import 'package:sales_sphere_erp/features/expenses/domain/repositories/expense_repository.dart';
import 'package:sales_sphere_erp/features/expenses/presentation/controllers/expenses_controller.dart';
import 'package:sales_sphere_erp/features/expenses/presentation/providers/expenses_providers.dart';
import 'package:sales_sphere_erp/features/expenses/presentation/widgets/expense_category_field.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/add_form_header.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/party_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class AddExpenseClaimPage extends ConsumerStatefulWidget {
  const AddExpenseClaimPage({super.key});

  @override
  ConsumerState<AddExpenseClaimPage> createState() =>
      _AddExpenseClaimPageState();
}

class _AddExpenseClaimPageState extends ConsumerState<AddExpenseClaimPage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();

  static const _maxImages = 2;

  String? _category;
  ExpenseParty? _party;
  DateTime? _date;
  final List<String> _imagePaths = <String>[];
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_imagePaths.length >= _maxImages) return;
    try {
      final file = await showImagePickerSheet(
        context,
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
    setState(() => _imagePaths.removeAt(index));
  }

  /// Amount validator: required + must parse to a number greater than 0.
  String? _validateAmount(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Amount is required';
    final parsed = double.tryParse(v);
    if (parsed == null) return 'Enter a valid amount';
    if (parsed <= 0) return 'Amount must be greater than 0';
    return null;
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    final category = _category;
    final date = _date;
    // The category picker (CustomOptionPicker) has no Form validator, so
    // its required-ness is enforced here. Surface a snackbar rather than
    // silently no-op so the user knows why submit didn't proceed.
    if (category == null) {
      SnackbarUtils.showError(context, 'Please choose an expense category.');
      return;
    }
    if (!formValid || date == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final draft = ExpenseClaim(
        id: '',
        // id / createdAt / status are server-assigned — placeholders.
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        date: date,
        category: category,
        status: ExpenseClaimStatus.pending,
        party: _party,
        description: _descriptionController.text.trim(),
        imagePaths: List<String>.unmodifiable(_imagePaths),
        createdAt: DateTime.now(),
      );
      await ref.read(expensesControllerProvider.notifier).addClaim(draft);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Expense claim added.');
      context.pop();
    } on PartialImageUploadException catch (e) {
      // Claim was saved; one or more receipts didn't upload. Still pop
      // back — the user has a row to look at and can re-attach the
      // missing slots from the edit page.
      if (!mounted) return;
      final n = e.failedSlots.length;
      SnackbarUtils.showError(
        context,
        "Expense claim added, but $n receipt${n == 1 ? '' : 's'} didn't "
        'upload: ${e.firstMessage}',
      );
      context.pop();
    } on Exception catch (_) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LightStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.primary,
        bottomNavigationBar: _SubmitBar(
          isLoading: _submitting,
          onPressed: _submit,
        ),
        body: Column(
          children: <Widget>[
            AddFormHeader(
              title: 'Add Expense Claim',
              subtitle: 'Submit a field expense for reimbursement',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32.r),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 28.h),
                    child: SectionCard(
                      children: <Widget>[
                        PrimaryTextField(
                          controller: _titleController,
                          label: 'Title',
                          hintText: 'Enter expense title',
                          prefixIcon: Icons.title_rounded,
                          minLines: 1,
                          maxLines: 2,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.requiredField(v, 'Title'),
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _amountController,
                          label: 'Amount',
                          hintText: 'Enter amount (Rs)',
                          prefixIcon: Icons.payments_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: <TextInputFormatter>[
                            // Digits + a single optional decimal point.
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          textInputAction: TextInputAction.next,
                          validator: _validateAmount,
                        ),
                        SizedBox(height: 16.h),
                        CustomDatePicker(
                          controller: _dateController,
                          label: 'Date',
                          hintText: 'When was it spent',
                          prefixIcon: Icons.event_outlined,
                          // An expense is incurred in the past or today —
                          // block future dates.
                          lastDate: DateTime.now(),
                          validator: (v) => Validators.requiredField(v, 'Date'),
                          onDateSelected: (picked) =>
                              setState(() => _date = picked),
                        ),
                        SizedBox(height: 16.h),
                        ExpenseCategoryField(
                          value: _category,
                          onChanged: (next) => setState(() => _category = next),
                        ),
                        SizedBox(height: 16.h),
                        PartyPickerField<ExpenseParty>(
                          value: _party,
                          onChanged: (next) => setState(() => _party = next),
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
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _descriptionController,
                          label: 'Description',
                          hintText: 'Add any details',
                          prefixIcon: Icons.notes_outlined,
                          minLines: 1,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          validator: (v) =>
                              Validators.requiredField(v, 'Description'),
                        ),
                        SizedBox(height: 20.h),
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
                          showLabel: false,
                          onPick: _pickImage,
                          onRemove: _removeImageAt,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({required this.isLoading, required this.onPressed});

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
            label: 'Add Expense Claim',
            leadingIcon: Icons.add_circle_outline,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
