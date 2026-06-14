import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/providers/odometer_providers.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

class StopTripSheet extends ConsumerStatefulWidget {
  const StopTripSheet({required this.trip, super.key});

  final OdometerTrip trip;

  @override
  ConsumerState<StopTripSheet> createState() => _StopTripSheetState();
}

class _StopTripSheetState extends ConsumerState<StopTripSheet> {
  final _formKey = GlobalKey<FormState>();
  final _readingController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;
  String? _photoPath;
  bool _imageError = false;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _readingController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (pickedFile != null) {
      setState(() {
        _photoPath = pickedFile.path;
        _imageError = false;
      });
    }
  }

  void _submit() async {
    final isValid = _formKey.currentState!.validate();
    
    if (_photoPath == null) {
      setState(() => _imageError = true);
    }
    
    if (!isValid || _photoPath == null) return;
    
    final readingStr = _readingController.text.trim();
    final reading = int.tryParse(readingStr);
    if (reading == null) return;

    setState(() => _isLoading = true);
    
    await ref.read(odometerProvider.notifier).stopTrip(
      tripId: widget.trip.id,
      stopReading: reading,
      photoUrl: _photoPath,
      description: _descController.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              children: [
                Text(
                  'Stop Trip',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            
            // Trip Started At Summary Card
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.blue500.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.blue500.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: AppColors.blue500.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.info_outline_rounded, color: AppColors.blue500, size: 16.sp),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Trip Started At',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Row(
                    children: [
                      _StartBadge(
                        icon: Icons.speed_rounded,
                        text: '${widget.trip.startReading} ${widget.trip.distanceUnit.label}',
                      ),
                      SizedBox(width: 12.w),
                      _StartBadge(
                        icon: Icons.schedule_rounded,
                        text: DateFormat('hh:mm a').format(widget.trip.startedAt),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Start Image Proof',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    height: 140.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8.r),
                      image: widget.trip.startPhotoUrl != null
                          ? DecorationImage(
                              image: FileImage(File(widget.trip.startPhotoUrl!)),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: widget.trip.startPhotoUrl == null
                        ? Center(
                            child: Icon(Icons.image_not_supported_rounded, color: AppColors.textHint, size: 24.sp),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24.h),
            Text(
              'Odometer Reading',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PrimaryTextField(
                    controller: _readingController,
                    keyboardType: TextInputType.number,
                    hintText: '000000',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Reading is required';
                      }
                      if (int.tryParse(value.trim()) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 12.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    widget.trip.distanceUnit.label,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
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
                        children: [
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
                              color: _imageError ? AppColors.red500 : AppColors.blue500, 
                              size: 24.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            _imageError ? 'Photo proof is required' : 'Tap to capture photo',
                            style: TextStyle(
                              color: _imageError ? AppColors.red500 : AppColors.blue500,
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
              'Description (Optional)',
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
              hintText: 'Enter details...',
            ),
            SizedBox(height: 32.h),
            CustomButton(
              onPressed: _submit,
              isLoading: _isLoading,
              label: 'Complete Trip',
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _StartBadge extends StatelessWidget {
  const _StartBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.blue500, size: 16.sp),
          SizedBox(width: 6.w),
          Text(
            text,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
