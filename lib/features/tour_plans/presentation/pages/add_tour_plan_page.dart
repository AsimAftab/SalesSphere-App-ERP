import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/tour_plans/domain/tour_plan.dart';
import 'package:sales_sphere_erp/features/tour_plans/presentation/controllers/tour_plans_controller.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class AddTourPlanPage extends ConsumerStatefulWidget {
  const AddTourPlanPage({super.key});

  @override
  ConsumerState<AddTourPlanPage> createState() => _AddTourPlanPageState();
}

class _AddTourPlanPageState extends ConsumerState<AddTourPlanPage> {
  final _formKey = GlobalKey<FormState>();

  final _placeController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _durationController = TextEditingController();
  final _purposeController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  bool _submitting = false;

  @override
  void dispose() {
    _placeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _durationController.dispose();
    _purposeController.dispose();
    super.dispose();
  }

  void _refreshDuration() {
    _durationController.text = tourPlanDurationLabel(_startDate, _endDate);
  }

  void _onStartDatePicked(DateTime picked) {
    setState(() {
      _startDate = picked;
      // If the previously chosen end date is now before the new start,
      // clear it — keeping it would let the user submit a backwards
      // range. The end-date picker re-anchors via `firstDate` below.
      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = null;
        _endDateController.text = '';
      }
      _refreshDuration();
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    final startDate = _startDate;
    final endDate = _endDate;
    if (startDate == null || endDate == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _submitting = true);
    try {
      final draft = TourPlan(
        id: '',
        // assigned by the API mock
        placeOfVisit: _placeController.text.trim(),
        startDate: startDate,
        endDate: endDate,
        purpose: _purposeController.text.trim(),
        // Mock API forces 'pending' on create regardless — placeholder.
        status: TourPlanStatus.pending,
        // Repository/API assigns the canonical createdAt — placeholder.
        createdAt: DateTime.now(),
      );
      await ref
          .read(tourPlansControllerProvider.notifier)
          .addTourPlan(draft);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Tour plan submitted.');
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
            _Header(onBack: () => context.pop()),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(32.r),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(24.w, 32.h, 24.w, 32.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        PrimaryTextField(
                          controller: _placeController,
                          label: 'Place of Visit',
                          hintText: 'City, region, or specific site',
                          prefixIcon: Icons.location_on_outlined,
                          textInputAction: TextInputAction.next,
                          validator: (v) =>
                              Validators.requiredField(v, 'Place of Visit'),
                        ),
                        SizedBox(height: 16.h),
                        CustomDatePicker(
                          controller: _startDateController,
                          label: 'Start Date',
                          hintText: 'When does the tour start?',
                          prefixIcon: Icons.calendar_today_outlined,
                          initialDate: _startDate,
                          // Past plans are allowed (e.g. logging a tour
                          // after the fact). Cap a year forward to keep
                          // the picker scannable.
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
                          label: 'End Date',
                          hintText: 'When does the tour end?',
                          prefixIcon: Icons.event_outlined,
                          initialDate: _endDate ?? _startDate,
                          // Earliest a tour can end is the start date
                          // itself (single-day tour). Until the user
                          // picks a start, leave the floor open.
                          firstDate: _startDate ?? DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                          onDateSelected: (picked) => setState(() {
                            _endDate = picked;
                            _refreshDuration();
                          }),
                          validator: (v) =>
                              Validators.requiredField(v, 'End Date'),
                        ),
                        SizedBox(height: 16.h),
                        // Read-only duration. Computed from start + end
                        // inclusively (Apr 12 → Apr 12 = "1 day"),
                        // updated on every date change.
                        PrimaryTextField(
                          controller: _durationController,
                          label: 'Duration',
                          hintText: 'Pick start and end dates',
                          prefixIcon: Icons.timelapse_rounded,
                          enabled: false,
                          readOnly: true,
                        ),
                        SizedBox(height: 16.h),
                        PrimaryTextField(
                          controller: _purposeController,
                          label: 'Purpose of Visit',
                          hintText: 'Describe the goal of this tour',
                          prefixIcon: Icons.notes_rounded,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.newline,
                          validator: (v) => Validators.requiredField(
                            v,
                            'Purpose of Visit',
                          ),
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

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 0),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                    onPressed: onBack,
                    tooltip: 'Back',
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Text(
              'Add Tour Plan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.sp,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Submit a new tour for approval',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
            SizedBox(height: 32.h),
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
            label: 'Add Tour Plan',
            leadingIcon: Icons.add_circle_outline,
            isLoading: isLoading,
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
