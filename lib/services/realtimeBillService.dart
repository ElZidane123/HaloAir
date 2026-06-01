// lib/services/realtimeBillService.dart (tanpa WebSocket)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:aplikasi_pdam/models/bill.dart';
import 'package:aplikasi_pdam/services/customerDashboardService.dart';

class RealtimeBillService {
  final CustomerDashboardService _dashboardService = CustomerDashboardService();
  Timer? _pollingTimer;
  List<Bill> _lastBills = [];
  Function(List<Bill>)? onNewBill;
  Function(List<Bill>)? onBillUpdate;

  void startPolling({Duration interval = const Duration(seconds: 5)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (timer) async {
      await _checkForUpdates();
    });
    debugPrint('[RealtimeBill] Polling started, interval: ${interval.inSeconds}s');
  }

  Future<void> _checkForUpdates() async {
    try {
      final res = await _dashboardService.getCustomerBills();
      if (res['success'] == true) {
        final currentBills = res['data'] as List<Bill>;

        // Check for new bills
        if (_lastBills.isNotEmpty) {
          final newBills = currentBills.where((bill) =>
            !_lastBills.any((last) => last.id == bill.id)
          ).toList();

          if (newBills.isNotEmpty) {
            debugPrint('[RealtimeBill] ${newBills.length} new bill(s) found');
            onNewBill?.call(newBills);
          }

          // Check for updated bills
          final updatedBills = currentBills.where((bill) {
            final lastBill = _lastBills.firstWhere(
              (last) => last.id == bill.id,
              orElse: () => bill,
            );
            return lastBill.paid != bill.paid ||
                   lastBill.verifiedPayment != bill.verifiedPayment;
          }).toList();

          if (updatedBills.isNotEmpty) {
            debugPrint('[RealtimeBill] ${updatedBills.length} updated bill(s)');
            onBillUpdate?.call(updatedBills);
          }
        }

        _lastBills = currentBills;
      }
    } catch (e) {
      debugPrint('[RealtimeBill] Polling error: $e');
    }
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    debugPrint('[RealtimeBill] Polling stopped');
  }

  void dispose() {
    stopPolling();
  }
}