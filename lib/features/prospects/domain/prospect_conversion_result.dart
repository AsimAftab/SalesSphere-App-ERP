import 'package:flutter/foundation.dart' show immutable;

/// Result of `POST /prospects/{id}/convert`. The backend swaps the
/// prospect for a real customer row and returns enough breadcrumbs for
/// the UI to navigate to the new party detail and announce how many
/// images survived the transfer.
@immutable
class ProspectConversionResult {
  const ProspectConversionResult({
    required this.convertedFromProspectId,
    required this.customerId,
    required this.transferredImageCount,
  });

  final String convertedFromProspectId;
  final String customerId;
  final int transferredImageCount;
}
