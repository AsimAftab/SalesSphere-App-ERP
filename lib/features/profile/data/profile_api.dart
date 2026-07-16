import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/profile/data/dto/profile_dto.dart';

class ProfileApi {
  ProfileApi(this._dio);

  final Dio _dio;

  Future<ProfileResponseDto> me() async {
    final response = await _dio.get<Map<String, dynamic>>(Endpoints.me);
    return ProfileResponseDto.fromJson(_unwrap(response.data));
  }

  /// `PATCH /employees/me/avatar` — multipart avatar-only self-service
  /// update: just the `avatar` file part, no body fields. (The broader
  /// `PATCH /employees/me` can't be used here — its `ProfileUpdateBody`
  /// requires address/phone/dob/gender on every call, which a file-only
  /// change can't satisfy.) The server accepts JPEG/PNG up to 5 MB and
  /// responds with the updated employee row, from which we only need the
  /// fresh Cloudinary `avatarUrl`.
  ///
  /// Same two upload traps as the other image endpoints: the `Content-Type`
  /// of the file part must be set from the extension (otherwise
  /// `MultipartFile.fromFile` ships `application/octet-stream` and Cloudinary
  /// rejects the blob), and the request-level content type must be
  /// `multipart/form-data`.
  Future<String?> updateAvatar(String filePath) async {
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    final form = FormData.fromMap(<String, dynamic>{
      'avatar': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: _mediaTypeForFilename(filename),
      ),
    });
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.employeesMeAvatar,
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return _unwrap(response.data)['avatarUrl'] as String?;
  }

  MediaType _mediaTypeForFilename(String filename) {
    final dotIdx = filename.lastIndexOf('.');
    final ext = dotIdx >= 0 ? filename.substring(dotIdx + 1).toLowerCase() : '';
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      default:
        // The server only accepts JPEG / PNG — let its mime filter reject
        // anything else explicitly (415) rather than guessing here.
        return MediaType('application', 'octet-stream');
    }
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
