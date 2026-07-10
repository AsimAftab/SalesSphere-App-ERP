import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';


import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/domain/unplanned_visit_exceptions.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/controllers/unplanned_visit_controller.dart';
import 'package:sales_sphere_erp/features/unplanned_visits/presentation/providers/unplanned_visit_providers.dart';
import 'package:sales_sphere_erp/shared/utils/error_messages.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

/// Bottom sheet to complete the active visit: capture the proof photo
/// (required), a description (required) and an optional follow-up date.
class StopVisitSheet extends ConsumerStatefulWidget {
  const StopVisitSheet({required this.visit, super.key});

  final UnplannedVisit visit;

  @override
  ConsumerState<StopVisitSheet> createState() => _StopVisitSheetState();
}

class _StopVisitSheetState extends ConsumerState<StopVisitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  String? _photoPath;
  bool _imageError = false;
  DateTime? _followUpDate;
  bool _isLoading = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await showImagePickerSheet(
      context,
      imageQuality: 80,
      cameraOnly: true,
    );
    if (picked != null) {
      setState(() {
        _photoPath = picked.path;
        _imageError = false;
      });
    }
  }

  Future<void> _pickFollowUpDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _followUpDate = picked);
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState!.validate();
    final photoPath = _photoPath;
    if (photoPath == null) setState(() => _imageError = true);
    if (!isValid || photoPath == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(unplannedVisitControllerProvider.notifier).stopVisit(
            imagePath: photoPath,
            description: _descController.text.trim(),
            followUpDate: _followUpDate,
          );
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Visit completed.');
      context.pop();
    } on UnplannedVisitConflictException catch (e) {
      // The open visit changed under us — refresh and close.
      if (!mounted) return;
      ref.invalidate(unplannedVisitsTodayProvider);
      SnackbarUtils.showInfo(context, e.message);
      context.pop();
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      SnackbarUtils.showError(context, userMessageFor(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = _followUpDate;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.only(
        top: 24.h,
        left: 20.w,
        right: 20.w,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Complete Visit',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          widget.visit.target.displayName,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              Text(
                'Photo Proof',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 140.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _imageError
                        ? AppColors.red500.withValues(alpha: 0.05)
                        : AppColors.blue500.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: _imageError
                          ? AppColors.red500.withValues(alpha: 0.3)
                          : AppColors.blue500.withValues(alpha: 0.3),
                    ),
                    image: _photoPath != null
                        ? DecorationImage(
                            image: FileImage(File(_photoPath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _photoPath == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.all(8.r),
                              decoration: BoxDecoration(
                                color: _imageError
                                    ? AppColors.red500.withValues(alpha: 0.1)
                                    : AppColors.blue500.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                color: _imageError
                                    ? AppColors.red500
                                    : AppColors.blue500,
                                size: 24.sp,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              _imageError
                                  ? 'Photo proof is required'
                                  : 'Tap to capture photo',
                              style: TextStyle(
                                color: _imageError
                                    ? AppColors.red500
                                    : AppColors.blue500,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'Description',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              PrimaryTextField(
                controller: _descController,
                maxLines: 3,
                hintText: 'What happened on this visit?',
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Description is required';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24.h),
              Text(
                'Follow-up Date (Optional)',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              InkWell(
                onTap: _pickFollowUpDate,
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(Icons.event_rounded,
                          color: AppColors.textSecondary, size: 18.sp),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          df == null
                              ? 'Add a follow-up date'
                              : '${df.year}-${df.month.toString().padLeft(2, '0')}-${df.day.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: df == null
                                ? AppColors.textHint
                                : AppColors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (df != null)
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.close,
                              color: AppColors.textSecondary, size: 18.sp),
                          tooltip: 'Clear follow-up date',
                          onPressed: () => setState(() => _followUpDate = null),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.h),
              CustomButton(
                onPressed: _submit,
                isLoading: _isLoading,
                label: 'Complete Visit',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
