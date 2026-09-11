import '../entities/auth_entities.dart';
import '../repositories/auth_repository.dart';

class Register {
  const Register(this._repository);
  final AuthRepository _repository;

  Future<AuthUser> call({
    required String email,
    required String userName,
    required String password,
    required String confirmPassword,
    String? firstName,
    String? lastName,
  }) => _repository.register(
        email: email,
        userName: userName,
        password: password,
        confirmPassword: confirmPassword,
        firstName: firstName,
        lastName: lastName,
      );
}