/// UI-facing party model. Decoupled from wire DTOs so backend renames don't
/// ripple into widgets. Will be promoted to freezed once the parties API
/// + drift table land.
class Party {
  const Party({
    required this.id,
    required this.name,
    required this.address,
    this.ownerName,
    this.panVat,
    this.phone,
    this.email,
    this.dateJoined,
    this.partyType,
    this.notes,
    this.latitude,
    this.longitude,
    this.imagePaths = const <String>[],
  });

  final String id;
  final String name;
  final String address;

  // Optional details captured by the add-party form.
  final String? ownerName;
  final String? panVat;
  final String? phone;
  final String? email;
  final DateTime? dateJoined;
  final String? partyType;
  final String? notes;
  final double? latitude;
  final double? longitude;

  /// Up to two attached image paths (gallery picks). Empty when none have
  /// been added.
  final List<String> imagePaths;
}
