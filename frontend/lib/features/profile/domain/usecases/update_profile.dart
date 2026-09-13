import '../entities/user_profile.dart';
import '../repositories/profile_repository.dart';

class UpdateProfile {
  const UpdateProfile(this._repository);
  final ProfileRepository _repository;

  Future<UserProfile> call({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? bio,
  }) => _repository.update(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        bio: bio,
      );
}
