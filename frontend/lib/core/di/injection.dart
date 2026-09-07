import 'package:get_it/get_it.dart';

import '../network/api_client.dart';
import '../network/token_storage.dart';
import '../../features/auth/data/datasources/auth_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  if (!getIt.isRegistered<TokenStorage>()) {
    getIt.registerLazySingleton<TokenStorage>(TokenStorage.new);
  }
  if (!getIt.isRegistered<ApiClient>()) {
    getIt.registerLazySingleton<ApiClient>(() => ApiClient(getIt<TokenStorage>()));
  }
  if (!getIt.isRegistered<AuthDataSource>()) {
    getIt.registerLazySingleton<AuthDataSource>(() => AuthDataSource(getIt<ApiClient>().dio));
  }
  if (!getIt.isRegistered<AuthRepository>()) {
    getIt.registerLazySingleton<AuthRepository>(() => AuthRepositoryImpl(
          getIt<AuthDataSource>(),
          getIt<TokenStorage>(),
        ));
  }
  if (!getIt.isRegistered<AuthCubit>()) {
    getIt.registerFactory<AuthCubit>(() => AuthCubit(getIt<AuthRepository>()));
  }
}
