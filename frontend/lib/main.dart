import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/notifications/presentation/cubit/notifications_cubit.dart';
import 'features/chat/presentation/cubit/conversations_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
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
    return MaterialApp.router(
      title: 'MotoHub',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      builder: (context, child) => MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: widget.authCubit),
          BlocProvider<NotificationsCubit>.value(value: getIt<NotificationsCubit>()),
          BlocProvider<ConversationsCubit>.value(value: getIt<ConversationsCubit>()),
        ],
        child: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthUnauthenticated) {
              context.read<NotificationsCubit>().clear();
              context.read<ConversationsCubit>().clear();
            }
          },
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
