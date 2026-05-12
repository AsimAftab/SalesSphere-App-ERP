import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';
import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Profile detail screen reached by pushing from the More tab.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String? _avatarPath;

  Future<void> _chooseAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(30.w, 26.h, 30.w, 36.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Choose Image Source',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 28.h),
              _ImageSourceOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                onTap: () => context.pop(ImageSource.camera),
              ),
              SizedBox(height: 20.h),
              _ImageSourceOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                onTap: () => context.pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;

    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 82,
      );
      if (image == null || !mounted) return;
      setState(() => _avatarPath = image.path);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile image.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.value;

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _ProfileAppBar(
                onBack: () =>
                    context.canPop() ? context.pop() : context.go(Routes.more),
                onLogout: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
              Expanded(
                child: auth.isLoading && user == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _ProfileContent(
                        user: user,
                        avatarPath: _avatarPath,
                        onChangeAvatar: _chooseAvatar,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageSourceOption extends StatelessWidget {
  const _ImageSourceOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: Row(
          children: <Widget>[
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: const Color(0xFFE9EEF4),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20.sp),
            ),
            SizedBox(width: 16.w),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAppBar extends StatelessWidget {
  const _ProfileAppBar({required this.onBack, required this.onLogout});

  final VoidCallback onBack;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 4.h, 16.w, 8.h),
      child: Row(
        children: <Widget>[
          IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textdark,
              size: 28.sp,
            ),
            onPressed: onBack,
            tooltip: 'Back',
          ),
          SizedBox(width: 12.w),
          Text(
            'Profile',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              Icons.logout_rounded,
              color: AppColors.error,
              size: 28.sp,
            ),
            onPressed: onLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.user,
    required this.avatarPath,
    required this.onChangeAvatar,
  });

  final AuthUser? user;
  final String? avatarPath;
  final VoidCallback onChangeAvatar;

  @override
  Widget build(BuildContext context) {
    final userFullName = user?.fullName.trim();
    final fullName = (userFullName?.isNotEmpty ?? false)
        ? userFullName!
        : 'Profile';
    final role = _formatRole(user?.systemRole);
    final emailVerified = user?.emailVerified ?? false;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24.w, 18.h, 24.w, 28.h),
      child: Column(
        children: <Widget>[
          _AvatarHeader(
            fullName: fullName,
            role: role,
            avatarPath: avatarPath,
            onChangeAvatar: onChangeAvatar,
          ),
          SizedBox(height: 24.h),
          Row(
            children: <Widget>[
              const Expanded(
                child: _SummaryCard(
                  value: '0%',
                  label: 'Attendance',
                  valueColor: AppColors.success,
                ),
              ),
              SizedBox(width: 20.w),
              const Expanded(
                child: _SummaryCard(
                  value: '0',
                  label: 'Orders',
                  valueColor: AppColors.tertiary,
                ),
              ),
            ],
          ),
          SizedBox(height: 22.h),
          _InfoCard(
            title: 'Personal Information',
            rows: <_InfoRowData>[
              _InfoRowData(
                icon: Icons.person_outline,
                label: 'Full Name',
                value: fullName,
              ),
              const _InfoRowData(
                icon: Icons.wc_outlined,
                label: 'Gender',
                value: 'Not specified',
              ),
              const _InfoRowData(
                icon: Icons.phone_outlined,
                label: 'Phone Number',
                value: 'Not specified',
              ),
              _InfoRowData(
                icon: Icons.email_outlined,
                label: 'Email Address',
                value: user?.email ?? 'Not specified',
              ),
              const _InfoRowData(
                icon: Icons.perm_contact_calendar_outlined,
                label: 'Age',
                value: 'Not specified',
              ),
              const _InfoRowData(
                icon: Icons.flag_outlined,
                label: 'Citizenship Number',
                value: 'Not specified',
              ),
              const _InfoRowData(
                icon: Icons.receipt_long_outlined,
                label: 'PAN Number',
                value: 'Not specified',
              ),
              const _InfoRowData(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: 'Not specified',
              ),
              const _InfoRowData(
                icon: Icons.cake_outlined,
                label: 'Date of Birth',
                value: 'Not specified',
              ),
              const _InfoRowData(
                icon: Icons.calendar_today_outlined,
                label: 'Date Joined',
                value: 'Not specified',
              ),
              _InfoRowData(
                icon: Icons.work_outline,
                label: 'Role',
                value: role,
              ),
              _InfoRowData(
                icon: Icons.verified_user_outlined,
                label: 'Email Verified',
                value: emailVerified ? 'Yes' : 'No',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({
    required this.fullName,
    required this.role,
    required this.avatarPath,
    required this.onChangeAvatar,
  });

  final String fullName;
  final String role;
  final String? avatarPath;
  final VoidCallback onChangeAvatar;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 112.r,
              height: 112.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textOrange, width: 3.w),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: avatarPath == null
                    ? null
                    : () => showPrimaryImagePreview(
                        context,
                        FileImage(File(avatarPath!)),
                      ),
                child: ClipOval(
                  child: avatarPath == null
                      ? CircleAvatar(
                          backgroundColor: AppColors.primary,
                          child: Text(
                            _initials(fullName),
                            style: TextStyle(
                              color: AppColors.textWhite,
                              fontSize: 32.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : Image.file(
                          File(avatarPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              _initials(fullName),
                              style: TextStyle(
                                color: AppColors.textWhite,
                                fontSize: 32.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
            Positioned(
              right: -2.w,
              bottom: 8.h,
              child: InkWell(
                onTap: onChangeAvatar,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 40.r,
                  height: 40.r,
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 3.w),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.textWhite,
                    size: 20.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 20.h),
        Text(
          fullName,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          role,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 86.h,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(22.w, 24.h, 22.w, 20.h),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 24.h),
          for (final row in rows) ...<Widget>[
            _InfoRow(data: row),
            if (row != rows.last) SizedBox(height: 20.h),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data});

  final _InfoRowData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 46.r,
          height: 46.r,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF4),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(data.icon, color: AppColors.primary, size: 22.sp),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                data.label,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                data.value,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRowData {
  const _InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return 'P';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

String _formatRole(String? role) {
  final value = role?.trim();
  if (value == null || value.isEmpty) return 'Not specified';
  return value;
}
