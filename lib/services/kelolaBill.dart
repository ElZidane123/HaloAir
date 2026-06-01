import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/models/bill.dart';
import 'package:aplikasi_pdam/models/responseDataList.dart';
import 'package:aplikasi_pdam/models/responseDataMap.dart';
import 'package:aplikasi_pdam/services/url.dart' as url;
class KelolaBillService {
  static const String _billsEndpoint = '/bills';

  late final Dio _dio;
  KelolaBillService() {
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

  /// Get stored token from SharedPreferences
  Future<String?> _getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Handle unauthorized (401) response
  Future<ResponseDataList> _handleUnauthorizedList() async {
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

  Future<ResponseDataMap> _handleUnauthorizedMap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    return ResponseDataMap(
      success: false,
      message: 'Sesi habis. Silakan login ulang.',
      data: {'redirectToLogin': true},
    );
  }

  // ==================== READ (GET ALL) ====================

  /// Fetch all bills
  Future<ResponseDataList> getBills() async {
    try {
      final token = await _getStoredToken();
      if (token == null) {
        return ResponseDataList(
          success: false,
          message: 'Token tidak ditemukan.',
        );
      }

      final response = await _dio.get(
        _billsEndpoint,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      final rawList = body['data'] as List<dynamic>? ?? [];
      final bills = rawList
          .whereType<Map<String, dynamic>>()
          .map((j) => Bill.fromJson(j))
          .toList();

      return ResponseDataList(
        success: body['success'] == true,
        message: body['message']?.toString() ?? '',
        data: bills,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorizedList();
      return ResponseDataList(
        success: false,
        message:
            e.response?.data?['message']?.toString() ?? 'Gagal memuat tagihan.',
      );
    } catch (e) {
      return ResponseDataList(success: false, message: 'Terjadi kesalahan: $e');
    }
  }

  // ==================== CREATE ====================

  /// Create a new bill
  Future<ResponseDataMap> createBill({
    required int customerId,
    required int month,
    required int year,
    required String measurementNumber,
    required double usageValue,
  }) async {
    try {
      final token = await _getStoredToken();
      if (token == null) {
        return ResponseDataMap(
          success: false,
          message: 'Token tidak ditemukan.',
        );
      }

      final response = await _dio.post(
        _billsEndpoint,
        data: {
          'customer_id': customerId,
          'month': month,
          'year': year,
          'measurement_number': measurementNumber,
          'usage_value': usageValue,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataMap(
        success: body['success'] == true,
        message: body['message']?.toString() ?? '',
        data: body['data'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorizedMap();
      return ResponseDataMap(
        success: false,
        message:
            e.response?.data?['message']?.toString() ??
            'Gagal membuat tagihan.',
      );
    } catch (e) {
      return ResponseDataMap(success: false, message: 'Terjadi kesalahan: $e');
    }
  }

  // ==================== UPDATE ====================

  /// Update an existing bill by id
  Future<ResponseDataMap> updateBill({
    required int id,
    required int month,
    required int year,
    required String measurementNumber,
    required double usageValue,
  }) async {
    try {
      final token = await _getStoredToken();
      if (token == null) {
        return ResponseDataMap(
          success: false,
          message: 'Token tidak ditemukan.',
        );
      }

      final response = await _dio.put(
        '$_billsEndpoint/$id',
        data: {
          'month': month,
          'year': year,
          'measurement_number': measurementNumber,
          'usage_value': usageValue,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataMap(
        success: body['success'] == true,
        message: body['message']?.toString() ?? '',
        data: body['data'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorizedMap();
      return ResponseDataMap(
        success: false,
        message:
            e.response?.data?['message']?.toString() ??
            'Gagal memperbarui tagihan.',
      );
    } catch (e) {
      return ResponseDataMap(success: false, message: 'Terjadi kesalahan: $e');
    }
  }

  // ==================== DELETE ====================

  /// Delete a bill by id
  Future<ResponseDataMap> deleteBill(int id) async {
    try {
      final token = await _getStoredToken();
      if (token == null) {
        return ResponseDataMap(
          success: false,
          message: 'Token tidak ditemukan.',
        );
      }

      final response = await _dio.delete(
        '$_billsEndpoint/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataMap(
        success: body['success'] == true,
        message: body['message']?.toString() ?? '',
        data: body['data'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorizedMap();
      return ResponseDataMap(
        success: false,
        message:
            e.response?.data?['message']?.toString() ??
            'Gagal menghapus tagihan.',
      );
    } catch (e) {
      return ResponseDataMap(success: false, message: 'Terjadi kesalahan: $e');
    }
  }

  // ==================== VERIFY ACCEPT ====================

  /// Accept / approve a payment by payment id
  Future<ResponseDataMap> verifyAcceptPayment(int paymentId) async {
    try {
      final token = await _getStoredToken();
      if (token == null) {
        return ResponseDataMap(
          success: false,
          message: 'Token tidak ditemukan.',
        );
      }

      // Gunakan PATCH, bukan POST, dan tanpa payload
      final response = await _dio.patch(
        '/payments/$paymentId', // Endpoint yang benar
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      return ResponseDataMap(
        success: body['success'] == true,
        message: body['message']?.toString() ?? '',
        data: body['data'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorizedMap();
      return ResponseDataMap(
        success: false,
        message:
            e.response?.data?['message']?.toString() ??
            'Gagal menerima pembayaran.',
      );
    } catch (e) {
      return ResponseDataMap(success: false, message: 'Terjadi kesalahan: $e');
    }
  }

  // ==================== VERIFY REJECT ====================

  /// Reject a payment by payment id + notify customer via store
  /// Backend PATCH = auto-accept, jadi pakai DELETE untuk reject
  Future<ResponseDataMap> verifyRejectPayment(
    int paymentId, {
    int? billId,
    String reason = 'Bukti pembayaran tidak sesuai dengan transaksi.',
  }) async {
    try {
      final token = await _getStoredToken();
      if (token == null) {
        return ResponseDataMap(
          success: false,
          message: 'Token tidak ditemukan.',
        );
      }

      // DELETE payment (backend PATCH auto-accept, jadi harus DELETE)
      final response = await _dio.delete(
        '/payments/$paymentId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      final body = response.data as Map<String, dynamic>;
      final success = body['success'] == true;

      if (success) {
        // No need to track or notify here — NotificationStore is local to device.
        // Customer will detect rejection via polling (payment disappeared = rejected).
        debugPrint('[KelolaBillService] Payment $paymentId rejected successfully');
      }

      return ResponseDataMap(
        success: success,
        message: body['message']?.toString() ?? '',
        data: body['data'] as Map<String, dynamic>?,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) return await _handleUnauthorizedMap();
      return ResponseDataMap(
        success: false,
        message:
            e.response?.data?['message']?.toString() ??
            'Gagal menolak pembayaran.',
      );
    } catch (e) {
      return ResponseDataMap(success: false, message: 'Terjadi kesalahan: $e');
    }
  }



}
