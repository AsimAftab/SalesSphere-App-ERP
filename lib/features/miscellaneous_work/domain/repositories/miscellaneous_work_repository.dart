import 'package:sales_sphere_erp/features/miscellaneous_work/data/dto/miscellaneous_work_image_ref.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work.dart';
import 'package:sales_sphere_erp/features/miscellaneous_work/domain/miscellaneous_work_page.dart';

/// Thrown by [MiscellaneousWorkRepository.addWork] when the work row
/// was successfully created but at least one of the attached image
/// uploads failed. Carries the created [work] so callers can still
/// reflect the new row in the UI, plus per-slot [failures] keyed by
/// 1-indexed slot number with the backend's error message (or a
/// generic fallback when the response had no shape we recognised).
///
/// Hard failures (the work itself couldn't be created) keep bubbling
/// as the underlying `DioException` — those reach the form's generic
/// catch and leave the user on the page to retry.
class MiscellaneousWorkPartialImageUploadException implements Exception {
  const MiscellaneousWorkPartialImageUploadException({
    required this.work,
    required this.failures,
  });

  final MiscellaneousWork work;
  final Map<int, String> failures;

  /// 1-indexed slot numbers that failed, in deterministic order so
  /// the form's snackbar copy is stable across runs.
  List<int> get failedSlots => failures.keys.toList()..sort();

  /// Convenience for snackbars: the first failure's backend message,
  /// or the generic fallback when there were none.
  String get firstMessage =>
      failures.isEmpty ? 'Upload failed' : failures.values.first;

  @override
  String toString() =>
      'MiscellaneousWorkPartialImageUploadException(work=${work.id}, '
      'failures=$failures)';
}

/// Contract for the miscellaneous-work data source. The concrete impl
/// (`MiscellaneousWorkRepositoryImpl`) handles wire-DTO ↔ domain
/// mapping and — once the backend lands — drift persistence + outbox
/// enqueue. Tests substitute fakes via the Riverpod override.
abstract class MiscellaneousWorkRepository {
  /// Fetch one paginated page of miscellaneous-work rows.
  Future<MiscellaneousWorkPage> getPage({int limit, String? cursor});

  /// Persists the work row + attached images. On image-only failures,
  /// throws [MiscellaneousWorkPartialImageUploadException] carrying
  /// the created row so the caller can still reflect the new row in
  /// the UI.
  Future<MiscellaneousWork> addWork(MiscellaneousWork draft);

  Future<MiscellaneousWork> updateWork(MiscellaneousWork work);

  /// Fetch the row's current image gallery for the edit form's
  /// picker to hydrate. Returns `[]` for a row with no images.
  Future<List<MiscellaneousWorkImageRef>> listImages(String id);

  /// Upload (or replace) one image slot.
  Future<MiscellaneousWorkImageRef> uploadImage({
    required String id,
    required String filePath,
    required int slot,
  });

  /// Delete one image slot.
  Future<void> removeImage({
    required String id,
    required int slot,
  });
}
