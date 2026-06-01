import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/models/bill.dart';
import 'package:aplikasi_pdam/services/url.dart' as url;

class CustomerDashboardService {
  late final Dio _dio;

  CustomerDashboardService() {
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

  /// Fetch all bills of currently logged-in customer
  Future<Map<String, dynamic>> getCustomerBills() async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
          'data': <Bill>[],
          'count': 0
        };
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.get('/bills/me');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawList = body['data'] as List<dynamic>? ?? [];
        final bills = rawList
            .whereType<Map<String, dynamic>>()
            .map((j) => Bill.fromJson(j))
            .toList();

        return {
          'success': body['success'] == true,
          'message': body['message']?.toString() ?? '',
          'data': bills,
          'count': body['count'] ?? bills.length,
        };
      }
      return {
        'success': false,
        'message': 'Gagal mengambil data tagihan',
        'data': <Bill>[],
        'count': 0
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan: $e',
        'data': <Bill>[],
        'count': 0
      };
    }
  }
}
