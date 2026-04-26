enum Flavor { dev, staging, prod }

extension FlavorX on Flavor {
  String get displayName => switch (this) {
        Flavor.dev => 'Dev',
        Flavor.staging => 'Staging',
        Flavor.prod => 'Prod',
      };

  bool get isProd => this == Flavor.prod;
  bool get isDev => this == Flavor.dev;
}

Flavor flavorFromString(String value) {
  return switch (value.toLowerCase()) {
    'dev' => Flavor.dev,
    'staging' => Flavor.staging,
    'prod' => Flavor.prod,
    _ => throw ArgumentError('Unknown flavor "$value"'),
  };
}
