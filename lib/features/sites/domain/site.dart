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
    this.email,
    this.dateJoined,
    this.interests = const <Interest>[],
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

  // Other optional details captured by the add-site form.
  final String? email;
  final DateTime? dateJoined;

  /// Multi-select category + brand pairs. Same shape as the prospect
  /// interest list — sites used to carry per-category contacts on each
  /// entry but the (category → contacts) link was dropped, so the
  /// entries are now plain [Interest]s.
  final List<Interest> interests;

  final String? notes;
  final double? latitude;
  final double? longitude;

  /// Up to two attached image paths (gallery picks). Empty when none have
  /// been added.
  final List<String> imagePaths;
}
