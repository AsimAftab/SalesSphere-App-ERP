import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sales_sphere_erp/features/targets/data/repositories/targets_repository_impl.dart'
    show targetsRepositoryProvider;
import 'package:sales_sphere_erp/features/targets/domain/repositories/targets_repository.dart';

export 'package:sales_sphere_erp/features/targets/data/repositories/targets_repository_impl.dart'
    show targetsRepositoryProvider;

/// The day the rep is looking at. `null` = today, which goes over the wire
/// **param-less** so the server resolves "today" in the org's timezone —
/// deliberately not the device's date. Non-null = an explicit past day the
/// user navigated to, normalized to local-midnight Y/M/D.
class SelectedTargetDateNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Select a day. Today or later snaps back to the default (null) state:
  /// only the server can compare against org-timezone "today", so the device
  /// never sends its own idea of it.
  void select(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    state = day.isBefore(_today()) ? day : null;
  }

  void previousDay() => select((state ?? _today()).subtract(const Duration(days: 1)));

  /// No-op while already on today — the header disables the chevron too.
  void nextDay() {
    final current = state;
    if (current != null) select(current.add(const Duration(days: 1)));
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

final selectedTargetDateProvider =
    NotifierProvider<SelectedTargetDateNotifier, DateTime?>(
  SelectedTargetDateNotifier.new,
);

/// Fetches assigned targets for the selected day. Changing
/// [selectedTargetDateProvider] refetches automatically; pull-to-refresh
/// invalidates this provider directly.
final myTargetsProvider =
    FutureProvider.autoDispose<MyTargetsSnapshot>((ref) async {
  final date = ref.watch(selectedTargetDateProvider);
  final repository = ref.watch(targetsRepositoryProvider);
  return repository.getMyTargets(date: date);
});
