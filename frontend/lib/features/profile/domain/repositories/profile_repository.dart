import '../entities/user_profile.dart';

abstract interface class ProfileRepository {
  Future<UserProfile> getCurrent();
  Future<UserProfile> update({
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? bio,
  });
}
