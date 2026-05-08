import 'package:sales_sphere_erp/shared/widgets/interest_picker.dart';

/// UI-facing site model. Decoupled from wire DTOs so backend renames
/// don't ripple into widgets. Will be promoted to freezed once the
/// sites API + drift table land.
class Site {
  const Site({
    required this.id,
    required this.name,
    required this.address,
    this.ownerName,
    this.panVat,
    this.phone,
    this.email,
    this.dateJoined,
    this.interests = const <SiteInterest>[],
    this.notes,
    this.latitude,
    this.longitude,
    this.imagePaths = const <String>[],
  });

  final String id;
  final String name;
  final String address;

  // Optional details captured by the add-site form.
  final String? ownerName;
  final String? panVat;
  final String? phone;
  final String? email;
  final DateTime? dateJoined;

  /// Multi-select category + brand pairs. Each entry also carries its
  /// own list of (name, phone) contacts captured inside the same
  /// picker sheet via [SiteInterestPicker]. Sites embed contacts on the
  /// interest entries themselves so the (category → contacts) link is
  /// explicit at the data shape.
  final List<SiteInterest> interests;

  final String? notes;
  final double? latitude;
  final double? longitude;

  /// Up to two attached image paths (gallery picks). Empty when none have
  /// been added.
  final List<String> imagePaths;
}
