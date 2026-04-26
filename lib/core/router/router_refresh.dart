import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/auth/auth_state.dart';

/// Adapts the Riverpod auth state into a [Listenable] that GoRouter's
/// `refreshListenable` understands. Whenever auth state changes, the router
/// re-evaluates redirects.
class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(
      authStateProvider,
      (_, __) => notifyListeners(),
      fireImmediately: false,
    );
  }
}
