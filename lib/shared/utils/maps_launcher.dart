import 'package:url_launcher/url_launcher.dart';

/// Opens the given coordinates in the OS-level maps experience —
/// Google Maps app on Android (via the `https://www.google.com/maps`
/// deep link), or a browser fallback when the app isn't installed.
///
/// `label`, when provided, is the pin caption that Google Maps shows
/// next to the marker (typically the party / prospect name).
///
/// Returns `true` when the launch was handed off successfully. Callers
/// should surface their own error UX on `false`.
Future<bool> openInMaps({
  required double lat,
  required double lng,
  String? label,
}) async {
  final query = Uri.encodeComponent(
    label != null && label.trim().isNotEmpty ? '$lat,$lng($label)' : '$lat,$lng',
  );
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$query',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
