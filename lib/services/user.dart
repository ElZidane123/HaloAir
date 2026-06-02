import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/models/responseDataMap.dart';
import 'package:aplikasi_pdam/services/url.dart' as url;

class UserServices {
  // API Endpoints
  static const String _adminEndpoint = '/admins';
  static const String _customerEndpoint = '/customers';
  static const String _authEndpoint = '/auth';
  static const String _adminMeEndpoint = '/admins/me';
  static const String _customerMeEndpoint = '/customers/me';

  // Dio instance
  late final Dio _dio;

  UserServices() {
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

  // ==================== AUTHENTICATION ====================

  /// Register new admin user
  Future<ResponseDataMap> registerUser(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        _adminEndpoint,
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return await _handleRegistrationSuccess(data, response.data, 'ADMIN');
      }
      return _handleRegistrationError(response.data, response.statusCode!);
    } on DioException catch (e) {
      return ResponseDataMap(success: false, message: 'Koneksi gagal: ${e.message}');
    }
  }

  /// Register new customer user
  Future<ResponseDataMap> registerCustomer(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        _customerEndpoint,
        data: data,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return await _handleRegistrationSuccess(data, response.data, 'CUSTOMER');
      }
      return _handleRegistrationError(response.data, response.statusCode!);
    } on DioException catch (e) {
      return ResponseDataMap(success: false, message: 'Koneksi gagal: ${e.message}');
    }
  }

  /// Handle registration success - save token if available or auto-login
  Future<ResponseDataMap> _handleRegistrationSuccess(
    Map<String, dynamic> data,
    Map<String, dynamic> response,
    String defaultRole,
  ) async {
    final String token = response['token'] ?? '';
    final String role = response['role'] ?? defaultRole;
    final String username = data['username'] ?? '';
    final String password = data['password'] ?? '';
    final String message = response['message'] ?? 'Registrasi Berhasil!';

    // Jika server langsung memberikan token, simpan
    if (token.isNotEmpty) {
      await _saveAuthCredentials(token, role, username);
      return ResponseDataMap(
        success: true,
        message: message,
        data: response['data'],
      );
    }

    // Jika tidak ada token, lakukan auto-login
    if (username.isEmpty || password.isEmpty) {
      return ResponseDataMap(
        success: false,
        message: 'Data registrasi tidak lengkap',
      );
    }

    final loginResult = await loginUser(username, password);
    if (loginResult.success) {
      return ResponseDataMap(
        success: true,
        message: message,
        data: response['data'],
      );
    }
    return loginResult;
  }

  /// Handle registration error response
  ResponseDataMap _handleRegistrationError(
    Map<String, dynamic> response,
    int statusCode,
  ) {
    final message = response['message'];
    return ResponseDataMap(
      success: false,
      message: message is List
          ? message.join(', ')
          : (message ?? 'Registrasi gagal ($statusCode)'),
    );
  }

  /// Login user with username and password
  Future<ResponseDataMap> loginUser(String username, String password) async {
    try {
      final response = await _dio.post(
        _authEndpoint,
        data: {'username': username, 'password': password},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final String token = response.data['token'] ?? '';
        final String role = response.data['role'] ?? 'CUSTOMER';

        if (token.isEmpty) {
          return ResponseDataMap(
            success: false,
            message: 'Server tidak mengirimkan token',
          );
        }

        await _saveAuthCredentials(token, role, username);
        return ResponseDataMap(
          success: true,
          message: response.data['message'] ?? 'Login Berhasil!',
          data: {'token': token, 'role': role},
        );
      }

      return _handleLoginError(response.data, response.statusCode!);
    } on DioException catch (e) {
      return ResponseDataMap(success: false, message: 'Koneksi gagal: ${e.message}');
    }
  }

  /// Handle login error response
  ResponseDataMap _handleLoginError(
    Map<String, dynamic> response,
    int statusCode,
  ) {
    final message = response['message'];
    return ResponseDataMap(
      success: false,
      message: message is List
          ? message.join(', ')
          : (message ?? 'Login gagal ($statusCode)'),
    );
  }

  // ==================== HELPER METHODS ====================

  /// Save authentication credentials to local storage
  Future<void> _saveAuthCredentials(
    String token,
    String role,
    String username,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('role', role.toUpperCase());
    await prefs.setString('username', username);
  }

  /// Get stored token from local storage
  Future<String?> _getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }



  /// Handle unauthorized response (token expired)
  Future<ResponseDataMap> _handleUnauthorized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    return ResponseDataMap(
      success: false,
      message: 'Sesi habis. Silakan login ulang.',
      data: {'redirectToLogin': true},
    );
  }

  // ==================== PROFILE (SHOWME) ====================

  /// Get admin profile
  Future<ResponseDataMap> showmeAdmin() async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return ResponseDataMap(
          success: false,
          message: 'Token tidak ditemukan. Silakan login ulang.',
          data: {'redirectToLogin': true},
        );
      }

      final response = await _dio.get(
        _adminMeEndpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataMap(
        success: body['success'] == true || response.statusCode == 200,
        message: body['message']?.toString() ?? 'Profil berhasil diambil',
        data: body['data'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorized();
      return ResponseDataMap(
        success: false,
        message: e.response?.data?['message']?.toString() ??
            'Koneksi gagal: ${e.message}',
      );
    } catch (e) {
      return ResponseDataMap(success: false, message: 'Terjadi kesalahan: $e');
    }
  }

  /// Get customer profile
  Future<ResponseDataMap> showmeCustomer() async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return ResponseDataMap(
          success: false,
          message: 'Token tidak ditemukan. Silakan login ulang.',
          data: {'redirectToLogin': true},
        );
      }

      final response = await _dio.get(
        _customerMeEndpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataMap(
        success: body['success'] == true || response.statusCode == 200,
        message: body['message']?.toString() ?? 'Profil berhasil diambil',
        data: body['data'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorized();
      return ResponseDataMap(
        success: false,
        message: e.response?.data?['message']?.toString() ??
            'Koneksi gagal: ${e.message}',
      );
    } catch (e) {
      return ResponseDataMap(success: false, message: 'Terjadi kesalahan: $e');
    }
  }

  // ==================== UPDATE PROFILE ====================

  /// Update admin profile. [id] is the admin ID from profile data.
  Future<ResponseDataMap> updateAdmin(int id, Map<String, dynamic> data) async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return ResponseDataMap(success: false, message: 'Token tidak ditemukan');
      }

      final response = await _dio.patch(
        '$_adminEndpoint/$id',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataMap(
        success: body['success'] == true || response.statusCode == 200,
        message: body['message']?.toString() ?? 'Profil berhasil diperbarui',
        data: body['data'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorized();
      return ResponseDataMap(
        success: false,
        message: e.response?.data?['message']?.toString() ??
            'Gagal memperbarui profil: ${e.message}',
      );
    } catch (e) {
      return ResponseDataMap(success: false, message: 'Terjadi kesalahan: $e');
    }
  }

  /// Update customer profile. [id] is the customer ID from profile data.
  Future<ResponseDataMap> updateCustomer(int id, Map<String, dynamic> data) async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return ResponseDataMap(success: false, message: 'Token tidak ditemukan');
      }

      final response = await _dio.patch(
        '$_customerEndpoint/$id',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataMap(
        success: body['success'] == true || response.statusCode == 200,
        message: body['message']?.toString() ?? 'Profil berhasil diperbarui',
        data: body['data'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorized();
      return ResponseDataMap(
        success: false,
        message: e.response?.data?['message']?.toString() ??
            'Gagal memperbarui profil: ${e.message}',
      );
    } catch (e) {
      return ResponseDataMap(success: false, message: 'Terjadi kesalahan: $e');
    }
  }

  /// Handle profile fetch error response
  ResponseDataMap _handleProfileError(
    Map<String, dynamic> response,
    int statusCode,
  ) {
    final message = response['message'];
    return ResponseDataMap(
      success: false,
      message: message is List
          ? message.join(', ')
          : (message ?? 'Gagal mengambil profil ($statusCode)'),
    );
  }
}