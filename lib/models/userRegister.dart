import 'package:shared_preferences/shared_preferences.dart';

class UserRegister {
  String username;
  String password;
  String name;
  String phone;
  UserRegister({
    required this.username,
    required this.password,
    required this.name,
    required this.phone,
  });
  
  Future prefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("username", username);
    await prefs.setString("password", password);
    await prefs.setString("name", name);
    await prefs.setString("phone", phone);
  }

  Future<UserRegister> getUserRegister() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    UserRegister userRegister = UserRegister(
      username: prefs.getString('username') ?? '',
      password: prefs.getString('password') ?? '',
      name: prefs.getString('name') ?? '',
      phone: prefs.getString('phone') ?? '',
    );
    return userRegister;
  }

  Future clearUserRegister() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("username");
    await prefs.remove("password");
    await prefs.remove("name");
    await prefs.remove("phone");
  }

  factory UserRegister.fromJson(Map<String, dynamic> json) {
    var target = json['data'] ?? json;
    return UserRegister(
      username: target['username'] ?? '',
      password: target['password'] ?? '',
      name: target['name'] ?? '',
      phone: target['phone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'name': name,
      'phone': phone,
    };
  }
}
