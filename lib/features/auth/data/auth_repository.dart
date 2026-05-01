import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/interceptors/auth_interceptor.dart';
import 'package:sales_sphere_erp/core/auth/token_storage.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/daos/users_dao.dart';
import 'package:sales_sphere_erp/core/exceptions/api_exception.dart';
import 'package:sales_sphere_erp/features/auth/data/auth_api.dart';
import 'package:sales_sphere_erp/features/auth/data/dto/auth_user_dto.dart';
import 'package:sales_sphere_erp/features/auth/data/dto/login_request_dto.dart';
import 'package:sales_sphere_erp/features/auth/domain/auth_user.dart';

/// Anti-corruption layer between the wire DTOs and the rest of the app.
/// All DTO → domain mapping happens here, plus drift persistence.
class AuthRepository {
  AuthRepository({
    required AuthApi api,
    required TokenStorage tokens,
    required UsersDao users,
  })  : _api = api,
        _tokens = tokens,
        _users = users;

  final AuthApi _api;
  final TokenStorage _tokens;
  final UsersDao _users;

  Future<AuthUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final dto = await _api.login(
        LoginRequestDto(email: email, password: password),
      );
      await _tokens.save(
        accessToken: dto.accessToken,
        refreshToken: dto.refreshToken,
        expiresAt: dto.expiresAt,
      );
      final user = _toDomain(dto.user);
      await _persist(user);
      return user;
    } on DioException catch (e) {
      // The error interceptor stashes a typed [ApiException] in DioException.error.
      // Unwrap it so the rest of the app never sees raw dio errors, and convert
      // a login-time 401 into the more specific [BadCredentialsException] so the
      // UI can distinguish it from a session-expired 401.
      final mapped = e.error;
      if (mapped is UnauthorizedException) {
        throw const BadCredentialsException();
      }
      if (mapped is ApiException) throw mapped;
      rethrow;
    }
  }

  /// Re-fetches the authenticated user. Used after biometric unlock or app
  /// foregrounding to confirm the session is still valid.
  Future<AuthUser> me() async {
    final dto = await _api.me();
    final user = _toDomain(dto);
    await _persist(user);
    return user;
  }

  Future<TokenPair?> refreshTokens(String refreshToken) async {
    try {
      final dto = await _api.refresh(refreshToken);
      return TokenPair(
        accessToken: dto.accessToken,
        refreshToken: dto.refreshToken,
        expiresAt: dto.expiresAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // best-effort — local clear happens regardless
    }
    await _tokens.clear();
    await _users.deleteAll();
  }

  Future<AuthUser?> cachedUser() async {
    final rows = await _users.findById(await _firstStoredUserId() ?? '');
    if (rows == null) return null;
    return AuthUser(
      id: rows.id,
      email: rows.email,
      fullName: rows.fullName,
      phone: rows.phone,
      organizationId: rows.organizationId,
      roleId: rows.roleId,
      avatarUrl: rows.avatarUrl,
    );
  }

  Future<bool> hasSession() => _tokens.hasSession();

  // ── private ────────────────────────────────────────────────────────────────

  AuthUser _toDomain(AuthUserDto dto) {
    return AuthUser(
      id: dto.id,
      email: dto.email,
      fullName: dto.fullName,
      phone: dto.phone,
      organizationId: dto.organizationId,
      roleId: dto.roleId,
      avatarUrl: dto.avatarUrl,
    );
  }

  Future<void> _persist(AuthUser user) async {
    await _users.upsert(
      UsersCompanion(
        id: Value(user.id),
        email: Value(user.email),
        fullName: Value(user.fullName),
        phone: Value(user.phone),
        organizationId: Value(user.organizationId),
        roleId: Value(user.roleId),
        avatarUrl: Value(user.avatarUrl),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<String?> _firstStoredUserId() async {
    final all = await (_users.select(_users.attachedDatabase.users)
          ..limit(1))
        .get();
    return all.isEmpty ? null : all.first.id;
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(authApiProvider),
    tokens: ref.watch(tokenStorageProvider),
    users: ref.watch(usersDaoProvider),
  );
});
