import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/models/adminService.dart';
import 'package:aplikasi_pdam/models/responseDataList.dart';
import 'package:aplikasi_pdam/services/url.dart' as url;

class KelolaServisService {
  static const String _servicesEndpoint = '/services';

  late final Dio _dio;

  KelolaServisService() {
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

  /// Get stored token from local storage
  Future<String?> _getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Handle unauthorized response (token expired)
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

  /// Create new service
  Future<ResponseDataList> createService({
    required String name,
    required String minUsage,
    required String maxUsage,
    required String price,
  }) async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return await _handleUnauthorized();
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.post(
        _servicesEndpoint,
        data: {
          'name': name,
          'min_usage': minUsage,
          'max_usage': maxUsage,
          'price': price,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResponseDataList(
          success: response.data['success'] ?? true,
          message: response.data['message'] ?? 'Servis berhasil dibuat',
          data: response.data['data'] != null
              ? [AdminService.fromJson(response.data['data']).toJson()]
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
    }
  }

  // ==================== READ ====================

  /// Get all services
  Future<ResponseDataList> getServices() async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return await _handleUnauthorized();
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.get(_servicesEndpoint);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final List<dynamic> dataList = response.data['data'] ?? [];
        final services = dataList
            .map(
              (item) =>
                  AdminService.fromJson(item as Map<String, dynamic>).toJson(),
            )
            .toList();

        return ResponseDataList(
          success: response.data['success'] ?? true,
          message: response.data['message'] ?? 'Data servis berhasil diambil',
          data: services,
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
    }
  }

  /// Get service by ID
  Future<ResponseDataList> getServiceById(int id) async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return await _handleUnauthorized();
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.get('$_servicesEndpoint/$id');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResponseDataList(
          success: response.data['success'] ?? true,
          message: response.data['message'] ?? 'Data servis berhasil diambil',
          data: response.data['data'] != null
              ? [AdminService.fromJson(response.data['data']).toJson()]
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
    }
  }

  // ==================== UPDATE ====================

  /// Update existing service
  Future<ResponseDataList> updateService({
    required int id,
    required String name,
    required String minUsage,
    required String maxUsage,
    required String price,
  }) async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return await _handleUnauthorized();
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.patch(
        '$_servicesEndpoint/$id',
        data: {
          'name': name,
          'min_usage': minUsage,
          'max_usage': maxUsage,
          'price': price,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResponseDataList(
          success: response.data['success'] ?? true,
          message: response.data['message'] ?? 'Servis berhasil diperbarui',
          data: response.data['data'] != null
              ? [AdminService.fromJson(response.data['data']).toJson()]
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
    }
  }

  // ==================== DELETE ====================

  /// Delete service by ID
  Future<ResponseDataList> deleteService(int id) async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return await _handleUnauthorized();
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.delete('$_servicesEndpoint/$id');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResponseDataList(
          success: response.data['success'] ?? true,
          message: response.data['message'] ?? 'Servis berhasil dihapus',
          data: response.data['data'],
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
    }
  }

  // ==================== ERROR HANDLING ====================

  /// Handle error response
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
