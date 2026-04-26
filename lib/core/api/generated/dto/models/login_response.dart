// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

import 'auth_user.dart';

part 'login_response.freezed.dart';
part 'login_response.g.dart';

@Freezed()
class LoginResponse with _$LoginResponse {
  const factory LoginResponse({
    required String accessToken,
    required String refreshToken,
    required AuthUser user,
    DateTime? expiresAt,
  }) = _LoginResponse;
  
  factory LoginResponse.fromJson(Map<String, Object?> json) => _$LoginResponseFromJson(json);
}
