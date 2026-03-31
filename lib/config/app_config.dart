class AppConfig {
  AppConfig._();

  // Injected at build time via --dart-define
  // CI sets this to 'true' for prod/staging, empty for dev
  static const String _env = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static bool get isProduction => _env == 'production';
  static bool get isStaging => _env == 'staging';
  static bool get isDev => _env == 'development';

  static const String _productionBase = 'https://luckybobastores.com';
  static const String _stagingBase = 'https://staging.luckybobastores.com';
  static const String _devBase = 'http://192.168.1.126:8000';

  static String get baseUrl {
    if (isProduction) return _productionBase;
    if (isStaging) return _stagingBase;
    return _devBase;
  }

  static String get apiUrl => '$baseUrl/api';
  static String get storageUrl => '$baseUrl/storage';
}