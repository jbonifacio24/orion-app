import '../entities/auth_entities.dart';

abstract interface class AuthRepository {
  Future<AuthUser> login(String emailOrUserName, String password);
  Future<AuthUser> register({
    required String email,
    required String userName,
    required String password,
    required String confirmPassword,
    String? firstName,
    String? lastName,
  });
  Future<void> logout();
  Future<void> restoreSession();
  Future<void> forgotPassword(String email);
  AuthUser? get currentUser;
}