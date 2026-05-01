import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSubmitting = true);

    try {
      // Simulated API call — replace with the real reset-code endpoint.
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await _showSuccessSheet(_emailController.text.trim());
    } on Exception {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      SnackbarUtils.showError(
        context,
        'Could not send the reset link. Please try again.',
      );
    }
  }

  Future<void> _showSuccessSheet(String email) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _SuccessSheet(
        email: email,
        onBackToLogin: () {
          Navigator.of(sheetContext).pop();
          _backToLogin();
        },
      ),
    );
  }

  void _backToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height;
    final keyboardInset = mq.viewInsets.bottom;
    final isKeyboardUp = keyboardInset > 0;

    final defaultSheetHeight = screenHeight * 0.45;
    final defaultBrandHeight = screenHeight - defaultSheetHeight + 40.h;
    final formEstimateHeight = 375.h;
    final expandedSheetHeight = (keyboardInset + formEstimateHeight).clamp(
      defaultSheetHeight,
      screenHeight - mq.padding.top - 8.h,
    );
    final sheetHeight = isKeyboardUp ? expandedSheetHeight : defaultSheetHeight;

    return LightStatusBar(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF1E64A4),
                  Color(0xFF123E70),
                ],
              ),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: defaultBrandHeight,
                  child: const SafeArea(
                    bottom: false,
                    child: _ForgotPasswordHeader(),
                  ),
                ),
                Positioned(
                  top: mq.padding.top + 4.h,
                  left: 4.w,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                    onPressed: _backToLogin,
                    tooltip: 'Back',
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: sheetHeight,
                  child: _ForgotPasswordSheet(
                    formKey: _formKey,
                    emailController: _emailController,
                    isSubmitting: _isSubmitting,
                    keyboardInset: keyboardInset,
                    onSubmit: _submit,
                    onBackToLogin: _backToLogin,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordHeader extends StatelessWidget {
  const _ForgotPasswordHeader();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(bottom: 40.h),
        child: SvgPicture.asset(
          'assets/images/forgot_password.svg',
          width: MediaQuery.of(context).size.width * 0.85,
        ),
      ),
    );
  }
}

class _ForgotPasswordSheet extends StatelessWidget {
  const _ForgotPasswordSheet({
    required this.formKey,
    required this.emailController,
    required this.isSubmitting,
    required this.keyboardInset,
    required this.onSubmit,
    required this.onBackToLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isSubmitting;
  final double keyboardInset;
  final VoidCallback onSubmit;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          left: 24.w,
          right: 24.w,
          top: 16.h,
          bottom: 40.h + keyboardInset,
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'Forgot Password?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 12.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Text(
                  'Enter your email address to receive a password reset link.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15.sp,
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: 28.h),
              PrimaryTextField(
                controller: emailController,
                hintText: 'Email Address',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                enabled: !isSubmitting,
                onFieldSubmitted: (_) => onSubmit(),
                validator: Validators.email,
              ),
              SizedBox(height: 24.h),
              PrimaryButton(
                label: 'Send Reset Link',
                onPressed: onSubmit,
                isLoading: isSubmitting,
                size: ButtonSize.large,
              ),
              SizedBox(height: 12.h),
              Center(
                child: GestureDetector(
                  onTap: onBackToLogin,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 8.h,
                      horizontal: 16.w,
                    ),
                    child: Text.rich(
                      TextSpan(
                        text: 'Remember your password? ',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15.sp,
                        ),
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'Login',
                            style: TextStyle(
                              color: AppColors.secondary,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.secondary,
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
      ),
    );
  }
}

class _SuccessSheet extends StatelessWidget {
  const _SuccessSheet({required this.email, required this.onBackToLogin});

  final String email;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final viewInsets = mq.viewInsets.bottom;
    final sheetHeight = mq.size.height * 0.45;

    return PopScope(
      canPop: false,
      child: Container(
        width: double.infinity,
        height: sheetHeight + viewInsets,
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 24.h + viewInsets),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10.r),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  CircleAvatar(
                    radius: 40.r,
                    backgroundColor: AppColors.success.withValues(alpha: 0.15),
                    child: CircleAvatar(
                      radius: 28.r,
                      backgroundColor: AppColors.success,
                      child: Icon(
                        Icons.check,
                        size: 36.sp,
                        color: AppColors.textWhite,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Request Submitted!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Text(
                      'If that email is registered, a password reset link has been sent. Please check your inbox and spam folder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15.sp,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PrimaryButton(
              label: 'Back to Login',
              onPressed: onBackToLogin,
              size: ButtonSize.large,
            ),
          ],
        ),
      ),
    );
  }
}
