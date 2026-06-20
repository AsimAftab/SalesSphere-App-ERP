import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/settings/presentation/controllers/change_password_controller.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _currentPwdCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmPwdCtrl = TextEditingController();

  @override
  void dispose() {
    _currentPwdCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmPwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(changePasswordControllerProvider);
    final notifier = ref.read(changePasswordControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Change Password',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        child: Column(
          children: <Widget>[
            // ── Form Card ──────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const _Label('Current Password'),
                  PrimaryTextField(
                    controller: _currentPwdCtrl,
                    hintText: 'Enter your current password',
                    obscureText: state.obscureCurrent,
                    suffixWidget: IconButton(
                      icon: Icon(
                        state.obscureCurrent
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: notifier.toggleObscureCurrent,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  const _Label('New Password'),
                  PrimaryTextField(
                    controller: _newPwdCtrl,
                    hintText: 'Enter your new password',
                    obscureText: state.obscureNew,
                    onChanged: notifier.setNewPassword,
                    suffixWidget: IconButton(
                      icon: Icon(
                        state.obscureNew
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: notifier.toggleObscureNew,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  const _Label('Confirm New Password'),
                  PrimaryTextField(
                    controller: _confirmPwdCtrl,
                    hintText: 'Re-enter your new password',
                    obscureText: state.obscureConfirm,
                    suffixWidget: IconButton(
                      icon: Icon(
                        state.obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: notifier.toggleObscureConfirm,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // ── Requirements Box ───────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.info.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.info_outline, color: AppColors.info, size: 20.sp),
                      SizedBox(width: 8.w),
                      Text(
                        'Password Requirements',
                        style: TextStyle(
                          color: AppColors.info,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _RequirementRow(
                    text: 'At least 8 characters',
                    isMet: state.hasMinLength,
                  ),
                  _RequirementRow(
                    text: 'One uppercase letter (A-Z)',
                    isMet: state.hasUppercase,
                  ),
                  _RequirementRow(
                    text: 'One lowercase letter (a-z)',
                    isMet: state.hasLowercase,
                  ),
                  _RequirementRow(
                    text: 'One number (0-9)',
                    isMet: state.hasNumber,
                  ),
                  _RequirementRow(
                    text: r'One special character (!@#$%^&*)',
                    isMet: state.hasSpecialChar,
                  ),
                ],
              ),
            ),
            SizedBox(height: 32.h),

            // ── Submit Button ──────────────────────────────────────────────
            PrimaryButton(
              label: 'Update Password',
              leadingIcon: Icons.check_circle_outline,
              isLoading: state.isLoading,
              size: ButtonSize.large,
              onPressed: () async {
                if (!state.isValid) {
                  SnackbarUtils.showError(
                    context,
                    'Please meet all password requirements first.',
                  );
                  return;
                }
                if (_newPwdCtrl.text != _confirmPwdCtrl.text) {
                  SnackbarUtils.showError(
                    context,
                    'New passwords do not match.',
                  );
                  return;
                }

                await notifier.submit();

                if (context.mounted) {
                  SnackbarUtils.showSuccess(
                    context,
                    'Password updated successfully!',
                  );
                  context.pop();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String text;
  final bool isMet;

  const _RequirementRow({required this.text, required this.isMet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: <Widget>[
          Icon(
            isMet ? Icons.check_circle : Icons.circle,
            color: isMet ? AppColors.success : AppColors.info,
            size: isMet ? 14.sp : 6.sp,
          ),
          SizedBox(width: 8.w),
          Text(
            text,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }
}
