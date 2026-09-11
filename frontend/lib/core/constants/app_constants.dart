import 'environment_config.dart';

abstract final class AppConstants {
  static const String appName = 'MotoHub';
  static String get apiBaseUrl => EnvironmentConfig.apiBaseUrl;
}
