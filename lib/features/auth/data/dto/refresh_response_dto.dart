import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:sales_sphere_erp/features/auth/data/dto/tokens_dto.dart';

part 'refresh_response_dto.freezed.dart';
part 'refresh_response_dto.g.dart';

@freezed
abstract class RefreshResponseDto with _$RefreshResponseDto {
  const factory RefreshResponseDto({
    required TokensDto tokens,
  }) = _RefreshResponseDto;

  factory RefreshResponseDto.fromJson(Map<String, dynamic> json) =>
      _$RefreshResponseDtoFromJson(json);
}
