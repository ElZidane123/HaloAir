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

      _dio.options.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.get(_adminMeEndpoint);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResponseDataMap(
          success: true,
          message: response.data['message'] ?? 'Profil berhasil diambil',
          data: response.data['data'],
        );
      } else if (response.statusCode == 401) {
        return await _handleUnauthorized();
      }

      return _handleProfileError(response.data, response.statusCode!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return await _handleUnauthorized();
      }
      return ResponseDataMap(success: false, message: 'Koneksi gagal: ${e.message}');
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

      _dio.options.headers['Authorization'] = 'Bearer $token';
      final response = await _dio.get(_customerMeEndpoint);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return ResponseDataMap(
          success: true,
          message: response.data['message'] ?? 'Profil berhasil diambil',
          data: response.data['data'],
        );
      } else if (response.statusCode == 401) {
        return await _handleUnauthorized();
      }

      return _handleProfileError(response.data, response.statusCode!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return await _handleUnauthorized();
      }
      return ResponseDataMap(success: false, message: 'Koneksi gagal: ${e.message}');
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