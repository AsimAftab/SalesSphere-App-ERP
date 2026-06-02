import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/profile/data/dto/profile_dto.dart';

class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  Future<ProfileResponseDto> me() async {
    final response = await _dio.get<Map<String, dynamic>>(Endpoints.me);
    return ProfileResponseDto.fromJson(_unwrap(response.data));
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Profile API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final profileApiProvider = Provider<ProfileApi>(
  (ref) => ProfileApi(ref.watch(dioProvider)),
);
