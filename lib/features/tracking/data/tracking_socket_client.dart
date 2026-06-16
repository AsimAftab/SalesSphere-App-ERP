import 'dart:async';

import 'package:sales_sphere_erp/features/tracking/domain/tracking_models.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Thin, isolate-agnostic wrapper over `socket_io_client` encoding the
/// `live-tracking-socket.md` contract. Holds no Riverpod / Flutter deps so it
/// runs inside the background-service isolate.
///
/// Auth: the access JWT is supplied via `setAuthFn`, which re-reads
/// [_token] on every (re)connect — so after the runtime refreshes the token
/// and calls [updateToken], the next reconnect authenticates with the fresh
/// one without rebuilding the socket. Brief drops auto-recover (the server's
/// connection-state recovery); the runtime flushes its ping outbox on each
/// `connect`.
class TrackingSocketClient {
  TrackingSocketClient({
    required String origin,
    required String token,
    void Function(String message, {Object? error})? log,
  })  : _origin = _normaliseOrigin(origin),
        _token = token,
        _log = log;

  final String _origin;
  final void Function(String message, {Object? error})? _log;
  String _token;

  io.Socket? _socket;
  final StreamController<TrackingServerEvent> _events =
      StreamController<TrackingServerEvent>.broadcast();

  Stream<TrackingServerEvent> get events => _events.stream;
  bool get isConnected => _socket?.connected ?? false;

  /// Update the in-memory token used by `setAuthFn` on the next (re)connect.
  void updateToken(String token) => _token = token;

  void connect() {
    if (_socket != null) return;
    final url = '$_origin/v1/tracking';
    final socket = io.io(
      url,
      io.OptionBuilder()
          .setPath('/realtime')
          .setTransports(<String>['websocket', 'polling'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(8000)
          .setReconnectionAttempts(1 << 30)
          .setAuthFn((callback) => callback(<String, String>{'token': _token}))
          .build(),
    );
    _wire(socket);
    _socket = socket;
    socket.connect();
  }

  /// Force an immediate reconnect (used after a token refresh). The auth fn
  /// re-reads the freshest [_token].
  void reconnect() {
    final socket = _socket;
    if (socket == null) {
      connect();
      return;
    }
    socket
      ..disconnect()
      ..connect();
  }

  Future<void> disconnect() async {
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      socket.dispose();
    }
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }

  // ── Client → server (ack-bearing) ─────────────────────────────────────────
  Future<TrackingAck> startTracking(String beatPlanId) =>
      _emit('start-tracking', <String, dynamic>{'beatPlanId': beatPlanId});

  Future<TrackingAck> updateLocation({
    required String beatPlanId,
    required LocationFix fix,
  }) =>
      _emit('update-location', fix.toLiveJson(beatPlanId));

  Future<TrackingAck> updateLocationBatch({
    required String beatPlanId,
    required List<LocationFix> fixes,
  }) =>
      _emit('update-location-batch', <String, dynamic>{
        'beatPlanId': beatPlanId,
        'pings': fixes.map((f) => f.toPingJson()).toList(growable: false),
      });

  Future<TrackingAck> pause(String beatPlanId) =>
      _emit('pause-tracking', <String, dynamic>{'beatPlanId': beatPlanId});

  Future<TrackingAck> resume(String beatPlanId) =>
      _emit('resume-tracking', <String, dynamic>{'beatPlanId': beatPlanId});

  Future<TrackingAck> stop(String beatPlanId) =>
      _emit('stop-tracking', <String, dynamic>{'beatPlanId': beatPlanId});

  // ── Internals ─────────────────────────────────────────────────────────────
  Future<TrackingAck> _emit(
    String event,
    Map<String, dynamic> data, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future<TrackingAck>.value(
        const TrackingAck(ok: false, code: 'NOT_CONNECTED'),
      );
    }
    final completer = Completer<TrackingAck>();
    socket.emitWithAck(
      event,
      data,
      ack: (dynamic resp) {
        if (!completer.isCompleted) completer.complete(_parseAck(resp));
      },
    );
    return completer.future.timeout(
      timeout,
      onTimeout: () => const TrackingAck(ok: false, code: 'ACK_TIMEOUT'),
    );
  }

  void _wire(io.Socket socket) {
    socket
      ..onConnect((_) {
        _log?.call('tracking socket connected');
        _emitEvent(const ConnectionStateEvent(connected: true));
      })
      ..onDisconnect((dynamic reason) {
        _log?.call('tracking socket disconnected: $reason');
        _emitEvent(ConnectionStateEvent(connected: false, reason: '$reason'));
      })
      ..onConnectError((dynamic err) {
        final message = _errorMessage(err);
        _log?.call('tracking connect_error: $message');
        // The handshake rejected us. UNAUTHORIZED/AUTH_EXPIRED → ask the
        // runtime to refresh + reconnect; other codes surface as errors.
        if (message == 'UNAUTHORIZED' || message == 'AUTH_EXPIRED') {
          _emitEvent(const AuthExpiredEvent());
        } else {
          _emitEvent(TrackingErrorEvent(code: 'CONNECT_ERROR', message: message));
        }
      })
      ..on('location-update', (dynamic data) {
        final ev = _parseLocationUpdate(data);
        if (ev != null) _emitEvent(ev);
      })
      ..on('tracking-status-update', (dynamic data) {
        final ev = _parseStatusUpdate(data);
        if (ev != null) _emitEvent(ev);
      })
      ..on('tracking-force-stopped', (dynamic data) {
        final ev = _parseForceStopped(data);
        if (ev != null) _emitEvent(ev);
      })
      ..on('tracking-error', (dynamic data) {
        final map = _asMap(data);
        _emitEvent(TrackingErrorEvent(
          code: (map?['code'] as String?) ?? 'INTERNAL_ERROR',
          message: map?['message'] as String?,
        ));
      })
      ..on('auth-expired', (_) => _emitEvent(const AuthExpiredEvent()))
      ..on('server-shutting-down',
          (_) => _emitEvent(const ServerShuttingDownEvent()));
  }

  void _emitEvent(TrackingServerEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  TrackingAck _parseAck(dynamic resp) {
    final map = _asMap(resp);
    if (map == null) {
      return const TrackingAck(ok: false, code: 'BAD_ACK');
    }
    final ok = map['ok'] == true;
    return TrackingAck(
      ok: ok,
      code: _asString(map['code']),
      message: _asString(map['message']),
      data: Map<String, dynamic>.from(map),
    );
  }

  LocationBroadcastEvent? _parseLocationUpdate(dynamic data) {
    final map = _asMap(data);
    if (map == null) return null;
    final beatPlanId = _asString(map['beatPlanId']);
    final loc = _asMap(map['location']);
    if (beatPlanId == null || loc == null) return null;
    final lat = (loc['latitude'] as num?)?.toDouble();
    final lng = (loc['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LocationBroadcastEvent(
      beatPlanId: beatPlanId,
      latitude: lat,
      longitude: lng,
      recordedAt: _parseDate(loc['recordedAt']),
      address: _asString(loc['address']),
    );
  }

  StatusUpdateEvent? _parseStatusUpdate(dynamic data) {
    final map = _asMap(data);
    if (map == null) return null;
    final beatPlanId = _asString(map['beatPlanId']);
    if (beatPlanId == null) return null;
    final summaryMap = _asMap(map['summary']);
    return StatusUpdateEvent(
      beatPlanId: beatPlanId,
      status: TrackingStatus.fromWire(_asString(map['status'])),
      reason: _asString(map['reason']),
      summary: summaryMap == null ? null : TrackingSummary.fromJson(summaryMap),
    );
  }

  ForceStoppedEvent? _parseForceStopped(dynamic data) {
    final map = _asMap(data);
    if (map == null) return null;
    final beatPlanId = _asString(map['beatPlanId']);
    if (beatPlanId == null) return null;
    final summaryMap = _asMap(map['summary']);
    return ForceStoppedEvent(
      beatPlanId: beatPlanId,
      reason: ForceStopReason.fromWire(_asString(map['reason'])),
      sessionId: _asString(map['sessionId']),
      summary: summaryMap == null ? null : TrackingSummary.fromJson(summaryMap),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    if (v is List && v.isNotEmpty) return _asMap(v.first);
    return null;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  /// Coerce a payload field to `String?` without throwing — the backend may
  /// send a non-string (int/bool/list) where we expect text, and a hard
  /// `as String?` cast would raise a runtime `TypeError`.
  static String? _asString(Object? v) => v is String ? v : null;

  static String _errorMessage(dynamic err) {
    if (err is String) return err;
    final map = _asMap(err);
    if (map != null) {
      return _asString(map['message']) ?? _asString(map['code']) ?? '$err';
    }
    return '$err';
  }

  static String _normaliseOrigin(String raw) {
    var origin = raw.trim();
    if (origin.endsWith('/')) origin = origin.substring(0, origin.length - 1);
    if (origin.startsWith('wss://')) {
      return 'https://${origin.substring(6)}';
    }
    if (origin.startsWith('ws://')) {
      return 'http://${origin.substring(5)}';
    }
    return origin;
  }
}
