import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/auth_entities.dart';
import '../../domain/repositories/auth_repository.dart';

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
  AuthCubit(this._repository) : super(const AuthInitial());

  final AuthRepository _repository;

  Future<void> restore() async {
    emit(const AuthLoading());
    try {
      await _repository.restoreSession();
      final user = _repository.currentUser;
      emit(user == null ? const AuthUnauthenticated() : AuthAuthenticated(user));
    } catch (error) {
      emit(AuthFailure(error.toString()));
    }
  }

  Future<void> login(String identifier, String password) async {
    emit(const AuthLoading());
    try {
      final user = await _repository.login(identifier, password);
      emit(AuthAuthenticated(user));
    } catch (error) {
      emit(AuthFailure(error.toString()));
    }
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
      emit(const AuthUnauthenticated());
    } catch (error) {
      emit(AuthFailure(error.toString()));
    }
  }
}