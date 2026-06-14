/// Pure value types for the live-tracking realtime layer. These mirror the
/// `live-tracking-socket.md` contract and are deliberately framework-free so
/// they're safe to use inside the background-service isolate.
library;

/// Session lifecycle state.
enum TrackingStatus {
  active,
  paused,
  completed;

  static TrackingStatus fromWire(String? raw) {
    switch ((raw ?? '').toUpperCase()) {
      case 'PAUSED':
        return TrackingStatus.paused;
      case 'COMPLETED':
        return TrackingStatus.completed;
      case 'ACTIVE':
      default:
        return TrackingStatus.active;
    }
  }
}

/// Why a session was closed server-side (`tracking-force-stopped.reason`).
enum ForceStopReason {
  beatPlanCompleted,
  forceCompleted,
  attendanceCheckout,
  staleTimeout,
  unknown;

  static ForceStopReason fromWire(String? raw) {
    switch (raw) {
      case 'beat_plan_completed':
        return ForceStopReason.beatPlanCompleted;
      case 'force_completed':
        return ForceStopReason.forceCompleted;
      case 'attendance_checkout':
        return ForceStopReason.attendanceCheckout;
      case 'stale_timeout':
        return ForceStopReason.staleTimeout;
      default:
        return ForceStopReason.unknown;
    }
  }

  /// Short, user-facing reason for the "session ended" toast.
  String get displayLabel {
    switch (this) {
      case ForceStopReason.beatPlanCompleted:
        return 'Beat plan completed';
      case ForceStopReason.forceCompleted:
        return 'Completed by your manager';
      case ForceStopReason.attendanceCheckout:
        return 'Auto-closed on checkout';
      case ForceStopReason.staleTimeout:
        return 'Closed after inactivity';
      case ForceStopReason.unknown:
        return 'Tracking ended';
    }
  }
}

/// One GPS fix queued for the socket. [clientPingId] is the server's
/// idempotency key — minted once at capture time, stable across retries.
class LocationFix {
  const LocationFix({
    required this.clientPingId,
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.accuracy,
    this.speed,
    this.heading,
    this.address,
  });

  final String clientPingId;
  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? accuracy;
  final double? speed;
  final double? heading;
  final String? address;

  /// `update-location` payload (carries `beatPlanId` at the top level).
  Map<String, dynamic> toLiveJson(String beatPlanId) => <String, dynamic>{
        'beatPlanId': beatPlanId,
        ...toPingJson(),
      };

  /// One element of an `update-location-batch.pings` array (no `beatPlanId`).
  Map<String, dynamic> toPingJson() => <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (speed != null) 'speed': speed,
        if (heading != null) 'heading': heading,
        'recordedAt': recordedAt.toUtc().toIso8601String(),
        'clientPingId': clientPingId,
        if (address != null) 'address': address,
      };
}

/// Computed route stats returned by `stop-tracking` (and force-stop).
class TrackingSummary {
  const TrackingSummary({
    this.totalDistanceKm = 0,
    this.totalDurationMin = 0,
    this.averageSpeedKmh = 0,
    this.directoriesVisited = 0,
  });

  factory TrackingSummary.fromJson(Map<String, dynamic> json) {
    return TrackingSummary(
      totalDistanceKm: (json['totalDistanceKm'] as num?)?.toDouble() ?? 0,
      totalDurationMin: (json['totalDurationMin'] as num?)?.toInt() ?? 0,
      averageSpeedKmh: (json['averageSpeedKmh'] as num?)?.toDouble() ?? 0,
      directoriesVisited: (json['directoriesVisited'] as num?)?.toInt() ?? 0,
    );
  }

  final double totalDistanceKm;
  final int totalDurationMin;
  final double averageSpeedKmh;
  final int directoriesVisited;
}

/// Result of an ack-bearing client→server emit.
class TrackingAck {
  const TrackingAck({
    required this.ok,
    this.code,
    this.message,
    this.data = const <String, dynamic>{},
  });

  final bool ok;
  final String? code;
  final String? message;
  final Map<String, dynamic> data;

  int get persisted => (data['persisted'] as num?)?.toInt() ?? 0;
  int get deduped => (data['deduped'] as num?)?.toInt() ?? 0;
  String? get sessionId => data['sessionId'] as String?;

  TrackingSummary? get summary {
    final s = data['summary'];
    return s is Map<String, dynamic> ? TrackingSummary.fromJson(s) : null;
  }
}

/// ── Server → client events ────────────────────────────────────────────────
sealed class TrackingServerEvent {
  const TrackingServerEvent();
}

/// Socket connect/disconnect, surfaced so the runtime can flush the outbox on
/// reconnect and toggle the notification's online/offline indicator.
class ConnectionStateEvent extends TrackingServerEvent {
  const ConnectionStateEvent({required this.connected, this.reason});
  final bool connected;
  final String? reason;
}

class LocationBroadcastEvent extends TrackingServerEvent {
  const LocationBroadcastEvent({
    required this.beatPlanId,
    required this.latitude,
    required this.longitude,
    this.recordedAt,
    this.address,
  });
  final String beatPlanId;
  final double latitude;
  final double longitude;
  final DateTime? recordedAt;
  final String? address;
}

class StatusUpdateEvent extends TrackingServerEvent {
  const StatusUpdateEvent({
    required this.beatPlanId,
    required this.status,
    this.reason,
    this.summary,
  });
  final String beatPlanId;
  final TrackingStatus status;
  final String? reason;
  final TrackingSummary? summary;
}

class ForceStoppedEvent extends TrackingServerEvent {
  const ForceStoppedEvent({
    required this.beatPlanId,
    required this.reason,
    this.sessionId,
    this.summary,
  });
  final String beatPlanId;
  final ForceStopReason reason;
  final String? sessionId;
  final TrackingSummary? summary;
}

class TrackingErrorEvent extends TrackingServerEvent {
  const TrackingErrorEvent({required this.code, this.message});
  final String code;
  final String? message;
}

class AuthExpiredEvent extends TrackingServerEvent {
  const AuthExpiredEvent();
}

class ServerShuttingDownEvent extends TrackingServerEvent {
  const ServerShuttingDownEvent();
}
