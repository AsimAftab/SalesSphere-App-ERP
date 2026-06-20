/// Which kind of entity an unplanned visit is made to. Exactly one is set per
/// visit (the "select customer / prospect / site" requirement), mirroring how
/// a note links to one party/prospect/site.
enum VisitTargetType { customer, prospect, site }

extension VisitTargetTypeX on VisitTargetType {
  /// Human label for chips/headers. `customer` reads as `Party` — the mobile
  /// app speaks "party" for customers (matches the beat-plan stop badge).
  String get label => switch (this) {
    VisitTargetType.customer => 'Party',
    VisitTargetType.prospect => 'Prospect',
    VisitTargetType.site => 'Site',
  };

  /// Lowercase wire value used by the backend's `target.type`.
  String get wire => switch (this) {
    VisitTargetType.customer => 'customer',
    VisitTargetType.prospect => 'prospect',
    VisitTargetType.site => 'site',
  };
}

/// The entity an unplanned visit is/was made to. Used both as the picker's
/// result (write side — the rep selects who they're visiting) and as the
/// denormalised target the backend returns on read, so the list/detail pages
/// render without a cross-feature lookup.
///
/// [latitude]/[longitude] are the geofence anchor: the start flow blocks
/// unless the rep is within range of them. They're nullable because a
/// customer/site/prospect may not have coordinates recorded — in that case the
/// geofence gate is skipped (there's nothing to measure against).
class VisitTarget {
  const VisitTarget({
    required this.type,
    required this.id,
    required this.displayName,
    this.address,
    this.latitude,
    this.longitude,
  });

  final VisitTargetType type;
  final String id;
  final String displayName;
  final String? address;
  final double? latitude;
  final double? longitude;

  /// True when both coordinates are present, i.e. the geofence can be enforced.
  bool get hasLocation => latitude != null && longitude != null;
}
