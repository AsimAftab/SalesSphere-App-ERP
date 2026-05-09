import 'package:flutter/foundation.dart' show immutable;

/// Sub-organization (branch / division) a site can be tagged with.
/// Backed today by a mocked list inside `SitesApi` — swap to a real
/// fetch once the backend exposes a `/sub-organizations` endpoint.
@immutable
class SubOrganization {
  const SubOrganization({required this.id, required this.name});

  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SubOrganization && other.id == id && other.name == name);

  @override
  int get hashCode => Object.hash(id, name);
}
