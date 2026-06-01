class AdminService {
  int? id;
  String name;
  int minUsage;
  int maxUsage;
  int price;
  String? ownerToken;
  String? createdAt;
  String? updatedAt;

  AdminService({
    this.id,
    required this.name,
    required this.minUsage,
    required this.maxUsage,
    required this.price,
    this.ownerToken,
    this.createdAt,
    this.updatedAt,
  });

  factory AdminService.fromJson(Map<String, dynamic> json) {
    return AdminService(
      id: json['id'],
      name: json['name'] ?? '',
      minUsage: json['min_usage'] ?? 0,
      maxUsage: json['max_usage'] ?? 0,
      price: json['price'] ?? 0,
      ownerToken: json['owner_token'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'min_usage': minUsage,
      'max_usage': maxUsage,
      'price': price,
      'owner_token': ownerToken,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
