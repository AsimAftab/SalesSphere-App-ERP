import 'package:sales_sphere_erp/shared/widgets/interest_picker.dart';

/// UI-facing prospect model. Decoupled from wire DTOs so backend renames
/// don't ripple into widgets. Will be promoted to freezed once the
/// prospects API + drift table land.
class Prospect {
  const Prospect({
    required this.id,
    required this.name,
    required this.address,
    this.ownerName,
    this.panVat,
    this.phone,
    this.email,
    this.dateJoined,
    this.interests = const <Interest>[],
    this.notes,
    this.latitude,
    this.longitude,
    this.imagePaths = const <String>[],
  });

  final String id;
  final String name;
  final String address;

  // Optional details captured by the add-prospect form.
  final String? ownerName;
  final String? panVat;
  final String? phone;
  final String? email;
  final DateTime? dateJoined;

  /// Multi-select category + brand pairs. Backed by the catalogue served
  /// by `prospectInterestsProvider`; the picker can also append new
  /// categories or brands inline.
  final List<Interest> interests;

  final String? notes;
  final double? latitude;
  final double? longitude;

  /// Up to two attached image paths (gallery picks). Empty when none have
  /// been added.
  final List<String> imagePaths;
}
