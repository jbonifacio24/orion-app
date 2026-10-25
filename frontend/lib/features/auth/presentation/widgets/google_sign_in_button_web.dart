import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart';

import 'google_sign_in_config.dart';

class GoogleSignInButton extends StatefulWidget {
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
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  late final Future<void> _ready;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _ready = _initialize();
  }

  Future<void> _initialize() async {
    await initializeGoogleSignIn();
    _subscription = GoogleSignIn.instance.authenticationEvents.listen(
      (event) {
        if (event case GoogleSignInAuthenticationEventSignIn(:final user)) {
          unawaited(_submitIdToken(user));
        }
      },
      onError: (Object error) => widget.onError(error),
    );
  }

  Future<void> _submitIdToken(GoogleSignInAccount account) async {
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      widget.onError(StateError('Google no devolvió un token de identidad.'));
      return;
    }
    await widget.onIdToken(idToken);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: null,
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
                ),
                const SizedBox(height: 12),
                const Text('Google no está configurado.'),
              ],
            );
          }
          if (snapshot.connectionState != ConnectionState.done ||
              widget.isLoading) {
            return const SizedBox(
              height: 44,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return SizedBox(height: 44, child: renderButton());
        },
      );
}
