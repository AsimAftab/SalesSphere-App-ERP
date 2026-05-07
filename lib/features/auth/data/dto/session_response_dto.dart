import 'package:freezed_annotation/freezed_annotation.dart';

part 'session_response_dto.freezed.dart';
part 'session_response_dto.g.dart';

/// Wire response for `GET /auth/session`. The backend uses this as a
/// lightweight access-token-validity check that also surfaces session
/// metadata (mobile login flag, expiry timestamps, server time).
@freezed
abstract class SessionResponseDto with _$SessionResponseDto {
  const factory SessionResponseDto({
    required bool valid,
    String? userId,
    String? sessionId,
    String? organizationId,
    String? systemRole,
    DateTime? accessTokenExpiresAt,
    DateTime? refreshTokenExpiresAt,
    DateTime? serverTime,
    @Default(false) bool mobileLoginAllowed,
  }) = _SessionResponseDto;

  factory SessionResponseDto.fromJson(Map<String, dynamic> json) =>
      _$SessionResponseDtoFromJson(json);
}
