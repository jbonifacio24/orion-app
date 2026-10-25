import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/widgets/app_error_state.dart';
import '../cubit/auth_cubit.dart';
import '../widgets/google_sign_in_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String? _googleError;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    final loading = state is AuthLoading;
    final supportsGoogle =
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final compact = constraints.maxHeight < 700;

            return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 1200,
                    minHeight: constraints.maxHeight,
                    maxHeight: wide ? constraints.maxHeight : double.infinity,
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, progress, child) => Opacity(
                      opacity: progress,
                      child: Transform.translate(
                        offset: Offset(0, 18 * (1 - progress)),
                        child: child,
                      ),
                    ),
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                flex: 6,
                                child: _buildBrandPanel(
                                  context,
                                  wide: true,
                                  compact: compact,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: _buildSignInPanel(
                                  context,
                                  state: state,
                                  loading: loading,
                                  supportsGoogle: supportsGoogle,
                                  wide: true,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildBrandPanel(
                                context,
                                wide: false,
                                compact: compact,
                              ),
                              _buildSignInPanel(
                                context,
                                state: state,
                                loading: loading,
                                supportsGoogle: supportsGoogle,
                                wide: false,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandPanel(
    BuildContext context, {
    required bool wide,
    required bool compact,
  }) {
    final theme = Theme.of(context);

    return Container(
      color: const Color(0xFF1A2022),
      padding: EdgeInsets.symmetric(
        horizontal: wide ? 64 : 28,
        vertical: wide ? (compact ? 28 : 56) : (compact ? 24 : 32),
      ),
      child: Column(
        mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment:
            wide ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            'assets/images/motohub_logo.svg',
            width: wide ? 236 : 188,
            height: wide ? 75 : 60,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            semanticsLabel: 'MotoHub',
          ),
          SizedBox(height: wide ? (compact ? 36 : 64) : (compact ? 24 : 32)),
          Row(
            children: [
              Container(
                width: 24,
                height: 3,
                color: const Color(0xFFFF806D),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'MOTOCOMUNIDAD  /  RUTA 01',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: const Color(0xFFAFBDC2),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: Text.rich(
              const TextSpan(
                children: [
                  TextSpan(
                    text: 'Tu próxima ',
                  ),
                  TextSpan(
                    text: 'ruta empieza aquí.',
                    style: TextStyle(color: Color(0xFFFF806D)),
                  ),
                ],
              ),
              style: theme.textTheme.displaySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.04,
              ),
            ),
          ),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Text(
              'Compra, vende y comparte rutas con otros motociclistas.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: const Color(0xFFAFBDC2),
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: wide ? (compact ? 24 : 48) : 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 4.8,
              child: Image.asset(
                'assets/videos/motohub_route_loop.gif',
                fit: BoxFit.cover,
                gaplessPlayback: true,
                semanticLabel: 'Animación de ruta y motocicleta',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInPanel(
    BuildContext context, {
    required AuthState state,
    required bool loading,
    required bool supportsGoogle,
    required bool wide,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final alignment =
        wide ? CrossAxisAlignment.start : CrossAxisAlignment.center;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: wide ? 64 : 28, vertical: 36),
      child: Align(
        alignment: wide ? Alignment.centerLeft : Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: alignment,
            children: [
              Text(
                'Únete a MotoHub',
                textAlign: wide ? TextAlign.left : TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Inicia sesión con tu cuenta de Google para continuar.',
                textAlign: wide ? TextAlign.left : TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              if (_googleError != null) ...[
                AppErrorState(message: _googleError!),
                const SizedBox(height: 12),
              ],
              GoogleSignInButton(
                isLoading: loading,
                onIdToken: (idToken) {
                  setState(() => _googleError = null);
                  return context.read<AuthCubit>().loginWithGoogle(idToken);
                },
                onError: (error) {
                  if (mounted) {
                    setState(() => _googleError = error.toString());
                  }
                },
              ),
              if (!supportsGoogle) ...[
                const SizedBox(height: 12),
                Text(
                  'Google no está disponible en esta plataforma.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (state case AuthFailure(:final message)) ...[
                const SizedBox(height: 12),
                AppErrorState(message: message),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
