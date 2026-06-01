import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/models/bill.dart';
import 'package:aplikasi_pdam/services/url.dart' as url;

class LayananCustService {
  late final Dio _dio;

  LayananCustService() {
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

  /// Fetch customer service ID from their profile
  Future<Map<String, dynamic>> getCustomerServiceId() async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
          'serviceId': null,
        };
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.get('/customers/me');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final customerData = body['data'] as Map<String, dynamic>?;
        
        if (customerData != null) {
          final rawServiceId = customerData['service_id'] ?? 
                             customerData['serviceId'] ?? 
                             customerData['service']?['id'];
          
          final serviceId = rawServiceId is int 
              ? rawServiceId 
              : int.tryParse(rawServiceId?.toString() ?? '0') ?? 0;
          
          return {
            'success': true,
            'message': 'Berhasil mengambil service ID',
            'serviceId': serviceId,
          };
        }
        
        return {
          'success': false,
          'message': 'Data customer tidak ditemukan',
          'serviceId': null,
        };
      }

      return {
        'success': false,
        'message': 'Gagal mengambil data profil customer',
        'serviceId': null,
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        return {
          'success': false,
          'message': 'Sesi habis. Silakan login ulang.',
          'serviceId': null,
        };
      }
      return {
        'success': false,
        'message': e.response?.data?['message']?.toString() ?? 'Gagal memuat data.',
        'serviceId': null,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan: $e',
        'serviceId': null,
      };
    }
  }

  /// Fetch all available services
  Future<Map<String, dynamic>> getAllServices() async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan',
          'data': <BillService>[],
        };
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.get('/services');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final rawList = body['data'] as List<dynamic>? ?? [];
        final services = rawList
            .whereType<Map<String, dynamic>>()
            .map((s) => BillService.fromJson(s))
            .toList();

        return {
          'success': body['success'] == true,
          'message': body['message']?.toString() ?? '',
          'data': services,
        };
      }

      return {
        'success': false,
        'message': 'Gagal mengambil data layanan',
        'data': <BillService>[],
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        return {
          'success': false,
          'message': 'Sesi habis. Silakan login ulang.',
          'data': <BillService>[],
        };
      }
      return {
        'success': false,
        'message': e.response?.data?['message']?.toString() ?? 'Gagal memuat data.',
        'data': <BillService>[],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan: $e',
        'data': <BillService>[],
      };
    }
  }
}
