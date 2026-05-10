import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/auth/data/dto/auth_user_dto.dart';
import 'package:sales_sphere_erp/features/auth/data/dto/login_request_dto.dart';
import 'package:sales_sphere_erp/features/auth/data/dto/login_response_dto.dart';
import 'package:sales_sphere_erp/features/auth/data/dto/refresh_response_dto.dart';
import 'package:sales_sphere_erp/features/auth/data/dto/session_response_dto.dart';

/// Raw HTTP calls for the auth endpoints. Knows nothing about drift, secure
/// storage, or domain models — the repository wires those in.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<LoginResponseDto> login(LoginRequestDto req) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.login,
      data: req.toJson(),
    );
    return LoginResponseDto.fromJson(_unwrap(response.data));
  }

  Future<RefreshResponseDto> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.refresh,
      data: <String, String>{'refreshToken': refreshToken},
    );
    return RefreshResponseDto.fromJson(_unwrap(response.data));
  }

  Future<AuthUserDto> me() async {
    final response = await _dio.get<Map<String, dynamic>>(Endpoints.me);
    return AuthUserDto.fromJson(_unwrap(response.data));
  }

  /// Lightweight access-token validity check. The auth interceptor handles
  /// 401-triggered refresh transparently — a thrown `DioException(401)` here
  /// means both access AND refresh tokens are dead.
  Future<SessionResponseDto> session() async {
    final response = await _dio.get<Map<String, dynamic>>(Endpoints.session);
    return SessionResponseDto.fromJson(_unwrap(response.data));
  }

  Future<void> logout() async {
    await _dio.post<void>(Endpoints.logout);
  }

  // The backend wraps every payload in `{ success, data: {...} }`. Peel the
  // envelope here so DTOs stay focused on the inner shape. Failures
  // surface as `FormatException` instead of silently falling through to
  // the raw body, which previously masked contract violations behind
  // confusing DTO parse errors.
  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Auth API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed auth envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider)),
);
