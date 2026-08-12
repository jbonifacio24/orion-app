import 'package:get_it/get_it.dart';

import '../network/api_client.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  if (!getIt.isRegistered<ApiClient>()) {
    getIt.registerLazySingleton<ApiClient>(ApiClient.new);
  }
}
