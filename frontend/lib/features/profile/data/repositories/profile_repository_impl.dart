import '../../../../core/error/error_mapper.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_data_source.dart';
import '../models/profile_models.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl(this._dataSource);
  final ProfileDataSource _dataSource;

  @override
  Future<UserProfile> getCurrent() async {
    try {
      return await _dataSource.getCurrent();
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }

  @override
  Future<UserProfile> update({String? firstName, String? lastName, String? phoneNumber, String? bio}) async {
    try {
      return await _dataSource.update(UpdateProfileRequestModel(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: phoneNumber,
        bio: bio,
      ));
    } catch (error) {
      throw ErrorMapper.from(error);
    }
  }
}
