/// UI-facing model for a one-off field task. Decoupled from wire DTOs
/// so backend renames don't ripple into widgets. Will be promoted to
/// freezed once the miscellaneous-work API + drift table land.
class MiscellaneousWork {
  const MiscellaneousWork({
    required this.id,
    required this.natureOfWork,
    required this.assignedBy,
    required this.workDate,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    this.imagePaths = const <String>[],
  });

  final String id;
  final String natureOfWork;
  final String assignedBy;
  final DateTime workDate;

  final String address;
  final double latitude;
  final double longitude;

  /// Up to two attached image paths (gallery picks). Empty when none
  /// have been added.
  final List<String> imagePaths;

  /// Timestamp the record was created. Distinct from `workDate`
  /// (which is the date the work happened); the list page sorts by
  /// `createdAt` descending so the most recently logged row floats
  /// to the top.
  final DateTime createdAt;
}
