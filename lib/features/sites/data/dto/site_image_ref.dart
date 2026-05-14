/// Slim view of one image slot on a site's gallery, derived from
/// `GET /api/v1/sites/{id}/images`. Mirrors `PartyImageRef`: the
/// mobile UI only needs the slot number (for upsert/delete) and the
/// URL (for rendering in the edit form's picker). The wire DTO has
/// `id`, `imagePublicId`, and `createdAt` too — those are dropped
/// because the picker doesn't surface them.
///
/// Backend convention (same as customer images): `sortOrder =
/// imageNumber - 1`. We flip back to 1-indexed slots here so call
/// sites match the POST/DELETE `imageNumber` URL/form param.
class SiteImageRef {
  const SiteImageRef({required this.slot, required this.url});

  factory SiteImageRef.fromJson(Map<String, dynamic> json) => SiteImageRef(
        slot: (json['sortOrder'] as num).toInt() + 1,
        url: json['imageUrl'] as String,
      );

  final int slot;
  final String url;
}
