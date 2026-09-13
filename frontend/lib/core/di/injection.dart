import 'package:get_it/get_it.dart';

import '../auth/session_events.dart';
import '../network/api_client.dart';
import '../network/token_storage.dart';
import '../../features/auth/data/datasources/auth_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/profile/data/datasources/profile_data_source.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/get_current_profile.dart';
import '../../features/profile/domain/usecases/update_profile.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/motorcycles/data/datasources/motorcycle_data_source.dart';
import '../../features/motorcycles/data/repositories/motorcycle_repository_impl.dart';
import '../../features/motorcycles/domain/repositories/motorcycle_repository.dart';
import '../../features/motorcycles/domain/usecases/create_motorcycle.dart';
import '../../features/motorcycles/domain/usecases/delete_motorcycle.dart';
import '../../features/motorcycles/domain/usecases/get_motorcycle_by_id.dart';
import '../../features/motorcycles/domain/usecases/get_motorcycles.dart';
import '../../features/motorcycles/domain/usecases/update_motorcycle.dart';
import '../../features/motorcycles/presentation/cubit/motorcycle_cubit.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  if (!getIt.isRegistered<SessionEvents>()) {
    getIt.registerLazySingleton<SessionEvents>(SessionEvents.new);
  }
  if (!getIt.isRegistered<TokenStorage>()) {
    getIt.registerLazySingleton<TokenStorage>(TokenStorage.new);
  }
  if (!getIt.isRegistered<ApiClient>()) {
    getIt.registerLazySingleton<ApiClient>(
      () => ApiClient(getIt<TokenStorage>(), getIt<SessionEvents>()),
    );
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
    getIt.registerFactory<AuthCubit>(
      () => AuthCubit(getIt<AuthRepository>(), getIt<SessionEvents>()),
    );
  }
  if (!getIt.isRegistered<ProfileDataSource>()) getIt.registerLazySingleton(() => ProfileDataSource(getIt<ApiClient>().dio));
  if (!getIt.isRegistered<ProfileRepository>()) getIt.registerLazySingleton<ProfileRepository>(() => ProfileRepositoryImpl(getIt<ProfileDataSource>()));
  if (!getIt.isRegistered<GetCurrentProfile>()) getIt.registerLazySingleton(() => GetCurrentProfile(getIt<ProfileRepository>()));
  if (!getIt.isRegistered<UpdateProfile>()) getIt.registerLazySingleton(() => UpdateProfile(getIt<ProfileRepository>()));
  if (!getIt.isRegistered<ProfileCubit>()) getIt.registerFactory(() => ProfileCubit(getIt<GetCurrentProfile>(), getIt<UpdateProfile>()));

  if (!getIt.isRegistered<MotorcycleDataSource>()) getIt.registerLazySingleton(() => MotorcycleDataSource(getIt<ApiClient>().dio));
  if (!getIt.isRegistered<MotorcycleRepository>()) getIt.registerLazySingleton<MotorcycleRepository>(() => MotorcycleRepositoryImpl(getIt<MotorcycleDataSource>()));
  if (!getIt.isRegistered<GetMotorcycles>()) getIt.registerLazySingleton(() => GetMotorcycles(getIt<MotorcycleRepository>()));
  if (!getIt.isRegistered<GetMotorcycleById>()) getIt.registerLazySingleton(() => GetMotorcycleById(getIt<MotorcycleRepository>()));
  if (!getIt.isRegistered<CreateMotorcycle>()) getIt.registerLazySingleton(() => CreateMotorcycle(getIt<MotorcycleRepository>()));
  if (!getIt.isRegistered<UpdateMotorcycle>()) getIt.registerLazySingleton(() => UpdateMotorcycle(getIt<MotorcycleRepository>()));
  if (!getIt.isRegistered<DeleteMotorcycle>()) getIt.registerLazySingleton(() => DeleteMotorcycle(getIt<MotorcycleRepository>()));
  if (!getIt.isRegistered<MotorcycleCubit>()) getIt.registerFactory(() => MotorcycleCubit(getIt<GetMotorcycles>(), getIt<GetMotorcycleById>(), getIt<CreateMotorcycle>(), getIt<UpdateMotorcycle>(), getIt<DeleteMotorcycle>()));
}
