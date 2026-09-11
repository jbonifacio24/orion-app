import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';

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
      builder: (context, child) => BlocProvider<AuthCubit>.value(
        value: widget.authCubit,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
