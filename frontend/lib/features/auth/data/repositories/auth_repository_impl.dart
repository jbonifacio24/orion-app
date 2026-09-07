import '../../../../core/network/token_storage.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/entities/auth_entities.dart';
import '../datasources/auth_data_source.dart';
import '../models/auth_models.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._dataSource, this._tokenStorage);

  final AuthDataSource _dataSource;
  final TokenStorage _tokenStorage;
  AuthUser? _currentUser;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Future<AuthUser> login(String emailOrUserName, String password) async {
    final response = await _dataSource.login(emailOrUserName, password);
    await _saveSession(response);
    return _currentUser!;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String userName,
    required String password,
    required String confirmPassword,
    String? firstName,
    String? lastName,
  }) async {
    final response = await _dataSource.register(
      email: email,
      userName: userName,
      password: password,
      confirmPassword: confirmPassword,
      firstName: firstName,
      lastName: lastName,
    );
    await _saveSession(response);
    return _currentUser!;
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.refreshToken;
    if (refreshToken != null) {
      await _dataSource.logout(refreshToken);
    }
    await _tokenStorage.clear();
    _currentUser = null;
  }

  @override
  Future<void> restoreSession() async {
    final accessToken = await _tokenStorage.accessToken;
    if (accessToken == null) return;
    _currentUser = _toDomainUser(await _dataSource.currentUser());
  }

  @override
  Future<void> forgotPassword(String email) => _dataSource.forgotPassword(email);

  Future<void> _saveSession(AuthResponseModel response) async {
    await _tokenStorage.save(response.accessToken, response.refreshToken);
    _currentUser = _toDomainUser(response.user);
  }

  AuthUser _toDomainUser(AuthUserModel user) => AuthUser(
        id: user.id,
        email: user.email,
        userName: user.userName,
        firstName: user.firstName,
        lastName: user.lastName,
        emailConfirmed: user.emailConfirmed,
        roles: user.roles,
      );
}