import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/auth/data/dto/auth_user_dto.dart';
import 'package:sales_sphere_erp/features/auth/data/dto/login_request_dto.dart';
import 'package:sales_sphere_erp/features/auth/data/dto/login_response_dto.dart';
import 'package:sales_sphere_erp/features/auth/data/dto/refresh_response_dto.dart';

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
    return LoginResponseDto.fromJson(response.data!);
  }

  Future<RefreshResponseDto> refresh(String refreshToken) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.refresh,
      data: <String, String>{'refreshToken': refreshToken},
    );
    return RefreshResponseDto.fromJson(response.data!);
  }

  Future<AuthUserDto> me() async {
    final response = await _dio.get<Map<String, dynamic>>(Endpoints.me);
    return AuthUserDto.fromJson(response.data!);
  }

  Future<void> logout() async {
    await _dio.post<void>(Endpoints.logout);
  }
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider)),
);
