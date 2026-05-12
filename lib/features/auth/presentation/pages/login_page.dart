import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';
import 'package:sales_sphere_erp/features/auth/presentation/controllers/auth_controller.dart';
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
    final screenHeight = MediaQuery.of(context).size.height;

    return LightStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        // Keeps the UI completely rigid when the keyboard opens
        resizeToAvoidBottomInset: false,
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Stack(
            children: <Widget>[
              // Curved Top Blue Gradient Background
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: screenHeight * 0.50,
                child: ClipPath(
                  clipper: _CurvedBottomClipper(),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          _loginGradientStart,
                          _loginGradientEnd,
                        ],
                      ),
                    ),
                    child: SizedBox.expand(),
                  ),
                ),
              ),

              // Main Content
              Positioned.fill(
                child: SingleChildScrollView(
                  // Completely disables scrolling at all times
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: 80.h),
                      const _BrandHeader(),
                      SizedBox(height: 30.h),
                      _CentralCard(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  'Welcome back',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  'Use your work email and password.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                SizedBox(height: 32.h),
                                PrimaryTextField(
                                  controller: _emailController,
                                  hintText: 'Email address',
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
                                    onPressed: isLoading
                                        ? null
                                        : () => setState(() => _obscurePassword = !_obscurePassword),
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      size: 20.sp,
                                    ),
                                    splashRadius: 20.r,
                                  ),
                                  textInputAction: TextInputAction.done,
                                  enabled: !isLoading,
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: Validators.password,
                                ),
                                SizedBox(height: 16.h),
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
                                      'Forgot password?',
                                      style: TextStyle(
                                        color: AppColors.secondary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 32.h),
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: PrimaryButton(
                                        label: 'Log in',
                                        onPressed: _submit,
                                        isLoading: isLoading,
                                        size: ButtonSize.large,
                                      ),
                                    ),
                                    SizedBox(width: 16.w),
                                    Container(
                                      width: 60.w,
                                      height: 60.h,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                        borderRadius: BorderRadius.circular(15.r),
                                      ),
                                      // Visual placeholder — biometric unlock is
                                      // wired in a follow-up. Keep the icon so
                                      // the login layout doesn't shift when the
                                      // handler lands.
                                      child: IconButton(
                                        onPressed: isLoading ? null : () {},
                                        icon: Icon(
                                          Icons.fingerprint,
                                          size: 32.sp,
                                          color: AppColors.secondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 60.h),
                    ],
                  ),
                ),
              ),

              // Bottom Text - Locked in place
              Positioned(
                bottom: 30.h,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    'Need an account? Ask SalesSphere Team.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14.sp,
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

class _CurvedBottomClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final controlPoint = Offset(size.width / 2, size.height + 20);
    final endPoint = Offset(size.width, size.height - 60);

    return Path()
      ..lineTo(0, size.height - 60)
      ..quadraticBezierTo(
        controlPoint.dx,
        controlPoint.dy,
        endPoint.dx,
        endPoint.dy,
      )
      ..lineTo(size.width, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Image.asset(
          'assets/images/png/logo.png',
          width: 90.w,
          height: 90.h,
        ),
        SizedBox(height: 12.h),
        Text(
          'SalesSphere',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 32.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _CentralCard extends StatelessWidget {
  const _CentralCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.r),
      ),
      color: AppColors.surface,
      child: child,
    );
  }
}

// Hero gradient on the auth screen. The blues sit between
// AppColors.primary (navy) and AppColors.secondary, so they don't
// reuse either cleanly — kept file-local to avoid polluting the
// shared palette with one-off tokens.
const _loginGradientStart = Color(0xFF1E64A4);
const _loginGradientEnd = Color(0xFF123E70);
