import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aplikasi_pdam/models/bill.dart';
import 'package:aplikasi_pdam/models/customer.dart';
import 'package:aplikasi_pdam/services/kelolaBill.dart';
import 'package:aplikasi_pdam/services/kelolaCust.dart';
import 'package:aplikasi_pdam/widgets/alertMassage.dart';
import 'package:aplikasi_pdam/services/invoicePdf.dart';

class KelolaBill extends StatefulWidget {
  const KelolaBill({super.key});

  @override
  State<KelolaBill> createState() => _KelolaBillState();
}

class _KelolaBillState extends State<KelolaBill>
    with SingleTickerProviderStateMixin {
  final KelolaBillService _billService = KelolaBillService();
  final KelolaCustService _custService = KelolaCustService();
  final Alertmassage _alert = Alertmassage();

  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Bill> _allBills = [];
  List<Bill> _filteredBills = [];
  List<Customer> _customers = [];
  bool _isLoading = true;

  DateTime? _filterFromDate;
  DateTime? _filterToDate;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final billRes = await _billService.getBills();
      final custRes = await _custService.getCustomers();

      if (mounted) {
        setState(() {
          if (billRes.success && billRes.data != null) {
            _allBills = billRes.data!.whereType<Bill>().toList();
          }
          if (custRes.success && custRes.data != null) {
            _customers = custRes.data!
                .whereType<Map<String, dynamic>>()
                .map((j) => Customer.fromJson(j))
                .toList();
          }
          _applyFilter(_searchController.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter([String? query]) {
    final q = (query ?? _searchController.text).toLowerCase();
    setState(() {
      _filteredBills = _allBills.where((b) {
        // 1. Search Query filter
        final name = b.customer?.name.toLowerCase() ?? '';
        final inv = b.invoiceNumber.toLowerCase();
        final matchesSearch = name.contains(q) || inv.contains(q);
        if (!matchesSearch) return false;

        // 2. Status filter
        if (_filterStatus != null) {
          bool statusMatches = false;
          if (_filterStatus == 'Sudah Diverifikasi') {
            statusMatches = b.verifiedPayment;
          } else if (_filterStatus == 'Belum Diverifikasi') {
            statusMatches = b.paid && !b.verifiedPayment;
          } else if (_filterStatus == 'Pending Upload') {
            statusMatches = !b.paid && b.payments.isNotEmpty;
          } else if (_filterStatus == 'Ditolak') {
            statusMatches = !b.paid && b.payments.isEmpty;
          }
          if (!statusMatches) return false;
        }

        // 3. Date Range filter
        if (_filterFromDate != null || _filterToDate != null) {
          final billDate = DateTime.tryParse(b.createdAt)?.toLocal();
          if (billDate != null) {
            if (_filterFromDate != null) {
              final from = DateTime(_filterFromDate!.year, _filterFromDate!.month, _filterFromDate!.day);
              final dateComp = DateTime(billDate.year, billDate.month, billDate.day);
              if (dateComp.isBefore(from)) return false;
            }
            if (_filterToDate != null) {
              final to = DateTime(_filterToDate!.year, _filterToDate!.month, _filterToDate!.day, 23, 59, 59);
              if (billDate.isAfter(to)) return false;
            }
          }
        }

        return true;
      }).toList();
    });
  }

  List<Bill> get _unverifiedBills =>
      _filteredBills.where((b) => !b.verifiedPayment && b.paid).toList();

  List<Bill> get _tabBills =>
      _tabController.index == 0 ? _unverifiedBills : _filteredBills;

  String _formatNumber(num n) => n
      .toInt()
      .toString()
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');

  // ==================== FILTER HELPERS ====================
  String _formatDateDDMMYYYY(DateTime? date) {
    if (date == null) return 'Select date';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    return '$day-$month-$year';
  }

  Widget _buildRadioCircle(bool isSelected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? const Color(0xff295CD0) : const Color(0xffD0D5DD),
          width: isSelected ? 6.5 : 1.5,
        ),
        color: Colors.white,
      ),
    );
  }

  Widget _buildStatusRow({
    required IconData icon,
    required Color iconColor,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(12) : Radius.zero,
        bottom: isLast ? const Radius.circular(12) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ),
            _buildRadioCircle(isSelected),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    DateTime? tempFrom = _filterFromDate;
    DateTime? tempTo = _filterToDate;
    String? tempStatus = _filterStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      'Filter',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff1D2939),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xffEAECF0)),
                  const SizedBox(height: 20),

                  Text(
                    'Date Range',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff1D2939),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'From',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff667085),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: tempFrom ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xff295CD0),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null) {
                                  setSheetState(() => tempFrom = date);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xffD0D5DD),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDateDDMMYYYY(tempFrom),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: tempFrom == null
                                            ? const Color(0xff98A2B3)
                                            : const Color(0xff344054),
                                        fontWeight: tempFrom == null
                                            ? FontWeight.w400
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      color: Color(0xff667085),
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'To',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xff667085),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: tempTo ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xff295CD0),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (date != null) {
                                  setSheetState(() => tempTo = date);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xffD0D5DD),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDateDDMMYYYY(tempTo),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: tempTo == null
                                            ? const Color(0xff98A2B3)
                                            : const Color(0xff344054),
                                        fontWeight: tempTo == null
                                            ? FontWeight.w400
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    const Icon(
                                      Icons.calendar_month_rounded,
                                      color: Color(0xff667085),
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Status',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff1D2939),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xffEAECF0),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildStatusRow(
                          icon: Icons.access_time_rounded,
                          iconColor: const Color(0xffF79009),
                          text: 'Belum Diverifikasi',
                          isSelected: tempStatus == 'Belum Diverifikasi',
                          onTap: () {
                            setSheetState(() {
                              tempStatus = tempStatus == 'Belum Diverifikasi'
                                  ? null
                                  : 'Belum Diverifikasi';
                            });
                          },
                          isFirst: true,
                        ),
                        const Divider(height: 1, color: Color(0xffEAECF0)),
                        _buildStatusRow(
                          icon: Icons.cloud_upload_rounded,
                          iconColor: const Color(0xff2F80ED),
                          text: 'Pending Upload',
                          isSelected: tempStatus == 'Pending Upload',
                          onTap: () {
                            setSheetState(() {
                              tempStatus = tempStatus == 'Pending Upload'
                                  ? null
                                  : 'Pending Upload';
                            });
                          },
                        ),
                        const Divider(height: 1, color: Color(0xffEAECF0)),
                        _buildStatusRow(
                          icon: Icons.check_circle_rounded,
                          iconColor: const Color(0xff12B76A),
                          text: 'Sudah Diverifikasi',
                          isSelected: tempStatus == 'Sudah Diverifikasi',
                          onTap: () {
                            setSheetState(() {
                              tempStatus = tempStatus == 'Sudah Diverifikasi'
                                  ? null
                                  : 'Sudah Diverifikasi';
                            });
                          },
                        ),
                        const Divider(height: 1, color: Color(0xffEAECF0)),
                        _buildStatusRow(
                          icon: Icons.cancel_rounded,
                          iconColor: const Color(0xffF04438),
                          text: 'Ditolak',
                          isSelected: tempStatus == 'Ditolak',
                          onTap: () {
                            setSheetState(() {
                              tempStatus = tempStatus == 'Ditolak'
                                  ? null
                                  : 'Ditolak';
                            });
                          },
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setSheetState(() {
                              tempFrom = null;
                              tempTo = null;
                              tempStatus = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Color(0xffD0D5DD), width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Reset All',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xff344054),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _filterFromDate = tempFrom;
                              _filterToDate = tempTo;
                              _filterStatus = tempStatus;
                            });
                            _applyFilter();
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff295CD0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'Apply now',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ==================== VERIFY ====================
  void _verifyPayment(Bill bill, bool accept) async {
    if (bill.payments.isEmpty) {
      _alert.showAlert(context, 'Tidak ada data pembayaran.', false);
      return;
    }
    
    final payment = bill.payments.last;
    final label = accept ? 'Terima' : 'Tolak';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$label Pembayaran',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          '$label pembayaran dari ${bill.customer?.name ?? '-'} sebesar Rp ${_formatNumber(bill.amount)}?',
          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xff475467)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.poppins(color: const Color(0xff667085), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: accept ? const Color(0xff12B76A) : Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(label,
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    try {
      final res = accept
          ? await _billService.verifyAcceptPayment(payment.id)
          : await _billService.verifyRejectPayment(payment.id, billId: bill.id);
          
      if (mounted) {
        _alert.showAlert(context, res.success ? 'Pembayaran berhasil di-$label!' : res.message, res.success);
      }
      if (res.success) {
        await _fetchData();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _alert.showAlert(context, 'Terjadi kesalahan: $e', false);
      }
    }
  }

  // ==================== DELETE ====================
  void _confirmDelete(Bill bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Tagihan',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        content: Text(
          'Hapus tagihan ${bill.invoiceNumber} untuk ${bill.customer?.name ?? '-'}?',
          style: GoogleFonts.poppins(fontSize: 14, color: const Color(0xff475467)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal',
                style: GoogleFonts.poppins(
                    color: const Color(0xff667085), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              final res = await _billService.deleteBill(bill.id);
              if (mounted) {
                _alert.showAlert(context, res.success ? 'Tagihan berhasil dihapus!' : res.message, res.success);
              }
              if (res.success) {
                _fetchData();
              } else {
                setState(() => _isLoading = false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Hapus',
                style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ==================== PRINT INVOICE ====================
  Future<void> _printInvoice(Bill bill) async {
    await InvoicePdfService.showInvoicePreview(context, bill);
  }

  // ==================== DETAIL SHEET ====================
  void _showBillDetail(Bill bill) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isPaid = bill.paid;
        final isVerified = bill.verifiedPayment;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xffD0D5DD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xff295CD0), Color(0xff41a1f6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.invoiceNumber,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bill.customer?.name ?? '-',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Rp ${_formatNumber(bill.amount)}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isVerified
                                  ? const Color(0xff12B76A)
                                  : isPaid
                                      ? Colors.orange
                                      : Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isVerified ? 'Terverifikasi' : isPaid ? 'Menunggu Verifikasi' : 'Belum Bayar',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _billDetailRow(Icons.calendar_month_rounded, 'Periode', bill.period),
                const Divider(height: 1, color: Color(0xffF2F4F7)),
                _billDetailRow(Icons.speed_rounded, 'No. Meteran', bill.measurementNumber),
                const Divider(height: 1, color: Color(0xffF2F4F7)),
                _billDetailRow(Icons.water_drop_rounded, 'Pemakaian', '${bill.usageValue} m³'),
                const Divider(height: 1, color: Color(0xffF2F4F7)),
                _billDetailRow(Icons.layers_rounded, 'Layanan', bill.service?.name ?? '-'),
                const Divider(height: 1, color: Color(0xffF2F4F7)),
                _billDetailRow(Icons.location_on_rounded, 'Alamat', bill.customer?.address ?? '-'),
                const Divider(height: 1, color: Color(0xffF2F4F7)),
                _billDetailRow(Icons.phone_android_rounded, 'Telepon', bill.customer?.phone ?? '-'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _printInvoice(bill),
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: Text('Cetak Invoice', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xff295CD0),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showBillForm(bill: bill);
                        },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: Text('Edit', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff295CD0),
                          side: const BorderSide(color: Color(0xff295CD0)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _confirmDelete(bill);
                        },
                        icon: const Icon(Icons.delete_rounded, size: 18),
                        label: Text('Hapus', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isPaid && !isVerified) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _verifyPayment(bill, true);
                          },
                          icon: const Icon(Icons.check_circle_rounded, size: 18),
                          label: Text('Terima', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff12B76A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _verifyPayment(bill, false);
                          },
                          icon: const Icon(Icons.cancel_rounded, size: 18),
                          label: Text('Tolak', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _billDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xffF2F4F7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xff667085), size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.poppins(
                      fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xff98A2B3))),
              Text(value,
                  style: GoogleFonts.poppins(
                      fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xff344054))),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== CARD FOR ALL BILLS TAB ====================
  Widget _buildAllBillCard(Bill bill) {
    // Determine status
    String statusText;
    Color statusColor;
    Color statusBgColor;
    
    if (bill.verifiedPayment) {
      statusText = 'Sudah Diverifikasi';
      statusColor = const Color(0xff027A48);
      statusBgColor = const Color(0xffECFDF3);
    } else if (bill.paid && !bill.verifiedPayment) {
      statusText = 'Menunggu Verifikasi';
      statusColor = const Color(0xffB54708);
      statusBgColor = const Color(0xffFFFAEB);
    } else if (!bill.paid && bill.payments.isNotEmpty) {
      statusText = 'Pending Upload';
      statusColor = const Color(0xffF59E0B);
      statusBgColor = const Color(0xffFEF3C7);
    } else {
      statusText = 'Belum Bayar';
      statusColor = const Color(0xffDC2626);
      statusBgColor = const Color(0xffFEF2F2);
    }

    return GestureDetector(
      onTap: () => _showBillDetail(bill),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xffEAECF0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left section - Invoice info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bill.invoiceNumber,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff1D2939),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Rp ${_formatNumber(bill.amount)}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xff295CD0),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bill.customer?.name ?? '-',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xff475467),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 12, color: Color(0xff98A2B3)),
                      const SizedBox(width: 4),
                      Text(
                        bill.period,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xff667085),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Right section - Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Text(
                statusText,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== CARD FOR UNVERIFIED TAB ====================
  Widget _buildUnverifiedBillCard(Bill bill) {
    final payment = bill.payments.isNotEmpty ? bill.payments.last : null;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffEAECF0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.customer?.name ?? '-',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff1D2939),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Rp ${_formatNumber(bill.amount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff295CD0),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      bill.invoiceNumber,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: const Color(0xff667085),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xffFFFAEB),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xffFECD1B).withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Menunggu Verifikasi',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xffB54708),
                  ),
                ),
              ),
            ],
          ),
          if (payment != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xffF2F4F7)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xffF0F5FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.payment_rounded, color: Color(0xff295CD0), size: 14),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPaymentMethod(payment.paymentProof),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xff344054),
                        ),
                      ),
                      Text(
                        _formatDate(payment.paymentDate),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: const Color(0xff667085),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () => _verifyPayment(bill, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff12B76A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        minimumSize: const Size(60, 32),
                      ),
                      child: Text('Verifikasi', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _verifyPayment(bill, false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        minimumSize: const Size(60, 32),
                      ),
                      child: Text('Tolak', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _getPaymentMethod(String paymentProof) {
    if (paymentProof.toLowerCase().contains('bca')) return 'Transfer BCA';
    if (paymentProof.toLowerCase().contains('mandiri')) return 'Transfer Mandiri';
    if (paymentProof.toLowerCase().contains('bni')) return 'Transfer BNI';
    if (paymentProof.toLowerCase().contains('bri')) return 'Transfer BRI';
    return 'Transfer Bank';
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      const months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return dateStr;
    }
  }

  // ==================== FORM ADD/EDIT ====================
  void _showBillForm({Bill? bill}) {
    int? selectedCustomerId = bill?.customerId;
    final monthCtrl = TextEditingController(text: bill?.month.toString() ?? '');
    final yearCtrl = TextEditingController(text: bill?.year.toString() ?? DateTime.now().year.toString());
    final measureCtrl = TextEditingController(text: bill?.measurementNumber ?? '');
    final usageCtrl = TextEditingController(text: bill?.usageValue.toString() ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModal) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40, height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xffD0D5DD),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      bill == null ? 'Tambah Tagihan' : 'Edit Tagihan',
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    if (bill == null) ...[
                      _formLabel('Customer'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        initialValue: selectedCustomerId,
                        dropdownColor: Colors.white,
                        style: GoogleFonts.poppins(fontSize: 14, color: Colors.black),
                        decoration: _inputDeco('Pilih Customer', Icons.person_rounded),
                        items: _customers
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name, style: GoogleFonts.poppins(fontSize: 14)),
                                ))
                            .toList(),
                        onChanged: (v) => setModal(() => selectedCustomerId = v),
                        validator: (v) => v == null ? 'Pilih customer' : null,
                      ),
                      const SizedBox(height: 14),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _formLabel('Bulan'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: monthCtrl,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: _inputDeco('1 - 12', Icons.calendar_month_rounded),
                                validator: (v) {
                                  final n = int.tryParse(v ?? '');
                                  if (n == null || n < 1 || n > 12) return 'Bulan 1-12';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _formLabel('Tahun'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: yearCtrl,
                                keyboardType: TextInputType.number,
                                style: GoogleFonts.poppins(fontSize: 14),
                                decoration: _inputDeco('2025', Icons.date_range_rounded),
                                validator: (v) {
                                  final n = int.tryParse(v ?? '');
                                  if (n == null || n < 2000) return 'Tahun tidak valid';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    _formLabel('No. Meteran'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: measureCtrl,
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _inputDeco('Contoh: MTR-001', Icons.speed_rounded),
                      validator: (v) => v == null || v.trim().isEmpty ? 'No. meteran wajib diisi' : null,
                    ),
                    const SizedBox(height: 14),

                    _formLabel('Pemakaian (m³)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: usageCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.poppins(fontSize: 14),
                      decoration: _inputDeco('Contoh: 12.5', Icons.water_drop_rounded),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n < 0) return 'Pemakaian tidak valid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModal(() => isSubmitting = true);
                                Navigator.pop(ctx);
                                await _submitBillForm(
                                  isEdit: bill != null,
                                  id: bill?.id,
                                  customerId: selectedCustomerId ?? 0,
                                  month: int.parse(monthCtrl.text),
                                  year: int.parse(yearCtrl.text),
                                  measurementNumber: measureCtrl.text.trim(),
                                  usageValue: double.parse(usageCtrl.text),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff295CD0),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          bill == null ? 'Simpan Tagihan' : 'Perbarui Tagihan',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  Widget _formLabel(String label) => Text(
        label,
        style: GoogleFonts.poppins(
            fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xff344054)),
      );

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        prefixIcon: Icon(icon, color: const Color(0xff667085), size: 20),
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xff98A2B3)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffD0D5DD), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xffD0D5DD), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xff295CD0), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      );

  // ==================== SUBMIT ====================
  Future<void> _submitBillForm({
    required bool isEdit,
    int? id,
    required int customerId,
    required int month,
    required int year,
    required String measurementNumber,
    required double usageValue,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = isEdit
          ? await _billService.updateBill(
              id: id!,
              month: month,
              year: year,
              measurementNumber: measurementNumber,
              usageValue: usageValue,
            )
          : await _billService.createBill(
              customerId: customerId,
              month: month,
              year: year,
              measurementNumber: measurementNumber,
              usageValue: usageValue,
            );

      if (mounted) {
        _alert.showAlert(
          context,
          res.success
              ? (isEdit ? 'Tagihan berhasil diperbarui!' : 'Tagihan berhasil dibuat!')
              : res.message,
          res.success,
        );
      }
      if (res.success) {
        _fetchData();
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _alert.showAlert(context, 'Terjadi kesalahan: $e', false);
      }
    }
  }

  // ==================== BUILD ====================
  @override
  Widget build(BuildContext context) {
    final tabs = _tabBills;
    final unverifiedCount = _unverifiedBills.length;
    
    // Calculate total bill amount for all bills
    final totalAmount = _filteredBills.fold<double>(0.0, (sum, bill) => sum + bill.amount);

    return Scaffold(
      backgroundColor: const Color(0xffF8F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Kelola Bill',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
          labelColor: const Color(0xff295CD0),
          unselectedLabelColor: const Color(0xff667085),
          indicatorColor: const Color(0xff295CD0),
          indicatorWeight: 2.5,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Belum Diverifikasi'),
                  if (unverifiedCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unverifiedCount',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'Semua Bill'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        color: const Color(0xff295CD0),
        child: Column(
          children: [
            // Search bar + Filter
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _searchController,
                      onChanged: _applyFilter,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.grey, size: 22),
                        hintText: 'Cari invoice atau nama customer...',
                        hintStyle: GoogleFonts.poppins(fontSize: 13, color: const Color(0xff9EAAD2)),
                        filled: true,
                        fillColor: const Color(0xFFF4F7FE),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xffEEEEEE), width: 1),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xffEEEEEE), width: 1),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xff295CD0), width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _showFilterBottomSheet,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xffCADFFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.filter_alt_rounded,
                        color: Color(0xff2C5EC5),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Add button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: GestureDetector(
                onTap: () => _showBillForm(),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xff295CD0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tambah Tagihan',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // List
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xff295CD0)),
                    )
                  : tabs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined,
                                  size: 64, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada tagihan',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(top: 4, bottom: 80),
                          itemCount: tabs.length,
                          itemBuilder: (_, i) {
                            final bill = tabs[i];
                            // Use different card for each tab
                            if (_tabController.index == 0) {
                              return _buildUnverifiedBillCard(bill);
                            } else {
                              return _buildAllBillCard(bill);
                            }
                          },
                        ),
            ),
            
            // Total Bill Footer (only for All Bills tab)
            if (_tabController.index == 1 && _filteredBills.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xff1E40AF),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Bill',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Rp.${_formatNumber(totalAmount)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}