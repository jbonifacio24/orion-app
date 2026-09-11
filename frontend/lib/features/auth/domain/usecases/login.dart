import '../entities/auth_entities.dart';
import '../repositories/auth_repository.dart';

class Login {
  const Login(this._repository);
  final AuthRepository _repository;

  Future<AuthUser> call(String identifier, String password) =>
      _repository.login(identifier, password);
}