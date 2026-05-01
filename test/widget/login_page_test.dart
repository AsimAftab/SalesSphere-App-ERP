import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/features/auth/auth_controller.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';
import 'package:sales_sphere_erp/features/auth/presentation/pages/login_page.dart';

class _StubAuthController extends AuthController {
  @override
  AsyncValue<AuthUser?> build() => const AsyncValue<AuthUser?>.data(null);

  @override
  Future<void> login({required String email, required String password}) async {
    state = const AsyncValue<AuthUser?>.loading();
  }
}

Widget _harness(Widget child) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_StubAuthController.new),
    ],
    child: ScreenUtilInit(
      designSize: const Size(360, 800),
      builder: (context, _) => MaterialApp(home: child),
    ),
  );
}

// The page is a portrait phone layout; the default 800x600 test viewport
// puts the submit button off-screen and breaks tap hit-testing.
void _usePortraitViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('LoginPage renders fields and submit button', (tester) async {
    _usePortraitViewport(tester);

    await tester.pumpWidget(_harness(const LoginPage()));
    await tester.pump();

    expect(find.text('Welcome Back!'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('LoginPage shows validation errors when fields are empty',
      (tester) async {
    _usePortraitViewport(tester);

    await tester.pumpWidget(_harness(const LoginPage()));
    await tester.pump();

    await tester.tap(find.text('Login'));
    // PrimaryTextField surfaces validator errors via a post-frame setState,
    // so we need a couple of pumps for the error text to land in the tree.
    await tester.pump();
    await tester.pump();

    // PrimaryTextField renders the error twice — once in the underlying
    // TextFormField (zero-sized) and once in its own custom display.
    expect(find.text('Email required'), findsAtLeastNWidgets(1));
    expect(find.text('Password required'), findsAtLeastNWidgets(1));
  });
}
