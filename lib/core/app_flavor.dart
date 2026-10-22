import 'package:flutter/services.dart' show appFlavor;

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
    // Flutter derives appFlavor from the actual native build variant. A legacy
    // Dart define must never enable QA inside the production Android package.
    // The fallback preserves host-side tests and unflavored development tools.
    final flavorName = appFlavor ?? _flavorName;
    switch (flavorName) {
      case 'dev':
        return AppFlavor.dev;
      case 'prod':
        return AppFlavor.prod;
      default:
        throw StateError(
          'Unsupported app flavor. Use "dev" or "prod".',
        );
    }
  }

  static bool get isDev => current == AppFlavor.dev;

  static bool get qaToolsEnabled => isDev;

  static String get appName => isDev ? 'Tile Adventure DEV' : 'Tile Adventure';
}
