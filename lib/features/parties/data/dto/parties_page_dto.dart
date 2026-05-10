import 'package:sales_sphere_erp/features/parties/data/dto/party_dto.dart';

/// One paginated slice of `GET /customers`. The wire response is just an
/// array; `nextCursor` is computed client-side as `items.last.id` when the
/// page is full.
class PartiesPageDto {
  const PartiesPageDto({required this.items, this.nextCursor});

  final List<PartyDto> items;
  final String? nextCursor;
}
