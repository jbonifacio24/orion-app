import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/foundation/presentation/pages/home_page.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/motorcycles/presentation/cubit/motorcycle_cubit.dart';
import '../../features/motorcycles/presentation/pages/create_motorcycle_page.dart';
import '../../features/motorcycles/presentation/pages/edit_motorcycle_page.dart';
import '../../features/motorcycles/presentation/pages/motorcycle_detail_page.dart';
import '../../features/motorcycles/presentation/pages/motorcycles_page.dart';
import '../di/injection.dart';
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
    GoRoute(
      name: RouteNames.profile,
      path: '/profile',
      builder: (context, state) => BlocProvider(create: (_) => getIt<ProfileCubit>(), child: const ProfilePage()),
    ),
    GoRoute(
      name: RouteNames.profileEdit,
      path: '/profile/edit',
      builder: (context, state) => BlocProvider(create: (_) => getIt<ProfileCubit>()..loadProfile(), child: const EditProfilePage()),
    ),
    GoRoute(
      name: RouteNames.motorcycles,
      path: '/motorcycles',
      builder: (context, state) => BlocProvider(create: (_) => getIt<MotorcycleCubit>(), child: const MotorcyclesPage()),
    ),
    GoRoute(
      name: RouteNames.motorcycleCreate,
      path: '/motorcycles/create',
      builder: (context, state) => BlocProvider(create: (_) => getIt<MotorcycleCubit>(), child: const CreateMotorcyclePage()),
    ),
    GoRoute(
      name: RouteNames.motorcycleDetail,
      path: '/motorcycles/:id',
      builder: (context, state) => BlocProvider(create: (_) => getIt<MotorcycleCubit>(), child: MotorcycleDetailPage(id: state.pathParameters['id']!)),
    ),
    GoRoute(
      name: RouteNames.motorcycleEdit,
      path: '/motorcycles/:id/edit',
      builder: (context, state) => BlocProvider(create: (_) => getIt<MotorcycleCubit>()..loadMotorcycle(state.pathParameters['id']!), child: EditMotorcyclePage(id: state.pathParameters['id']!)),
    ),
  ],
  );
}
