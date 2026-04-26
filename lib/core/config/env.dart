import 'flavors.dart';

class Env {
  const Env._({
    required this.flavor,
    required this.apiBaseUrl,
    required this.wsBaseUrl,
    required this.sentryDsn,
    required this.googleMapsAndroidKey,
  });

  final Flavor flavor;
  final String apiBaseUrl;
  final String wsBaseUrl;
  final String sentryDsn;
  final String googleMapsAndroidKey;

  static const _flavor = String.fromEnvironment('FLAVOR');
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const _wsBaseUrl = String.fromEnvironment('WS_BASE_URL');
  static const _sentryDsn = String.fromEnvironment('SENTRY_DSN');
  static const _googleMapsAndroidKey =
      String.fromEnvironment('GOOGLE_MAPS_ANDROID_KEY');

  static Env? _current;

  static Env get current {
    final env = _current;
    if (env == null) {
      throw StateError(
        'Env not initialised. Call Env.initialise() from your flavor entrypoint.',
      );
    }
    return env;
  }

  static Env initialise() {
    if (_flavor.isEmpty) {
      throw StateError(
        'FLAVOR not provided. Run with --dart-define-from-file=env/<flavor>.json',
      );
    }
    final env = Env._(
      flavor: flavorFromString(_flavor),
      apiBaseUrl: _apiBaseUrl,
      wsBaseUrl: _wsBaseUrl,
      sentryDsn: _sentryDsn,
      googleMapsAndroidKey: _googleMapsAndroidKey,
    );
    _current = env;
    return env;
  }
}
