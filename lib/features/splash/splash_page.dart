import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Cold-start splash. Shares the navy gradient + bubble decorations with
/// `LoginPage` so the splash → login transition reads as one continuous
/// surface. Also sits beneath the OS biometric prompt during the
/// auto-unlock path — see `AuthController._attemptBiometricUnlock`.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _logoScale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0, 0.7, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );

    _revealController.forward();
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LightStatusBar(
      child: Scaffold(
        body: Container(
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
                top: -20.h,
                left: -40.w,
                child: Opacity(
                  opacity: 0.15,
                  child: SvgPicture.asset(
                    'assets/images/left_bubble.svg',
                    width: 200.w,
                  ),
                ),
              ),
              Positioned(
                bottom: -20.h,
                right: -50.w,
                child: Opacity(
                  opacity: 0.15,
                  child: SvgPicture.asset(
                    'assets/images/right_bubble.svg',
                    width: 180.w,
                  ),
                ),
              ),
              SafeArea(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _revealController,
                    builder: (context, child) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: Image.asset(
                                'assets/images/png/logo.png',
                                width: 100.w,
                                height: 100.h,
                              ),
                            ),
                          ),
                          SizedBox(height: 20.h),
                          Opacity(
                            opacity: _textOpacity.value,
                            child: SlideTransition(
                              position: _textSlide,
                              child: Text(
                                'Sales\nSphere',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 38.sp,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                bottom: 48.h,
                left: 0,
                right: 0,
                child: const _AnimatedDotsLoader(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedDotsLoader extends StatefulWidget {
  const _AnimatedDotsLoader();

  @override
  State<_AnimatedDotsLoader> createState() => _AnimatedDotsLoaderState();
}

class _AnimatedDotsLoaderState extends State<_AnimatedDotsLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final delay = index * 0.2;

            final opacityAnimation = Tween<double>(begin: 0.3, end: 1).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  delay,
                  (delay + 0.4).clamp(0, 1),
                  curve: Curves.easeInOut,
                ),
              ),
            );

            final scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
              CurvedAnimation(
                parent: _controller,
                curve: Interval(
                  delay,
                  (delay + 0.4).clamp(0, 1),
                  curve: Curves.easeInOut,
                ),
              ),
            );

            return Transform.scale(
              scale: scaleAnimation.value,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 5.w),
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: opacityAnimation.value,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
