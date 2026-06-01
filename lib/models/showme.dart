class Showme {
  int id;
  int userId;
  String name;
  String phone;
  String ownerToken;
  String createdAt;
  String updatedAt;
  User? user;
  Showme({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.ownerToken,
    required this.createdAt,
    required this.updatedAt,
    this.user,
  });
  factory Showme.fromJson(Map<String, dynamic> json) {
    return Showme(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? json['userId'] ?? 0,
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      ownerToken: json['owner_token'] ?? json['ownerToken'] ?? '',
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
      updatedAt: json['updatedAt'] ?? json['updated_at'] ?? '',
      user: json['user'] != null ? User.fromJson(json['user']) : null,
    );
  }
}

class User {
  int id;
  String username;
  String password;
  String role;
  String ownerToken;
  String createdAt;
  String updatedAt;
  User({
    required this.id,
    required this.username,
    required this.password,
    required this.role,
    required this.ownerToken,
    required this.createdAt,
    required this.updatedAt,
  });
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      password: json['password'],
      role: json['role'],
      ownerToken: json['owner_token'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }
}