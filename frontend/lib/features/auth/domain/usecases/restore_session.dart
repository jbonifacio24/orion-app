import '../repositories/auth_repository.dart';

class RestoreSession {
  const RestoreSession(this._repository);
  final AuthRepository _repository;

  Future<void> call() => _repository.restoreSession();
}