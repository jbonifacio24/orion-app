import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/auth/session_events.dart';
import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/register.dart';
import '../../domain/usecases/restore_session.dart';

sealed class AuthState {
  const AuthState();
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final AuthUser user;
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

final class AuthFailure extends AuthState {
  const AuthFailure(this.message);
  final String message;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository, [SessionEvents? sessionEvents])
      : _login = Login(_repository),
        _register = Register(_repository),
        _logout = Logout(_repository),
        _restoreSession = RestoreSession(_repository),
        super(const AuthInitial()) {
    _sessionSubscription = sessionEvents?.onInvalidated.listen((_) {
      if (!isClosed) emit(const AuthUnauthenticated());
    });
  }

  final AuthRepository _repository;
  final Login _login;
  final Register _register;
  final Logout _logout;
  final RestoreSession _restoreSession;
  StreamSubscription<void>? _sessionSubscription;

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    return super.close();
  }

  Future<void> restoreSession() async {
    emit(const AuthLoading());
    try {
      await _restoreSession();
      final user = _repository.currentUser;
      emit(user == null ? const AuthUnauthenticated() : AuthAuthenticated(user));
    } catch (error) {
      emit(AuthFailure(ErrorMapper.from(error).message));
    }
  }

  Future<void> restore() => restoreSession();

  Future<void> login(String identifier, String password) async {
    emit(const AuthLoading());
    try {
      final user = await _login(identifier, password);
      emit(AuthAuthenticated(user));
    } catch (error) {
      emit(AuthFailure(ErrorMapper.from(error).message));
    }
  }

  Future<void> register({
    required String email,
    required String userName,
    required String password,
    required String confirmPassword,
    String? firstName,
    String? lastName,
  }) async {
    emit(const AuthLoading());
    try {
      final user = await _register(
        email: email,
        userName: userName,
        password: password,
        confirmPassword: confirmPassword,
        firstName: firstName,
        lastName: lastName,
      );
      emit(AuthAuthenticated(user));
    } catch (error) {
      emit(AuthFailure(ErrorMapper.from(error).message));
    }
  }

  Future<void> logout() async {
    try {
      await _logout();
    } catch (_) {}
    emit(const AuthUnauthenticated());
  }
}