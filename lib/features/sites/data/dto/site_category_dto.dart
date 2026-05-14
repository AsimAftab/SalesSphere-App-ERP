/// Wire DTO for one row in `GET /api/v1/site-categories`. Carries the
/// server `id` so future write paths (assigning brands by id, renaming
/// a category) can reference the row without a name lookup. The mobile
/// domain `InterestCatalogue` consumes only name + brands today —
/// id stays on the DTO until a screen actually needs it.
///
/// Extra wire fields (`interestCount`, `createdAt`, `updatedAt`) are
/// intentionally dropped — none of them shape current UI.
class SiteCategoryDto {
  const SiteCategoryDto({
    required this.id,
    required this.name,
    required this.brands,
  });

  factory SiteCategoryDto.fromJson(Map<String, dynamic> json) {
    final rawBrands = json['brands'];
    final brands = rawBrands is List<dynamic>
        ? rawBrands.whereType<String>().toList(growable: false)
        : const <String>[];
    return SiteCategoryDto(
      id: json['id'] as String,
      name: json['name'] as String,
      brands: brands,
    );
  }

  final String id;
  final String name;
  final List<String> brands;
}
