import 'package:shared_preferences/shared_preferences.dart';

/// The current tracking "intent", persisted so it survives process death and
/// crosses the UI ↔ background isolate boundary. The UI writes it before
/// starting the service; the background isolate reads it on start (covering
/// the invoke-before-listener race and process-restart resume); the
/// cold-start reconciler reads it to decide whether to relaunch the service.
class TrackingIntent {
  const TrackingIntent({
    required this.active,
    required this.beatPlanId,
    required this.total,
    required this.visited,
    required this.skipped,
    required this.resume,
  });

  final bool active;
  final String beatPlanId;
  final int total;
  final int visited;
  final int skipped;

  /// Whether a (re)start should resume the existing session rather than reset
  /// it. Set true once a session exists so a watchdog / cold-start restart
  /// preserves the running duration + distance instead of zeroing them.
  final bool resume;
}

class TrackingPrefs {
  TrackingPrefs._();

  static const String _active = 'tracking.active';
  static const String _beatPlanId = 'tracking.beatPlanId';
  static const String _total = 'tracking.total';
  static const String _visited = 'tracking.visited';
  static const String _skipped = 'tracking.skipped';
  static const String _resume = 'tracking.resume';

  static Future<void> saveStart({
    required String beatPlanId,
    required int total,
    required int visited,
    required int skipped,
    bool resume = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_active, true);
    await prefs.setString(_beatPlanId, beatPlanId);
    await prefs.setInt(_total, total);
    await prefs.setInt(_visited, visited);
    await prefs.setInt(_skipped, skipped);
    await prefs.setBool(_resume, resume);
  }

  /// Flag the active intent as resumable — called by the service once a session
  /// exists, so any later process restart resumes it instead of resetting.
  static Future<void> markResumable() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_active) ?? false)) return;
    await prefs.setBool(_resume, true);
  }

  static Future<void> updateProgress({
    required int total,
    required int visited,
    required int skipped,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_active) ?? false)) return;
    await prefs.setInt(_total, total);
    await prefs.setInt(_visited, visited);
    await prefs.setInt(_skipped, skipped);
  }

  static Future<TrackingIntent?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final beatPlanId = prefs.getString(_beatPlanId);
    if (beatPlanId == null || beatPlanId.isEmpty) return null;
    return TrackingIntent(
      active: prefs.getBool(_active) ?? false,
      beatPlanId: beatPlanId,
      total: prefs.getInt(_total) ?? 0,
      visited: prefs.getInt(_visited) ?? 0,
      skipped: prefs.getInt(_skipped) ?? 0,
      resume: prefs.getBool(_resume) ?? false,
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_active);
    await prefs.remove(_beatPlanId);
    await prefs.remove(_total);
    await prefs.remove(_visited);
    await prefs.remove(_skipped);
    await prefs.remove(_resume);
  }
}
