import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/core/api/interceptors/auth_interceptor.dart';
import 'package:sales_sphere_erp/core/auth/auth_state.dart';
import 'package:sales_sphere_erp/core/auth/biometric_service.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';
import 'package:sales_sphere_erp/features/auth/domain/usecases/login_usecase.dart';
import 'package:sales_sphere_erp/features/auth/domain/usecases/logout_usecase.dart';
import 'package:sales_sphere_erp/features/auth/domain/usecases/refresh_session_usecase.dart';
import 'package:sales_sphere_erp/features/auth/domain/usecases/refresh_tokens_usecase.dart';
import 'package:sales_sphere_erp/features/auth/domain/usecases/restore_session_usecase.dart';

/// Owns the auth lifecycle. Drives the router-visible [authStateProvider]
/// and the dio interceptor's refresh handler. Depends only on use cases.
class AuthController extends Notifier<AsyncValue<AuthUser?>> {
  late LoginUseCase _login;
  late LogoutUseCase _logout;
  late RefreshSessionUseCase _refreshSession;
  late RefreshTokensUseCase _refreshTokens;
  late RestoreSessionUseCase _restoreSession;
  late BiometricService _biometric;

  @override
  AsyncValue<AuthUser?> build() {
    _login = ref.read(loginUseCaseProvider);
    _logout = ref.read(logoutUseCaseProvider);
    _refreshSession = ref.read(refreshSessionUseCaseProvider);
    _refreshTokens = ref.read(refreshTokensUseCaseProvider);
    _restoreSession = ref.read(restoreSessionUseCaseProvider);
    _biometric = ref.read(biometricServiceProvider);

    // Wire the dio refresh handler + failure sink to this controller.
    ref.read(tokenRefreshHandlerProvider);
    ref.read(tokenRefreshFailureSinkProvider);

    Future.microtask(_resolveStartup);
    return const AsyncValue<AuthUser?>.loading();
  }

  // ── Startup flow ───────────────────────────────────────────────────────────
  Future<void> _resolveStartup() async {
    final result = await _restoreSession();
    switch (result) {
      case RestoreSessionUnauthenticated():
        _emit(const AuthState.unauthenticated(), null);
      case RestoreSessionBiometric(:final cachedUser):
        await _attemptBiometricUnlock(cachedUser);
      case RestoreSessionAuthenticated(:final user):
        _emit(AuthState.authenticated(userId: user.id), user);
    }
  }

  /// Cold-start path when a cached session + biometric hardware are
  /// available. Triggers the OS biometric prompt directly — there is no
  /// custom Flutter page in between. On cancel/fail, falls through to
  /// the unauthenticated state and the router redirects to /login.
  ///
  /// On biometric success, we already know the session is valid (the
  /// upstream `RestoreSessionUseCase` validated it via `/auth/session`).
  /// `/auth/me` is best-effort here — a 404, shape mismatch, network
  /// blip, or any other failure isn't a reason to throw the user back to
  /// /login. Fall back to the cached user so the home shell renders with
  /// what we already have.
  Future<void> _attemptBiometricUnlock(AuthUser cachedUser) async {
    final ok = await _biometric.authenticate(
      localizedReason: 'Unlock SalesSphere',
    );
    if (!ok) {
      _emit(const AuthState.unauthenticated(), null);
      return;
    }
    AuthUser user;
    try {
      user = await _refreshSession();
    } catch (_) {
      user = cachedUser;
    }
    _emit(AuthState.authenticated(userId: user.id), user);
  }

  // ── Public actions ────────────────────────────────────────────────────────

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue<AuthUser?>.loading();
    try {
      final user = await _login(email: email, password: password);
      _emit(AuthState.authenticated(userId: user.id), user);
    } catch (e, st) {
      state = AsyncValue<AuthUser?>.error(e, st);
      ref
          .read(authStateProvider.notifier)
          .set(AuthState.unauthenticated(error: e.toString()));
    }
  }

  Future<void> logout() async {
    await _logout();
    _emit(const AuthState.unauthenticated(), null);
  }

  // ── Refresh handler hook (for AuthInterceptor) ────────────────────────────
  Future<TokenPair?> _refreshHandler(String refreshToken) =>
      _refreshTokens(refreshToken);

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
/// resolves to a function that delegates to the live AuthController
/// (which in turn calls [RefreshTokensUseCase]). Apply this override at
/// the ProviderScope root in `bootstrap()`.
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
