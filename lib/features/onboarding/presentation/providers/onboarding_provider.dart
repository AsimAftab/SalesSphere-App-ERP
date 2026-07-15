import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sales_sphere_erp/core/auth/auth_state.dart';
import 'package:sales_sphere_erp/core/providers/shared_prefs_provider.dart';
import 'package:sales_sphere_erp/core/router/app_router.dart';
import 'package:sales_sphere_erp/core/router/routes.dart';
import 'package:sales_sphere_erp/features/onboarding/domain/onboarding_slide.dart';

part 'onboarding_provider.g.dart';

@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  int build() => 0;

  static const List<OnboardingSlide> slides = <OnboardingSlide>[
    OnboardingSlide(
      title: 'Welcome to SalesSphere!',
      description:
          'Your complete platform to manage sales, track leads, and plan your day. This is your new all-in-one sales toolkit.',
      imagePath: 'assets/images/onboarding_welcome.svg',
      wavePath: 'assets/images/onboarding_first_page_wave.svg',
    ),
    OnboardingSlide(
      title: 'Follow Your Beat Plan',
      description:
          'Never miss a customer visit. Easily see your daily route, manage your meetings, and check in at every location.',
      imagePath: 'assets/images/onboarding_beat_plan.svg',
      wavePath: 'assets/images/onboarding_second_page_wave.svg',
    ),
    OnboardingSlide(
      title: 'Track Your Performance',
      description:
          'Effortlessly log attendance and manage all your sales orders. Monitor your progress and achieve your goals with ease.',
      imagePath: 'assets/images/onboarding_performance.svg',
      wavePath: 'assets/images/onboarding_third_page_wave.svg',
    ),
  ];

  // ignore: use_setters_to_change_properties -- Riverpod UI callback method
  void onPageChanged(int index) {
    state = index;
  }

  Future<void> completeOnboarding() async {
    final prefs = ref.read(sharedPrefsProvider);
    await prefs.setBool('hasSeenOnboarding', true);

    final router = ref.read(appRouterProvider);
    final authState = ref.read(authStateProvider);

    if (authState.status == AuthStatus.authenticated) {
      router.go(Routes.home);
    } else {
      router.go(Routes.login);
    }
  }
}
