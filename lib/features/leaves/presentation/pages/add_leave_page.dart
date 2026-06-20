import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/leaves/domain/leave.dart';
import 'package:sales_sphere_erp/features/leaves/presentation/controllers/leaves_controller.dart';
import 'package:sales_sphere_erp/features/leaves/presentation/widgets/leave_category_field.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/add_form_header.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class AddLeavePage extends ConsumerStatefulWidget {
  const AddLeavePage({super.key});

  @override
  ConsumerState<AddLeavePage> createState() => _AddLeavePageState();
}

class _AddLeavePageState extends ConsumerState<AddLeavePage> {
  final _formKey = GlobalKey<FormState>();

  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _durationController = TextEditingController();
  final _reasonController = TextEditingController();

  LeaveCategory? _category;
  DateTime? _startDate;

  /// Optional — null when the request is for a single day. Cleared
  /// automatically if the user picks an end date earlier than the
  /// current start date (see `_onStartDatePicked`).
  DateTime? _endDate;

  bool _submitting = false;

  @override
  void dispose() {
    _startDateController.dispose();
    _endDateController.dispose();
    _durationController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _refreshDuration() {
    _durationController.text = leaveDurationLabel(_startDate, _endDate);
  }

  void _onStartDatePicked(DateTime picked) {
    setState(() {
      _startDate = picked;
      // If the previously chosen end date is now before the new start,
      // clear it — keeping it would let the user submit a backwards
      // range. The end-date picker re-anchors to `_startDate` via
      // `firstDate` below, so the user can repick cleanly.
      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = null;
        _endDateController.text = '';
      }
      _refreshDuration();
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final category = _category;
    final startDate = _startDate;
    if (category == null || startDate == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final draft = Leave(
        id: '',
        // assigned by the API mock
        category: category,
        startDate: startDate,
        endDate: _endDate,
        reason: _reasonController.text.trim(),
        // Mock API forces 'pending' on create regardless — placeholder.
        status: LeaveStatus.pending,
        // Repository/API assigns the canonical createdAt — placeholder.
        createdAt: DateTime.now(),
      );
      await ref.read(leavesControllerProvider.notifier).addLeave(draft);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Leave request submitted.');
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      SnackbarUtils.showError(context, e.message);
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
              title: 'Apply for Leave',
              subtitle: 'Submit a leave request for approval',
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
                        CustomDatePicker(
                          controller: _startDateController,
                          label: 'Start Date',
                          hintText: 'When does the leave start?',
                          prefixIcon: Icons.calendar_today_outlined,
                          initialDate: _startDate,
                          // Past leaves are allowed (e.g. logging a sick
                          // day after the fact). Cap a year forward to
                          // keep the picker scannable.
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          onDateSelected: _onStartDatePicked,
                          validator: (v) =>
                              Validators.requiredField(v, 'Start Date'),
                        ),
                        SizedBox(height: 16.h),
                        CustomDatePicker(
                          controller: _endDateController,
                          label: 'End Date (Optional)',
                          hintText: 'Leave blank for single-day leave',
                          prefixIcon: Icons.event_outlined,
                          initialDate: _endDate ?? _startDate,
                          // Earliest a multi-day request can end is the
                          // start date itself. Until the user picks a
                          // start, leave the floor open.
                          firstDate: _startDate ?? DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          onDateSelected: (picked) => setState(() {
                            _endDate = picked;
                            _refreshDuration();
                          }),
                        ),
                        SizedBox(height: 16.h),
                        // Read-only duration. Computed from start +
                        // end inclusively (Apr 12 → Apr 12 = "1 day"),
                        // updated on every date change.
                        PrimaryTextField(
                          controller: _durationController,
                          label: 'Duration',
                          hintText: 'Pick a start date',
                          prefixIcon: Icons.timelapse_rounded,
                          enabled: false,
                          readOnly: true,
                        ),
                        SizedBox(height: 16.h),
                        LeaveCategoryField(
                          value: _category,
                          onChanged: (next) => setState(() => _category = next),
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _reasonController,
                          label: 'Reason',
                          hintText: 'Reason for leave',
                          prefixIcon: Icons.notes_rounded,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          validator: (v) =>
                              Validators.requiredField(v, 'Reason'),
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
            label: 'Submit Leave Request',
            leadingIcon: Icons.send_rounded,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
