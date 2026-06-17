import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_exceptions.dart';
import 'package:sales_sphere_erp/features/odometer/domain/odometer_trip.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/controllers/odometer_controller.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/odometer_formatting.dart';
import 'package:sales_sphere_erp/features/odometer/presentation/providers/odometer_providers.dart';
import 'package:sales_sphere_erp/shared/utils/error_messages.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
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

  Future<void> _submit() async {
    final isValid = _formKey.currentState!.validate();

    if (_photoPath == null) {
      setState(() => _imageError = true);
    }

    if (!isValid || _photoPath == null) return;

    final reading = double.tryParse(_readingController.text.trim());
    if (reading == null) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(odometerControllerProvider.notifier).stopTrip(
            stopReading: reading,
            unit: widget.trip.distanceUnit,
            description: _descController.text.trim(),
            imagePath: _photoPath,
          );
      if (!mounted) return;
      SnackbarUtils.showSuccess(context, 'Trip completed.');
      context.pop();
    } on OdometerConflictException catch (e) {
      // No active trip server-side — refresh and close.
      if (!mounted) return;
      ref.invalidate(odometerTodayStatusProvider);
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
    final trip = widget.trip;
    final startedAt = trip.startedAt;
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
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppColors.textSecondary),
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
                  border:
                      Border.all(color: AppColors.blue500.withValues(alpha: 0.2)),
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
                          child: Icon(Icons.info_outline_rounded,
                              color: AppColors.blue500, size: 16.sp),
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
                          text:
                              '${formatReading(trip.startReading)} ${trip.distanceUnit.label}',
                        ),
                        SizedBox(width: 12.w),
                        if (startedAt != null)
                          _StartBadge(
                            icon: Icons.schedule_rounded,
                            text: DateFormat('hh:mm a').format(startedAt),
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: _StartImagePreview(url: trip.startImageUrl),
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      hintText: '000000',
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Reading is required';
                        final parsed = double.tryParse(text);
                        if (parsed == null) return 'Invalid number';
                        final start = trip.startReading;
                        if (start != null && parsed < start) {
                          return 'Must be ≥ start (${formatReading(start)})';
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
                      trip.distanceUnit.label,
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

/// Renders the trip's start photo from its remote (Cloudinary) URL.
class _StartImagePreview extends StatelessWidget {
  const _StartImagePreview({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) {
      return Container(
        height: 140.h,
        width: double.infinity,
        color: AppColors.background,
        child: Center(
          child: Icon(Icons.image_not_supported_rounded,
              color: AppColors.textHint, size: 24.sp),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      height: 140.h,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        height: 140.h,
        color: AppColors.background,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        height: 140.h,
        color: AppColors.background,
        child: Center(
          child: Icon(Icons.broken_image_rounded,
              color: AppColors.textHint, size: 24.sp),
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
