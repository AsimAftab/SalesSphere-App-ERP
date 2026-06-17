import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:sales_sphere_erp/features/profile/presentation/controllers/profile_controller.dart';

part 'permissions.g.dart';

/// Backend RBAC permission strings used by the mobile app. The server is
/// authoritative — these gate the UI only (hide/disable actions the user
/// can't perform) so a denied call never surprises the user with a 403.
abstract final class Permissions {
  static const odometerRecord = 'odometer:record';
  static const odometerView = 'odometer:view';
  static const odometerDelete = 'odometer:delete';

  static const unplannedVisitView = 'unplanned-visits:view';
  static const unplannedVisitRecord = 'unplanned-visits:record';
  static const unplannedVisitDelete = 'unplanned-visits:delete';
}

/// Whether the signed-in user's active-membership role grants [permission].
///
/// Reads the active membership's role permissions from
/// [profileControllerProvider]. OrgAdmin holds the `*` wildcard, which grants
/// everything. While the profile is still loading (or absent) this returns
/// `true` — the action stays visible and the backend remains the real gate —
/// so the UI doesn't flicker actions off then on as the profile resolves.
@riverpod
bool hasPermission(Ref ref, String permission) {
  final profile = ref.watch(profileControllerProvider).value;
  if (profile == null) return true;
  final perms = profile.activeMembership?.role.permissions ?? const <String>[];
  return perms.contains('*') || perms.contains(permission);
}
