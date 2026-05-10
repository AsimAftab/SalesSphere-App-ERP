import 'package:url_launcher/url_launcher.dart';

/// Opens the given coordinates in the OS-level maps experience —
/// Google Maps app on Android (via the `https://www.google.com/maps`
/// deep link), or a browser fallback when the app isn't installed.
///
/// Just drops a pin at the coordinates. We used to pass the party name
/// as a label (`lat,lng(name)`), but Google Maps interprets the
/// `query` parameter as a search string — supplying a name made it
/// search for "ACME Trading" near the coords instead of pinning the
/// location directly, which was the user-visible regression.
///
/// Returns `true` when the launch was handed off successfully. Callers
/// should surface their own error UX on `false`.
Future<bool> openInMaps({
  required double lat,
  required double lng,
}) async {
  final query = Uri.encodeComponent('$lat,$lng');
  final uri = Uri.parse(
    'https://www.google.com/maps/search/?api=1&query=$query',
  );
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
