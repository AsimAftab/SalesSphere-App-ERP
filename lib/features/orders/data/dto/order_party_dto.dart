/// The "Bill To" party block embedded in an invoice / estimate response,
/// sourced from the linked Customer. The wire field is `panNo`; the domain
/// keeps `panVat` (the repository mapper translates).
class OrderPartyDto {
  const OrderPartyDto({
    required this.id,
    required this.name,
    this.ownerName,
    this.address,
    this.phone,
    this.panVat,
  });

  factory OrderPartyDto.fromJson(Map<String, dynamic> json) => OrderPartyDto(
    id: json['id'] as String,
    name: json['name'] as String,
    ownerName: json['ownerName'] as String?,
    address: json['address'] as String?,
    phone: json['phone'] as String?,
    panVat: json['panVat'] as String?,
  );

  final String id;
  final String name;
  final String? ownerName;
  final String? address;
  final String? phone;
  final String? panVat;
}
