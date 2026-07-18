import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';

import 'package:sales_sphere_erp/core/api/dio_client.dart';
import 'package:sales_sphere_erp/features/notes/data/dto/note_dto.dart';
import 'package:sales_sphere_erp/features/notes/data/dto/note_image_ref.dart';
import 'package:sales_sphere_erp/features/notes/data/dto/notes_page_dto.dart';

/// Wire value for the `relatedTo` query parameter. Server narrows the
/// list to notes with the matching FK populated.
enum NotesRelatedTo { customer, prospect, site }

/// HTTP layer for the notes feature. The list + create + image-upload
/// paths hit the real backend; `update` is still in-memory until
/// `PATCH /notes/{id}` ships.
class NotesApi {
  NotesApi(this._dio);

  final Dio _dio;

  /// Fetch one paginated page from `GET /notes`.
  ///
  /// The server is authoritative on pagination — the inner envelope
  /// carries `items`, `hasMore`, and `nextCursor`. We trust
  /// `nextCursor` when `hasMore` is true and clear it otherwise.
  Future<NotesPageDto> list({
    int limit = 10,
    String? cursor,
    NotesRelatedTo? relatedTo,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.notes,
      queryParameters: <String, dynamic>{
        'limit': limit,
        if (cursor != null) 'cursor': cursor,
        if (relatedTo != null) 'relatedTo': relatedTo.name,
      },
    );
    final data = _unwrapMap(response.data);
    final rawItems = data['items'];
    if (rawItems is! List<dynamic>) {
      throw const FormatException(
        'Malformed notes page: missing or invalid `items` array',
      );
    }
    final items = rawItems
        .map((j) => NoteDto.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
    final hasMore = (data['hasMore'] as bool?) ?? false;
    final nextCursor = hasMore ? data['nextCursor'] as String? : null;
    return NotesPageDto(items: items, nextCursor: nextCursor);
  }

  /// `POST /notes`. Body is the writable subset produced by
  /// `NoteDto.toJson()` — server assigns `id`, `createdAt`,
  /// `createdById`, etc. The `customerId` / `prospectId` / `siteId`
  /// XOR is enforced by `toJson` only emitting the non-null one.
  Future<NoteDto> create(NoteDto draft) async {
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.notes,
      data: draft.toJson(),
    );
    return NoteDto.fromJson(_unwrapMap(response.data));
  }

  /// `PATCH /notes/{id}`. Same writable shape as `create`; the server
  /// treats an explicit `null` as a clear (relevant for the inactive
  /// link-id fields when the user re-links the note).
  Future<NoteDto> update(NoteDto note) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      Endpoints.noteById(note.id),
      data: note.toJson(),
    );
    return NoteDto.fromJson(_unwrapMap(response.data));
  }

  /// `GET /notes/{id}/images`. Returns the note's gallery, ordered by
  /// `sortOrder` ascending. Returns `[]` if the response shape is
  /// unexpected so the edit page can still render.
  Future<List<NoteImageRef>> listImages(String noteId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      Endpoints.noteImages(noteId),
    );
    final body = response.data;
    if (body == null || body['success'] == false) return const [];
    final data = body['data'];
    if (data is! List<dynamic>) return const [];
    return data
        .map((j) => NoteImageRef.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// `POST /notes/{id}/images` — multipart `image` file +
  /// `imageNumber` form field. Slot-based upsert: re-posting the same
  /// slot replaces the existing image.
  ///
  /// Same two non-obvious details as the parties / sites variants:
  ///   * `imageNumber` is added **before** the file. Multer streams
  ///     parts in order and populates `req.body` text fields as it
  ///     goes — text after a file part can be left unread.
  ///   * The file's `Content-Type` is set explicitly from the
  ///     extension. Without it, `MultipartFile.fromFile` ships
  ///     `application/octet-stream`, Cloudinary refuses the blob, and
  ///     the backend wraps the failure as a generic 500.
  Future<NoteImageRef> uploadImage({
    required String noteId,
    required String filePath,
    required int imageNumber,
  }) async {
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    if (kDebugMode) {
      try {
        final bytes = await File(filePath).length();
        debugPrint(
          '[notes_api] uploadImage slot=$imageNumber '
          'file=$filename size=${bytes}B (${(bytes / 1024 / 1024).toStringAsFixed(2)} MB)',
        );
      } on FileSystemException {
        debugPrint(
          '[notes_api] uploadImage slot=$imageNumber file=$filename '
          'size=<stat failed>',
        );
      }
    }
    final form = FormData.fromMap(<String, dynamic>{
      'imageNumber': imageNumber.toString(),
      'image': await MultipartFile.fromFile(
        filePath,
        filename: filename,
        contentType: _mediaTypeForFilename(filename),
      ),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      Endpoints.noteImages(noteId),
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    return NoteImageRef.fromJson(_unwrapMap(response.data));
  }

  /// `DELETE /notes/{id}/images/{slot}` — removes a specific slot.
  /// No-op idempotency on 404 is up to the caller.
  Future<void> removeImage({
    required String noteId,
    required int imageNumber,
  }) async {
    await _dio.delete<Map<String, dynamic>>(
      Endpoints.noteImageSlot(noteId, imageNumber),
    );
  }

  /// Maps a filename's extension to a `Content-Type`. The backend only
  /// accepts JPEG and PNG; anything else falls back to
  /// `application/octet-stream` so the server's mime filter rejects it
  /// explicitly.
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
        return MediaType('application', 'octet-stream');
    }
  }

  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? body) {
    if (body == null) {
      throw const FormatException('Empty response body');
    }
    if (body['success'] == false) {
      throw const FormatException('Notes API returned success=false');
    }
    final inner = body['data'];
    if (inner is! Map<String, dynamic>) {
      throw const FormatException(
        'Malformed notes envelope: missing or invalid `data` object',
      );
    }
    return inner;
  }
}

final notesApiProvider = Provider<NotesApi>(
  (ref) => NotesApi(ref.watch(dioProvider)),
);
