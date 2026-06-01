import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/models/responseDataList.dart';
import 'package:aplikasi_pdam/services/url.dart' as url;

class KelolaCustService {
  static const String _customersEndpoint = '/customers';
  late final Dio _dio;

  KelolaCustService() {
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

  Future<ResponseDataList> _handleUnauthorized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    return ResponseDataList(
      success: false,
      message: 'Sesi habis. Silakan login ulang.',
      data: [
        {'redirectToLogin': true},
      ],
    );
  }

  // ==================== CREATE ====================
  Future<ResponseDataList> createCustomer({
    required String username,
    required String password,
    required String customerNumber,
    required String name,
    required String phone,
    required String address,
    required int serviceId,
  }) async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return await _handleUnauthorized();
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.post(
        _customersEndpoint,
        data: {
          'username': username,
          'password': password,
          'customer_number': customerNumber,
          'name': name,
          'phone': phone,
          'address': address,
          'service_id': serviceId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResponseDataList(
          success: response.data['success'] ?? true,
          message: response.data['message'] ?? 'Customer berhasil dibuat',
          data: response.data['data'] != null ? [response.data['data']] : null,
        );
      } else if (response.statusCode == 401) {
        return await _handleUnauthorized();
      }

      return _handleError(response.data, response.statusCode!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return await _handleUnauthorized();
      }
      return ResponseDataList(
        success: false,
        message: 'Koneksi gagal: ${e.message}',
      );
    } catch (e) {
      return ResponseDataList(
        success: false,
        message: 'Terjadi kesalahan sistem: $e',
      );
    }
  }

  // ==================== READ ====================
  Future<ResponseDataList> getCustomers() async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return await _handleUnauthorized();
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.get(_customersEndpoint);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> dataList = response.data['data'] ?? [];
        return ResponseDataList(
          success: response.data['success'] ?? true,
          message: response.data['message'] ?? 'Data customer berhasil diambil',
          data: dataList,
        );
      } else if (response.statusCode == 401) {
        return await _handleUnauthorized();
      }

      return _handleError(response.data, response.statusCode!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return await _handleUnauthorized();
      }
      return ResponseDataList(
        success: false,
        message: 'Koneksi gagal: ${e.message}',
      );
    } catch (e) {
      return ResponseDataList(
        success: false,
        message: 'Terjadi kesalahan sistem: $e',
      );
    }
  }

  // ==================== UPDATE ====================
  Future<ResponseDataList> updateCustomer({
    required int id,
    required String name,
    required String phone,
    required String address,
    required int serviceId,
  }) async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return await _handleUnauthorized();
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.patch(
        '$_customersEndpoint/$id',
        data: {
          'name': name,
          'phone': phone,
          'address': address,
          'service_id': serviceId,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResponseDataList(
          success: response.data['success'] ?? true,
          message: response.data['message'] ?? 'Customer berhasil diperbarui',
          data: response.data['data'] != null ? [response.data['data']] : null,
        );
      } else if (response.statusCode == 401) {
        return await _handleUnauthorized();
      }

      return _handleError(response.data, response.statusCode!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return await _handleUnauthorized();
      }
      return ResponseDataList(
        success: false,
        message: 'Koneksi gagal: ${e.message}',
      );
    } catch (e) {
      return ResponseDataList(
        success: false,
        message: 'Terjadi kesalahan sistem: $e',
      );
    }
  }

  // ==================== DELETE ====================
  Future<ResponseDataList> deleteCustomer(int id) async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return await _handleUnauthorized();
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.delete('$_customersEndpoint/$id');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResponseDataList(
          success: response.data['success'] ?? true,
          message: response.data['message'] ?? 'Customer berhasil dihapus',
          data: response.data['data'] != null
              ? [Map<String, dynamic>.from(response.data['data'] as Map)]
              : null,
        );
      } else if (response.statusCode == 401) {
        return await _handleUnauthorized();
      }

      return _handleError(response.data, response.statusCode!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return await _handleUnauthorized();
      }
      return ResponseDataList(
        success: false,
        message: 'Koneksi gagal: ${e.message}',
      );
    } catch (e) {
      return ResponseDataList(
        success: false,
        message: 'Terjadi kesalahan sistem: $e',
      );
    }
  }

  ResponseDataList _handleError(Map<String, dynamic> response, int statusCode) {
    final message = response['message'];
    return ResponseDataList(
      success: false,
      message: message is List
          ? message.join(', ')
          : (message ?? 'Operasi gagal ($statusCode)'),
    );
  }
}
