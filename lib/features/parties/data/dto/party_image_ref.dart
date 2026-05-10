/// Slim view of one image slot on a customer's gallery, derived from
/// `GET /customers/{id}/images`. The mobile UI only cares about the
/// slot number (for upsert/delete) and the URL (for rendering in the
/// edit form's picker) — the wire DTO has `id`, `imagePublicId`, and
/// `createdAt` too, but we don't surface those.
///
/// Backend convention: `sortOrder = imageNumber - 1`. We flip back to
/// 1-indexed slots here so call sites match the POST/DELETE
/// `imageNumber` URL/form param.
class PartyImageRef {
  const PartyImageRef({required this.slot, required this.url});

  factory PartyImageRef.fromJson(Map<String, dynamic> json) => PartyImageRef(
        slot: (json['sortOrder'] as num).toInt() + 1,
        url: json['imageUrl'] as String,
      );

  final int slot;
  final String url;
}
