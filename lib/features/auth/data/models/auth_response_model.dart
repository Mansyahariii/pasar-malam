class UserModel {
  final int id;
  final String firebaseUid;
  final String email;
  final String name;
  final String role;
  final bool emailVerified;
  final String createdAt;

  const UserModel({
    required this.id,
    required this.firebaseUid,
    required this.email,
    required this.name,
    required this.role,
    required this.emailVerified,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        firebaseUid: json['firebase_uid'] as String,
        email: json['email'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        emailVerified: json['email_verified'] as bool,
        createdAt: json['created_at'] as String,
      );
}

class AuthResponseModel {
  final bool success;
  final String message;
  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final UserModel user;

  const AuthResponseModel({
    required this.success,
    required this.message,
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return AuthResponseModel(
      success: json['success'] as bool,
      message: json['message'] as String,
      accessToken: data['access_token'] as String,
      tokenType: data['token_type'] as String,
      expiresIn: data['expires_in'] as int,
      user: UserModel.fromJson(data['user'] as Map<String, dynamic>),
    );
  }
}
