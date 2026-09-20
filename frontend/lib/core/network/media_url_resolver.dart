import '../constants/environment_config.dart';

abstract final class MediaUrlResolver {
  static String resolve(String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.hasScheme) return url;
    final base = Uri.parse(EnvironmentConfig.apiBaseUrl);
    final path = url.startsWith('/') ? url : '/$url';
    return Uri(
      scheme: base.scheme,
      userInfo: base.userInfo,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
    ).toString();
  }
}