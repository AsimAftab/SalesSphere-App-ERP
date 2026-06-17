import 'package:sales_sphere_erp/core/utils/geo_distance.dart';

/// UI-facing stop on a beat plan's route. `kind` and `status` stay as the raw
/// backend enums (`CUSTOMER`/`SITE`/`PROSPECT`, `PENDING`/`VISITED`/`SKIPPED`)
/// so logic can switch on them; [typeLabel] / [statusLabel] give the
/// human-readable form the cards render.
class BeatPlanStop {
  const BeatPlanStop({
    required this.id,
    required this.beatPlanId,
    required this.kind,
    required this.status,
    this.entityId,
    this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.sortOrder = 0,
    this.visitStartedAt,
    this.visitedAt,
    this.visitDurationSec,
    this.skippedAt,
    this.visitNotes,
    this.followUpDate,
    this.visitImageUrl,
    this.distanceToNextKm,
    this.syncPending = false,
    this.syncError,
  });

  final String id;
  final String beatPlanId;
  final String kind;
  final String status;
  final String? entityId;
  final String? name;
  final String? address;
  final double? latitude;
  final double? longitude;
  final int sortOrder;

  /// When the rep tapped "Start" on the stop.
  final DateTime? visitStartedAt;

  /// Visit END time (the canonical "visited at").
  final DateTime? visitedAt;

  /// Server-computed visit duration (seconds). Null when no start was recorded.
  final int? visitDurationSec;

  /// When the rep skipped this stop (the canonical "skipped at" time). Set only
  /// for [isSkipped] stops — `visitedAt` stays null for a skip.
  final DateTime? skippedAt;
  final String? visitNotes;
  final DateTime? followUpDate;

  /// Visit-proof photo URL, if uploaded.
  final String? visitImageUrl;

  final double? distanceToNextKm;
  final bool syncPending;
  final String? syncError;

  bool get hasPhoto => visitImageUrl != null && visitImageUrl!.isNotEmpty;
  bool get hasNotes => visitNotes != null && visitNotes!.trim().isNotEmpty;

  /// Human-readable time-on-site for the visited card (`18m 30s`, `1h 5m`,
  /// `45s`). Null when no duration was recorded — the card shows a placeholder.
  String? get timeSpentLabel {
    final sec = visitDurationSec;
    if (sec == null || sec <= 0) return null;
    final d = Duration(seconds: sec);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return s > 0 ? '${m}m ${s}s' : '${m}m';
    return '${s}s';
  }

  bool get isPending => status.toUpperCase() == 'PENDING';
  bool get isVisited => status.toUpperCase() == 'VISITED';
  bool get isSkipped => status.toUpperCase() == 'SKIPPED';

  bool get hasLocation => latitude != null && longitude != null;

  /// Distance in metres from [fromLat]/[fromLng] (the rep's current position)
  /// to this stop, or null when either side lacks a location. Backs the
  /// per-stop geofence check.
  double? distanceMetersFrom(double? fromLat, double? fromLng) {
    if (!hasLocation || fromLat == null || fromLng == null) return null;
    return haversineMeters(fromLat, fromLng, latitude!, longitude!);
  }

  /// Whether [fromLat]/[fromLng] is within [radius] metres of this stop. Null
  /// when the distance can't be measured (stop or rep position missing).
  bool? isWithinRange(
    double? fromLat,
    double? fromLng, {
    double radius = kGeofenceRadiusMeters,
  }) {
    final d = distanceMetersFrom(fromLat, fromLng);
    return d == null ? null : d <= radius;
  }

  /// Card badge label: `CUSTOMER` → `Party` (mobile speaks "party"), the
  /// others title-cased.
  String get typeLabel {
    switch (kind.toUpperCase()) {
      case 'SITE':
        return 'Site';
      case 'PROSPECT':
        return 'Prospect';
      case 'CUSTOMER':
      default:
        return 'Party';
    }
  }

  /// Title-cased status for the card (`VISITED` → `Visited`).
  String get statusLabel {
    final s = status.toUpperCase();
    if (s.isEmpty) return 'Pending';
    return s[0] + s.substring(1).toLowerCase();
  }
}
