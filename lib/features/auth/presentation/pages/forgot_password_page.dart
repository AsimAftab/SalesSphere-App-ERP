import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static const _formEstimateHeight = 385.0;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Email required';
    if (!_emailRegex.hasMatch(value)) return 'Enter a valid email';
    return null;
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    // Simulating API Call
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    await _showSuccessSheet(_emailController.text.trim());
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
    final defaultBrandHeight = screenHeight - defaultSheetHeight + 40;
    final expandedSheetHeight = (keyboardInset + _formEstimateHeight).clamp(
      defaultSheetHeight,
      screenHeight - mq.padding.top - 8,
    );
    final sheetHeight = isKeyboardUp ? expandedSheetHeight : defaultSheetHeight;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
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
                  top: mq.padding.top + 4,
                  left: 4,
                  child: IconButton(
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 24,
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
                    errorMessage: _errorMessage,
                    keyboardInset: keyboardInset,
                    onSubmit: _submit,
                    validateEmail: _validateEmail,
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
    // Dynamic centering ensures the illustration looks perfect on all screen sizes
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 40.0), // Pushes image up slightly from the sheet
        child: SvgPicture.asset(
          'assets/images/forgot_password.svg',
          height: MediaQuery.of(context).size.height * 0.25, // Scales beautifully
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
    required this.errorMessage,
    required this.keyboardInset,
    required this.onSubmit,
    required this.validateEmail,
    required this.onBackToLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isSubmitting;
  final String? errorMessage;
  final double keyboardInset;
  final VoidCallback onSubmit;
  final String? Function(String?) validateEmail;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: 32 + keyboardInset,
        ),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
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
              const SizedBox(height: 24),
              const Text(
                'Forgot Password?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Enter your email to receive a password reset link.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (errorMessage != null) ...<Widget>[
                _StatusBanner(
                  icon: Icons.error_outline,
                  message: errorMessage!,
                  iconColor: const Color(0xFFC62828),
                  textColor: const Color(0xFFB71C1C),
                  borderColor: const Color(0xFFE53935),
                  fillColor: const Color(0xFFFFEBEE),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: emailController,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                ),
                cursorColor: AppColors.secondary,
                decoration: _decoration(
                  hint: 'Email Address',
                  icon: Icons.mail_outline,
                ),
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !isSubmitting,
                onFieldSubmitted: (_) => onSubmit(),
                validator: validateEmail,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1A73E8),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                    const Color(0xFF1A73E8).withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12), // Smoother border
                    ),
                  ),
                  onPressed: isSubmitting ? null : onSubmit,
                  child: isSubmitting
                      ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                      : const Text(
                    'Send Reset Link',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // REPLACED TextButton with GestureDetector to guarantee styling works
              Center(
                child: GestureDetector(
                  onTap: onBackToLogin,
                  behavior: HitTestBehavior.opaque, // Expands touch target
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: Text.rich(
                      TextSpan(
                        text: 'Remember your password? ',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                        ),
                        children: <InlineSpan>[
                          TextSpan(
                            text: 'Login',
                            style: TextStyle(
                              color: AppColors.secondary,
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

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textHint, size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 16),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 16,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.secondary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
      ),
    );
  }
}
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.message,
    required this.iconColor,
    required this.textColor,
    required this.borderColor,
    required this.fillColor,
  });

  final IconData icon;
  final String message;
  final Color iconColor;
  final Color textColor;
  final Color borderColor;
  final Color fillColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: fillColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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

    return PopScope(
      canPop: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + viewInsets),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
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
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: AppColors.success.withValues(alpha: 0.15),
                child: const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.success,
                  child: Icon(
                    Icons.check,
                    size: 36,
                    color: AppColors.textWhite,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Request Submitted!',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'If that email is registered, a password reset token has been sent. Please check your inbox and spam folder.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1A73E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: onBackToLogin,
                child: const Text(
                  'Back to Login',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}