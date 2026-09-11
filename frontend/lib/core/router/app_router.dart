import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/foundation/presentation/pages/home_page.dart';
import 'route_names.dart';
import 'router_refresh_notifier.dart';

GoRouter createAppRouter(AuthCubit authCubit) {
  final refreshNotifier = RouterRefreshNotifier(authCubit);
  return GoRouter(
  initialLocation: '/splash',
  refreshListenable: refreshNotifier,
  redirect: (context, state) {
    final authState = authCubit.state;
    final isLoading = authState is AuthInitial || authState is AuthLoading;
    final isAuthenticated = authState is AuthAuthenticated;
    final isPublic = state.matchedLocation == '/login' || state.matchedLocation == '/register';
    if (isLoading && state.matchedLocation != '/splash') return '/splash';
    if (!isLoading && !isAuthenticated && !isPublic && state.matchedLocation != '/splash') {
      return '/login';
    }
    if (!isLoading && isAuthenticated && (isPublic || state.matchedLocation == '/splash')) {
      return '/home';
    }
    if (!isLoading && !isAuthenticated && state.matchedLocation == '/splash') return '/login';
    return null;
  },
  routes: [
    GoRoute(
      name: RouteNames.splash,
      path: '/splash',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      name: RouteNames.login,
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      name: RouteNames.register,
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),
    GoRoute(
      name: RouteNames.home,
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),
  ],
  );
}
