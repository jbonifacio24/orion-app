import 'package:flutter_test/flutter_test.dart';

import 'package:motohub/core/auth/session_events.dart';
import 'package:motohub/core/di/injection.dart';
import 'package:motohub/core/router/router_refresh_notifier.dart';
import 'package:motohub/features/auth/presentation/cubit/auth_cubit.dart';

void main() {
  test('GetIt injects the registered SessionEvents into AuthCubit', () async {
    await getIt.reset();
    await configureDependencies();
    final events = getIt<SessionEvents>();
    final cubit = getIt<AuthCubit>();
    final notifier = RouterRefreshNotifier(cubit);
    var navigationRefreshes = 0;
    notifier.addListener(() => navigationRefreshes++);

    addTearDown(() async {
      notifier.dispose();
      await cubit.close();
      await events.dispose();
      await getIt.reset();
    });

    events.invalidate();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<AuthUnauthenticated>());
    expect(navigationRefreshes, 1);
  });
}