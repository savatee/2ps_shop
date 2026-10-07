class LoginUserModel {
  final int userId;
  final String name;
  final String email;
  final String? userPhone;
  final String role;
  final String userStatus;
  final String apiToken;

  LoginUserModel({
    required this.userId,
    required this.name,
    required this.email,
    this.userPhone,
    required this.role,
    required this.userStatus,
    this.apiToken = '',
  });

  factory LoginUserModel.fromJson(Map<String, dynamic> json) {
    return LoginUserModel(
      userId: json['user_id'] is int
          ? json['user_id']
          : int.tryParse(json['user_id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      userPhone: json['user_phone']?.toString(),
      role: json['role']?.toString().toLowerCase() ?? 'buyer',
      userStatus: json['user_status']?.toString().toLowerCase() ?? 'inactive',
      apiToken: json['api_token']?.toString() ?? '',
    );
  }

  bool get isActive => userStatus == 'active';
  bool get isBlocked => userStatus == 'blocked';
  bool get isInactive => userStatus == 'inactive';
}
