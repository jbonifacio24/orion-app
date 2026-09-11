import 'package:flutter/foundation.dart';
import 'dart:async';

import '../../features/auth/presentation/cubit/auth_cubit.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this._cubit) {
    _subscription = _cubit.stream.listen((_) => notifyListeners());
  }

  final AuthCubit _cubit;
  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}