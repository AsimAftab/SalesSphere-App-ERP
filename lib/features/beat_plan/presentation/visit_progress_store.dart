import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the in-progress visit **start time per stop** (set when the rep
/// taps "Start" on a stop, before the visit is completed). Without this the
/// start time lives only in widget state and is lost on navigation, a tracking
/// reconnect, or an app/process restart — silently reverting the stop's card
/// from "Stop" back to "Start" and dropping the elapsed time. Cleared once the
/// visit is recorded (or skipped).
///
/// Keyed by stop id (globally unique), stored as one JSON map.
class VisitProgressStore {
  VisitProgressStore._();

  static const String _key = 'beat_plan.visit_started_at';

  static Future<Map<String, DateTime>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <String, DateTime>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      // Corrupt / partially-written JSON (e.g. process killed mid-write).
      // Drop it gracefully rather than crashing the detail page on launch.
      return <String, DateTime>{};
    }
    if (decoded is! Map) return <String, DateTime>{};
    final out = <String, DateTime>{};
    decoded.forEach((key, value) {
      final dt = value is String ? DateTime.tryParse(value) : null;
      if (key is String && dt != null) out[key] = dt;
    });
    return out;
  }

  static Future<void> start(String stopId, DateTime at) async {
    final map = await load()
      ..[stopId] = at;
    await _save(map);
  }

  static Future<void> remove(String stopId) async {
    final map = await load()..remove(stopId);
    await _save(map);
  }

  static Future<void> _save(Map<String, DateTime> map) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      map.map((key, value) => MapEntry(key, value.toIso8601String())),
    );
    await prefs.setString(_key, encoded);
  }
}
