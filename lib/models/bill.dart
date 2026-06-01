class Payment {
  final int id;
  final int billId;
  final String paymentDate;
  final bool verified;
  final String status; // 'pending', 'verified', 'rejected'
  final double totalAmount;
  final String paymentProof;
  final String ownerToken;
  final String createdAt;
  final String updatedAt;

  Payment({
    required this.id,
    required this.billId,
    required this.paymentDate,
    required this.verified,
    required this.status,
    required this.totalAmount,
    required this.paymentProof,
    required this.ownerToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    // Determine status from various fields
    final statusVal = json['status']?.toString().toLowerCase();
    final isVerified = json['verified'] == true || json['verified'] == 1;
    
    String status = 'pending';
    if (statusVal == 'verified' || statusVal == 'success' || isVerified) {
      status = 'verified';
    } else if (statusVal == 'rejected' || statusVal == 'reject' || statusVal == 'ditolak') {
      status = 'rejected';
    }

    return Payment(
      id: json['id'] ?? 0,
      billId: json['bill_id'] ?? 0,
      paymentDate: json['payment_date']?.toString() ?? '',
      verified: isVerified,
      status: status,
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      paymentProof: json['payment_proof']?.toString() ?? '',
      ownerToken: json['owner_token']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '',
    );
  }
}

class BillService {
  final int id;
  final String name;
  final double minUsage;
  final double maxUsage;
  final double price;
  final String ownerToken;
  final String createdAt;
  final String updatedAt;

  BillService({
    required this.id,
    required this.name,
    required this.minUsage,
    required this.maxUsage,
    required this.price,
    required this.ownerToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BillService.fromJson(Map<String, dynamic> json) {
    return BillService(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      minUsage: (json['min_usage'] ?? 0).toDouble(),
      maxUsage: (json['max_usage'] ?? 0).toDouble(),
      price: (json['price'] ?? 0).toDouble(),
      ownerToken: json['owner_token']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '',
    );
  }
}

class BillAdmin {
  final int id;
  final int userId;
  final String name;
  final String phone;
  final String ownerToken;
  final String createdAt;
  final String updatedAt;

  BillAdmin({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.ownerToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BillAdmin.fromJson(Map<String, dynamic> json) {
    return BillAdmin(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      ownerToken: json['owner_token']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '',
    );
  }
}

class BillCustomer {
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

  BillCustomer({
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
  });

  factory BillCustomer.fromJson(Map<String, dynamic> json) {
    return BillCustomer(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      customerNumber: json['customer_number']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      serviceId: json['service_id'] is int
          ? json['service_id']
          : int.tryParse(json['service_id']?.toString() ?? '0') ?? 0,
      ownerToken: json['owner_token']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '',
    );
  }
}

class Bill {
  final int id;
  final int customerId;
  final int adminId;
  final int month;
  final int year;
  final String measurementNumber;
  final double usageValue;
  final double price;
  final int serviceId;
  final bool paid;
  final String ownerToken;
  final String createdAt;
  final String updatedAt;

  // Nested relations (available on READ)
  final BillService? service;
  final BillAdmin? admin;
  final BillCustomer? customer;
  final List<Payment> payments;
  final double amount;
  final bool verifiedPayment;

  Bill({
    required this.id,
    required this.customerId,
    required this.adminId,
    required this.month,
    required this.year,
    required this.measurementNumber,
    required this.usageValue,
    required this.price,
    required this.serviceId,
    required this.paid,
    required this.ownerToken,
    required this.createdAt,
    required this.updatedAt,
    this.service,
    this.admin,
    this.customer,
    this.payments = const [],
    this.amount = 0,
    this.verifiedPayment = false,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    final serviceMap = json['service'] as Map<String, dynamic>?;
    final adminMap = json['admin'] as Map<String, dynamic>?;
    final customerMap = json['customer'] as Map<String, dynamic>?;
    final rawPayments = json['payments'];
    final List<dynamic> paymentsList;
    if (rawPayments is List) {
      paymentsList = rawPayments;
    } else if (rawPayments is Map) {
      paymentsList = [rawPayments];
    } else {
      paymentsList = [];
    }


    return Bill(
      id: json['id'] ?? 0,
      customerId: json['customer_id'] ?? 0,
      adminId: json['admin_id'] ?? 0,
      month: json['month'] is int
          ? json['month']
          : int.tryParse(json['month']?.toString() ?? '0') ?? 0,
      year: json['year'] is int
          ? json['year']
          : int.tryParse(json['year']?.toString() ?? '0') ?? 0,
      measurementNumber: json['measurement_number']?.toString() ?? '',
      usageValue: _toDouble(json['usage_value']),
      price: _toDouble(json['price']),
      serviceId: json['service_id'] is int
          ? json['service_id']
          : int.tryParse(json['service_id']?.toString() ?? '0') ?? 0,
      paid: json['paid'] == true || json['paid'] == 1,
      ownerToken: json['owner_token']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString() ?? '',
      updatedAt: json['updatedAt']?.toString() ?? json['updated_at']?.toString() ?? '',
      service: serviceMap != null ? BillService.fromJson(serviceMap) : null,
      admin: adminMap != null ? BillAdmin.fromJson(adminMap) : null,
      customer: customerMap != null ? BillCustomer.fromJson(customerMap) : null,
      payments: paymentsList
          .whereType<Map<String, dynamic>>()
          .map((p) => Payment.fromJson(p))
          .toList(),
      amount: _toDouble(json['amount'] ?? json['price'] ?? 0),
      verifiedPayment: json['verified_payment'] == true ||
          json['verified_payment'] == 1 ||
          paymentsList.any((p) =>
              p is Map<String, dynamic> &&
              (p['verified'] == true || p['verified'] == 1 || p['verified'] == '1')),
    );
  }

  /// Helper to safely convert any value to double
  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      // Remove any currency symbols or separators
      final cleaned = value.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  /// Generate invoice number like INV/2025/05/001
  String get invoiceNumber {
    final monthStr = month.toString().padLeft(2, '0');
    final idStr = id.toString().padLeft(3, '0');
    return 'INV/$year/${monthStr}S$idStr';
  }

  /// Month name in Indonesian
  String get monthName {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return month >= 1 && month <= 12 ? months[month] : month.toString();
  }

  /// Formatted period: Mei 2025
  String get period => '$monthName $year';
}
