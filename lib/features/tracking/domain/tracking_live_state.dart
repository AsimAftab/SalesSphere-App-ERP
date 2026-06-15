import 'package:sales_sphere_erp/features/tracking/domain/tracking_models.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_ipc.dart';

/// Ephemeral live tracking state pushed from the background service to the UI
/// over the service event channel (NOT drift — two isolates don't share drift
/// stream invalidation). Rebuilt from each `evt.state` payload.
class TrackingLiveState {
  const TrackingLiveState({
    required this.isTracking,
    this.beatPlanId,
    this.status = TrackingStatus.active,
    this.connected = false,
    this.latitude,
    this.longitude,
    this.distanceKm = 0,
    this.durationSec = 0,
    this.queued = 0,
    this.total = 0,
    this.visited = 0,
    this.skipped = 0,
  });

  const TrackingLiveState.idle() : this(isTracking: false);

  factory TrackingLiveState.fromMap(Map<String, dynamic> map) {
    final status = TrackingStatus.values.firstWhere(
      (s) => s.name == map[TrackingIpc.kStatus],
      orElse: () => TrackingStatus.active,
    );
    final beatPlanId = map[TrackingIpc.kBeatPlanId] as String?;
    return TrackingLiveState(
      isTracking: beatPlanId != null && status != TrackingStatus.completed,
      beatPlanId: beatPlanId,
      status: status,
      connected: map[TrackingIpc.kConnected] as bool? ?? false,
      latitude: (map[TrackingIpc.kLat] as num?)?.toDouble(),
      longitude: (map[TrackingIpc.kLng] as num?)?.toDouble(),
      distanceKm: (map[TrackingIpc.kDistanceKm] as num?)?.toDouble() ?? 0,
      durationSec: (map[TrackingIpc.kDurationSec] as num?)?.toInt() ?? 0,
      queued: (map[TrackingIpc.kQueued] as num?)?.toInt() ?? 0,
      total: (map[TrackingIpc.kTotal] as num?)?.toInt() ?? 0,
      visited: (map[TrackingIpc.kVisited] as num?)?.toInt() ?? 0,
      skipped: (map[TrackingIpc.kSkipped] as num?)?.toInt() ?? 0,
    );
  }

  final bool isTracking;
  final String? beatPlanId;
  final TrackingStatus status;
  final bool connected;
  final double? latitude;
  final double? longitude;
  final double distanceKm;
  final int durationSec;
  final int queued;
  final int total;
  final int visited;
  final int skipped;

  bool get isPaused => status == TrackingStatus.paused;

  /// True when this state is the live session for [planId].
  bool isFor(String planId) => isTracking && beatPlanId == planId;

  /// `2h 45m` / `12m` / `45s`.
  String get durationLabel {
    final d = Duration(seconds: durationSec);
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${s}s';
  }
}
