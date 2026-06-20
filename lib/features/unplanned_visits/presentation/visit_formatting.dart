// Dependency-free formatting helpers for unplanned-visit timestamps. Kept
// pure-Dart (no `intl`) to match the feature's lightweight formatting layer.

/// 12-hour clock time, e.g. `3:45 PM`. Returns `--` for null.
String formatVisitTime(DateTime? value) {
  if (value == null) return '--';
  final local = value.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '$hour12:$minute $period';
}

/// Calendar day, e.g. `2026-06-17`. Returns `--` for null.
String formatVisitDate(DateTime? value) {
  if (value == null) return '--';
  final d = value.toLocal();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Visit length from the server-computed seconds, e.g. `1h 23m` / `5m 30s` /
/// `45s`. Seconds are shown for sub-hour durations so short visits don't read
/// as `0m`. Returns `--` for null.
String formatVisitDuration(int? seconds) {
  if (seconds == null) return '--';
  if (seconds < 60) return '${seconds}s';
  final mins = seconds ~/ 60;
  final secs = seconds % 60;
  if (mins < 60) return secs == 0 ? '${mins}m' : '${mins}m ${secs}s';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}
