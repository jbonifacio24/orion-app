class AuthUserModel {
  const AuthUserModel({
    required this.id,
    required this.email,
    required this.userName,
    required this.emailConfirmed,
    required this.roles,
    this.firstName,
    this.lastName,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) => AuthUserModel(
        id: json['id'] as String,
        email: json['email'] as String,
        userName: json['userName'] as String,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        emailConfirmed: json['emailConfirmed'] as bool? ?? false,
        roles: (json['roles'] as List<dynamic>? ?? const []).cast<String>(),
      );

  final String id;
  final String email;
  final String userName;
  final String? firstName;
  final String? lastName;
  final bool emailConfirmed;
  final List<String> roles;
}

class AuthResponseModel {
  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) => AuthResponseModel(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        accessTokenExpiresAt: DateTime.parse(json['accessTokenExpiresAt'] as String),
        user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>),
      );

  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final AuthUserModel user;
}