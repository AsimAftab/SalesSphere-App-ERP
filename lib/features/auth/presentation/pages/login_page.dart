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
  final _scrollController = ScrollController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Pins the form to the bottom of the space above the keyboard so the
  /// whole card — including the Log in button — clears it. With the keyboard
  /// closed the content is shorter than the viewport (maxScrollExtent == 0),
  /// so this leaves the resting layout untouched. The brand header slides up
  /// behind the card; that's intentional. `viewInsets` animates with the
  /// keyboard, so re-pinning each frame produces a smooth lift.
  void _pinFormAboveKeyboard(double keyboardInset) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = keyboardInset > 0
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      if ((_scrollController.offset - target).abs() > 0.5) {
        _scrollController.jumpTo(target);
      }
    });
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
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final keyboardInset = mediaQuery.viewInsets.bottom;
    final keyboardOpen = keyboardInset > 0;
    _pinFormAboveKeyboard(keyboardInset);

    return LightStatusBar(
      child: Scaffold(
        backgroundColor: AppColors.background,
        // The background gradient + bottom text stay rigid (they're
        // anchored to the full screen and ignore the keyboard inset). Only
        // the form layer below shrinks to the space above the keyboard so
        // the focused field can scroll into view.
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

              // Main Content — bounded to the area above the keyboard. When
              // the keyboard opens this layer shrinks and the form is pinned
              // to its bottom (see _pinFormAboveKeyboard) so the card lifts up
              // over the brand header and the Log in button clears the
              // keyboard. With the keyboard closed (inset 0) it fills the
              // screen and the content is too short to scroll.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: keyboardInset,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: 80.h),
                      // Fade the brand header out while the keyboard is open
                      // so it's hidden rather than sitting awkwardly pushed
                      // up above the card that lifts into focus. It fades
                      // back in when the keyboard closes.
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: keyboardOpen ? 0 : 1,
                        child: const _BrandHeader(),
                      ),
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
                                    fontWeight: FontWeight.w700,
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
                                // Biometric entry is temporarily disabled — a
                                // refreshed plan for the unlock UX is coming.
                                // When it returns, restore the Row + fingerprint
                                // icon button (see git history). For now the
                                // Log in CTA takes the full width.
                                PrimaryButton(
                                  label: 'Log in',
                                  onPressed: _submit,
                                  isLoading: isLoading,
                                  size: ButtonSize.large,
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
