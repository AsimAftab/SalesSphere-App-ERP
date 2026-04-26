import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_sphere_erp/core/auth/auth_state.dart';

void main() {
  group('AuthState transitions', () {
    test('starts unknown', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(authStateProvider).status, AuthStatus.unknown);
      expect(container.read(authStateProvider).isResolved, isFalse);
    });

    test('set() transitions through unauthenticated → authenticated', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(authStateProvider.notifier)
          .set(const AuthState.unauthenticated());
      expect(container.read(authStateProvider).status,
          AuthStatus.unauthenticated);

      container
          .read(authStateProvider.notifier)
          .set(const AuthState.authenticated(userId: 'u1'));
      final auth = container.read(authStateProvider);
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.userId, 'u1');
      expect(auth.isAuthenticated, isTrue);
    });
  });
}
