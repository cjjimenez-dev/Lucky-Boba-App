class AppConfig {
  AppConfig._();

  // ── 🚀 SET TO true TO TEST WITH HOSTINGER ────────────────────────────────
  static const bool _isProduction = false;

  static const String _productionBase = 'https://luckybobastores.com';
  static const String _devBase = 'http://10.0.2.2:8000';

  static String get baseUrl =>
      _isProduction ? _productionBase : _devBase;

  static String get apiUrl => '$baseUrl/api';
}