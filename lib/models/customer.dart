class Customer {
  final int id;
  final int userId;
  final String customerNumber;
  final String name;
  final String phone;
  final String address;
  final int serviceId;
  final String ownerToken;
  final String createdAt;
  final String updatedAt;
  final String username;
  final String serviceName;

  Customer({
    required this.id,
    required this.userId,
    required this.customerNumber,
    required this.name,
    required this.phone,
    required this.address,
    required this.serviceId,
    required this.ownerToken,
    required this.createdAt,
    required this.updatedAt,
    required this.username,
    required this.serviceName,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>? ?? {};
    final serviceMap = json['service'] as Map<String, dynamic>? ?? {};
    
    return Customer(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? json['userId'] ?? 0,
      customerNumber: json['customer_number'] ?? json['customerNumber'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address'] ?? '',
      serviceId: json['service_id'] is int 
          ? json['service_id'] 
          : int.tryParse(json['service_id']?.toString() ?? '0') ?? 0,
      ownerToken: json['owner_token'] ?? '',
      createdAt: json['createdAt'] ?? json['created_at'] ?? '',
      updatedAt: json['updatedAt'] ?? json['updated_at'] ?? '',
      username: userMap['username'] ?? '',
      serviceName: serviceMap['name'] ?? 'Layanan Umum',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'customer_number': customerNumber,
      'name': name,
      'phone': phone,
      'address': address,
      'service_id': serviceId,
      'owner_token': ownerToken,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'username': username,
      'service_name': serviceName,
    };
  }
}
