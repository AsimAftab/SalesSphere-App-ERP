import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sales_sphere_erp/core/constants/app_colors.dart';
import 'package:sales_sphere_erp/features/onboarding/presentation/providers/onboarding_provider.dart';
import 'package:sales_sphere_erp/features/onboarding/presentation/widgets/onboarding_slide_widget.dart';
import 'package:sales_sphere_erp/shared/widgets/status_bar_style.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  double _getWaveHeight(int currentPage) {
    switch (currentPage) {
      case 0:
        return 250.h;
      case 1:
        return 170.h;
      case 2:
        return 250.h;
      default:
        return 250.h;
    }
  }

  double _getHeaderHeight(int currentPage) {
    switch (currentPage) {
      case 0:
        return 160.h;
      case 1:
        return 40.h;
      case 2:
        return 160.h;
      default:
        return 160.h;
    }
  }

  void _onNextPressed(int currentPage, int totalSlides) {
    if (currentPage < totalSlides - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      ref.read(onboardingControllerProvider.notifier).completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(onboardingControllerProvider);
    const slides = OnboardingController.slides;
    final currentSlide = slides[currentPage];

    return LightStatusBar(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SvgPicture.asset(
                currentSlide.wavePath,
                fit: BoxFit.fill,
                width: MediaQuery.of(context).size.width,
                height: _getWaveHeight(currentPage),
              ),
            ),
            SafeArea(
              child: Column(
                children: <Widget>[
                  SizedBox(height: _getHeaderHeight(currentPage)),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: slides.length,
                      onPageChanged: (index) {
                        ref
                            .read(onboardingControllerProvider.notifier)
                            .onPageChanged(index);
                      },
                      itemBuilder: (context, index) {
                        return OnboardingSlideWidget(
                          slide: slides[index],
                          pageIndex: index,
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 20.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        SizedBox(
                          width: 50.w,
                          child: currentPage < slides.length - 1
                              ? TextButton(
                                  onPressed: () {
                                    ref
                                        .read(
                                          onboardingControllerProvider.notifier,
                                        )
                                        .completeOnboarding();
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Text(
                                    'Skip',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w500,
                                      fontFamily: 'Poppins',
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(slides.length, (index) {
                            final isActive = currentPage == index;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: EdgeInsets.symmetric(horizontal: 4.w),
                              width: isActive ? 28.w : 8.w,
                              height: 8.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4.r),
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.primary.withValues(alpha: 0.25),
                              ),
                            );
                          }),
                        ),
                        TextButton(
                          onPressed: () => _onNextPressed(
                            currentPage,
                            slides.length,
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: currentPage == slides.length - 1
                                  ? 16.w
                                  : 24.w,
                              vertical: 10.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                          ),
                          child: Text(
                            currentPage == slides.length - 1
                                ? 'Get Started'
                                : 'Next',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14.sp,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
