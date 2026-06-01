import 'package:shared_preferences/shared_preferences.dart';

class CustomerRegister {
  String username;
  String password;
  String customerNumber;
  String address;
  int serviceId;
  String name;
  String phone;

  CustomerRegister({
    required this.username,
    required this.password,
    required this.customerNumber,
    required this.address,
    required this.serviceId,
    required this.name,
    required this.phone,
  });

  Future prefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString("cust_username", username);
    await prefs.setString("cust_password", password);
    await prefs.setString("cust_customer_number", customerNumber);
    await prefs.setString("cust_address", address);
    await prefs.setInt("cust_service_id", serviceId);
    await prefs.setString("cust_name", name);
    await prefs.setString("cust_phone", phone);
  }

  Future<CustomerRegister> getCustomerRegister() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return CustomerRegister(
      username: prefs.getString('cust_username') ?? '',
      password: prefs.getString('cust_password') ?? '',
      customerNumber: prefs.getString('cust_customer_number') ?? '',
      address: prefs.getString('cust_address') ?? '',
      serviceId: prefs.getInt('cust_service_id') ?? 0,
      name: prefs.getString('cust_name') ?? '',
      phone: prefs.getString('cust_phone') ?? '',
    );
  }

  Future clearCustomerRegister() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("cust_username");
    await prefs.remove("cust_password");
    await prefs.remove("cust_customer_number");
    await prefs.remove("cust_address");
    await prefs.remove("cust_service_id");
    await prefs.remove("cust_name");
    await prefs.remove("cust_phone");
  }

  factory CustomerRegister.fromJson(Map<String, dynamic> json) {
    // Handling possible nesting under 'data' like UserRegister
    var target = json['data'] ?? json;
    return CustomerRegister(
      username: target['username'] ?? '',
      password: target['password'] ?? '',
      customerNumber: target['customer_number'] ?? '',
      address: target['address'] ?? '',
      serviceId: target['service_id'] is int 
          ? target['service_id'] 
          : int.tryParse(target['service_id']?.toString() ?? '0') ?? 0,
      name: target['name'] ?? '',
      phone: target['phone']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'customer_number': customerNumber,
      'address': address,
      'service_id': serviceId,
      'name': name,
      'phone': phone,
    };
  }
}
