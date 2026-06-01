import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/models/bill.dart';
import 'package:aplikasi_pdam/services/url.dart' as url;

class PaymentService {
  late final Dio _dio;

  PaymentService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: url.baseUrl,
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

  // ==================== CREATE PAYMENT ====================
  /// POST /payments  — multipart: bill_id + file + payment_date + total_amount
  Future<Map<String, dynamic>> createPayment({
    required int billId,
    required File imageFile,
    required String paymentDate,
    required double paymentAmount,
  }) async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return {'success': false, 'message': 'Token tidak ditemukan.'};
      }

      final fileName = imageFile.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'bill_id': billId,
        'payment_date': paymentDate,
        'total_amount': paymentAmount,
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '/payments',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      final body = response.data as Map<String, dynamic>;
      return {
        'success': body['success'] == true,
        'message': body['message']?.toString() ?? '',
        'data': body['data'],
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        return {'success': false, 'message': 'Sesi habis. Silakan login ulang.'};
      }
      return {
        'success': false,
        'message': e.response?.data?['message']?.toString() ?? 'Gagal mengirim pembayaran.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // ==================== READ MY PAYMENTS ====================
  /// GET /bills/me  — returns bills with nested payments
  Future<Map<String, dynamic>> getMyPayments() async {
    try {
      final token = await _getStoredToken();
      if (token == null || token.isEmpty) {
        return {
          'success': false,
          'message': 'Token tidak ditemukan.',
          'data': <Bill>[],
          'count': 0,
        };
      }

      final response = await _dio.get(
        '/bills/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

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
        'message': 'Gagal mengambil data pembayaran.',
        'data': <Bill>[],
        'count': 0,
      };
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');
        return {
          'success': false,
          'message': 'Sesi habis. Silakan login ulang.',
          'data': <Bill>[],
          'count': 0,
        };
      }
      return {
        'success': false,
        'message': e.response?.data?['message']?.toString() ?? 'Gagal memuat data.',
        'data': <Bill>[],
        'count': 0,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan: $e',
        'data': <Bill>[],
        'count': 0,
      };
    }
  }

  // ==================== GET PAYMENT PROOF URL ====================
  /// Returns the full URL for accessing a payment proof image
  String getPaymentProofUrl(String fileName) {
    return '${url.baseUrl}/payment-proof/$fileName';
  }
}
