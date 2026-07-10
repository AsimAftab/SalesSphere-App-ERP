import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';
import 'package:sales_sphere_erp/features/profile/domain/entities/profile_entity.dart';
import 'package:sales_sphere_erp/features/profile/presentation/controllers/profile_controller.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_image_picker.dart';
import 'package:sales_sphere_erp/shared/widgets/sign_out_confirmation_dialog.dart';
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
    try {
      final image = await showImagePickerSheet(
        context,
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

  Future<void> _signOut() async {
    final confirmed = await showSignOutConfirmation(context);
    if (!confirmed) return;
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.value;

    return DarkStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _ProfileAppBar(
                onBack: () =>
                    context.canPop() ? context.pop() : context.go(Routes.more),
                onLogout: _signOut,
              ),
              Expanded(
                child: profileState.isLoading && profile == null
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _ProfileContent(
                        profile: profile,
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
    required this.profile,
    required this.avatarPath,
    required this.onChangeAvatar,
  });

  final ProfileEntity? profile;
  final String? avatarPath;
  final VoidCallback onChangeAvatar;

  @override
  Widget build(BuildContext context) {
    final userFullName = profile?.user.name.trim();
    final fullName = (userFullName?.isNotEmpty ?? false)
        ? userFullName!
        : 'Profile';
    final membership = profile?.activeMembership;
    final role = _formatRole(membership?.role.name ?? profile?.user.systemRole);
    final emailVerified = profile?.user.emailVerified ?? false;

    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(24.w, 18.h, 24.w, 28.h),
      child: Column(
        children: <Widget>[
          _AvatarHeader(
            fullName: fullName,
            role: role,
            organization: membership?.organization.name,
            avatarPath: avatarPath,
            avatarUrl: membership?.avatarUrl,
            onChangeAvatar: onChangeAvatar,
          ),
          SizedBox(height: 24.h),
          _InfoCard(
            title: 'Personal Information',
            rows: <_InfoRowData>[
              _InfoRowData(
                icon: Icons.person_outline,
                label: 'Full Name',
                value: fullName,
              ),
              _InfoRowData(
                icon: Icons.wc_outlined,
                label: 'Gender',
                value: _formatGender(membership?.gender),
              ),
              _InfoRowData(
                icon: Icons.cake_outlined,
                label: 'Date of Birth',
                value: _formatDate(membership?.dateOfBirth),
              ),
              _InfoRowData(
                icon: Icons.perm_contact_calendar_outlined,
                label: 'Age',
                value: _formatAge(membership?.dateOfBirth),
              ),
              _InfoRowData(
                icon: Icons.phone_outlined,
                label: 'Phone Number',
                value: _orNotSpecified(membership?.phone),
              ),
              _InfoRowData(
                icon: Icons.email_outlined,
                label: 'Email Address',
                value: profile?.user.email ?? 'Not specified',
              ),
              _InfoRowData(
                icon: Icons.verified_user_outlined,
                label: 'Email Verified',
                value: emailVerified ? 'Yes' : 'No',
              ),
              _InfoRowData(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: _orNotSpecified(membership?.address),
              ),
              _InfoRowData(
                icon: Icons.flag_outlined,
                label: 'Citizenship Number',
                value: _orNotSpecified(membership?.citizenshipNumber),
              ),
              _InfoRowData(
                icon: Icons.receipt_long_outlined,
                label: 'PAN Number',
                value: _orNotSpecified(membership?.panNumber),
              ),
              _InfoRowData(
                icon: Icons.work_outline,
                label: 'Role',
                value: role,
              ),
              _InfoRowData(
                icon: Icons.business_outlined,
                label: 'Organization',
                value: membership?.organization.name ?? 'Not specified',
              ),
              _InfoRowData(
                icon: Icons.location_city_outlined,
                label: 'Branches',
                value: membership?.organization.branches.isEmpty == false
                    ? membership!.organization.branches
                        .map((b) => b.name)
                        .join(', ')
                    : 'Not specified',
              ),
              _InfoRowData(
                icon: Icons.calendar_today_outlined,
                label: 'Date Joined',
                value: _formatDate(membership?.dateJoined),
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
    required this.organization,
    required this.avatarPath,
    required this.avatarUrl,
    required this.onChangeAvatar,
  });

  final String fullName;
  final String role;
  final String? organization;
  final String? avatarPath;
  final String? avatarUrl;
  final VoidCallback onChangeAvatar;

  Widget _initialsAvatar() {
    return CircleAvatar(
      backgroundColor: AppColors.primary,
      child: Text(
        _initials(fullName),
        style: TextStyle(
          color: AppColors.textWhite,
          fontSize: 32.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 72.r,
              height: 72.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textOrange, width: 2.w),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Builder(
                builder: (context) {
                  // Locally-picked image wins (just-changed, not yet uploaded);
                  // otherwise fall back to the server avatar, then initials.
                  ImageProvider<Object>? preview;
                  if (avatarPath != null) {
                    preview = FileImage(File(avatarPath!));
                  } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
                    preview = NetworkImage(avatarUrl!);
                  }
                  return GestureDetector(
                    onTap: preview == null
                        ? null
                        : () => showPrimaryImagePreview(context, preview!),
                    child: ClipOval(
                      child: preview == null
                          ? _initialsAvatar()
                          : Image(
                              image: preview,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _initialsAvatar(),
                            ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              right: -2.w,
              bottom: -2.h,
              child: InkWell(
                onTap: onChangeAvatar,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 28.r,
                  height: 28.r,
                  decoration: BoxDecoration(
                    color: AppColors.info,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2.5.w),
                  ),
                  child: Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.textWhite,
                    size: 15.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                fullName,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                role,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (organization != null &&
                  organization!.trim().isNotEmpty) ...<Widget>[
                SizedBox(height: 6.h),
                Text(
                  organization!.trim(),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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

/// Trims and falls back to the shared placeholder for empty/null strings.
String _orNotSpecified(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? 'Not specified' : trimmed;
}

/// `MALE` → `Male`. The backend stores gender as an upper-case enum.
String _formatGender(String? gender) {
  final value = gender?.trim();
  if (value == null || value.isEmpty) return 'Not specified';
  return value[0].toUpperCase() + value.substring(1).toLowerCase();
}

String _formatDate(DateTime? date) {
  if (date == null) return 'Not specified';
  // Format from the value's own calendar fields (the backend sends date-only
  // values at UTC midnight) so a timezone offset can't shift the day.
  return DateFormat('dd MMM yyyy').format(date);
}

/// Whole years between [dob] and today. Returns the placeholder when the date
/// is missing or implausible (future-dated).
String _formatAge(DateTime? dob) {
  if (dob == null) return 'Not specified';
  final now = DateTime.now();
  var age = now.year - dob.year;
  if (now.month < dob.month ||
      (now.month == dob.month && now.day < dob.day)) {
    age--;
  }
  if (age < 0) return 'Not specified';
  return age == 1 ? '1 year' : '$age years';
}
