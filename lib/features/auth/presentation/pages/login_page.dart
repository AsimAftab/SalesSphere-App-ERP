import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/auth/auth_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _formEstimateHeight = 375.0;

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

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email required';
    if (!_emailRegex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String _formatError(Object? err) {
    if (err == null) return 'Login failed. Please try again.';
    final s = err.toString();
    final lower = s.toLowerCase();
    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        lower.contains('invalid credentials')) {
      return 'Invalid email or password. Please try again.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('network') ||
        lower.contains('connection')) {
      return 'Connection error. Please check your internet.';
    }
    if (lower.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    final colonIdx = s.indexOf(': ');
    final msg = (colonIdx > 0 && colonIdx < 40) ? s.substring(colonIdx + 2) : s;
    return msg.length > 120 ? 'Login failed. Please try again.' : msg;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.isLoading;
    final hasError = auth.hasError;
    final errorMessage = hasError ? _formatError(auth.error) : null;

    final mq = MediaQuery.of(context);
    final screenHeight = mq.size.height;
    final keyboardInset = mq.viewInsets.bottom;
    final isKeyboardUp = keyboardInset > 0;

    final defaultSheetHeight = screenHeight * 0.45;
    final defaultBrandHeight = screenHeight - defaultSheetHeight + 40;
    final expandedSheetHeight = (keyboardInset + _formEstimateHeight).clamp(
      defaultSheetHeight,
      screenHeight - mq.padding.top - 8,
    );
    final isExpanded = isKeyboardUp;
    final sheetHeight = isExpanded ? expandedSheetHeight : defaultSheetHeight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
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
                        left: 24,
                        right: 24,
                        top: 16,
                        bottom: 24 + keyboardInset,
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
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.border,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            if (errorMessage != null) ...<Widget>[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  border: Border.all(
                                    color: const Color(0xFFE53935),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: <Widget>[
                                    const Icon(
                                      Icons.error_outline,
                                      color: Color(0xFFC62828),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorMessage,
                                        style: const TextStyle(
                                          color: Color(0xFFB71C1C),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            TextFormField(
                              controller: _emailController,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                              ),
                              cursorColor: AppColors.secondary,
                              decoration: _decoration(
                                hint: 'Email Address',
                                icon: Icons.mail_outline,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                              ),
                              cursorColor: AppColors.secondary,
                              decoration: _decoration(
                                hint: 'Password',
                                icon: Icons.lock_outline,
                                suffix: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                  onPressed: isLoading
                                      ? null
                                      : () => setState(
                                        () => _obscurePassword =
                                    !_obscurePassword,
                                  ),
                                ),
                              ),
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              enabled: !isLoading,
                              onFieldSubmitted: (_) => _submit(),
                              validator: _validatePassword,
                            ),
                            const SizedBox(height: 24),
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
                                child: const Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    color: Color(0xFF1E88E5),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 52,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A73E8), // Matched blue button
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: isLoading ? null : _submit,
                                child: isLoading
                                    ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                                    : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
      ),
    );
  }

  InputDecoration _decoration({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.secondary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE53935)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
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
          top: -20,
          left: -40,
          child: Opacity(
            opacity: 0.15,
            child: SvgPicture.asset(
              'assets/images/left_bubble.svg',
              width: 160,
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          right: -50,
          child: Opacity(
            opacity: 0.15,
            child: SvgPicture.asset(
              'assets/images/right_bubble.svg',
              width: 140,
            ),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center, // Centered to match the image spacing
          children: <Widget>[
            const SizedBox(height: 50),
            Image.asset(
              'assets/images/png/logo.png',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 20),
            const Text(
              'Sales\nSphere',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 38,
                fontWeight: FontWeight.w800, // Heavier weight to match image
                height: 1.15,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Welcome Back!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)), // Smoothed corner radius
      ),
      child: child,
    );
  }
}