import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/models/bill.dart' as model;
import 'package:aplikasi_pdam/services/paymentService.dart';
import 'package:aplikasi_pdam/services/notificationStore.dart';

class Bill extends StatefulWidget {
  const Bill({super.key});

  @override
  State<Bill> createState() => _BillState();
}

class _BillState extends State<Bill> with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  final NotificationStore _notifStore = NotificationStore();

  late TabController _tabController;
  late Timer _autoRefreshTimer;
  List<model.Bill> _unpaidBills = [];
  List<model.Bill> _paidBills = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Set<int> _uploadedBillIds = {}; // Bill IDs yang sudah diupload customer
  Set<int> _rejectedBillIds = {}; // Bill IDs yang payment-nya hilang (ditolak admin)

  static const String _uploadedKey = 'uploaded_bill_ids';
  static const String _rejectedKey = 'rejected_bill_ids';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _notifStore.addListener(_onNotificationUpdated);
    _loadCachedBills();
    _fetchData();
    
    // Auto-refresh setiap 5 detik untuk detect status changes
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isLoading) {
        _fetchData();
      }
    });
  }

  /// Muat daftar bill yang sudah diupload & ditolak dari local storage
  Future<void> _loadCachedBills() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uploaded = prefs.getStringList(_uploadedKey) ?? [];
      _uploadedBillIds = uploaded.map((e) => int.tryParse(e) ?? 0).toSet();
      final rejected = prefs.getStringList(_rejectedKey) ?? [];
      _rejectedBillIds = rejected.map((e) => int.tryParse(e) ?? 0).toSet();
      debugPrint('[Bill] Loaded: ${_uploadedBillIds.length} uploaded, ${_rejectedBillIds.length} rejected');
    } catch (e) {
      debugPrint('[Bill] Error loading cached bills: $e');
    }
  }

  /// Simpan daftar bill yang sudah diupload
  Future<void> _saveUploadedBill(int billId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_uploadedKey) ?? [];
      if (!ids.contains(billId.toString())) {
        ids.add(billId.toString());
        await prefs.setStringList(_uploadedKey, ids);
      }
      _uploadedBillIds.add(billId);
      debugPrint('[Bill] Saved uploaded bill: $billId');
    } catch (e) {
      debugPrint('[Bill] Error saving uploaded bill: $e');
    }
  }

  /// Hapus rejected flag setelah upload ulang berhasil
  Future<void> _clearRejectedFlag(int billId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Hapus dari rejected list
      final rejected = prefs.getStringList(_rejectedKey) ?? [];
      rejected.remove(billId.toString());
      await prefs.setStringList(_rejectedKey, rejected);
      _rejectedBillIds.remove(billId);
      // Masukkin ke uploaded list
      await _saveUploadedBill(billId);
      debugPrint('[Bill] Cleared rejected flag: $billId');
    } catch (e) {
      debugPrint('[Bill] Error clearing rejected flag: $e');
    }
  }

  /// Deteksi rejection: payment hilang dari bill yang sebelumnya sudah diupload
  Future<void> _detectRejections(List<model.Bill> bills) async {
    final prefs = await SharedPreferences.getInstance();

    for (final billId in _uploadedBillIds.toList()) {
      // Cari bill di response — cek id match
      final found = bills.any((b) => b.id == billId);

      // Jika pernah diupload, bill ada tapi payment kosong → ditolak admin
      if (found) {
        final bill = bills.firstWhere((b) => b.id == billId);
        if (bill.payments.isEmpty && !_rejectedBillIds.contains(billId)) {
          _rejectedBillIds.add(billId);
          final rejectedList = prefs.getStringList(_rejectedKey) ?? [];
          if (!rejectedList.contains(billId.toString())) {
            rejectedList.add(billId.toString());
            await prefs.setStringList(_rejectedKey, rejectedList);
          }
          
          // Simpan notifikasi ke NotificationStore customer
          try {
            await _notifStore.load();
            await _notifStore.add(
              title: '❌ Pembayaran Ditolak',
              body: 'Pembayaran untuk ${bill.invoiceNumber} ditolak oleh admin. Silakan upload ulang bukti pembayaran.',
            );
            debugPrint('[Bill] Saved rejection notification for bill $billId');
          } catch (e) {
            debugPrint('[Bill] Error saving rejection notification: $e');
          }
          
          debugPrint('[Bill] Detected rejection for bill $billId');
        }
      }
      // Jika bill tidak ditemukan sama sekali — mungkin sudah tidak aktif, skip
    }

    // No setState here — caller (_fetchData) handles rebuild via its own setState
  }

  void _onNotificationUpdated() {
    // Tunggu 1.5 detik agar backend selesai update
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        debugPrint('[Bill] Notification updated, refreshing data after delay');
        _fetchData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _autoRefreshTimer.cancel();
    _notifStore.removeListener(_onNotificationUpdated);
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final res = await _paymentService.getMyPayments();
      if (mounted) {
        if (res['success'] == true) {
          final bills = res['data'] as List<model.Bill>;
          
          // Deteksi rejection SEBELUM setState — await outside setState
          await _detectRejections(bills);
          
          setState(() {
            // Paksa bill yang ditolak masuk ke unpaid, meskipun backend masih paid
            _unpaidBills = bills.where((b) => !b.paid || _rejectedBillIds.contains(b.id)).toList();
            _paidBills = bills.where((b) => b.paid && !_rejectedBillIds.contains(b.id)).toList();
            _isLoading = false;
          });
          debugPrint('[Bill] Fetched ${_unpaidBills.length} unpaid (${_rejectedBillIds.length} rejected), ${_paidBills.length} paid');
        } else {
          setState(() {
            _errorMessage = res['message']?.toString() ?? 'Gagal memuat data.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Terjadi kesalahan: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatNumber(num n) {
    return n.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final unpaidTotal = _unpaidBills.fold<double>(0, (s, b) => s + b.amount);

    return Scaffold(
      backgroundColor: const Color(0xffF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ==================== HEADER ====================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kelola Pembayaran Bill',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff091540),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    controller: _tabController,
                    labelColor: const Color(0xff2768CF),
                    unselectedLabelColor: const Color(0xff667085),
                    indicatorColor: const Color(0xff2768CF),
                    indicatorWeight: 2.5,
                    labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    unselectedLabelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                    ),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Belum Dibayar'),
                            if (_unpaidBills.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xffFEE4E2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_unpaidBills.length}',
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xffB42318),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Tab(text: 'Riwayat'),
                    ],
                  ),
                ],
              ),
            ),

            // ==================== BODY ====================
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xff2768CF),
                      ),
                    )
                  : _errorMessage.isNotEmpty
                  ? _buildError()
                  : RefreshIndicator(
                      onRefresh: _fetchData,
                      color: const Color(0xff2768CF),
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildUnpaidTab(unpaidTotal),
                          _buildHistoryTab(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== ERROR STATE ====================
  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xffB42318), size: 48),
            const SizedBox(height: 12),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xff667085),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff2768CF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text('Coba Lagi', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== UNPAID TAB ====================
  Widget _buildUnpaidTab(double unpaidTotal) {
    if (_unpaidBills.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_outline,
        iconColor: const Color(0xff12B76A),
        message: 'Tidak ada tagihan yang belum dibayar',
        subtitle: 'Semua tagihan Anda sudah lunas 🎉',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ..._unpaidBills.map((b) => _buildUnpaidCard(b)),
        const SizedBox(height: 4),

        // Total footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xffEAECF0), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Belum Dibayar',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff344054),
                ),
              ),
              Text(
                'Rp ${_formatNumber(unpaidTotal)}',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xff2768CF),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUnpaidCard(model.Bill bill) {
    final hasPendingPayment = bill.payments.isNotEmpty;
    // Cek rejection: payment dihapus admin (tidak ada di response) + pernah diupload
    final isPaymentRejected = _rejectedBillIds.contains(bill.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffEAECF0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xffF0F5FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.invoiceNumber,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff091540),
                      ),
                    ),
                    Text(
                      bill.period,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xff667085),
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _showBillDetail(context, bill),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffFEE4E2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Belum Dibayar',
                          style: GoogleFonts.poppins(
                            color: const Color(0xffB42318),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: Color(0xff667085),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rp ${_formatNumber(bill.amount)}',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xff091540),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Color(0xff667085),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Jatuh tempo: 28 ${bill.monthName} ${bill.year}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xff667085),
                      ),
                    ),
                  ],
                ),
                if (bill.service != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.water_drop_outlined,
                        size: 14,
                        color: Color(0xff667085),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Layanan: ${bill.service!.name}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xff667085),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.speed_outlined,
                      size: 14,
                      color: Color(0xff667085),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Pemakaian: ${bill.usageValue.toInt()} m³',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xff667085),
                      ),
                    ),
                  ],
                ),

                // Payment Status Notice
                // Tampilkan alert rejection MESKIPUN payments.isEmpty (setelah dihapus admin)
                if (hasPendingPayment || isPaymentRejected) ...[
                  const SizedBox(height: 12),
                  if (isPaymentRejected)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xffFFEBEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xffF04438).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.cancel_outlined,
                            size: 16,
                            color: Color(0xffF04438),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pembayaran ditolak. Silakan upload bukti pembayaran yang sesuai.',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xffF04438),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xffFFFAEB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xffFECD1B).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 16,
                            color: Color(0xffB54708),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Bukti pembayaran sudah dikirim, menunggu verifikasi admin',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xffB54708),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: 14),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showBillDetail(context, bill),
                        icon: const Icon(Icons.info_outline, size: 16),
                        label: Text(
                          'Detail',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff2768CF),
                          side: const BorderSide(color: Color(0xff2768CF)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => _openPaymentSheet(context, bill),
                        icon: const Icon(Icons.upload_file_outlined, size: 16),
                        label: Text(
                          isPaymentRejected ? 'Upload Ulang' : (hasPendingPayment ? 'Kirim Ulang' : 'Bayar'),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPaymentRejected ? const Color(0xffF04438) : const Color(0xff12B76A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== HISTORY TAB ====================
  Widget _buildHistoryTab() {
    if (_paidBills.isEmpty) {
      return _buildEmptyState(
        icon: Icons.receipt_long_outlined,
        iconColor: const Color(0xff667085),
        message: 'Belum ada riwayat pembayaran',
        subtitle: 'Pembayaran yang sudah lunas akan tampil di sini',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _paidBills.length,
      itemBuilder: (_, i) => _buildHistoryCard(_paidBills[i]),
    );
  }

  Widget _buildHistoryCard(model.Bill bill) {
    final payment = bill.payments.isNotEmpty ? bill.payments.last : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffEAECF0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xffF0FDF4),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.invoiceNumber,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff091540),
                      ),
                    ),
                    Text(
                      bill.period,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xff667085),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xffD1FADF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xff027A48),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Lunas',
                        style: GoogleFonts.poppins(
                          color: const Color(0xff027A48),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Bayar',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xff667085),
                      ),
                    ),
                    Text(
                      'Rp ${_formatNumber(payment?.totalAmount ?? bill.amount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff091540),
                      ),
                    ),
                  ],
                ),
                if (payment != null) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xffEAECF0)),
                  const SizedBox(height: 8),
                  _infoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Tanggal Bayar',
                    value: _formatDate(payment.paymentDate),
                  ),
                  const SizedBox(height: 6),
                  _infoRow(
                    icon: Icons.verified_outlined,
                    label: 'Verifikasi',
                    value: payment.verified
                        ? 'Terverifikasi'
                        : 'Menunggu Verifikasi',
                    valueColor: payment.verified
                        ? const Color(0xff027A48)
                        : const Color(0xffB54708),
                  ),
                ],
                const SizedBox(height: 12),

                // Buttons
                Row(
                  children: [
                    if (payment != null && payment.paymentProof.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _showPaymentProof(context, payment.paymentProof),
                          icon: const Icon(Icons.image_outlined, size: 16),
                          label: Text(
                            'Lihat Bukti',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff2768CF),
                            side: const BorderSide(color: Color(0xff2768CF)),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showBillDetail(context, bill),
                        icon: const Icon(Icons.receipt_outlined, size: 16),
                        label: Text(
                          'Detail',
                          style: GoogleFonts.poppins(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff667085),
                          side: const BorderSide(color: Color(0xffD0D5DD)),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EMPTY STATE ====================
  Widget _buildEmptyState({
    required IconData icon,
    required Color iconColor,
    required String message,
    required String subtitle,
  }) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 44),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xff344054),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xff667085),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== BOTTOM SHEET: PAYMENT UPLOAD ====================
  void _openPaymentSheet(BuildContext ctx, model.Bill bill) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentUploadSheet(
        bill: bill,
        paymentService: _paymentService,
        formatNumber: _formatNumber,
        onSuccess: () async {
          // Save/re-save uploaded bill untuk rejection detection
          await _saveUploadedBill(bill.id);
          // Clear rejected flag jika ini re-upload setelah ditolak
          if (_rejectedBillIds.contains(bill.id)) {
            await _clearRejectedFlag(bill.id);
          }
          _fetchData();
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(
                'Bukti pembayaran berhasil dikirim!',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              backgroundColor: const Color(0xff12B76A),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }

  // ==================== BOTTOM SHEET: DETAIL ====================
  void _showBillDetail(BuildContext ctx, model.Bill bill) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BillDetailSheet(
        bill: bill,
        formatNumber: _formatNumber,
        onPay: bill.paid
            ? null
            : () {
                Navigator.pop(ctx);
                _openPaymentSheet(ctx, bill);
              },
      ),
    );
  }

  // ==================== PROOF VIEWER ====================
  void _showPaymentProof(BuildContext ctx, String fileName) {
    final imageUrl = _paymentService.getPaymentProofUrl(fileName);
    showDialog(
      context: ctx,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bukti Pembayaran',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                headers: const {
                  'APP-KEY': '19bb0feea2f8ac775c0866083cad89a2eb4e85ab',
                },
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: const Color(0xff1D2939),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gambar tidak dapat dimuat',
                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 200,
                    color: const Color(0xff1D2939),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== HELPERS ====================
  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xff98A2B3)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: const Color(0xff667085),
              ),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: valueColor ?? const Color(0xff344054),
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

// ==============================================================
// PAYMENT UPLOAD BOTTOM SHEET WIDGET
// ==============================================================
class _PaymentUploadSheet extends StatefulWidget {
  final model.Bill bill;
  final PaymentService paymentService;
  final String Function(num) formatNumber;
  final VoidCallback onSuccess;

  const _PaymentUploadSheet({
    required this.bill,
    required this.paymentService,
    required this.formatNumber,
    required this.onSuccess,
  });

  @override
  State<_PaymentUploadSheet> createState() => _PaymentUploadSheetState();
}

class _PaymentUploadSheetState extends State<_PaymentUploadSheet> {
  File? _selectedImage;
  bool _isUploading = false;
  String _uploadError = '';
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _dateCtrl = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedImage = File(picked.path);
          _uploadError = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadError = 'Gagal memilih gambar: $e');
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xff2768CF)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = '${picked.day}/${picked.month}/${picked.year}';
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedImage == null) {
      setState(
        () => _uploadError = 'Silakan pilih bukti pembayaran terlebih dahulu.',
      );
      return;
    }
    if (_dateCtrl.text.isEmpty) {
      setState(() => _uploadError = 'Silakan pilih tanggal pembayaran.');
      return;
    }
    if (_amountCtrl.text.isEmpty) {
      setState(() => _uploadError = 'Silakan masukkan jumlah pembayaran.');
      return;
    }

    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _uploadError = 'Jumlah pembayaran harus lebih dari 0.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadError = '';
    });

    final dateStr = _selectedDate != null
        ? '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}'
        : '';

    final res = await widget.paymentService.createPayment(
      billId: widget.bill.id,
      imageFile: _selectedImage!,
      paymentDate: dateStr,
      paymentAmount: amount,
    );

    if (!mounted) return;

    if (res['success'] == true) {
      Navigator.pop(context);
      widget.onSuccess();
    } else {
      setState(() {
        _uploadError =
            res['message']?.toString() ?? 'Gagal mengirim pembayaran.';
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xffD0D5DD),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            Text(
              'Upload Bukti Pembayaran',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xff091540),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pastikan bukti pembayaran terlihat jelas',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xff667085),
              ),
            ),
            const SizedBox(height: 20),

            // Bill summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffF0F5FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffBFD3F8), width: 1.2),
              ),
              child: Column(
                children: [
                  _summaryRow('Invoice', bill.invoiceNumber),
                  const SizedBox(height: 8),
                  _summaryRow('Periode', bill.period),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xffBFD3F8)),
                  const SizedBox(height: 8),
                  _summaryRow(
                    'Total Tagihan',
                    'Rp ${widget.formatNumber(bill.amount)}',
                    valueStyle: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff2768CF),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment Date
            Text(
              'Tanggal Pembayaran',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff344054),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xffD0D5DD),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _dateCtrl.text.isEmpty ? 'Pilih tanggal' : _dateCtrl.text,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _dateCtrl.text.isEmpty
                            ? const Color(0xff98A2B3)
                            : Colors.black,
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: Color(0xff2768CF),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Payment Amount
            Text(
              'Jumlah Pembayaran (Rp)',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff344054),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Contoh: 50000',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xff98A2B3),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xffD0D5DD),
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xffD0D5DD),
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xff2768CF),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Bukti Pembayaran',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xff344054),
              ),
            ),
            const SizedBox(height: 10),

            // Image preview / placeholder
            GestureDetector(
              onTap: () => _showSourcePicker(context),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _selectedImage != null
                      ? Colors.transparent
                      : const Color(0xffF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _selectedImage != null
                        ? const Color(0xff2768CF)
                        : const Color(0xffD0D5DD),
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _selectedImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(_selectedImage!, fit: BoxFit.cover),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              color: Colors.black.withValues(alpha: 0.45),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Ganti Foto',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: const BoxDecoration(
                              color: Color(0xffE3EBFD),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.upload_file_outlined,
                              color: Color(0xff2768CF),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap untuk memilih foto',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff2768CF),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Kamera atau Galeri',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xff667085),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Camera & Gallery buttons
            Row(
              children: [
                Expanded(
                  child: _pickerBtn(
                    Icons.camera_alt_outlined,
                    'Kamera',
                    () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _pickerBtn(
                    Icons.photo_library_outlined,
                    'Galeri',
                    () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),

            // Error
            if (_uploadError.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xffFEE4E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xffB42318),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _uploadError,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xffB42318),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff12B76A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xff12B76A,
                  ).withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isUploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Kirim Bukti Pembayaran',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourcePicker(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pilih Sumber Foto',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: const Color(0xff091540),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xffE3EBFD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.camera_alt_outlined,
                  color: Color(0xff2768CF),
                ),
              ),
              title: Text(
                'Kamera',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Ambil foto langsung',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xffE3EBFD),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xff2768CF),
                ),
              ),
              title: Text(
                'Galeri',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Pilih dari galeri foto',
                style: GoogleFonts.poppins(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _pickerBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xffD0D5DD)),
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: const Color(0xff667085)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xff344054),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xff667085),
          ),
        ),
        Text(
          value,
          style:
              valueStyle ??
              GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xff344054),
              ),
        ),
      ],
    );
  }
}

// ==============================================================
// BILL DETAIL BOTTOM SHEET WIDGET
// ==============================================================
class _BillDetailSheet extends StatelessWidget {
  final model.Bill bill;
  final String Function(num) formatNumber;
  final VoidCallback? onPay;

  const _BillDetailSheet({
    required this.bill,
    required this.formatNumber,
    this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final payment = bill.payments.isNotEmpty ? bill.payments.last : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xffD0D5DD),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // Invoice header card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xffF0F5FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xff2768CF).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: Color(0xff2768CF),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.invoiceNumber,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff091540),
                        ),
                      ),
                      Text(
                        bill.period,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xff667085),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Detail Pembayaran',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: const Color(0xff091540),
              ),
            ),
            const SizedBox(height: 12),

            // Info rows
            _detailCard([
              if (bill.customer != null)
                _detailRow('Nama Pelanggan', bill.customer!.name),
              if (bill.customer != null)
                _detailRow('No. Pelanggan', bill.customer!.customerNumber),
              _detailRow('Periode', bill.period),
              if (bill.service != null)
                _detailRow('Layanan', bill.service!.name),
              _detailRow('Pemakaian', '${bill.usageValue.toInt()} m³'),
              _detailRow('No. Pengukuran', bill.measurementNumber),
            ]),
            const SizedBox(height: 12),

            // Total amount banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xff1E40AF), Color(0xff2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Rp ${formatNumber(bill.price)}',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Payment status
            _detailCard([
              _detailRow(
                'Status',
                bill.paid ? 'Lunas' : 'Belum Dibayar',
                valueColor: bill.paid
                    ? const Color(0xff027A48)
                    : const Color(0xffB42318),
              ),
              if (payment != null) ...[
                _detailRow('Tanggal Bayar', _formatDate(payment.paymentDate)),
                _detailRow(
                  'Verifikasi',
                  payment.verified ? 'Terverifikasi' : 'Menunggu Verifikasi',
                  valueColor: payment.verified
                      ? const Color(0xff027A48)
                      : const Color(0xffB54708),
                ),
              ],
              _detailRow('Jatuh Tempo', '28 ${bill.monthName} ${bill.year}'),
            ]),
            const SizedBox(height: 24),

            // Pay button
            if (onPay != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPay,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(
                    'Upload Bukti Pembayaran',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff12B76A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xffEAECF0), width: 1.5),
      ),
      child: Column(
        children: rows
            .asMap()
            .entries
            .expand(
              (e) => [
                e.value,
                if (e.key < rows.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xffF2F4F7)),
                  ),
              ],
            )
            .toList(),
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: const Color(0xff667085),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xff344054),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
