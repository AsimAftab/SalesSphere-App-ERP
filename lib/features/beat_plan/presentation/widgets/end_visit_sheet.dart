import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';


import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

class EndVisitSheet extends StatefulWidget {
  final Map<String, dynamic> entity;

  /// Called with the captured visit details when the rep confirms. The photo
  /// and notes are required by the form; [followUpDate] is optional.
  final void Function({
    required String notes,
    required String photoPath,
    DateTime? followUpDate,
  }) onEndVisit;

  const EndVisitSheet({
    super.key,
    required this.entity,
    required this.onEndVisit,
  });

  @override
  State<EndVisitSheet> createState() => _EndVisitSheetState();
}

class _EndVisitSheetState extends State<EndVisitSheet> {
  String? _photoPath;
  DateTime? _followUpDate;
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _imageError = false;

  @override
  void dispose() {
    _notesController.dispose();
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

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _followUpDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() => _followUpDate = date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, MediaQuery.of(context).viewInsets.bottom + 24.h),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Visit',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        (widget.entity['name'] as String?) ?? 'Unknown Entity',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            Text('Notes', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            SizedBox(height: 8.h),
            PrimaryTextField(
              controller: _notesController,
              maxLines: 3,
              hintText: 'Enter visit notes or outcomes...',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter visit notes';
                }
                return null;
              },
            ),
            SizedBox(height: 24.h),
            Text('Photo Proof', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 140.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _imageError 
                      ? AppColors.error.withValues(alpha: 0.05)
                      : AppColors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: _imageError 
                        ? AppColors.error.withValues(alpha: 0.3)
                        : AppColors.primary.withValues(alpha: 0.3),
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
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(
                              color: _imageError 
                                  ? AppColors.error.withValues(alpha: 0.1)
                                  : AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.camera_alt_rounded,
                              color: _imageError ? AppColors.error : AppColors.primary,
                              size: 24.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _imageError ? 'Photo proof is required' : 'Tap to capture photo',
                            style: TextStyle(
                              color: _imageError ? AppColors.error : AppColors.primary,
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
            Text('Follow-up Date (Optional)', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            SizedBox(height: 8.h),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                height: 50.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        _followUpDate != null
                            ? '${_followUpDate!.day.toString().padLeft(2, '0')}/${_followUpDate!.month.toString().padLeft(2, '0')}/${_followUpDate!.year}'
                            : 'Select a follow-up date',
                        style: TextStyle(
                          color: _followUpDate != null ? AppColors.textPrimary : AppColors.textSecondary,
                          fontSize: 14.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 32.h),
            CustomButton(
              label: 'End Visit',
              onPressed: () {
                final isValid = _formKey.currentState?.validate() ?? false;
                
                if (_photoPath == null) {
                  setState(() => _imageError = true);
                }

                if (!isValid || _photoPath == null) {
                  return;
                }

                Navigator.of(context).pop();
                widget.onEndVisit(
                  notes: _notesController.text.trim(),
                  photoPath: _photoPath!,
                  followUpDate: _followUpDate,
                );
              },
            ),
          ],
        ),
        ),
      ),
    );
  }
}
