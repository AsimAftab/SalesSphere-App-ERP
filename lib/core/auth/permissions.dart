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

  // Collections — one unified module. The backend merged Collection Plus into
  // it, so `collection-plus:*` no longer exists in the catalog and a role can
  // never hold those keys again; a migration rewrote the granted ones across
  // to `collections:*`.
  //
  // The module ships on every plan, including CRM-only orgs with no ledger. A
  // rep typically holds `view-own` rather than `view` and the server narrows
  // their list reads either way, so gate reads on whichever of the two is
  // present — never on `view` alone.
  static const collectionsView = 'collections:view';
  static const collectionsViewOwn = 'collections:view-own';
  static const collectionsCreate = 'collections:create';
  static const collectionsUpdate = 'collections:update';
  static const collectionsDelete = 'collections:delete';
  static const collectionsChequeStatus = 'collections:cheque-status';
  static const collectionsManageImages = 'collections:manage-images';

  // Ledger-bound, and the exception to "every plan": effective permissions are
  // `role ∩ plan`, and the plan catalogue withholds these two from every
  // non-accounting tier. So a CRM-only tenant's session carries neither, their
  // receipts stay DRAFT forever, and posting UI must be gated on
  // [collectionsPost] rather than on holding the module at all.
  static const collectionsPost = 'collections:post';
  static const collectionsCancel = 'collections:cancel';

  /// Catalogue-only today — the backend defines the key but ships no
  /// `/collections/export` route, so gating a button on this would 404.
  static const collectionsExport = 'collections:export';
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
