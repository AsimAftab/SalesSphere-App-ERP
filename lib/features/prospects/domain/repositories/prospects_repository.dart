import 'package:sales_sphere_erp/features/prospects/data/dto/prospect_image_ref.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect.dart';
import 'package:sales_sphere_erp/features/prospects/domain/prospect_conversion_result.dart';
import 'package:sales_sphere_erp/shared/domain/interest_catalogue.dart';

/// Thrown by [ProspectsRepository.addProspect] when the prospect was
/// successfully created but at least one of the attached image uploads
/// failed. Carries the created [prospect] so callers can still reflect
/// the new row in the UI, plus per-slot [failures] keyed by 1-indexed
/// slot number with the backend's error message (or a generic fallback
/// when the response had no shape we recognised).
///
/// Hard failures (the prospect itself couldn't be created) keep
/// bubbling as the underlying `DioException` — those reach the form's
/// generic catch and leave the user on the page to retry.
class ProspectPartialImageUploadException implements Exception {
  const ProspectPartialImageUploadException({
    required this.prospect,
    required this.failures,
  });

  final Prospect prospect;
  final Map<int, String> failures;

  /// 1-indexed slot numbers that failed, in deterministic order so the
  /// form's snackbar copy is stable across runs.
  List<int> get failedSlots => failures.keys.toList()..sort();

  /// Convenience for snackbars: the first failure's backend message,
  /// or the generic fallback when there were none.
  String get firstMessage =>
      failures.isEmpty ? 'Upload failed' : failures.values.first;

  @override
  String toString() =>
      'ProspectPartialImageUploadException(prospect=${prospect.id}, '
      'failures=$failures)';
}

/// Domain-side contract for prospects data. The concrete implementation
/// (DTO mapping, drift persistence, outbox enqueue) lives in
/// `data/repositories/prospects_repository_impl.dart`.
abstract class ProspectsRepository {
  Future<List<Prospect>> getProspects();

  /// Single-row read for cold-start deep-links. Returns `null` only when
  /// the row genuinely doesn't exist (404); network errors propagate.
  Future<Prospect?> getProspectById(String id);

  Future<Prospect> addProspect(Prospect draft);

  Future<Prospect> updateProspect(Prospect prospect);

  Future<InterestCatalogue> getInterestCatalogue();

  Future<void> addInterestCategory(String category);

  Future<void> addInterestBrand(String category, String brand);

  /// Fetch the prospect's current image gallery for the edit form's
  /// picker to hydrate. Returns `[]` for a prospect with no images.
  Future<List<ProspectImageRef>> listImages(String prospectId);

  /// Upload (or replace) one image slot.
  Future<void> uploadImage({
    required String prospectId,
    required String filePath,
    required int slot,
  });

  /// Delete one image slot.
  Future<void> removeImage({
    required String prospectId,
    required int slot,
  });

  /// Promote a prospect into a customer. Backed by
  /// `POST /prospects/{id}/convert`. Returns the new `customerId` (and
  /// the count of images that survived the transfer) so the caller can
  /// navigate to the resulting party detail.
  Future<ProspectConversionResult> convertToParty({
    required String prospectId,
    bool keepImages,
  });
}
