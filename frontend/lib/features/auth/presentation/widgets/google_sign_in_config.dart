import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/environment_config.dart';

Future<void>? _initialization;

Future<void> initializeGoogleSignIn() {
  if (EnvironmentConfig.googleClientId.isEmpty) {
    throw StateError('Google sign-in is not configured.');
  }

  final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  if (isIos && EnvironmentConfig.googleIosClientId.isEmpty) {
    throw StateError('IOS_GOOGLE_CLIENT_ID es obligatorio en iOS.');
  }

  return _initialization ??= GoogleSignIn.instance.initialize(
    clientId: kIsWeb
        ? EnvironmentConfig.googleClientId
        : isIos
            ? EnvironmentConfig.googleIosClientId
            : null,
    serverClientId: kIsWeb ? null : EnvironmentConfig.googleClientId,
  );
}
