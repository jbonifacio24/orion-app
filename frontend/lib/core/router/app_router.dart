import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/foundation/presentation/pages/home_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/profile/presentation/pages/edit_profile_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/motorcycles/presentation/cubit/motorcycle_cubit.dart';
import '../../features/motorcycles/presentation/pages/create_motorcycle_page.dart';
import '../../features/motorcycles/presentation/pages/edit_motorcycle_page.dart';
import '../../features/motorcycles/presentation/pages/motorcycle_detail_page.dart';
import '../../features/motorcycles/presentation/pages/motorcycles_page.dart';
import '../../features/marketplace/presentation/cubit/categories_cubit.dart';
import '../../features/marketplace/presentation/cubit/favorites_cubit.dart';
import '../../features/marketplace/presentation/cubit/marketplace_cubit.dart';
import '../../features/marketplace/presentation/cubit/my_products_cubit.dart';
import '../../features/marketplace/presentation/cubit/product_detail_cubit.dart';
import '../../features/marketplace/presentation/cubit/product_form_cubit.dart';
import '../../features/marketplace/presentation/cubit/product_images_cubit.dart';
import '../../features/marketplace/presentation/pages/create_product_page.dart';
import '../../features/marketplace/presentation/pages/edit_product_page.dart';
import '../../features/marketplace/presentation/pages/favorites_page.dart';
import '../../features/marketplace/presentation/pages/marketplace_page.dart';
import '../../features/marketplace/presentation/pages/my_products_page.dart';
import '../../features/marketplace/presentation/pages/product_detail_page.dart';
import '../../features/marketplace/presentation/pages/manage_product_images_page.dart';
import '../../features/workshops/presentation/cubit/workshop_detail_cubit.dart';
import '../../features/workshops/presentation/cubit/workshops_cubit.dart';
import '../../features/workshops/presentation/pages/workshop_detail_page.dart';
import '../../features/workshops/presentation/pages/workshops_page.dart';
import '../../features/theft/presentation/cubit/my_theft_reports_cubit.dart';
import '../../features/theft/presentation/cubit/theft_report_detail_cubit.dart';
import '../../features/theft/presentation/cubit/theft_report_form_cubit.dart';
import '../../features/theft/presentation/cubit/theft_reports_cubit.dart';
import '../../features/theft/presentation/pages/create_theft_report_page.dart';
import '../../features/theft/presentation/pages/my_theft_reports_page.dart';
import '../../features/theft/presentation/pages/theft_report_detail_page.dart';
import '../../features/theft/presentation/pages/theft_reports_page.dart';
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
      name: RouteNames.notifications,
      path: '/notifications',
      builder: (context, state) => const NotificationsPage(),
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
    GoRoute(name: RouteNames.marketplace, path: '/marketplace', builder: (context, state) => MultiBlocProvider(providers: [BlocProvider(create: (_) => getIt<MarketplaceCubit>()), BlocProvider(create: (_) => getIt<CategoriesCubit>())], child: const MarketplacePage())),
    GoRoute(name: RouteNames.marketplaceProductDetail, path: '/marketplace/products/:id', builder: (context, state) => BlocProvider(create: (_) => getIt<ProductDetailCubit>(), child: ProductDetailPage(id: state.pathParameters['id']!))),
    GoRoute(name: RouteNames.marketplaceCreate, path: '/marketplace/create', builder: (context, state) => MultiBlocProvider(providers: [BlocProvider(create: (_) => getIt<CategoriesCubit>()), BlocProvider(create: (_) => getIt<ProductFormCubit>(param1: ProductFormMode.create))], child: const CreateProductPage())),
    GoRoute(name: RouteNames.marketplaceProductEdit, path: '/marketplace/products/:id/edit', builder: (context, state) => MultiBlocProvider(providers: [BlocProvider(create: (_) => getIt<CategoriesCubit>()), BlocProvider(create: (_) => getIt<ProductDetailCubit>())], child: EditProductPage(productId: state.pathParameters['id']!))),
    GoRoute(name: RouteNames.marketplaceProductImages, path: '/marketplace/products/:id/images', builder: (context, state) => BlocProvider(create: (_) => getIt<ProductImagesCubit>(), child: ManageProductImagesPage(productId: state.pathParameters['id']!, fromCreate: state.uri.queryParameters['from'] == 'create'))),
    GoRoute(name: RouteNames.myProducts, path: '/my-products', builder: (context, state) => BlocProvider(create: (_) => getIt<MyProductsCubit>(), child: const MyProductsPage())),
    GoRoute(name: RouteNames.favorites, path: '/favorites', builder: (context, state) => BlocProvider(create: (_) => getIt<FavoritesCubit>(), child: const FavoritesPage())),
    GoRoute(name: RouteNames.workshops, path: '/workshops', builder: (context, state) => BlocProvider(create: (_) => getIt<WorkshopsCubit>(), child: const WorkshopsPage())),
    GoRoute(name: RouteNames.workshopDetail, path: '/workshops/:id', builder: (context, state) => BlocProvider(create: (_) => getIt<WorkshopDetailCubit>(), child: WorkshopDetailPage(id: state.pathParameters['id']!))),
    ...theftReportRoutes(),
  ],
  );
}

List<RouteBase> theftReportRoutes() => [
      GoRoute(name: RouteNames.theftReports, path: '/theft-reports', builder: (context, state) => BlocProvider(create: (_) => getIt<TheftReportsCubit>(), child: const TheftReportsPage())),
      GoRoute(name: RouteNames.myTheftReports, path: '/theft-reports/mine', builder: (context, state) => BlocProvider(create: (_) => getIt<MyTheftReportsCubit>(), child: const MyTheftReportsPage())),
      GoRoute(name: RouteNames.theftReportCreate, path: '/theft-reports/create', builder: (context, state) => BlocProvider(create: (_) => getIt<TheftReportFormCubit>(), child: const CreateTheftReportPage())),
      GoRoute(name: RouteNames.theftReportDetail, path: '/theft-reports/:id', builder: (context, state) => BlocProvider(create: (_) => getIt<TheftReportDetailCubit>(), child: TheftReportDetailPage(id: state.pathParameters['id']!))),
    ];
