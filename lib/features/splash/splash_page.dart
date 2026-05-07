import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

/// Cold-start splash. Shares the navy gradient + bubble decorations with
/// `LoginPage` so the splash → login transition reads as one continuous
/// surface. Also sits beneath the OS biometric prompt during the
/// auto-unlock path — see `AuthController._attemptBiometricUnlock`.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
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
                      SizedBox(height: 64.h),
                      SizedBox(
                        width: 24.r,
                        height: 24.r,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    ],
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
