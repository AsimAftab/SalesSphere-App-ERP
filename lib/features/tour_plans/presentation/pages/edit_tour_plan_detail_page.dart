import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/tour_plans/domain/tour_plan.dart';
import 'package:sales_sphere_erp/features/tour_plans/presentation/controllers/tour_plans_controller.dart';
import 'package:sales_sphere_erp/features/tour_plans/presentation/providers/tour_plans_providers.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_date_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/section_card.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Per-status colour palette mirrors the list page so the inline
/// status banner reads as the same component.
({Color fg, Color bg}) _statusPalette(TourPlanStatus s) => switch (s) {
  TourPlanStatus.pending => (fg: AppColors.warning, bg: AppColors.warning),
  TourPlanStatus.approved => (fg: AppColors.green500, bg: AppColors.green500),
  TourPlanStatus.rejected => (fg: AppColors.error, bg: AppColors.error),
  TourPlanStatus.completed => (fg: AppColors.blue500, bg: AppColors.blue500),
};

class EditTourPlanDetailPage extends ConsumerStatefulWidget {
  const EditTourPlanDetailPage({required this.id, this.initial, super.key});

  final String id;

  /// Optional starting record passed via `extra` when navigating from
  /// the list — saves a re-fetch on first paint.
  final TourPlan? initial;

  @override
  ConsumerState<EditTourPlanDetailPage> createState() =>
      _EditTourPlanDetailPageState();
}

class _EditTourPlanDetailPageState
    extends ConsumerState<EditTourPlanDetailPage> {
  final _formKey = GlobalKey<FormState>();

  final _placeController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _durationController = TextEditingController();
  final _purposeController = TextEditingController();
  final _createdAtController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  TourPlanStatus _status = TourPlanStatus.pending;
  DateTime? _createdAt;
  String? _rejectionReason;

  bool _editing = false;
  bool _saving = false;
  bool _loading = false;
  bool _notFound = false;

  /// Pending requests are user-mutable. Approved or rejected requests
  /// are decided by the manager and lock to read-only — the detail
  /// page hides the edit affordance entirely so the user can't tap
  /// into a flow that would just throw on save.
  bool get _isMutable => _status == TourPlanStatus.pending;

  /// Only approved plans can be marked as completed.
  bool get _canMarkCompleted => _status == TourPlanStatus.approved;

  /// Show bottom bar for pending (edit) or approved (mark completed) plans.
  bool get _showBottomBar => _isMutable || _canMarkCompleted;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _populate(widget.initial!);
    } else {
      _loading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _hydrate());
    }
  }

  /// Loads the record by awaiting the byId provider's future.
  Future<void> _hydrate() async {
    TourPlan? plan;
    try {
      plan = await ref.read(tourPlanByIdProvider(widget.id).future);
    } on Object catch (_) {
      // List failed; fall through to the not-found state below.
    }
    if (!mounted) return;
    if (plan != null) {
      _populate(plan);
      setState(() => _loading = false);
    } else {
      setState(() {
        _loading = false;
        _notFound = true;
      });
    }
  }

  @override
  void dispose() {
    _placeController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _durationController.dispose();
    _purposeController.dispose();
    _createdAtController.dispose();
    super.dispose();
  }

  void _refreshDuration() {
    _durationController.text = tourPlanDurationLabel(_startDate, _endDate);
  }

  void _populate(TourPlan p) {
    _placeController.text = p.placeOfVisit;
    _startDate = p.startDate;
    _endDate = p.endDate;
    _startDateController.text = DateFormat('dd MMM yyyy').format(p.startDate);
    _endDateController.text = DateFormat('dd MMM yyyy').format(p.endDate);
    _refreshDuration();
    _purposeController.text = p.purpose;
    _status = p.status;
    _createdAt = p.createdAt;
    _rejectionReason = p.rejectionReason;
    _createdAtController.text = DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(p.createdAt);
  }

  void _toggleEdit() {
    if (!_isMutable) return;
    setState(() => _editing = !_editing);
  }

  void _cancelEdit() {
    final saved =
        ref.read(tourPlanByIdProvider(widget.id)).value ?? widget.initial;
    if (saved != null) _populate(saved);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _editing = false);
  }

  void _onStartDatePicked(DateTime picked) {
    setState(() {
      _startDate = picked;
      // If the previously chosen end date is now before the new start,
      // clear it — keeping it would let the user save a backwards
      // range. The end-date picker re-anchors via `firstDate` below.
      if (_endDate != null && _endDate!.isBefore(picked)) {
        _endDate = null;
        _endDateController.text = '';
      }
      _refreshDuration();
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) return;
    final startDate = _startDate;
    final endDate = _endDate;
    if (startDate == null || endDate == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      final updated = TourPlan(
        id: widget.id,
        placeOfVisit: _placeController.text.trim(),
        startDate: startDate,
        endDate: endDate,
        purpose: _purposeController.text.trim(),
        status: _status,
        createdAt: _createdAt ?? DateTime.now(),
      );
      await ref
          .read(tourPlansControllerProvider.notifier)
          .updateTourPlan(updated);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _editing = false;
      });
      SnackbarUtils.showSuccess(context, 'Tour plan updated.');
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, 'Could not save. Please try again.');
    }
  }

  Future<void> _markCompleted() async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _saving = true);
    try {
      await ref
          .read(tourPlansControllerProvider.notifier)
          .markTourPlanCompleted(widget.id);
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Tour plan marked as completed.');
      context.pop();
    } on Exception catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      SnackbarUtils.showError(context, 'Could not mark as completed. Please try again.');
    }
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _DetailSkeleton(onBack: _back);
    if (_notFound) return const _NotFoundScaffold();
    // Keep the provider warm so cancelEdit can read the saved snapshot.
    ref.watch(tourPlanByIdProvider(widget.id));

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        bottomNavigationBar: _showBottomBar
            ? (_isMutable
                ? _SubmitBar(
                    editing: _editing,
                    isLoading: _saving,
                    onPressed: _editing ? _save : _toggleEdit,
                  )
                : _CompletionBar(
                    isLoading: _saving,
                    onPressed: _markCompleted,
                  ))
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
                                  controller: _placeController,
                                  label: 'Place of Visit',
                                  hintText: 'City, region, or specific site',
                                  prefixIcon: Icons.location_on_outlined,
                                  enabled: _editing,
                                  validator: (v) => Validators.requiredField(
                                    v,
                                    'Place of Visit',
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                CustomDatePicker(
                                  controller: _startDateController,
                                  label: 'Start Date',
                                  hintText: 'When does the tour start?',
                                  prefixIcon: Icons.calendar_today_outlined,
                                  enabled: _editing,
                                  initialDate: _startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                  onDateSelected: _onStartDatePicked,
                                  validator: (v) =>
                                      Validators.requiredField(v, 'Start Date'),
                                ),
                                SizedBox(height: 12.h),
                                CustomDatePicker(
                                  controller: _endDateController,
                                  label: 'End Date',
                                  hintText: 'When does the tour end?',
                                  prefixIcon: Icons.event_outlined,
                                  enabled: _editing,
                                  initialDate: _endDate ?? _startDate,
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
                                SizedBox(height: 12.h),
                                // Read-only duration. Computed from
                                // start + end inclusively, refreshes on
                                // every date change.
                                PrimaryTextField(
                                  controller: _durationController,
                                  label: 'Duration',
                                  hintText: '—',
                                  prefixIcon: Icons.timelapse_rounded,
                                  enabled: false,
                                  readOnly: true,
                                ),
                                SizedBox(height: 12.h),
                                PrimaryTextField(
                                  controller: _purposeController,
                                  label: 'Purpose of Visit',
                                  hintText: 'Describe the goal of this tour',
                                  prefixIcon: Icons.notes_rounded,
                                  enabled: _editing,
                                  minLines: 1,
                                  maxLines: 5,
                                  validator: (v) => Validators.requiredField(
                                    v,
                                    'Purpose of Visit',
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                // Read-only metadata. The submission
                                // timestamp is server-assigned and not
                                // user-editable, so the field stays
                                // disabled regardless of edit mode.
                                PrimaryTextField(
                                  controller: _createdAtController,
                                  label: 'Created On',
                                  hintText: '—',
                                  prefixIcon: Icons.access_time_rounded,
                                  enabled: false,
                                  readOnly: true,
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
  const _StatusBanner({
    required this.status,
    this.rejectionReason,
  });

  final TourPlanStatus status;
  final String? rejectionReason;

  @override
  Widget build(BuildContext context) {
    final palette = _statusPalette(status);
    final icon = switch (status) {
      TourPlanStatus.pending => Icons.hourglass_empty_rounded,
      TourPlanStatus.approved => Icons.check_circle_outline_rounded,
      TourPlanStatus.rejected => Icons.cancel_outlined,
      TourPlanStatus.completed => Icons.task_alt_rounded,
    };
    final note = switch (status) {
      TourPlanStatus.pending => 'Awaiting approver review. You can still edit.',
      TourPlanStatus.approved =>
        'Approved by your approver. No changes allowed.',
      TourPlanStatus.rejected =>
        'Rejected by your approver. No changes allowed.',
      TourPlanStatus.completed => 'Completed and closed. No changes allowed.',
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        // Solid surface fill so the corner-bubble SVG behind the page
        // doesn't bleed through the banner. The accent reads via the
        // colored icon and text — no border needed.
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
          Icon(icon, color: palette.fg, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  tourPlanStatusLabel(status),
                  style: TextStyle(
                    color: palette.fg,
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
                if (status == TourPlanStatus.rejected &&
                    (rejectionReason?.isNotEmpty ?? false)) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: palette.bg.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      'Reason: $rejectionReason',
                      style: TextStyle(
                        color: palette.fg,
                        fontSize: 12.sp,
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
          Text(
            'Tour Plan Details',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
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
                  fontSize: 16.sp,
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

class _CompletionBar extends StatelessWidget {
  const _CompletionBar({
    required this.isLoading,
    required this.onPressed,
  });

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
          child: Tooltip(
            message: 'Mark this approved tour plan as completed',
            child: PrimaryButton(
              label: 'Mark Completed',
              leadingIcon: Icons.task_alt_rounded,
              isLoading: isLoading,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: DarkStatusBar(
        child: Scaffold(
          backgroundColor: AppColors.background,
          bottomNavigationBar: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
                child: Bone(
                  width: double.infinity,
                  height: 60.h,
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
          body: Stack(
            children: <Widget>[
              const _CurvedHeader(),
              SafeArea(
                child: Column(
                  children: <Widget>[
                    Padding(
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
                          Text(
                            'Tour Plan Details',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Bone(
                              width: double.infinity,
                              height: 64.h,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            SizedBox(height: 12.h),
                            SectionCard(
                              children: <Widget>[
                                for (var i = 0; i < 5; i++) ...<Widget>[
                                  if (i > 0) SizedBox(height: 12.h),
                                  Bone(
                                    width: double.infinity,
                                    height: 56.h,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          title: const Text('Tour Plan Details'),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.w),
            child: Text(
              "Couldn't load this tour plan — it may have been removed.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
            ),
          ),
        ),
      ),
    );
  }
}
