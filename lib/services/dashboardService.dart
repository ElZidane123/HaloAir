import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/services/url.dart' as url;

class DashboardService {
  late final Dio _dio;

  DashboardService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: url.baseUrl,
        contentType: 'application/json',
        headers: {
          'Accept': 'application/json',
          'APP-KEY': '19bb0feea2f8ac775c0866083cad89a2eb4e85ab',
        },
      ),
    );
  }

  Future<String?> _getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Get total customer count from `/customers`
  Future<int> getCustomersCount() async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) return 0;

      _dio.options.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.get('/customers');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final count = response.data['count'];
        if (count != null) return int.tryParse(count.toString()) ?? 0;
        final list = response.data['data'];
        if (list is List) return list.length;
      }
      return 0;
    } catch (e) {
      debugPrint('Error fetching customers count: $e');
      return 0;
    }
  }

  /// Get total services count from `/services`
  Future<int> getServicesCount() async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) return 0;

      _dio.options.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.get('/services');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final count = response.data['count'];
        if (count != null) return int.tryParse(count.toString()) ?? 0;
        final list = response.data['data'];
        if (list is List) return list.length;
      }
      return 0;
    } catch (e) {
      debugPrint('Error fetching services count: $e');
      return 0;
    }
  }

  /// Get payment statistics from `/payments`
  /// Returns a map containing:
  /// - 'unverifiedCount': number of unverified payments
  /// - 'totalRevenue': total sum of verified payments
  Future<Map<String, dynamic>> getPaymentStats() async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return {'unverifiedCount': 0, 'totalRevenue': 0.0};
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.get('/payments');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> payments = response.data['data'] ?? [];
        
        int unverifiedCount = 0;
        double totalRevenue = 0.0;

        for (var item in payments) {
          if (item is Map<String, dynamic>) {
            bool verified = false;
            
            final statusVal = item['status']?.toString().toUpperCase();
            if (statusVal != null) {
              if (statusVal == 'VERIFIED' || statusVal == 'SUCCESS' || statusVal == 'LUNAS' || statusVal == 'PAID') {
                verified = true;
              }
            } else {
              final isVerifiedVal = item['is_verified'] ?? item['verified'];
              if (isVerifiedVal != null) {
                if (isVerifiedVal is bool) {
                  verified = isVerifiedVal;
                } else if (isVerifiedVal is num) {
                  verified = isVerifiedVal != 0;
                }
              }
            }

            if (!verified) {
              unverifiedCount++;
            } else {
              final amountVal = item['amount'] ?? item['price'] ?? item['total'] ?? item['total_price'] ?? item['total_payment'] ?? item['bayar'];
              double amount = 0.0;
              if (amountVal != null) {
                amount = double.tryParse(amountVal.toString()) ?? 0.0;
              } else {
                final bill = item['bill'] ?? item['usage'] ?? item['service'];
                if (bill is Map<String, dynamic>) {
                  final billAmt = bill['price'] ?? bill['price_total'] ?? bill['total'] ?? bill['amount'] ?? bill['total_price'];
                  if (billAmt != null) {
                    amount = double.tryParse(billAmt.toString()) ?? 0.0;
                  }
                }
              }
              totalRevenue += amount;
            }
          }
        }

        return {
          'unverifiedCount': unverifiedCount,
          'totalRevenue': totalRevenue,
        };
      }
      return {'unverifiedCount': 0, 'totalRevenue': 0.0};
    } catch (e) {
      debugPrint('Error fetching payment stats: $e');
      return {'unverifiedCount': 0, 'totalRevenue': 0.0};
    }
  }

  /// Get latest unverified payments with customer name + amount details.
  /// Returns list of maps: [{customerName, amount}]
  Future<List<Map<String, dynamic>>> getLatestUnverifiedPayments({int limit = 3}) async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) return [];

      _dio.options.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.get('/payments');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> payments = response.data['data'] ?? [];
        final List<Map<String, dynamic>> result = [];

        for (var item in payments) {
          if (item is Map<String, dynamic>) {
            // Check if unverified
            bool verified = false;
            final statusVal = item['status']?.toString().toUpperCase();
            if (statusVal == 'VERIFIED' || statusVal == 'SUCCESS' || statusVal == 'LUNAS' || statusVal == 'PAID') {
              verified = true;
            } else {
              final isVerifiedVal = item['is_verified'] ?? item['verified'];
              if (isVerifiedVal != null) {
                if (isVerifiedVal is bool) verified = isVerifiedVal;
                else if (isVerifiedVal is num) verified = isVerifiedVal != 0;
              }
            }
            if (verified) continue;

            // Extract customer name
            String? customerName;
            final bill = item['bill'] as Map<String, dynamic>?;
            if (bill != null) {
              final customer = bill['customer'] as Map<String, dynamic>?;
              if (customer != null) {
                customerName = customer['name']?.toString() ?? customer['username']?.toString();
              }
            }
            customerName ??= item['customer_name']?.toString() ?? item['customer']?.toString() ?? 'Customer';

            // Extract amount (prioritas: bayar/amount pembayaran dulu, bukan harga layanan)
            final amountVal = item['amount'] ?? item['bayar'] ?? item['total_payment'] ?? item['total'] ?? item['price'];
            double amount = 0.0;
            if (amountVal != null) {
              amount = double.tryParse(amountVal.toString()) ?? 0.0;
            } else if (bill != null) {
              final billAmt = bill['amount'] ?? bill['total_payment'] ?? bill['total'] ?? bill['price'] ?? bill['total_price'];
              if (billAmt != null) amount = double.tryParse(billAmt.toString()) ?? 0.0;
            }

            result.add({
              'customerName': customerName,
              'amount': amount,
            });

            if (result.length >= limit) break;
          }
        }
        return result;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching latest unverified payments: $e');
      return [];
    }
  }
}
