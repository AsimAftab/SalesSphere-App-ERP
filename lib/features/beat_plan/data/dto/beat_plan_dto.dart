/// Wire DTOs for the beat-plan endpoints. Hand-written until
/// `tool/gen_dto.sh` regenerates from `tool/openapi.json` — see
/// `beat-plans.schemas.ts` (`BeatPlanDto` / `BeatPlanDetailDto`) on the
/// backend for the source of truth.
///
/// The list endpoint returns the summary shape (progress counters, no stops);
/// `GET /beat-plans/:id` returns the detail shape (adds `stops` +
/// `totalRouteDistanceKm`). One DTO covers both: `stops` is empty for the
/// summary shape.
library;

DateTime? _parseDate(Object? v) {
  if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
  return null;
}

class BeatPlanDto {
  const BeatPlanDto({
    required this.id,
    required this.name,
    required this.status,
    required this.frequency,
    required this.scheduledDate,
    this.endDate,
    this.startedAt,
    this.completedAt,
    this.totalStops = 0,
    this.visitedStops = 0,
    this.skippedStops = 0,
    this.percentage = 0,
    this.stops = const <BeatPlanStopDto>[],
  });

  factory BeatPlanDto.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'];
    int counter(String key) => progress is Map<String, dynamic>
        ? (progress[key] as num?)?.toInt() ?? 0
        : 0;
    final pct = progress is Map<String, dynamic>
        ? (progress['percentage'] as num?)?.toDouble() ?? 0
        : 0.0;
    final rawStops = json['stops'];
    final stops = rawStops is List
        ? rawStops
            .map((e) => BeatPlanStopDto.fromJson(e as Map<String, dynamic>))
            .toList(growable: false)
        : const <BeatPlanStopDto>[];
    return BeatPlanDto(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Beat Plan',
      status: (json['status'] as String?) ?? 'PENDING',
      frequency: (json['frequency'] as String?) ?? 'CUSTOM',
      scheduledDate:
          _parseDate(json['scheduledDate']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endDate: _parseDate(json['endDate']),
      startedAt: _parseDate(json['startedAt']),
      completedAt: _parseDate(json['completedAt']),
      totalStops: counter('totalStops'),
      visitedStops: counter('visitedStops'),
      skippedStops: counter('skippedStops'),
      percentage: pct,
      stops: stops,
    );
  }

  final String id;
  final String name;

  /// `PENDING` | `ACTIVE` | `COMPLETED`.
  final String status;

  /// `DAILY` | `WEEKLY` | `MONTHLY` | `CUSTOM`.
  final String frequency;
  final DateTime scheduledDate;
  final DateTime? endDate;
  final DateTime? startedAt;
  final DateTime? completedAt;

  final int totalStops;
  final int visitedStops;
  final int skippedStops;

  /// Server-computed completion percentage, 0–100.
  final double percentage;

  final List<BeatPlanStopDto> stops;
}

class BeatPlanStopDto {
  const BeatPlanStopDto({
    required this.id,
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
    this.visitNotes,
    this.followUpDate,
    this.visitImageUrl,
    this.visitLatitude,
    this.visitLongitude,
    this.distanceToNextKm,
  });

  factory BeatPlanStopDto.fromJson(Map<String, dynamic> json) {
    // Visit proof photo: max one per stop (slot 1) → first image's url.
    final rawImages = json['images'];
    String? imageUrl;
    if (rawImages is List && rawImages.isNotEmpty) {
      final first = rawImages.first;
      if (first is Map<String, dynamic>) imageUrl = first['url'] as String?;
    }
    return BeatPlanStopDto(
      id: json['id'] as String,
      kind: (json['kind'] as String?) ?? 'CUSTOMER',
      status: (json['status'] as String?) ?? 'PENDING',
      entityId: json['entityId'] as String?,
      name: json['name'] as String?,
      address: json['address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      visitStartedAt: _parseDate(json['visitStartedAt']),
      visitedAt: _parseDate(json['visitedAt']),
      visitDurationSec: (json['visitDurationSec'] as num?)?.toInt(),
      visitNotes: json['visitNotes'] as String?,
      followUpDate: _parseDate(json['followUpDate']),
      visitImageUrl: imageUrl,
      visitLatitude: (json['visitLatitude'] as num?)?.toDouble(),
      visitLongitude: (json['visitLongitude'] as num?)?.toDouble(),
      distanceToNextKm: (json['distanceToNextKm'] as num?)?.toDouble(),
    );
  }

  final String id;

  /// `CUSTOMER` | `SITE` | `PROSPECT`.
  final String kind;

  /// `PENDING` | `VISITED` | `SKIPPED`.
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

  /// Server-computed visit duration (end − start), seconds. Null if no start.
  final int? visitDurationSec;
  final String? visitNotes;
  final DateTime? followUpDate;

  /// First (only) visit-proof photo URL, if any.
  final String? visitImageUrl;

  final double? visitLatitude;
  final double? visitLongitude;
  final double? distanceToNextKm;
}

/// One paginated slice of `GET /beat-plans`.
class BeatPlansPageDto {
  const BeatPlansPageDto({required this.items, this.nextCursor});

  final List<BeatPlanDto> items;
  final String? nextCursor;
}
