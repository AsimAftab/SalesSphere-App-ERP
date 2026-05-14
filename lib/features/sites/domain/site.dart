import 'package:sales_sphere_erp/features/sites/domain/site_contact.dart';
import 'package:sales_sphere_erp/shared/domain/interest.dart';

/// UI-facing site model. Decoupled from wire DTOs so backend renames
/// don't ripple into widgets. Will be promoted to freezed once the
/// sites API + drift table land.
class Site {
  const Site({
    required this.id,
    required this.name,
    required this.address,
    required this.ownerName,
    required this.phone,
    this.subOrganizationId,
    this.subOrganizationName,
    this.email,
    this.dateJoined,
    this.interests = const <Interest>[],
    this.contacts = const <SiteContact>[],
    this.notes,
    this.latitude,
    this.longitude,
    this.imagePaths = const <String>[],
  });

  final String id;
  final String name;
  final String address;

  /// Required by the form's `Validators.requiredField` / `phone10` on
  /// both add and edit — kept non-nullable here so the form contract
  /// and the domain shape agree.
  final String ownerName;
  final String phone;

  /// Optional sub-organization (branch / division) the site belongs to.
  /// Resolved against the catalogue exposed by `siteSubOrganizationsProvider`.
  final String? subOrganizationId;

  /// Display name for the selected sub-organization. The server's
  /// create/update endpoints expect the name (server resolves to id +
  /// auto-upserts the row); on read the wire returns both the id and a
  /// nested `subOrganization.name` block which we expose here so the
  /// detail page round-trips without an extra catalogue lookup.
  final String? subOrganizationName;

  // Other optional details captured by the add-site form.
  final String? email;
  final DateTime? dateJoined;

  /// Multi-select category + brand pairs. Same shape as the prospect
  /// interest list — sites used to carry per-category contacts on each
  /// entry but the (category → contacts) link was dropped, so the
  /// entries are now plain [Interest]s.
  final List<Interest> interests;

  /// Secondary points of contact at the site (name + phone). Capped at
  /// 4 by the `SiteContactPicker` widget — the cap isn't enforced at
  /// the entity level so backend-driven imports can carry more without
  /// the model throwing.
  final List<SiteContact> contacts;

  final String? notes;
  final double? latitude;
  final double? longitude;

  /// Up to two attached image paths (gallery picks). Empty when none have
  /// been added.
  final List<String> imagePaths;
}
