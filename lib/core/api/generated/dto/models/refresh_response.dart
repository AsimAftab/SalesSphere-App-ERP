// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, unused_import, invalid_annotation_target, unnecessary_import

import 'package:freezed_annotation/freezed_annotation.dart';

part 'refresh_response.freezed.dart';
part 'refresh_response.g.dart';

@Freezed()
class RefreshResponse with _$RefreshResponse {
  const factory RefreshResponse({
    required String accessToken,
    required String refreshToken,
    DateTime? expiresAt,
  }) = _RefreshResponse;
  
  factory RefreshResponse.fromJson(Map<String, Object?> json) => _$RefreshResponseFromJson(json);
}
