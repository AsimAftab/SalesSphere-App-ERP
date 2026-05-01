import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/auth/auth_controller.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';
import 'package:sales_sphere_erp/shared/utils/error_messages.dart';
import 'package:sales_sphere_erp/shared/utils/snackbar_utils.dart';
import 'package:sales_sphere_erp/shared/utils/validators.dart';
import 'package:sales_sphere_erp/shared/widgets/custom_button.dart';
import 'package:sales_sphere_erp/shared/widgets/primary_text_field.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    // Hides the keyboard when the user presses Login
    FocusManager.instance.primaryFocus?.unfocus();

    await ref.read(authControllerProvider.notifier).login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthUser?>>(authControllerProvider, (previous, next) {
      if (next.hasError) {
        SnackbarUtils.showError(
          context,
          userMessageFor(next.error, fallback: 'Login failed. Please try again.'),
        );
      }
    });

    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.isLoading;

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
    final isExpanded = isKeyboardUp;
    final sheetHeight = isExpanded ? expandedSheetHeight : defaultSheetHeight;

    return LightStatusBar(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        // FIX: Added GestureDetector to dismiss keyboard when tapping the background
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E64A4), // Matched lighter gradient blue from image
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
                    child: _BrandHeader(),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: sheetHeight,
                  child: _BubbleSheet(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        left: 24.w,
                        right: 24.w,
                        top: 16.h,
                        bottom: 24.h + keyboardInset,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // The Handle bar at the top
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
                            SizedBox(height: 32.h),
                            PrimaryTextField(
                              controller: _emailController,
                              hintText: 'Email Address',
                              prefixIcon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                              validator: Validators.email,
                            ),
                            SizedBox(height: 16.h),
                            PrimaryTextField(
                              controller: _passwordController,
                              hintText: 'Password',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixWidget: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20.sp,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: isLoading
                                    ? null
                                    : () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
                                        ),
                              ),
                              textInputAction: TextInputAction.done,
                              enabled: !isLoading,
                              onFieldSubmitted: (_) => _submit(),
                              validator: Validators.password,
                            ),
                            SizedBox(height: 24.h),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => context.go(Routes.forgotPassword),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: const Color(0xFF1E88E5),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.sp,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: 24.h),
                            PrimaryButton(
                              label: 'Login',
                              onPressed: _submit,
                              isLoading: isLoading,
                              size: ButtonSize.large,
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
      ),
    );
  }

}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          top: -20.h,
          left: -40.w,
          child: Opacity(
            opacity: 0.15,
            child: SvgPicture.asset(
              'assets/images/left_bubble.svg',
              width: 160.w,
            ),
          ),
        ),
        Positioned(
          bottom: 20.h,
          right: -50.w,
          child: Opacity(
            opacity: 0.15,
            child: SvgPicture.asset(
              'assets/images/right_bubble.svg',
              width: 140.w,
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(height: 50.h),
            Image.asset(
              'assets/images/png/logo.png',
              width: 100.w,
              height: 100.h,
            ),
            SizedBox(height: 20.h),
            Text(
              'Sales\nSphere',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 38.sp,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              'Welcome Back!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BubbleSheet extends StatelessWidget {
  const _BubbleSheet({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30.r)),
      ),
      child: child,
    );
  }
}
