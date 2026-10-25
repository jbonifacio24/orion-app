import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'google_sign_in_config.dart';

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.isLoading,
    required this.onIdToken,
    required this.onError,
    super.key,
  });

  final bool isLoading;
  final Future<void> Function(String idToken) onIdToken;
  final ValueChanged<Object> onError;

  @override
  Widget build(BuildContext context) {
    final isSupported = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    return OutlinedButton.icon(
      onPressed: isLoading || !isSupported ? null : () => _signIn(),
      icon: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      label: const Text('Continuar con Google'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Future<void> _signIn() async {
    try {
      await initializeGoogleSignIn();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError('Google no devolvió un token de identidad.');
      }
      await onIdToken(idToken);
    } catch (error) {
      onError(error);
    }
  }
}
