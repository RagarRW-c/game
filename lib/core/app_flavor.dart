enum AppFlavor {
  dev,
  prod,
}

abstract final class AppFlavorConfig {
  static const String _flavorName = String.fromEnvironment(
    'FLAVOR',
    defaultValue: 'prod',
  );

  static AppFlavor get current {
    switch (_flavorName) {
      case 'dev':
        return AppFlavor.dev;
      case 'prod':
        return AppFlavor.prod;
      default:
        throw StateError(
          'Unsupported FLAVOR="$_flavorName". Use "dev" or "prod".',
        );
    }
  }

  static bool get isDev => current == AppFlavor.dev;

  static bool get qaToolsEnabled => isDev;

  static String get appName => isDev ? 'Tile Adventure DEV' : 'Tile Adventure';
}
