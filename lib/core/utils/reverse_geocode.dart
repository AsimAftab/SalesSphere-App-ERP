import 'package:geocoding/geocoding.dart';

/// Best-effort reverse-geocoding helper. Resolves a lat/lng to a
/// human-readable, comma-joined address string built from every
/// placemark field that adds meaning, deduped case-insensitively to
/// drop the Plus Code / street-name collisions that `geocoding`
/// returns on some platforms.
///
/// Returns `null` when the platform has nothing to give us (no
/// placemarks, network failure, missing permission). The contract is
/// silent-failure on purpose so UI surfaces can fall back to showing
/// raw coordinates without `try`/`catch` plumbing at the call site.
Future<String?> reverseGeocodeAddress(double lat, double lng) async {
  try {
    final placemarks = await placemarkFromCoordinates(lat, lng);
    if (placemarks.isEmpty) return null;
    final p = placemarks.first;
    final raw = <String?>[
      p.name,
      p.subThoroughfare,
      p.thoroughfare,
      p.street,
      p.subLocality,
      p.locality,
      p.subAdministrativeArea,
      p.administrativeArea,
      p.postalCode,
      p.country,
    ].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty);

    final seen = <String>{};
    final deduped = <String>[];
    for (final part in raw) {
      if (seen.add(part.toLowerCase())) deduped.add(part);
    }
    if (deduped.isEmpty) return null;
    return deduped.join(', ');
  } on Object catch (_) {
    // Best-effort by contract: swallow *anything* (PlatformException, or an
    // Error like UnimplementedError when no geocoding platform is wired up)
    // and fall back to null. Reverse-geocoding must never break the caller.
    return null;
  }
}
