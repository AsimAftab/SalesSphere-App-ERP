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

  // Collections — granted on every plan, including CRM-only orgs that have no
  // ledger at all. A rep typically holds `view-own` rather than `view`; the
  // server narrows their list reads either way, so the UI gates on whichever
  // of the two is present.
  //
  // There is no `collections:post` / `collections:cancel`. A plain Collection
  // is a pure CRM record that never touches a ledger, so the backend has no
  // such routes and those keys have been deleted from the catalog — a role can
  // never hold them again. Posting and cancelling live only in Collection Plus.
  static const collectionsView = 'collections:view';
  static const collectionsViewOwn = 'collections:view-own';
  static const collectionsCreate = 'collections:create';
  static const collectionsUpdate = 'collections:update';
  static const collectionsDelete = 'collections:delete';
  static const collectionsChequeStatus = 'collections:cheque-status';
  static const collectionsManageImages = 'collections:manage-images';

  // Collection Plus — ACCOUNTING plans only. Effective permissions are
  // `role ∩ plan`, so these keys simply don't exist in a CRM-only tenant's
  // session and every `/collection-plus` route 403s. That's the whole
  // feature gate: no flag, no special-casing — just hide the tile.
  static const collectionView = 'collection-plus:view';
  static const collectionViewOwn = 'collection-plus:view-own';
  static const collectionCreate = 'collection-plus:create';
  static const collectionUpdate = 'collection-plus:update';
  static const collectionDelete = 'collection-plus:delete';
  static const collectionPost = 'collection-plus:post';
  static const collectionCancel = 'collection-plus:cancel';
  static const collectionChequeStatus = 'collection-plus:cheque-status';
  static const collectionManageImages = 'collection-plus:manage-images';
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

/// Whether the role grants **any** of [permissions]. Same fail-open-while-
/// loading contract as [hasPermission].
///
/// Needed because a module's read access is an either-or: a field rep holds
/// `<module>:view-own` while a supervisor holds `<module>:view`, and the
/// server narrows the query per-caller. Gating on `view` alone would hide the
/// feature from every rep who can legitimately use it.
@riverpod
bool hasAnyPermission(Ref ref, List<String> permissions) {
  final profile = ref.watch(profileControllerProvider).value;
  if (profile == null) return true;
  final perms = profile.activeMembership?.role.permissions ?? const <String>[];
  if (perms.contains('*')) return true;
  return permissions.any(perms.contains);
}
