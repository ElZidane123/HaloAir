import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/services/dashboardService.dart';
import 'package:aplikasi_pdam/services/notificationService.dart';
import 'package:aplikasi_pdam/services/notificationStore.dart';

class PaymentDetail {
  final String customerName;
  final double amount;
  PaymentDetail({required this.customerName, required this.amount});
}

/// Service yang melakukan polling periodik ke endpoint /payments
/// untuk mendeteksi pembayaran baru yang belum diverifikasi (admin).
class AdminPaymentPollingService {
  // Singleton
  static final AdminPaymentPollingService _instance =
      AdminPaymentPollingService._internal();
  factory AdminPaymentPollingService() => _instance;
  AdminPaymentPollingService._internal();

  final DashboardService _dashboardService = DashboardService();
  final NotificationService _notificationService = NotificationService();
  final NotificationStore _notificationStore = NotificationStore();

  Timer? _timer;
  int _lastUnverifiedCount = -1; // -1 = belum pernah polling
  Set<String> _notifiedPaymentIds = {}; // Track IDs yang sudah di-notify
  bool _isPolling = false; // Flag untuk prevent concurrent polls

  static const String _prefKey = 'last_unverified_payment_count';
  static const String _notifiedPaymentsKey = 'notified_payment_ids';
  static const Duration _pollInterval = Duration(seconds: 10); // Faster polling untuk real-time

  // Callback dengan detail pembayaran baru
  // Parameters: total count baru, list detail pembayaran baru
  void Function(int newCount, List<PaymentDetail> details)? onNewPayment;

  // ======================== START ========================
  /// Mulai polling. Panggil dari initState adminDashboard.
  Future<void> start() async {
    if (_timer != null && _timer!.isActive) return;

    // Load last count dari prefs supaya persistent antar session
    final prefs = await SharedPreferences.getInstance();
    _lastUnverifiedCount = prefs.getInt(_prefKey) ?? -1;
    
    // Load notified payment IDs
    final notifiedIds = prefs.getStringList(_notifiedPaymentsKey) ?? [];
    _notifiedPaymentIds = notifiedIds.toSet();

    debugPrint('[Polling] Started. Last count: $_lastUnverifiedCount');

    // Langsung check sekali
    await _poll();

    // Lalu periodik
    _timer = Timer.periodic(_pollInterval, (_) => _poll());
  }

  // ======================== STOP ========================
  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('[Polling] Stopped.');
  }

  void dispose() => stop();

  // ======================== POLL ========================
  Future<void> _poll() async {
    // Prevent concurrent polls
    if (_isPolling) return;
    _isPolling = true;

    try {
      final stats = await _dashboardService.getPaymentStats();
      final currentCount = (stats['unverifiedCount'] as int?) ?? 0;

      debugPrint('[Polling] current=$currentCount, last=$_lastUnverifiedCount');

      if (_lastUnverifiedCount == -1) {
        // Pertama kali — simpan baseline, tidak perlu notifikasi
        _lastUnverifiedCount = currentCount;
        await _saveCount(currentCount);
        return;
      }

      if (currentCount > _lastUnverifiedCount) {
        final delta = currentCount - _lastUnverifiedCount;

        // Ambil detail pembayaran baru (nama customer + nominal)
        final details = await _dashboardService.getLatestUnverifiedPayments(limit: delta);
        debugPrint('[Polling] Details fetched: $details');

        // Show detailed notification untuk setiap pembayaran baru yang belum di-notify
        int notificationId = 1001;
        final List<PaymentDetail> paymentDetailsList = [];
        
        for (final detail in details) {
          final customerName = detail['customerName'] as String? ?? 'Customer';
          final amount = detail['amount'] as double? ?? 0.0;
          final paymentKey = '${customerName}_$amount';
          
          // Hanya notify jika payment ini belum pernah di-notify sebelumnya
          if (!_notifiedPaymentIds.contains(paymentKey)) {
            await _notificationService.showDetailedPaymentNotification(
              id: notificationId++,
              customerName: customerName,
              amount: amount,
              totalUnverifiedCount: currentCount,
            );
            
            // Catat payment ini sudah di-notify
            _notifiedPaymentIds.add(paymentKey);
            debugPrint('[Polling] Notified: $customerName - Rp $amount');
          }
          
          // Add to list untuk callback
          paymentDetailsList.add(PaymentDetail(
            customerName: customerName,
            amount: amount,
          ));
        }

        // Simpan ke NotificationStore agar muncul di halaman notifikasi admin
        await _saveToNotificationStore(currentCount, paymentDetailsList);

        // Simpan notified IDs ke preferences
        await _saveNotifiedPaymentIds();

        // Panggil callback ke UI dengan detail
        onNewPayment?.call(currentCount, paymentDetailsList);
        debugPrint('[Polling] Callback executed with ${paymentDetailsList.length} payments');

        debugPrint('[Polling] New payments detected: +$delta (total: $currentCount)');
      }

      _lastUnverifiedCount = currentCount;
      await _saveCount(currentCount);
    } catch (e) {
      debugPrint('[Polling] Error: $e');
    } finally {
      _isPolling = false;
    }
  }

  // ======================== HELPERS ========================
  
  /// Simpan notifikasi ke store agar muncul di halaman notifikasi admin
  Future<void> _saveToNotificationStore(int currentCount, List<PaymentDetail> details) async {
    try {
      await _notificationStore.load();
      if (details.isEmpty) {
        await _notificationStore.add(
          title: '💳 Pembayaran Baru Masuk!',
          body: '$currentCount pembayaran menunggu verifikasi.',
        );
      } else if (details.length == 1) {
        final d = details.first;
        await _notificationStore.add(
          title: '💰 Pembayaran dari ${d.customerName}!',
          body: 'Rp ${_formatNumber(d.amount.toInt())} — segera verifikasi.',
        );
      } else {
        final names = details.map((d) => d.customerName).join(', ');
        await _notificationStore.add(
          title: '📥 ${details.length} Pembayaran Baru!',
          body: 'Dari: $names — Total $currentCount menunggu.',
        );
      }
      debugPrint('[Polling] Saved to NotificationStore');
    } catch (e) {
      debugPrint('[Polling] Error saving to NotificationStore: $e');
    }
  }

  String _formatNumber(num n) {
    return n.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  Future<void> _saveCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKey, count);
  }

  Future<void> _saveNotifiedPaymentIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_notifiedPaymentsKey, _notifiedPaymentIds.toList());
  }

  /// Force polling segera (tidak tunggu interval)
  /// Berguna ketika ada aksi UI yang perlu immediate check
  Future<void> forcePoll() async {
    debugPrint('[Polling] Force poll triggered');
    await _poll();
  }

  /// Reset baseline (misal setelah admin selesai verifikasi)
  Future<void> resetBaseline() async {
    _lastUnverifiedCount = -1;
    _notifiedPaymentIds.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
    await prefs.remove(_notifiedPaymentsKey);
    debugPrint('[Polling] Baseline reset');
  }

  /// Clear notified IDs untuk re-trigger notifications
  /// Berguna jika ada test atau reset system
  Future<void> clearNotifiedIds() async {
    _notifiedPaymentIds.clear();
    await _saveNotifiedPaymentIds();
    debugPrint('[Polling] Notified IDs cleared');
  }

  int get lastUnverifiedCount => _lastUnverifiedCount < 0 ? 0 : _lastUnverifiedCount;
}
