import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

void main() {
  testWidgets('LoginPage renders fields and submit button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_StubAuthController.new),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('LoginPage shows validation errors when fields are empty',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_StubAuthController.new),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );

    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Email required'), findsOneWidget);
    expect(find.text('Password required'), findsOneWidget);
  });
}
