import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/get_current_profile.dart';
import '../../domain/usecases/update_profile.dart';

sealed class ProfileState {
  const ProfileState();
}

final class ProfileInitial extends ProfileState {
  const ProfileInitial();
}

final class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

final class ProfileLoaded extends ProfileState {
  const ProfileLoaded(this.profile);
  final UserProfile profile;
}

final class ProfileUpdating extends ProfileState {
  const ProfileUpdating(this.profile);
  final UserProfile profile;
}

final class ProfileFailure extends ProfileState {
  const ProfileFailure(this.message, {this.profile});
  final String message;
  final UserProfile? profile;
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._getCurrent, this._update) : super(const ProfileInitial());

  final GetCurrentProfile _getCurrent;
  final UpdateProfile _update;
  bool _updating = false;

  Future<void> loadProfile() async {
    emit(const ProfileLoading());
    try {
      emit(ProfileLoaded(await _getCurrent()));
    } catch (error) {
      emit(ProfileFailure(ErrorMapper.from(error).message));
    }
  }

  Future<void> updateProfile({String? firstName, String? lastName, String? phoneNumber, String? bio}) async {
    if (_updating) return;
    final current = state is ProfileLoaded ? (state as ProfileLoaded).profile : state is ProfileUpdating ? (state as ProfileUpdating).profile : null;
    if (current == null) return;
    _updating = true;
    emit(ProfileUpdating(current));
    try {
      emit(ProfileLoaded(await _update(firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, bio: bio)));
    } catch (error) {
      emit(ProfileFailure(ErrorMapper.from(error).message, profile: current));
    } finally {
      _updating = false;
    }
  }
}
