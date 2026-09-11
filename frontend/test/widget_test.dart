import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';

import 'package:motohub/features/auth/domain/entities/auth_entities.dart';
import 'package:motohub/features/auth/domain/repositories/auth_repository.dart';
import 'package:motohub/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:motohub/features/auth/presentation/pages/login_page.dart';

void main() {
  testWidgets('renders login for an unauthenticated user', (tester) async {
    final authCubit = AuthCubit(_FakeAuthRepository());
    addTearDown(authCubit.close);

    await authCubit.restoreSession();
    await tester.pumpWidget(
      BlocProvider.value(
        value: authCubit,
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> login(String emailOrUserName, String password) =>
      Future.error(UnimplementedError());

  @override
  Future<AuthUser> register({
    required String email,
    required String userName,
    required String password,
    required String confirmPassword,
    String? firstName,
    String? lastName,
  }) => Future.error(UnimplementedError());

  @override
  Future<void> logout() async {}

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> forgotPassword(String email) async {}
}
