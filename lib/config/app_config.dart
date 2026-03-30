class AppConfig {
  AppConfig._();

  static const bool _isProduction = false;

  static const String _productionBase = 'https://luckybobastores.com';
  static const String _devBase = 'http://192.168.1.126:8000';

  static String get baseUrl =>
      _isProduction ? _productionBase : _devBase;

  static String get apiUrl => '$baseUrl/api';

  // ✅ Add this
  static String get storageUrl => '$baseUrl/storage';
}