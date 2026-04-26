// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refresh_response_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RefreshResponseDto _$RefreshResponseDtoFromJson(Map<String, dynamic> json) =>
    _RefreshResponseDto(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$RefreshResponseDtoToJson(_RefreshResponseDto instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'expiresAt': ?instance.expiresAt?.toIso8601String(),
    };
