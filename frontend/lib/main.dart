import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/notifications/presentation/cubit/notifications_cubit.dart';
import 'features/chat/presentation/cubit/conversations_cubit.dart';
import 'features/chat/domain/repositories/chat_realtime_repository.dart';
import 'features/chat/domain/entities/chat_entities.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await AppTheme.restoreThemeMode();
  runApp(MotoHubApp(authCubit: getIt<AuthCubit>()));
}

class MotoHubApp extends StatefulWidget {
  const MotoHubApp({required this.authCubit, this.restoreSessionOnStart = true, super.key});

  final AuthCubit authCubit;
  final bool restoreSessionOnStart;

  @override
  State<MotoHubApp> createState() => _MotoHubAppState();
}

class _MotoHubAppState extends State<MotoHubApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(widget.authCubit);
    if (widget.restoreSessionOnStart) {
      widget.authCubit.restoreSession();
    }
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, themeMode, _) => MaterialApp.router(
        title: 'MotoHub',
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: themeMode,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [Locale('es'), Locale('en')],
        routerConfig: _router,
        builder: (context, child) => MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: widget.authCubit),
          BlocProvider<NotificationsCubit>.value(value: getIt<NotificationsCubit>()),
          BlocProvider<ConversationsCubit>.value(value: getIt<ConversationsCubit>()),
        ],
        child: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              unawaited(getIt<ChatRealtimeRepository>().start());
            }
            if (state is AuthUnauthenticated) {
              context.read<NotificationsCubit>().clear();
              context.read<ConversationsCubit>().clear();
              unawaited(getIt<ChatRealtimeRepository>().stop());
            }
          },
          child: _IncomingMessageLayer(child: child ?? const SizedBox.shrink()),
        ),
        ),
      ),
    );
  }
}

class _IncomingMessageLayer extends StatefulWidget {
  const _IncomingMessageLayer({required this.child});

  final Widget child;

  @override
  State<_IncomingMessageLayer> createState() => _IncomingMessageLayerState();
}

class _IncomingMessageLayerState extends State<_IncomingMessageLayer> {
  StreamSubscription<ChatMessage>? _subscription;
  Timer? _hideTimer;
  ChatMessage? _message;

  @override
  void initState() {
    super.initState();
    _subscription = getIt<ChatRealtimeRepository>().messages.listen(_showMessage);
  }

  void _showMessage(ChatMessage message) {
    if (!mounted) return;
    context.read<ConversationsCubit>().incrementUnreadCount();
    _hideTimer?.cancel();
    setState(() => _message = message);
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _message = null);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          widget.child,
          AnimatedPositioned(
            duration: const Duration(milliseconds: 360),
            curve: Curves.easeOutCubic,
            top: _message == null ? -96 : 16,
            left: 16,
            right: 16,
            child: IgnorePointer(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                opacity: _message == null ? 0 : 1,
                child: _message == null ? const SizedBox(height: 72) : _IncomingMessageBanner(message: _message!),
              ),
            ),
          ),
        ],
      );
}

class _IncomingMessageBanner extends StatelessWidget {
  const _IncomingMessageBanner({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 12,
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.24), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Row(children: [
          CircleAvatar(backgroundColor: scheme.primary.withValues(alpha: 0.16), foregroundColor: scheme.primary, child: const Icon(Icons.mark_unread_chat_alt_rounded)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nuevo mensaje', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('${message.senderDisplayName}: ${message.content}', maxLines: 2, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }
}
