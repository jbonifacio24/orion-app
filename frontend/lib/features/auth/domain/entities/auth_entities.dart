class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.userName,
    required this.emailConfirmed,
    required this.roles,
    this.firstName,
    this.lastName,
  });

  final String id;
  final String email;
  final String userName;
  final String? firstName;
  final String? lastName;
  final bool emailConfirmed;
  final List<String> roles;
}