/// Slim view of one image slot on a miscellaneous-work row's gallery,
/// derived from `POST /miscellaneous-work/{id}/images` and the
/// embedded `images` array in `GET /miscellaneous-work/{id}`. The
/// mobile UI only cares about the slot number (for upsert/delete) and
/// the URL (for rendering in the edit form's picker) — the wire
/// response also has `id`, `imagePublicId`, and `createdAt`, but we
/// don't surface those.
///
/// Backend convention: `sortOrder = imageNumber - 1`. We flip back to
/// 1-indexed slots here so call sites match the POST/DELETE
/// `imageNumber` URL/form param.
class MiscellaneousWorkImageRef {
  const MiscellaneousWorkImageRef({required this.slot, required this.url});

  factory MiscellaneousWorkImageRef.fromJson(Map<String, dynamic> json) =>
      MiscellaneousWorkImageRef(
        slot: (json['sortOrder'] as num).toInt() + 1,
        url: json['imageUrl'] as String,
      );

  final int slot;
  final String url;
}
