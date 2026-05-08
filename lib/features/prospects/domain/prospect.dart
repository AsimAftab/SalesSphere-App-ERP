import 'package:sales_sphere_erp/shared/domain/interest.dart';

/// UI-facing prospect model. Decoupled from wire DTOs so backend renames
/// don't ripple into widgets. Will be promoted to freezed once the
/// prospects API + drift table land.
class Prospect {
  const Prospect({
    required this.id,
    required this.name,
    required this.address,
    required this.ownerName,
    required this.phone,
    this.panVat,
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

  /// Required by the form's `Validators.requiredField` / `phone10` on
  /// both add and edit — kept non-nullable here so the form contract
  /// and the domain shape agree.
  final String ownerName;
  final String phone;

  // Other optional details captured by the add-prospect form.
  final String? panVat;
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
