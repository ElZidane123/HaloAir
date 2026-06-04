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

      final response = await _dio.post(
        _servicesEndpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {
          'name': name,
          'min_usage': int.tryParse(minUsage) ?? 0,
          'max_usage': int.tryParse(maxUsage) ?? 0,
          'price': int.tryParse(price) ?? 0,
        },
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataList(
        success: body['success'] == true,
        message: body['message']?.toString() ?? 'Servis berhasil dibuat',
        data: body['data'] != null
            ? [(body['data'] is Map ? AdminService.fromJson(body['data'] as Map<String, dynamic>).toJson() : body['data'])]
            : null,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorized();
      return ResponseDataList(
        success: false,
        message: e.response?.data?['message']?.toString() ??
            'Koneksi gagal: ${e.message}',
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

      final response = await _dio.get(
        _servicesEndpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      final List<dynamic> rawList = body['data'] as List<dynamic>? ?? [];
      final services = rawList
          .whereType<Map<String, dynamic>>()
          .map((item) => AdminService.fromJson(item).toJson())
          .toList();

      return ResponseDataList(
        success: body['success'] == true,
        message: body['message']?.toString() ?? 'Data servis berhasil diambil',
        data: services,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorized();
      return ResponseDataList(
        success: false,
        message: e.response?.data?['message']?.toString() ??
            'Koneksi gagal: ${e.message}',
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

      final response = await _dio.get(
        '$_servicesEndpoint/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataList(
        success: body['success'] == true,
        message: body['message']?.toString() ?? 'Data servis berhasil diambil',
        data: body['data'] != null
            ? [AdminService.fromJson(body['data'] as Map<String, dynamic>).toJson()]
            : null,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorized();
      return ResponseDataList(
        success: false,
        message: e.response?.data?['message']?.toString() ??
            'Koneksi gagal: ${e.message}',
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

      final response = await _dio.patch(
        '$_servicesEndpoint/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: {
          'name': name,
          'min_usage': int.tryParse(minUsage) ?? 0,
          'max_usage': int.tryParse(maxUsage) ?? 0,
          'price': int.tryParse(price) ?? 0,
        },
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataList(
        success: body['success'] == true,
        message: body['message']?.toString() ?? 'Servis berhasil diperbarui',
        data: body['data'] != null
            ? [(body['data'] is Map ? AdminService.fromJson(body['data'] as Map<String, dynamic>).toJson() : body['data'])]
            : null,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorized();
      return ResponseDataList(
        success: false,
        message: e.response?.data?['message']?.toString() ??
            'Koneksi gagal: ${e.message}',
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

      final response = await _dio.delete(
        '$_servicesEndpoint/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataList(
        success: body['success'] == true,
        message: body['message']?.toString() ?? 'Servis berhasil dihapus',
        data: body['data'] as List?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorized();
      return ResponseDataList(
        success: false,
        message: e.response?.data?['message']?.toString() ??
            'Koneksi gagal: ${e.message}',
      );
    }
  }


}
