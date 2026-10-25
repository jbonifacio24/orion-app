import 'package:flutter/foundation.dart';

import 'environment_local.dart';

enum AppEnvironment { development, production }

abstract final class EnvironmentConfig {
  static const _environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const googleClientId =
      '630600846169-ndjjrtu5o323if7n9g57fv6njs4id4cl.apps.googleusercontent.com';
    static const googleIosClientId =
      String.fromEnvironment('IOS_GOOGLE_CLIENT_ID');
  static const mapboxAccessToken = mapboxAccessTokenLocal;

  static AppEnvironment get environment => _environment == 'production'
      ? AppEnvironment.production
      : AppEnvironment.development;

  static String get apiBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (environment == AppEnvironment.production) {
      throw StateError('API_BASE_URL es obligatorio en producción.');
    }
    if (defaultTargetPlatform == TargetPlatform.android)
      return 'http://10.0.2.2:5001/api';
    return 'http://localhost:5001/api';
  }
}
