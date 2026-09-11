import 'package:flutter_test/flutter_test.dart';

import 'package:motohub/core/auth/session_events.dart';
import 'package:motohub/features/auth/domain/entities/auth_entities.dart';
import 'package:motohub/features/auth/domain/repositories/auth_repository.dart';
import 'package:motohub/features/auth/presentation/cubit/auth_cubit.dart';

void main() {
  test('session invalidation moves AuthCubit to unauthenticated', () async {
    final events = SessionEvents();
    final cubit = AuthCubit(_FakeAuthRepository(), events);
    addTearDown(() async {
      await cubit.close();
      await events.dispose();
    });

    events.invalidate();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<AuthUnauthenticated>());
  });

  test('logout emits unauthenticated when the remote logout fails', () async {
    final cubit = AuthCubit(_FakeAuthRepository(failLogout: true));
    addTearDown(cubit.close);

    await cubit.login('user', 'password');
    await cubit.logout();

    expect(cubit.state, isA<AuthUnauthenticated>());
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.failLogout = false});

  final bool failLogout;

  @override
  AuthUser? get currentUser => const AuthUser(
        id: '1',
        email: 'user@example.com',
        userName: 'user',
        emailConfirmed: true,
        roles: [],
      );

  @override
  Future<AuthUser> login(String emailOrUserName, String password) async => currentUser!;

  @override
  Future<AuthUser> register({
    required String email,
    required String userName,
    required String password,
    required String confirmPassword,
    String? firstName,
    String? lastName,
  }) async => currentUser!;

  @override
  Future<void> logout() async {
    if (failLogout) throw Exception('remote logout failed');
  }

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> forgotPassword(String email) async {}
}