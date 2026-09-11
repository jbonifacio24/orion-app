import 'package:flutter/foundation.dart';

enum AppEnvironment { development, production }

abstract final class EnvironmentConfig {
  static const _environment = String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  static AppEnvironment get environment => _environment == 'production'
      ? AppEnvironment.production
      : AppEnvironment.development;

  static String get apiBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (environment == AppEnvironment.production) {
      throw StateError('API_BASE_URL es obligatorio en producción.');
    }
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:5001/api';
    return 'http://localhost:5001/api';
  }
}