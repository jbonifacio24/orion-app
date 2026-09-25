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
import '../../features/theft/data/datasources/theft_data_source.dart';
import '../../features/theft/data/repositories/theft_repository_impl.dart';
import '../../features/theft/domain/repositories/theft_repository.dart';
import '../../features/theft/domain/usecases/theft_report_usecases.dart';
import '../../features/theft/presentation/cubit/my_theft_reports_cubit.dart';
import '../../features/theft/presentation/cubit/theft_report_detail_cubit.dart';
import '../../features/theft/presentation/cubit/theft_report_form_cubit.dart';
import '../../features/theft/presentation/cubit/theft_reports_cubit.dart';
import '../../features/notifications/data/datasources/notifications_data_source.dart';
import '../../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../../features/notifications/domain/repositories/notifications_repository.dart';
import '../../features/notifications/domain/usecases/get_notifications.dart';
import '../../features/notifications/domain/usecases/get_unread_notification_count.dart';
import '../../features/notifications/domain/usecases/mark_all_notifications_as_read.dart';
import '../../features/notifications/domain/usecases/mark_notification_as_read.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/chat/data/datasources/chat_rest_data_source.dart';
import '../../features/chat/data/datasources/chat_realtime_data_source.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/repositories/chat_realtime_repository.dart';
import '../../features/chat/domain/usecases/chat_usecases.dart';
import '../../features/chat/presentation/cubit/chat_cubit.dart';
import '../../features/chat/presentation/cubit/conversations_cubit.dart';
import '../../features/community/data/datasources/community_rest_data_source.dart';
import '../../features/community/data/repositories/community_repository_impl.dart';
import '../../features/community/domain/repositories/community_repository.dart';
import '../../features/community/domain/usecases/create_community_post.dart';
import '../../features/community/domain/usecases/create_community_comment.dart';
import '../../features/community/domain/usecases/delete_community_comment.dart';
import '../../features/community/domain/usecases/delete_community_post.dart';
import '../../features/community/domain/usecases/get_community_comments.dart';
import '../../features/community/domain/usecases/get_community_feed.dart';
import '../../features/community/domain/usecases/get_community_post.dart';
import '../../features/community/domain/usecases/like_community_post.dart';
import '../../features/community/domain/usecases/unlike_community_post.dart';
import '../../features/community/presentation/cubit/community_feed_cubit.dart';
import '../../features/community/presentation/cubit/post_detail_cubit.dart';
import '../../features/news/data/datasources/news_rest_data_source.dart';
import '../../features/news/data/repositories/news_repository_impl.dart';
import '../../features/news/domain/repositories/news_repository.dart';
import '../../features/news/domain/usecases/get_news_categories.dart';
import '../../features/news/domain/usecases/get_news_feed.dart';
import '../../features/news/presentation/cubit/news_feed_cubit.dart';

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

  if (!getIt.isRegistered<TheftDataSource>()) getIt.registerLazySingleton(() => TheftDataSource(getIt<ApiClient>().dio));
  if (!getIt.isRegistered<TheftRepository>()) getIt.registerLazySingleton<TheftRepository>(() => TheftRepositoryImpl(getIt<TheftDataSource>()));
  if (!getIt.isRegistered<GetActiveTheftReports>()) getIt.registerLazySingleton(() => GetActiveTheftReports(getIt<TheftRepository>()));
  if (!getIt.isRegistered<GetTheftReportDetail>()) getIt.registerLazySingleton(() => GetTheftReportDetail(getIt<TheftRepository>()));
  if (!getIt.isRegistered<GetMyTheftReports>()) getIt.registerLazySingleton(() => GetMyTheftReports(getIt<TheftRepository>()));
  if (!getIt.isRegistered<CreateTheftReport>()) getIt.registerLazySingleton(() => CreateTheftReport(getIt<TheftRepository>()));
  if (!getIt.isRegistered<UpdateTheftReportStatus>()) getIt.registerLazySingleton(() => UpdateTheftReportStatus(getIt<TheftRepository>()));
  if (!getIt.isRegistered<TheftReportsCubit>()) getIt.registerFactory(() => TheftReportsCubit(getIt<GetActiveTheftReports>()));
  if (!getIt.isRegistered<TheftReportDetailCubit>()) getIt.registerFactory(() => TheftReportDetailCubit(getIt<GetTheftReportDetail>()));
  if (!getIt.isRegistered<MyTheftReportsCubit>()) getIt.registerFactory(() => MyTheftReportsCubit(getIt<GetMyTheftReports>(), getIt<UpdateTheftReportStatus>()));
  if (!getIt.isRegistered<TheftReportFormCubit>()) getIt.registerFactory(() => TheftReportFormCubit(getIt<GetMotorcycles>(), getIt<CreateTheftReport>()));

  if (!getIt.isRegistered<NotificationsDataSource>()) getIt.registerLazySingleton(() => NotificationsDataSource(getIt<ApiClient>().dio));
  if (!getIt.isRegistered<NotificationsRepository>()) getIt.registerLazySingleton<NotificationsRepository>(() => NotificationsRepositoryImpl(getIt<NotificationsDataSource>()));
  if (!getIt.isRegistered<GetNotifications>()) getIt.registerLazySingleton(() => GetNotifications(getIt<NotificationsRepository>()));
  if (!getIt.isRegistered<GetUnreadNotificationCount>()) getIt.registerLazySingleton(() => GetUnreadNotificationCount(getIt<NotificationsRepository>()));
  if (!getIt.isRegistered<MarkNotificationAsRead>()) getIt.registerLazySingleton(() => MarkNotificationAsRead(getIt<NotificationsRepository>()));
  if (!getIt.isRegistered<MarkAllNotificationsAsRead>()) getIt.registerLazySingleton(() => MarkAllNotificationsAsRead(getIt<NotificationsRepository>()));
  if (!getIt.isRegistered<NotificationsCubit>()) getIt.registerLazySingleton(() => NotificationsCubit(getIt<GetNotifications>(), getIt<GetUnreadNotificationCount>(), getIt<MarkNotificationAsRead>(), getIt<MarkAllNotificationsAsRead>()));

  if (!getIt.isRegistered<ChatRestDataSource>()) getIt.registerLazySingleton(() => ChatRestDataSource(getIt<ApiClient>().dio));
  if (!getIt.isRegistered<ChatRepository>()) getIt.registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl(getIt<ChatRestDataSource>()));
  if (!getIt.isRegistered<GetConversations>()) getIt.registerLazySingleton(() => GetConversations(getIt<ChatRepository>()));
  if (!getIt.isRegistered<GetOrCreateDirectConversation>()) getIt.registerLazySingleton(() => GetOrCreateDirectConversation(getIt<ChatRepository>()));
  if (!getIt.isRegistered<GetMessages>()) getIt.registerLazySingleton(() => GetMessages(getIt<ChatRepository>()));
  if (!getIt.isRegistered<SendMessage>()) getIt.registerLazySingleton(() => SendMessage(getIt<ChatRepository>()));
  if (!getIt.isRegistered<MarkConversationRead>()) getIt.registerLazySingleton(() => MarkConversationRead(getIt<ChatRepository>()));
  if (!getIt.isRegistered<SignalRChatRealtimeDataSource>()) getIt.registerLazySingleton(() => SignalRChatRealtimeDataSource(getIt<TokenStorage>()));
  if (!getIt.isRegistered<ChatRealtimeRepository>()) getIt.registerLazySingleton<ChatRealtimeRepository>(() => getIt<SignalRChatRealtimeDataSource>());
  if (!getIt.isRegistered<ConversationsCubit>()) getIt.registerLazySingleton(() => ConversationsCubit(getIt<GetConversations>(), getIt<GetOrCreateDirectConversation>()));
  if (!getIt.isRegistered<ChatCubit>()) getIt.registerFactory(() => ChatCubit(getIt<GetMessages>(), getIt<SendMessage>(), getIt<MarkConversationRead>(), getIt<ChatRealtimeRepository>()));
  if (!getIt.isRegistered<CommunityRestDataSource>()) getIt.registerLazySingleton(() => CommunityRestDataSource(getIt<ApiClient>().dio));
  if (!getIt.isRegistered<CommunityRepository>()) getIt.registerLazySingleton<CommunityRepository>(() => CommunityRepositoryImpl(getIt<CommunityRestDataSource>()));
  if (!getIt.isRegistered<GetCommunityFeed>()) getIt.registerLazySingleton(() => GetCommunityFeed(getIt<CommunityRepository>()));
  if (!getIt.isRegistered<GetCommunityPost>()) getIt.registerLazySingleton(() => GetCommunityPost(getIt<CommunityRepository>()));
  if (!getIt.isRegistered<LikeCommunityPost>()) getIt.registerLazySingleton(() => LikeCommunityPost(getIt<CommunityRepository>()));
  if (!getIt.isRegistered<UnlikeCommunityPost>()) getIt.registerLazySingleton(() => UnlikeCommunityPost(getIt<CommunityRepository>()));
  if (!getIt.isRegistered<GetCommunityComments>()) getIt.registerLazySingleton(() => GetCommunityComments(getIt<CommunityRepository>()));
  if (!getIt.isRegistered<CreateCommunityComment>()) getIt.registerLazySingleton(() => CreateCommunityComment(getIt<CommunityRepository>()));
  if (!getIt.isRegistered<DeleteCommunityComment>()) getIt.registerLazySingleton(() => DeleteCommunityComment(getIt<CommunityRepository>()));
  if (!getIt.isRegistered<CreateCommunityPost>()) getIt.registerLazySingleton(() => CreateCommunityPost(getIt<CommunityRepository>()));
  if (!getIt.isRegistered<DeleteCommunityPost>()) getIt.registerLazySingleton(() => DeleteCommunityPost(getIt<CommunityRepository>()));
  if (!getIt.isRegistered<CommunityFeedCubit>()) getIt.registerFactory(() => CommunityFeedCubit(getIt<GetCommunityFeed>(), getIt<CreateCommunityPost>(), getIt<DeleteCommunityPost>(), getIt<SessionEvents>()));
  if (!getIt.isRegistered<PostDetailCubit>()) getIt.registerFactory(() => PostDetailCubit(getIt<GetCommunityPost>(), getIt<GetCommunityComments>(), getIt<LikeCommunityPost>(), getIt<UnlikeCommunityPost>(), getIt<CreateCommunityComment>(), getIt<DeleteCommunityComment>(), getIt<SessionEvents>()));
  if (!getIt.isRegistered<NewsRestDataSource>()) getIt.registerLazySingleton(() => NewsRestDataSource(getIt<ApiClient>().dio));
  if (!getIt.isRegistered<NewsRepository>()) getIt.registerLazySingleton<NewsRepository>(() => NewsRepositoryImpl(getIt<NewsRestDataSource>()));
  if (!getIt.isRegistered<GetNewsFeed>()) getIt.registerLazySingleton(() => GetNewsFeed(getIt<NewsRepository>()));
  if (!getIt.isRegistered<GetNewsCategories>()) getIt.registerLazySingleton(() => GetNewsCategories(getIt<NewsRepository>()));
  if (!getIt.isRegistered<NewsFeedCubit>()) getIt.registerFactory(() => NewsFeedCubit(getIt<GetNewsFeed>(), getIt<GetNewsCategories>(), getIt<SessionEvents>()));
}
