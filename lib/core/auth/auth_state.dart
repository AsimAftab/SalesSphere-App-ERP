import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AuthStatus { unknown, unauthenticated, authenticated, awaitingBiometric }

class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.error,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.unauthenticated({String? error})
      : this(status: AuthStatus.unauthenticated, error: error);
  const AuthState.awaitingBiometric()
      : this(status: AuthStatus.awaitingBiometric);
  const AuthState.authenticated({required String userId})
      : this(status: AuthStatus.authenticated, userId: userId);

  final AuthStatus status;
  final String? userId;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get isResolved => status != AuthStatus.unknown;
}

/// Stub notifier — replaced by AuthController in lib/features/auth.
/// Exposes the slot the router watches; defaults to "unknown" so the
/// splash/loading state shows until the controller resolves it.
class AuthStateNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => const AuthState.unknown();

  void set(AuthState next) => state = next;
}

final authStateProvider =
    NotifierProvider<AuthStateNotifier, AuthState>(AuthStateNotifier.new);
