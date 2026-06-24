import 'dart:async';
import 'dart:ui';

import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:sales_sphere_erp/core/api/endpoints.dart';
import 'package:sales_sphere_erp/core/auth/token_storage.dart';
import 'package:sales_sphere_erp/core/config/env.dart';
import 'package:sales_sphere_erp/core/db/app_database.dart';
import 'package:sales_sphere_erp/core/db/daos/tracking_dao.dart';
import 'package:sales_sphere_erp/core/db/daos/tracking_pings_dao.dart';
import 'package:sales_sphere_erp/core/utils/app_logger.dart';
import 'package:sales_sphere_erp/core/utils/uuid.dart';
import 'package:sales_sphere_erp/features/tracking/data/tracking_socket_client.dart';
import 'package:sales_sphere_erp/features/tracking/domain/tracking_models.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_ipc.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_notification.dart';
import 'package:sales_sphere_erp/features/tracking/service/tracking_prefs.dart';

/// Set by `app.dart` (main isolate) so a notification tap can deep-link to the
/// plan. Lives as a global because the FLN foreground callback is a top-level
/// function with no access to the widget tree.
void Function(String beatPlanId)? trackingNotificationTapHandler;

void _onForegroundNotificationTap(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || !payload.startsWith('beat-plans/')) return;
  trackingNotificationTapHandler
      ?.call(payload.substring('beat-plans/'.length));
}

// ── UI-isolate facade ───────────────────────────────────────────────────────

/// Wire up the foreground service + notification channel. Call once in
/// `bootstrap()` before `runApp`.
Future<void> configureTrackingService() async {
  final plugin = FlutterLocalNotificationsPlugin();
  await initTrackingNotifications(
    plugin,
    onForegroundTap: _onForegroundNotificationTap,
  );

  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: trackingServiceOnStart,
      isForegroundMode: true,
      autoStart: false,
      autoStartOnBoot: false,
      foregroundServiceTypes: <AndroidForegroundType>[
        AndroidForegroundType.location,
      ],
      notificationChannelId: kTrackingChannelId,
      foregroundServiceNotificationId: kTrackingNotificationId,
      initialNotificationTitle: 'SalesSphere',
      initialNotificationContent: 'Starting live tracking…',
    ),
    // `configure()` requires an iosConfiguration; this is the inert default and
    // adds no iOS behaviour. The app remains Android-only — iOS comes later.
    iosConfiguration: IosConfiguration(autoStart: false),
  );
}

Future<bool> isTrackingServiceRunning() =>
    FlutterBackgroundService().isRunning();

/// Start (or hand the latest progress to) the tracking service for [beatPlanId].
///
/// [resume] = false is an explicit fresh start (the rep tapped "Start
/// Tracking") — it resets the session's start time + distance. [resume] = true
/// (cold-start reconcile / "Resume Tracking") reuses the existing open session,
/// so its running duration + distance are preserved across a process restart.
Future<void> startTrackingService({
  required String beatPlanId,
  required int total,
  required int visited,
  required int skipped,
  bool resume = false,
}) async {
  await TrackingPrefs.saveStart(
    beatPlanId: beatPlanId,
    total: total,
    visited: visited,
    skipped: skipped,
    resume: resume,
  );
  final service = FlutterBackgroundService();
  if (!await service.isRunning()) {
    await service.startService();
  }
  // Primary start path is the prefs read inside onStart; this invoke is the
  // immediate nudge for an already-running service / fast UI.
  service.invoke(TrackingIpc.cmdStart, <String, dynamic>{
    TrackingIpc.kBeatPlanId: beatPlanId,
    TrackingIpc.kTotal: total,
    TrackingIpc.kVisited: visited,
    TrackingIpc.kSkipped: skipped,
    TrackingIpc.kResume: resume,
  });
}

void updateTrackingProgress({
  required int total,
  required int visited,
  required int skipped,
}) {
  FlutterBackgroundService().invoke(TrackingIpc.cmdProgress, <String, dynamic>{
    TrackingIpc.kTotal: total,
    TrackingIpc.kVisited: visited,
    TrackingIpc.kSkipped: skipped,
  });
}

/// Ensure tracking is live for an **already-active** plan — without any user
/// action or permission prompt. Tracking is system-controlled, so the rep never
/// taps "resume": if the service is running we just nudge it to re-emit its
/// state; if it was killed we silently relaunch it (resume preserves the
/// running session). Permissions were granted when the plan was first started.
Future<void> ensureTrackingRunning({
  required String beatPlanId,
  required int total,
  required int visited,
  required int skipped,
}) async {
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke(TrackingIpc.cmdSync);
  } else {
    await startTrackingService(
      beatPlanId: beatPlanId,
      total: total,
      visited: visited,
      skipped: skipped,
      resume: true,
    );
  }
}

/// Tell a running tracking service to re-authenticate its socket with the
/// freshest token in secure storage. Call after a (re)login so a background
/// session that was looping on an expired token recovers immediately. No-op
/// when the service isn't running.
Future<void> reauthTrackingService() async {
  final service = FlutterBackgroundService();
  if (await service.isRunning()) {
    service.invoke(TrackingIpc.cmdReauth);
  }
}

// ── Background-isolate entrypoint ───────────────────────────────────────────

@pragma('vm:entry-point')
Future<void> trackingServiceOnStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  try {
    Env.initialise();
  } on Object {
    // Already initialised, or no flavor define — Env constants are baked in.
  }
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }
  final runtime = _TrackingRuntime(service);
  await runtime.bootstrap();
}

/// Owns the entire tracking runtime inside the foreground-service isolate: GPS
/// stream, socket, durable ping outbox, notification, and server-event
/// handling. The UI isolate never touches any of this — it sends commands and
/// receives ephemeral state over the service channel.
class _TrackingRuntime {
  _TrackingRuntime(this._service);

  final ServiceInstance _service;

  late final AppDatabase _db;
  late final TrackingDao _trackingDao;
  late final TrackingPingsDao _pingsDao;
  late final TokenStorage _tokens;
  late final Dio _refreshDio;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Local logger — this runs in the background service isolate where the
  /// Riverpod `appLoggerProvider` isn't reachable, so we hold our own instance.
  final AppLogger _log = AppLogger();

  TrackingSocketClient? _socket;
  StreamSubscription<TrackingServerEvent>? _socketSub;
  StreamSubscription<Position>? _gpsSub;
  Timer? _ticker;

  String? _beatPlanId;
  String? _sessionId;
  bool _started = false;
  bool _connected = false;
  bool _refreshing = false;
  DateTime? _lastRefreshAt;
  TrackingStatus _status = TrackingStatus.active;

  DateTime? _startedAt;
  DateTime? _lastProcessedAt;
  double _distanceKm = 0;
  double? _lastLat;
  double? _lastLng;
  int _queued = 0;
  int _total = 0;
  int _visited = 0;
  int _skipped = 0;

  final Battery _battery = Battery();

  /// Cached device battery % (0–100). Refreshed on start + the 15s tick so the
  /// GPS hot path never makes a platform-channel call. Null until first read.
  int? _batteryLevel;

  /// Reverse-geocoding is throttled: the first fix of a session is geocoded
  /// (start address) and then at most once per [_geocodeInterval]. This keeps
  /// the session's current/end address fresh without a network geocode on every
  /// ping. Null → the next fix is geocoded.
  DateTime? _lastGeocodeAt;
  static const Duration _geocodeInterval = Duration(seconds: 60);

  /// Tick counter so the server-state reconcile runs less often than the 15s
  /// state tick (every 2nd tick ≈ 30s).
  int _tickCount = 0;

  Future<void> bootstrap() async {
    // flutter_local_notifications is per-isolate — initialise it here so the
    // service can render/own the ongoing notification from this isolate.
    await initTrackingNotifications(_notifications);

    _db = AppDatabase();
    _trackingDao = _db.trackingDao;
    _pingsDao = _db.trackingPingsDao;
    _tokens = TokenStorage(
      const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ),
    );
    _refreshDio = Dio(
      BaseOptions(
        baseUrl: '${Env.current.apiBaseUrl}/api/v1',
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'x-client-type': 'mobile',
        },
      ),
    );

    _service.on(TrackingIpc.cmdStart).listen((args) {
      if (args == null) return;
      unawaited(start(
        beatPlanId: args[TrackingIpc.kBeatPlanId] as String,
        total: (args[TrackingIpc.kTotal] as num?)?.toInt() ?? 0,
        visited: (args[TrackingIpc.kVisited] as num?)?.toInt() ?? 0,
        skipped: (args[TrackingIpc.kSkipped] as num?)?.toInt() ?? 0,
        resume: args[TrackingIpc.kResume] as bool? ?? false,
      ));
    });
    _service.on(TrackingIpc.cmdSync).listen((_) {
      _pushState();
      unawaited(_updateNotification());
    });
    _service.on(TrackingIpc.cmdReauth).listen((_) {
      unawaited(_reauth());
    });
    _service.on(TrackingIpc.cmdProgress).listen((args) {
      if (args == null) return;
      updateProgress(
        total: (args[TrackingIpc.kTotal] as num?)?.toInt() ?? _total,
        visited: (args[TrackingIpc.kVisited] as num?)?.toInt() ?? _visited,
        skipped: (args[TrackingIpc.kSkipped] as num?)?.toInt() ?? _skipped,
      );
    });

    // Primary start/resume path: the UI wrote the intent before starting us.
    // A restart of this isolate is always a resume — we never want to zero a
    // running session's duration just because the OS respawned the service.
    final intent = await TrackingPrefs.read();
    if (intent != null && intent.active) {
      await start(
        beatPlanId: intent.beatPlanId,
        total: intent.total,
        visited: intent.visited,
        skipped: intent.skipped,
        resume: intent.resume,
      );
    }
  }

  Future<void> start({
    required String beatPlanId,
    required int total,
    required int visited,
    required int skipped,
    bool resume = false,
  }) async {
    if (_started && _beatPlanId == beatPlanId) {
      updateProgress(total: total, visited: visited, skipped: skipped);
      return;
    }
    if (_started && _beatPlanId != beatPlanId) {
      await _finalizePriorSession();
      await _teardownTrackingOnly();
    }
    _started = true;
    _beatPlanId = beatPlanId;
    _total = total;
    _visited = visited;
    _skipped = skipped;
    _status = TrackingStatus.active;
    _lastProcessedAt = null;
    _lastGeocodeAt = null; // geocode the first fix of this (re)start → start address

    // Reuse the existing open session on a resume so its start time, distance,
    // and last position survive a service/process restart (the duration timer
    // no longer resets). A fresh start closes any stale local session first so
    // an old run's start time can't leak in.
    final existing =
        resume ? await _trackingDao.activeForBeatPlan(beatPlanId) : null;
    if (existing != null) {
      _sessionId = existing.id;
      _startedAt = existing.startedAt;
      _distanceKm = existing.totalDistanceKm;
      _lastLat = existing.currentLatitude;
      _lastLng = existing.currentLongitude;
      await _trackingDao.setStatus(existing.id, 'ACTIVE');
    } else {
      if (!resume) {
        for (final s in await _trackingDao.openSessions()) {
          if (s.beatPlanId == beatPlanId) {
            await _trackingDao.markCompleted(s.id, DateTime.now());
          }
        }
      }
      _sessionId = 'local_${generateUuidV4()}';
      _startedAt = DateTime.now();
      _distanceKm = 0;
      _lastLat = null;
      _lastLng = null;
      await _trackingDao.upsertSession(
        TrackingSessionsCompanion.insert(
          id: _sessionId!,
          beatPlanId: beatPlanId,
          status: const Value<String>('ACTIVE'),
          startedAt: Value<DateTime>(_startedAt!),
        ),
      );
    }
    // A session now exists → any later restart should resume it, not reset.
    await TrackingPrefs.markResumable();

    await _readBattery();
    await _updateNotification();
    await _connectSocket();
    await _beginGps();

    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_tick());
    });

    _pushState();
  }

  Future<void> _connectSocket() async {
    final token = await _tokens.readAccessToken();
    if (token == null || token.isEmpty) {
      // No token — run offline; GPS still buffers, flushed once we reconnect
      // after a refresh / next app session.
      return;
    }
    final socket = TrackingSocketClient(
      origin: Env.current.wsBaseUrl,
      token: token,
      log: (message, {error}) {
        // AppLogger gates by level (debug suppressed in release), so no
        // kDebugMode guard needed — socket errors still surface as warnings.
        if (error != null) {
          _log.warn('[tracking-socket] $message', error: error);
        } else {
          _log.debug('[tracking-socket] $message');
        }
      },
    );
    _socketSub = socket.events.listen(_onServerEvent);
    _socket = socket;
    socket.connect();
  }

  Future<void> _beginGps() async {
    await _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(_onPosition, onError: (_) {});
  }

  Future<void> _onPosition(Position pos) async {
    if (!_started || _beatPlanId == null) return;
    // Always record while the service runs — there's no user pause. If the
    // server stale-paused us, sending this fix gets a SESSION_PAUSED ack, which
    // re-establishes (resumes) the session below.

    final now = DateTime.now();
    final speed = (pos.speed.isNaN || pos.speed < 0) ? 0.0 : pos.speed;
    final minGap = speed < 0.5
        ? const Duration(seconds: 30)
        : const Duration(seconds: 8);
    if (_lastProcessedAt != null && now.difference(_lastProcessedAt!) < minGap) {
      return;
    }
    _lastProcessedAt = now;

    // Reverse-geocode only the first fix + every [_geocodeInterval] (best-effort)
    // so the server's formattedAddress / current address stays populated without
    // a network geocode on every ping. Most pings carry a null address.
    String? address;
    if (_lastGeocodeAt == null ||
        now.difference(_lastGeocodeAt!) >= _geocodeInterval) {
      _lastGeocodeAt = now;
      address = await _reverseGeocode(pos.latitude, pos.longitude);
    }

    final fix = LocationFix(
      clientPingId: generateUuidV4(),
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      speed: speed,
      heading: pos.heading,
      recordedAt: pos.timestamp,
      batteryLevel: _batteryLevel,
      address: address,
    );

    await _pingsDao.enqueue(
      TrackingPingsCompanion.insert(
        clientPingId: fix.clientPingId,
        beatPlanId: _beatPlanId!,
        latitude: fix.latitude,
        longitude: fix.longitude,
        recordedAt: fix.recordedAt,
        accuracy: Value<double?>(fix.accuracy),
        speed: Value<double?>(fix.speed),
        heading: Value<double?>(fix.heading),
        batteryLevel: Value<int?>(fix.batteryLevel),
        address: Value<String?>(fix.address),
      ),
    );

    if (_lastLat != null && _lastLng != null) {
      _distanceKm += Geolocator.distanceBetween(
            _lastLat!,
            _lastLng!,
            pos.latitude,
            pos.longitude,
          ) /
          1000.0;
    }
    _lastLat = pos.latitude;
    _lastLng = pos.longitude;

    if (_sessionId != null) {
      await _trackingDao.updateLocation(
        _sessionId!,
        latitude: pos.latitude,
        longitude: pos.longitude,
        recordedAt: fix.recordedAt,
        totalDistanceKm: _distanceKm,
      );
    }

    if (_connected && _socket != null) {
      final ack = await _socket!.updateLocation(
        beatPlanId: _beatPlanId!,
        fix: fix,
      );
      if (ack.ok) {
        await _pingsDao.deleteByClientId(fix.clientPingId);
      } else if (ack.code == 'NO_ACTIVE_SESSION' ||
          ack.code == 'SESSION_PAUSED') {
        // Session lapsed / stale-paused server-side — re-establish (resumes);
        // the ping stays buffered and flushes on success.
        unawaited(_establishSession());
      }
      // RATE_LIMITED / transient → leave buffered for the next batch flush.
    }

    _queued = await _pingsDao.countPending();
    _pushState();
    await _updateNotification();
  }

  Future<void> _flushPending() async {
    final socket = _socket;
    if (socket == null || !socket.isConnected || _beatPlanId == null) return;
    while (true) {
      final rows = await _pingsDao.pendingForBeatPlan(_beatPlanId!, limit: 500);
      if (rows.isEmpty) break;
      final ack = await socket.updateLocationBatch(
        beatPlanId: _beatPlanId!,
        fixes: rows.map(_rowToFix).toList(growable: false),
      );
      if (!ack.ok) break;
      await _pingsDao.deleteByClientIds(
        rows.map((r) => r.clientPingId).toList(growable: false),
      );
      if (rows.length < 500) break;
    }
    _queued = await _pingsDao.countPending();
    _pushState();
  }

  Future<void> _onServerEvent(TrackingServerEvent event) async {
    switch (event) {
      case ConnectionStateEvent(:final connected):
        _connected = connected;
        if (connected) await _establishSession();
        _pushState();
        await _updateNotification();
      case StatusUpdateEvent(:final status):
        _status = status;
        if (_sessionId != null) {
          await _trackingDao.setStatus(_sessionId!, _statusWire(status));
        }
        _pushState();
        await _updateNotification();
      case ForceStoppedEvent(:final reason, :final summary):
        await _handleForceStopped(reason, summary);
      case AuthExpiredEvent():
        await _refreshToken();
      case ServerShuttingDownEvent():
        // Keep the outbox; socket auto-reconnects shortly.
        break;
      case TrackingErrorEvent():
        // RATE_LIMITED / transient — pings stay buffered, no action.
        break;
      case LocationBroadcastEvent():
        // Our own fixes aren't echoed back; nothing to do as the rep.
        break;
    }
  }

  /// Open (or resume) the server session and flush anything buffered. Sent on
  /// every connect — the server makes `start-tracking` idempotent.
  Future<void> _establishSession() async {
    final socket = _socket;
    if (socket == null || !socket.isConnected || _beatPlanId == null) return;
    final ack = await socket.startTracking(_beatPlanId!);
    if (!ack.ok) {
      if (ack.code == 'BEAT_PLAN_NOT_ASSIGNED') {
        await _handleForceStopped(
          ForceStopReason.unknown,
          null,
          reasonLabel: 'Not assigned to you',
        );
      }
      return;
    }
    // Re-established successfully — clear any prior stale-pause for display.
    _status = TrackingStatus.active;
    final sid = ack.sessionId;
    if (sid != null && sid.isNotEmpty && sid != _sessionId) {
      final prev = _sessionId;
      _sessionId = sid;
      if (prev != null) {
        await _trackingDao.renameSession(prev, sid);
      } else {
        await _trackingDao.upsertSession(
          TrackingSessionsCompanion.insert(
            id: sid,
            beatPlanId: _beatPlanId!,
            status: const Value<String>('ACTIVE'),
            startedAt: Value<DateTime>(_startedAt ?? DateTime.now()),
          ),
        );
      }
      _service.invoke(TrackingIpc.evtSession, <String, dynamic>{
        TrackingIpc.kBeatPlanId: _beatPlanId,
        TrackingIpc.kSessionId: sid,
      });
    }
    await _flushPending();
  }

  void updateProgress({
    required int total,
    required int visited,
    required int skipped,
  }) {
    _total = total;
    _visited = visited;
    _skipped = skipped;
    unawaited(TrackingPrefs.updateProgress(
      total: total,
      visited: visited,
      skipped: skipped,
    ));
    _pushState();
    unawaited(_updateNotification());
  }

  Future<void> _handleForceStopped(
    ForceStopReason reason,
    TrackingSummary? summary, {
    String? reasonLabel,
  }) async {
    await _flushPending();
    await _finish(
      reason: reason,
      reasonLabel: reasonLabel ?? reason.displayLabel,
      summary: summary,
      event: TrackingIpc.evtForceStopped,
    );
  }

  Future<void> _finish({
    required ForceStopReason? reason,
    required String? reasonLabel,
    required TrackingSummary? summary,
    required String event,
  }) async {
    _status = TrackingStatus.completed;
    await _gpsSub?.cancel();
    _gpsSub = null;
    if (_sessionId != null) {
      await _trackingDao.markCompleted(_sessionId!, DateTime.now());
    }

    final payload = <String, dynamic>{
      TrackingIpc.kBeatPlanId: _beatPlanId,
      if (_sessionId != null) TrackingIpc.kSessionId: _sessionId,
      if (reason != null) TrackingIpc.kReason: reason.name,
      if (reasonLabel != null) TrackingIpc.kReasonLabel: reasonLabel,
      if (summary != null) ...<String, dynamic>{
        'totalDistanceKm': summary.totalDistanceKm,
        'totalDurationMin': summary.totalDurationMin,
        'averageSpeedKmh': summary.averageSpeedKmh,
        'directoriesVisited': summary.directoriesVisited,
      },
    };
    _service.invoke(event, payload);

    await TrackingPrefs.clear();
    await _pingsDao.clearForBeatPlan(_beatPlanId ?? '');
    await cancelTrackingNotification(_notifications);
    await _shutdown();
  }

  /// Finalize the outgoing plan's session before switching to a new one.
  /// Runs while the socket is still up so buffered pings get one last flush,
  /// then marks the local session COMPLETED (so it can't resurface as a ghost
  /// ACTIVE row via `activeForBeatPlan` on the next launch) and discards any
  /// pings that couldn't flush — mirrors `_finish`'s finalization minus the
  /// service shutdown. Uses the still-current `_beatPlanId` / `_sessionId`,
  /// which `start()` reassigns only after this returns.
  Future<void> _finalizePriorSession() async {
    final priorBeatPlanId = _beatPlanId;
    await _flushPending();
    if (_sessionId != null) {
      await _trackingDao.markCompleted(_sessionId!, DateTime.now());
    }
    if (priorBeatPlanId != null) {
      await _pingsDao.clearForBeatPlan(priorBeatPlanId);
    }
    _sessionId = null;
  }

  /// Tear down the socket/GPS for a plan switch without stopping the service.
  Future<void> _teardownTrackingOnly() async {
    await _gpsSub?.cancel();
    _gpsSub = null;
    await _socketSub?.cancel();
    _socketSub = null;
    await _socket?.dispose();
    _socket = null;
    _connected = false;
  }

  Future<void> _shutdown() async {
    _started = false;
    _ticker?.cancel();
    _ticker = null;
    await _teardownTrackingOnly();
    await _db.close();
    await _service.stopSelf();
  }

  Future<void> _refreshToken() async {
    if (_refreshing) return;
    // De-dupe the burst of AuthExpiredEvents the reconnect loop emits while a
    // token is expired — at most one refresh attempt every few seconds.
    final now = DateTime.now();
    final last = _lastRefreshAt;
    if (last != null && now.difference(last) < const Duration(seconds: 3)) {
      return;
    }
    _lastRefreshAt = now;
    _refreshing = true;
    try {
      final refresh = await _tokens.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        // Tokens already cleared (e.g. the UI logged out, or the HTTP
        // interceptor hit a terminal refresh failure and signalled the UI).
        // Nothing to do here — don't re-trigger a logout.
        return;
      }
      final resp = await _refreshDio.post<Map<String, dynamic>>(
        Endpoints.refresh,
        data: <String, String>{'refreshToken': refresh},
      );
      final data = resp.data?['data'];
      final tokens = data is Map ? data['tokens'] : null;
      final access = tokens is Map ? tokens['access'] as String? : null;
      final newRefresh = tokens is Map ? tokens['refresh'] as String? : null;
      if (access == null || newRefresh == null) return;
      await _tokens.save(accessToken: access, refreshToken: newRefresh);
      _socket?.updateToken(access);
      _socket?.reconnect();
    } on DioException catch (e) {
      // A 4xx means the refresh token itself is dead (rotated / revoked /
      // 7-day expiry) — the background isolate can't recover. Nudge the UI to
      // clear auth and route to /login; the next login pushes a fresh token
      // back here via cmd.reauth. Network/5xx errors are transient: keep
      // buffering and let a later connect_error / tick retry.
      final status = e.response?.statusCode;
      if (status != null && status >= 400 && status < 500) {
        _service.invoke(TrackingIpc.evtAuthExpired);
      }
    } on Object {
      // Unexpected — keep buffering; a later retry or the UI auth flow recovers.
    } finally {
      _refreshing = false;
    }
  }

  /// Re-read the freshest access token from secure storage and reconnect the
  /// socket. Sent by the UI (via `cmd.reauth`) after a (re)login so a session
  /// that was looping on a stale/expired token recovers at once. No-op when not
  /// tracking or when no token is available yet.
  Future<void> _reauth() async {
    if (!_started) return;
    final token = await _tokens.readAccessToken();
    if (token == null || token.isEmpty) return;
    final socket = _socket;
    if (socket == null) {
      await _connectSocket();
      return;
    }
    socket.updateToken(token);
    socket.reconnect();
  }

  Future<void> _tick() async {
    if (!_started) return;
    await _readBattery();
    _queued = await _pingsDao.countPending();
    _pushState();
    await _updateNotification();

    // Backstop for missed `tracking-force-stopped` events (socket down, or the
    // server didn't push): poll the plan ~every 30s and close tracking if it's
    // COMPLETED / gone server-side (e.g. a manager force-completed it).
    _tickCount++;
    if (_tickCount.isEven) {
      await _reconcileServerState();
    }
  }

  /// Best-effort server reconcile: if the beat plan is COMPLETED (or 404/gone),
  /// run the same shutdown path as a server force-stop. Auth header is attached
  /// manually since the bg Dio is interceptor-free; any other error is ignored
  /// and retried next cycle.
  Future<void> _reconcileServerState() async {
    final beatPlanId = _beatPlanId;
    if (!_started || beatPlanId == null) return;
    try {
      final token = await _tokens.readAccessToken();
      if (token == null || token.isEmpty) return;
      final resp = await _refreshDio.get<Map<String, dynamic>>(
        Endpoints.beatPlanById(beatPlanId),
        options: Options(
          headers: <String, String>{'Authorization': 'Bearer $token'},
        ),
      );
      final data = resp.data?['data'];
      final status = data is Map ? data['status'] as String? : null;
      if (status == 'COMPLETED') {
        await _handleForceStopped(
          ForceStopReason.forceCompleted,
          null,
          reasonLabel: ForceStopReason.forceCompleted.displayLabel,
        );
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Plan deleted/gone server-side → close tracking.
        await _handleForceStopped(
          ForceStopReason.unknown,
          null,
          reasonLabel: 'Tracking ended',
        );
      }
      // Other errors (offline/timeout/401): best-effort, retry next cycle.
    } on Object {
      // Never let a reconcile failure break tracking.
    }
  }

  /// Best-effort battery read. A platform-channel failure must never break the
  /// GPS/socket pipeline — on error we keep the last cached value.
  Future<void> _readBattery() async {
    try {
      _batteryLevel = await _battery.batteryLevel;
    } on Object {
      // Keep the previous cached value (or null).
    }
  }

  /// Best-effort reverse-geocode to a short, human address. Bounded by a short
  /// timeout and never throws — on failure/offline the ping just carries a null
  /// address (the server stores null; the map marker still works on lat/lng).
  Future<String?> _reverseGeocode(double latitude, double longitude) async {
    try {
      final marks = await placemarkFromCoordinates(latitude, longitude)
          .timeout(const Duration(seconds: 5));
      if (marks.isEmpty) return null;
      final p = marks.first;
      final parts = <String?>[
        p.name,
        p.subLocality,
        p.locality,
        p.administrativeArea,
      ].where((s) => s != null && s.trim().isNotEmpty).cast<String>();
      // De-dupe consecutive repeats (e.g. name == subLocality) while keeping order.
      final seen = <String>{};
      final address = parts.where(seen.add).join(', ');
      return address.isEmpty ? null : address;
    } on Object {
      return null;
    }
  }

  void _pushState() {
    _service.invoke(TrackingIpc.evtState, <String, dynamic>{
      TrackingIpc.kBeatPlanId: _beatPlanId,
      TrackingIpc.kStatus: _status.name,
      TrackingIpc.kConnected: _connected,
      TrackingIpc.kLat: _lastLat,
      TrackingIpc.kLng: _lastLng,
      TrackingIpc.kDistanceKm: _distanceKm,
      TrackingIpc.kDurationSec: _startedAt == null
          ? 0
          : DateTime.now().difference(_startedAt!).inSeconds,
      TrackingIpc.kQueued: _queued,
      TrackingIpc.kTotal: _total,
      TrackingIpc.kVisited: _visited,
      TrackingIpc.kSkipped: _skipped,
      TrackingIpc.kBattery: _batteryLevel,
    });
  }

  Future<void> _updateNotification() async {
    final connection = _connected ? '🟢 Online' : '🔴 Offline';
    final title = _status == TrackingStatus.paused
        ? 'Tracking paused'
        : 'Tracking your beat plan';
    final body = StringBuffer(connection);
    if (_batteryLevel != null) body.write(' · 🔋 $_batteryLevel%');
    if (_queued > 0) body.write(' · $_queued queued');
    body.write('\n${_distanceKm.toStringAsFixed(2)} km');
    if (_total > 0) {
      body.write(' · ${_visited + _skipped}/$_total stops');
    }
    try {
      await showTrackingNotification(
        _notifications,
        beatPlanId: _beatPlanId ?? '',
        title: title,
        body: body.toString(),
        paused: _status == TrackingStatus.paused,
        whenEpochMs: _startedAt?.millisecondsSinceEpoch ??
            DateTime.now().millisecondsSinceEpoch,
        maxProgress: _total > 0 ? _total : null,
        progress: _total > 0 ? (_visited + _skipped) : null,
      );
    } on Object {
      // A notification failure must never break the GPS/socket pipeline.
    }
  }

  LocationFix _rowToFix(TrackingPingRow r) => LocationFix(
        clientPingId: r.clientPingId,
        latitude: r.latitude,
        longitude: r.longitude,
        recordedAt: r.recordedAt,
        accuracy: r.accuracy,
        speed: r.speed,
        heading: r.heading,
        address: r.address,
        batteryLevel: r.batteryLevel,
      );

  String _statusWire(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.active:
        return 'ACTIVE';
      case TrackingStatus.paused:
        return 'PAUSED';
      case TrackingStatus.completed:
        return 'COMPLETED';
    }
  }
}
