/// Where a trip leg was started or stopped. Latitude/longitude are captured
/// from the device; [address] is the best-effort reverse-geocoded label (may
/// be null when the platform couldn't resolve one).
class TripLocation {
  const TripLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? address;
}
