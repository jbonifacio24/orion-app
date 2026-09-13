import '../../domain/entities/user_profile.dart';

class ProfileModel extends UserProfile {
  const ProfileModel({
    required super.id,
    required super.userName,
    required super.email,
    required super.emailConfirmed,
    super.firstName,
    super.lastName,
    super.phoneNumber,
    super.profileImageUrl,
    super.bio,
    super.lastLoginAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) => ProfileModel(
        id: json['id'] as String,
        userName: json['userName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        phoneNumber: json['phoneNumber'] as String?,
        profileImageUrl: json['profileImageUrl'] as String?,
        bio: json['bio'] as String?,
        emailConfirmed: json['emailConfirmed'] as bool? ?? false,
        lastLoginAt: _parseDate(json['lastLoginAt']),
      );

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('Invalid profile date.');
    return DateTime.tryParse(value) ?? (throw const FormatException('Invalid profile date.'));
  }
}

class UpdateProfileRequestModel {
  const UpdateProfileRequestModel({this.firstName, this.lastName, this.phoneNumber, this.bio});

  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? bio;

  Map<String, dynamic> toJson() => {
        'firstName': firstName,
        'lastName': lastName,
        'phoneNumber': phoneNumber,
        'bio': bio,
      };
}
