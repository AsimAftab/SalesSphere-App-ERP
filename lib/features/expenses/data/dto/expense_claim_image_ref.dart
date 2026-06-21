/// Slim view of one receipt slot on an expense claim's gallery, derived
/// from `GET/POST /expense-claims/{id}/images`. The mobile UI only cares
/// about the slot number (for upsert/delete) and the URL (for rendering
/// in the edit form's picker) — the wire response has `id`,
/// `imagePublicId`, and `createdAt` too, but we don't surface those.
///
/// Backend convention: `sortOrder = imageNumber - 1`. We flip back to
/// 1-indexed slots here so call sites match the POST/DELETE `imageNumber`
/// URL/form param. Identical contract to `/notes/{id}/images`.
class ExpenseClaimImageRef {
  const ExpenseClaimImageRef({required this.slot, required this.url});

  factory ExpenseClaimImageRef.fromJson(Map<String, dynamic> json) =>
      ExpenseClaimImageRef(
        slot: (json['sortOrder'] as num).toInt() + 1,
        url: json['imageUrl'] as String,
      );

  final int slot;
  final String url;
}
