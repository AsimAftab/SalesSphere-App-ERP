/// Slim view of one image slot on a prospect's gallery, derived from
/// `GET /prospects/{id}/images`. The mobile UI only cares about the
/// slot number (for upsert/delete) and the URL (for rendering in the
/// edit form's picker) — the wire DTO has `id`, `imagePublicId`, and
/// `createdAt` too, but we don't surface those.
///
/// Backend convention: `sortOrder = imageNumber - 1`. We flip back to
/// 1-indexed slots here so call sites match the POST/DELETE
/// `imageNumber` URL/form param.
class ProspectImageRef {
  const ProspectImageRef({required this.slot, required this.url});

  factory ProspectImageRef.fromJson(Map<String, dynamic> json) =>
      ProspectImageRef(
        slot: (json['sortOrder'] as num).toInt() + 1,
        url: json['imageUrl'] as String,
      );

  final int slot;
  final String url;
}
