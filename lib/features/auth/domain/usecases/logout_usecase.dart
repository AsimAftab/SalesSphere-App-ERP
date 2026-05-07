import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:sales_sphere_erp/features/auth/domain/repositories/auth_repository.dart';

/// Signs the user out — clears tokens, drops cached user rows, and tells
/// the backend to revoke the session. Will later coalesce a sync flush
/// so any pending offline mutations don't carry forward into the next
/// session.
class LogoutUseCase {
  LogoutUseCase(this._repo);

  final AuthRepository _repo;

  Future<void> call() => _repo.logout();
}

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});
