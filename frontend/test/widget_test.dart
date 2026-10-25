import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    await tester.pumpAndSettle();

    expect(find.text('Tu próxima ruta empieza aquí.'), findsOneWidget);
  });

  testWidgets('shows only Google sign-in', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authCubit = AuthCubit(_FakeAuthRepository());
    addTearDown(authCubit.close);

    await authCubit.restoreSession();
    await tester.pumpWidget(
      BlocProvider.value(
        value: authCubit,
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Continuar con Google'), findsOneWidget);
    expect(find.text('Crear una cuenta'), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.text('Tu próxima ruta empieza aquí.'), findsOneWidget);
    expect(
      find.text('Compra, vende y comparte rutas con otros motociclistas.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.semanticLabel == 'Animación de ruta y motocicleta',
      ),
      findsOneWidget,
    );
    expect(find.text('Únete a MotoHub'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> login(String emailOrUserName, String password) =>
      Future.error(UnimplementedError());

  @override
  Future<AuthUser> loginWithGoogle(String idToken) =>
      Future.error(UnimplementedError());

  @override
  Future<AuthUser> register({
    required String email,
    required String userName,
    required String password,
    required String confirmPassword,
    String? firstName,
    String? lastName,
  }) =>
      Future.error(UnimplementedError());

  @override
  Future<void> logout() async {}

  @override
  Future<void> restoreSession() async {}

  @override
  Future<void> confirmEmail(String userId, String token) async {}

  @override
  Future<void> forgotPassword(String email) async {}
}
