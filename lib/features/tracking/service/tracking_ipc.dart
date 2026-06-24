/// Method + key names for the message channel between the UI isolate and the
/// background tracking-service isolate (`ServiceInstance.invoke` / `.on`).
/// Shared by both isolates so the two ends can't drift apart.
class TrackingIpc {
  TrackingIpc._();

  // ── UI → service commands ──────────────────────────────────────────────
  // Tracking is system-controlled: there is NO user pause / resume / stop.
  // A session ends only server-side (plan completed/force-completed, attendance
  // checkout, or the stale sweeper), handled via the `tracking-*` socket events.
  static const String cmdStart = 'cmd.start';
  static const String cmdProgress = 'cmd.progress';

  /// Ask the running service to immediately re-emit its live state (used when
  /// the UI re-opens the tracking screen instead of waiting for the next tick).
  static const String cmdSync = 'cmd.sync';

  /// Ask the running service to re-read the freshest access token from secure
  /// storage and reconnect its socket. Sent after a (re)login so a background
  /// session that was looping on a stale/expired token recovers immediately.
  static const String cmdReauth = 'cmd.reauth';

  // ── service → UI events ────────────────────────────────────────────────
  static const String evtState = 'evt.state';
  static const String evtSession = 'evt.session';
  static const String evtForceStopped = 'evt.forceStopped';
  static const String evtStopped = 'evt.stopped';

  /// The session's refresh token is itself expired/invalid — the background
  /// service can't recover on its own. The UI clears auth and routes to /login.
  static const String evtAuthExpired = 'evt.authExpired';

  // ── payload keys ───────────────────────────────────────────────────────
  static const String kBeatPlanId = 'beatPlanId';
  static const String kSessionId = 'sessionId';
  static const String kTotal = 'total';
  static const String kVisited = 'visited';
  static const String kSkipped = 'skipped';

  /// true → resume an existing session (preserve its start time/distance);
  /// false → a fresh start that resets the session.
  static const String kResume = 'resume';
  static const String kStatus = 'status'; // active | paused | completed
  static const String kLat = 'lat';
  static const String kLng = 'lng';
  static const String kDistanceKm = 'distanceKm';
  static const String kDurationSec = 'durationSec';
  static const String kQueued = 'queued';
  static const String kConnected = 'connected';
  static const String kBattery = 'battery'; // device battery % (0–100), nullable
  static const String kReason = 'reason';
  static const String kReasonLabel = 'reasonLabel';
}
