/// UI-facing party model. Decoupled from wire DTOs so backend renames don't
/// ripple into widgets. Will be promoted to freezed once the parties API
/// + drift table land.
class Party {
  const Party({
    required this.id,
    required this.name,
    required this.address,
    required this.ownerName,
    required this.phone,
    required this.panVat,
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

  /// Required by the form's `Validators.requiredField` / `phone10` /
  /// `panVat` on both add and edit — kept non-nullable here so the form
  /// contract and the domain shape agree.
  final String ownerName;
  final String phone;
  final String panVat;

  // Other optional details captured by the add-party form.
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
