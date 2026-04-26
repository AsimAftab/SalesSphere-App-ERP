import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/core/api/interceptors/auth_interceptor.dart';
import 'package:sales_sphere_erp/core/auth/auth_state.dart';
import 'package:sales_sphere_erp/core/auth/biometric_service.dart';
import 'package:sales_sphere_erp/features/auth/data/auth_repository.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';

/// Owns the auth lifecycle. Drives the router-visible [authStateProvider]
/// and the dio interceptor's refresh handler.
class AuthController extends Notifier<AsyncValue<AuthUser?>> {
  late AuthRepository _repo;
  late BiometricService _biometric;

  @override
  AsyncValue<AuthUser?> build() {
    _repo = ref.read(authRepositoryProvider);
    _biometric = ref.read(biometricServiceProvider);

    // Wire the dio refresh handler + failure sink to this controller.
    ref.read(tokenRefreshHandlerProvider);
    ref.read(tokenRefreshFailureSinkProvider);

    Future.microtask(_resolveStartup);
    return const AsyncValue<AuthUser?>.loading();
  }

  // ── Startup flow ───────────────────────────────────────────────────────────
  Future<void> _resolveStartup() async {
    final hasSession = await _repo.hasSession();
    if (!hasSession) {
      _emit(const AuthState.unauthenticated(), null);
      return;
    }

    final cached = await _repo.cachedUser();
    if (cached != null && await _biometric.isAvailable) {
      _emit(const AuthState.awaitingBiometric(), cached);
      return;
    }

    // Either no biometric available or no cached user — try a /me ping.
    try {
      final user = await _repo.me();
      _emit(AuthState.authenticated(userId: user.id), user);
    } catch (_) {
      _emit(const AuthState.unauthenticated(), null);
    }
  }

  // ── Public actions ────────────────────────────────────────────────────────

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue<AuthUser?>.loading();
    try {
      final user = await _repo.login(email: email, password: password);
      _emit(AuthState.authenticated(userId: user.id), user);
    } catch (e, st) {
      state = AsyncValue<AuthUser?>.error(e, st);
      ref
          .read(authStateProvider.notifier)
          .set(AuthState.unauthenticated(error: e.toString()));
    }
  }

  Future<void> unlockWithBiometrics() async {
    final ok = await _biometric.authenticate(
      localizedReason: 'Unlock SalesSphere',
    );
    if (!ok) return;
    try {
      final user = await _repo.me();
      _emit(AuthState.authenticated(userId: user.id), user);
    } catch (e, st) {
      state = AsyncValue<AuthUser?>.error(e, st);
      ref.read(authStateProvider.notifier).set(const AuthState.unauthenticated());
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    _emit(const AuthState.unauthenticated(), null);
  }

  // ── Refresh handler hook (for AuthInterceptor) ────────────────────────────
  Future<TokenPair?> _refreshHandler(String refreshToken) {
    return _repo.refreshTokens(refreshToken);
  }

  void _onRefreshFailed() {
    _emit(const AuthState.unauthenticated(), null);
  }

  // ── Internal ──────────────────────────────────────────────────────────────
  void _emit(AuthState routerState, AuthUser? user) {
    ref.read(authStateProvider.notifier).set(routerState);
    state = AsyncValue<AuthUser?>.data(user);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<AuthUser?>>(
  AuthController.new,
);

/// Provider override so `dioProvider`'s `tokenRefreshHandlerProvider`
/// resolves to a function that delegates to the live AuthController.
/// Apply this override at the ProviderScope root in `bootstrap()`.
final authProviderOverrides = [
  tokenRefreshHandlerProvider.overrideWith(
    (ref) => (refreshToken) =>
        ref.read(authControllerProvider.notifier)._refreshHandler(refreshToken),
  ),
  tokenRefreshFailureSinkProvider.overrideWith(
    (ref) => () =>
        ref.read(authControllerProvider.notifier)._onRefreshFailed(),
  ),
];
