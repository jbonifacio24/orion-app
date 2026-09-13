class UserProfile {
  const UserProfile({
    required this.id,
    required this.userName,
    required this.email,
    required this.emailConfirmed,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.profileImageUrl,
    this.bio,
    this.lastLoginAt,
  });

  final String id;
  final String userName;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? profileImageUrl;
  final String? bio;
  final bool emailConfirmed;
  final DateTime? lastLoginAt;
}
