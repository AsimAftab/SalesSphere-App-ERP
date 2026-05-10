import 'package:sales_sphere_erp/features/parties/data/dto/party_image_ref.dart';
import 'package:sales_sphere_erp/features/parties/domain/parties_page.dart';
import 'package:sales_sphere_erp/features/parties/domain/party.dart';

/// Thrown by [PartiesRepository.addParty] when the customer was
/// successfully created but at least one of the attached image
/// uploads failed. Carries the created [party] so callers can still
/// reflect the new row in the UI, plus per-slot [failures] keyed by
/// 1-indexed slot number with the backend's error message (or a
/// generic fallback when the response had no shape we recognised).
///
/// Hard failures (the customer itself couldn't be created) keep
/// bubbling as the underlying `DioException` — those reach the form's
/// generic catch and leave the user on the page to retry.
class PartialImageUploadException implements Exception {
  const PartialImageUploadException({
    required this.party,
    required this.failures,
  });

  final Party party;
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
      'PartialImageUploadException(party=${party.id}, '
      'failures=$failures)';
}

/// Domain-side contract for parties data. The concrete implementation
/// (DTO mapping, drift persistence, outbox enqueue) lives in
/// `data/repositories/parties_repository_impl.dart`.
abstract class PartiesRepository {
  /// Fetch one paginated slice. The repo upserts the result into drift so
  /// the UI's reactive list provider sees fresh content on the next emit.
  Future<PartiesPage> getPartiesPage({
    int limit,
    String? cursor,
    String? search,
  });

  /// Drift-first single-row read with API fallback for cold-start
  /// deep-links. Returns `null` only when the row genuinely doesn't exist
  /// (404) — network errors propagate.
  Future<Party?> getPartyById(String id);

  Future<Party> addParty(Party draft);

  Future<Party> updateParty(Party party);

  Future<List<String>> getPartyTypes();

  /// Fetch the customer's current image gallery for the edit form's
  /// picker to hydrate. Returns `[]` for a customer with no images.
  Future<List<PartyImageRef>> listImages(String customerId);

  /// Upload (or replace) one image slot.
  Future<void> uploadImage({
    required String customerId,
    required String filePath,
    required int slot,
  });

  /// Delete one image slot.
  Future<void> removeImage({
    required String customerId,
    required int slot,
  });
}
