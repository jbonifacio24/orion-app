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
import '../../features/marketplace/data/datasources/marketplace_data_source.dart';
import '../../features/marketplace/data/pickers/product_image_picker.dart';
import '../../features/marketplace/data/repositories/marketplace_repository_impl.dart';
import '../../features/marketplace/domain/entities/product.dart';
import '../../features/marketplace/domain/repositories/marketplace_repository.dart';
import '../../features/marketplace/domain/services/product_image_picker.dart';
import '../../features/marketplace/domain/usecases/add_favorite.dart';
import '../../features/marketplace/domain/usecases/create_product.dart';
import '../../features/marketplace/domain/usecases/delete_product.dart';
import '../../features/marketplace/domain/usecases/get_categories.dart';
import '../../features/marketplace/domain/usecases/get_favorites.dart';
import '../../features/marketplace/domain/usecases/get_my_products.dart';
import '../../features/marketplace/domain/usecases/get_product_detail.dart';
import '../../features/marketplace/domain/usecases/get_products.dart';
import '../../features/marketplace/domain/usecases/remove_favorite.dart';
import '../../features/marketplace/domain/usecases/update_product.dart';
import '../../features/marketplace/domain/usecases/upload_product_image.dart';
import '../../features/marketplace/domain/usecases/delete_product_image.dart';
import '../../features/marketplace/domain/usecases/set_primary_product_image.dart';
import '../../features/marketplace/presentation/cubit/categories_cubit.dart';
import '../../features/marketplace/presentation/cubit/favorites_cubit.dart';
import '../../features/marketplace/presentation/cubit/marketplace_cubit.dart';
import '../../features/marketplace/presentation/cubit/my_products_cubit.dart';
import '../../features/marketplace/presentation/cubit/product_detail_cubit.dart';
import '../../features/marketplace/presentation/cubit/product_form_cubit.dart';
import '../../features/marketplace/presentation/cubit/product_images_cubit.dart';
import '../../features/workshops/data/datasources/workshop_data_source.dart';
import '../../features/workshops/data/repositories/workshop_repository_impl.dart';
import '../../features/workshops/domain/repositories/workshop_repository.dart';
import '../../features/workshops/domain/usecases/get_workshop_detail.dart';
import '../../features/workshops/domain/usecases/get_workshops.dart';
import '../../features/workshops/presentation/cubit/workshop_detail_cubit.dart';
import '../../features/workshops/presentation/cubit/workshops_cubit.dart';

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

  if (!getIt.isRegistered<MarketplaceDataSource>()) getIt.registerLazySingleton(() => MarketplaceDataSource(getIt<ApiClient>().dio));
  if (!getIt.isRegistered<IProductImagePicker>()) getIt.registerLazySingleton<IProductImagePicker>(() => const FilePickerProductImagePicker());
  if (!getIt.isRegistered<MarketplaceRepository>()) getIt.registerLazySingleton<MarketplaceRepository>(() => MarketplaceRepositoryImpl(getIt<MarketplaceDataSource>()));
  if (!getIt.isRegistered<GetProducts>()) getIt.registerLazySingleton(() => GetProducts(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<GetProductDetail>()) getIt.registerLazySingleton(() => GetProductDetail(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<GetMyProducts>()) getIt.registerLazySingleton(() => GetMyProducts(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<CreateProduct>()) getIt.registerLazySingleton(() => CreateProduct(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<UpdateProduct>()) getIt.registerLazySingleton(() => UpdateProduct(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<DeleteProduct>()) getIt.registerLazySingleton(() => DeleteProduct(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<GetCategories>()) getIt.registerLazySingleton(() => GetCategories(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<GetFavorites>()) getIt.registerLazySingleton(() => GetFavorites(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<AddFavorite>()) getIt.registerLazySingleton(() => AddFavorite(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<RemoveFavorite>()) getIt.registerLazySingleton(() => RemoveFavorite(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<UploadProductImage>()) getIt.registerLazySingleton(() => UploadProductImage(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<DeleteProductImage>()) getIt.registerLazySingleton(() => DeleteProductImage(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<SetPrimaryProductImage>()) getIt.registerLazySingleton(() => SetPrimaryProductImage(getIt<MarketplaceRepository>()));
  if (!getIt.isRegistered<MarketplaceCubit>()) getIt.registerFactory(() => MarketplaceCubit(getIt<GetProducts>()));
  if (!getIt.isRegistered<MyProductsCubit>()) getIt.registerFactory(() => MyProductsCubit(getIt<GetMyProducts>()));
  if (!getIt.isRegistered<CategoriesCubit>()) getIt.registerFactory(() => CategoriesCubit(getIt<GetCategories>()));
  if (!getIt.isRegistered<FavoritesCubit>()) getIt.registerFactory(() => FavoritesCubit(getIt<GetFavorites>(), getIt<AddFavorite>(), getIt<RemoveFavorite>()));
  if (!getIt.isRegistered<ProductDetailCubit>()) getIt.registerFactory(() => ProductDetailCubit(getIt<GetProductDetail>(), getIt<AddFavorite>(), getIt<RemoveFavorite>(), getIt<DeleteProduct>()));
  if (!getIt.isRegistered<ProductFormCubit>()) getIt.registerFactoryParam<ProductFormCubit, ProductFormMode, Product?>((mode, initial) => ProductFormCubit(getIt<CreateProduct>(), getIt<UpdateProduct>(), mode: mode, initial: initial));
  if (!getIt.isRegistered<ProductImagesCubit>()) getIt.registerFactory(() => ProductImagesCubit(getIt<GetProductDetail>(), getIt<IProductImagePicker>(), getIt<UploadProductImage>(), getIt<DeleteProductImage>(), getIt<SetPrimaryProductImage>()));
  if (!getIt.isRegistered<WorkshopDataSource>()) getIt.registerLazySingleton(() => WorkshopDataSource(getIt<ApiClient>().dio));
  if (!getIt.isRegistered<WorkshopRepository>()) getIt.registerLazySingleton<WorkshopRepository>(() => WorkshopRepositoryImpl(getIt<WorkshopDataSource>()));
  if (!getIt.isRegistered<GetWorkshops>()) getIt.registerLazySingleton(() => GetWorkshops(getIt<WorkshopRepository>()));
  if (!getIt.isRegistered<GetWorkshopDetail>()) getIt.registerLazySingleton(() => GetWorkshopDetail(getIt<WorkshopRepository>()));
  if (!getIt.isRegistered<WorkshopsCubit>()) getIt.registerFactory(() => WorkshopsCubit(getIt<GetWorkshops>()));
  if (!getIt.isRegistered<WorkshopDetailCubit>()) getIt.registerFactory(() => WorkshopDetailCubit(getIt<GetWorkshopDetail>()));
}
