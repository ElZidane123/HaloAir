// lib/screens/homescreen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aplikasi_pdam/models/bill.dart';
import 'package:aplikasi_pdam/services/customerDashboardService.dart';
import 'package:aplikasi_pdam/services/realtimeBillService.dart';
import 'package:aplikasi_pdam/services/notificationStore.dart';
import 'package:aplikasi_pdam/views/customers/notifikasiCustomer.dart';
import 'package:aplikasi_pdam/widgets/bottomnavbar.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen>
    with TickerProviderStateMixin {
  final CustomerDashboardService _dashboardService = CustomerDashboardService();
  late RealtimeBillService _realtimeService;
  final NotificationStore _notifStore = NotificationStore();

  String _username = 'Pelanggan';
  List<Bill> _bills = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Animation for notification badge shake
  AnimationController? _shakeAnimController;
  Animation<double>? _shakeAnimation;

  // Track last bill count for animation
  int _lastUnpaidCount = 0;

  // ── Floating notification overlay ──
  bool _showFloatingNotif = false;
  String _floatingNotifTitle = '';
  String _floatingNotifBody = '';
  IconData _floatingNotifIcon = Icons.notifications_rounded;
  Color _floatingNotifColor = const Color(0xff295CD0);

  late AnimationController _floatAnimController;
  late Animation<Offset> _floatSlideAnim;

  @override
  void initState() {
    super.initState();
    _realtimeService = RealtimeBillService();
    _loadUserData();
    _fetchData();
    _setupRealtime();
    _setupAnimations();
  }

  void _setupAnimations() {
    // Shake animation for badge
    _shakeAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(
          parent: _shakeAnimController!, curve: Curves.elasticIn),
    );

    // Floating notif slide-down from top
    _floatAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _floatSlideAnim = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _floatAnimController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _setupRealtime() {
    // Handle new bill notifications
    _realtimeService.onNewBill = (newBills) {
      debugPrint('🆕 New bill detected: ${newBills.length} bill(s)');

      if (mounted) {
        setState(() {
          _bills.insertAll(0, newBills);
          _bills.sort((a, b) {
            if (a.year != b.year) return b.year.compareTo(a.year);
            return b.month.compareTo(a.month);
          });
        });

        final newUnpaidCount = _bills.where((b) => !b.paid).length;

        if (newUnpaidCount > _lastUnpaidCount) {
          _shakeAnimController?.forward().then(
            (_) => _shakeAnimController?.reset(),
          );

          final latestNewBill = newBills.first;

          // Simpan ke NotificationStore
          _notifStore.add(
            title: '📄 Tagihan Baru!',
            body:
                '${latestNewBill.period} - Rp ${_formatNumber(_getValidAmount(latestNewBill))}',
          );

          // Show elegant notification
          _showNewBillNotification(latestNewBill);
        }

        _lastUnpaidCount = newUnpaidCount;
      }
    };

    // Handle bill updates (payment status changes)
    _realtimeService.onBillUpdate = (updatedBills) {
      debugPrint('🔄 Bill updated: ${updatedBills.length} bill(s)');

      if (mounted) {
        setState(() {
          for (var updatedBill in updatedBills) {
            final index = _bills.indexWhere((b) => b.id == updatedBill.id);
            if (index != -1) {
              _bills[index] = updatedBill;
            }
          }
          _bills.sort((a, b) {
            if (a.year != b.year) return b.year.compareTo(a.year);
            return b.month.compareTo(a.month);
          });
        });

        for (var bill in updatedBills) {
          if (bill.paid && bill.verifiedPayment) {
            // Simpan ke NotificationStore
            _notifStore.add(
              title: '✅ Pembayaran Terverifikasi!',
              body: 'Tagihan ${bill.period} telah lunas. Terima kasih!',
            );

            _showPaymentVerifiedNotification(bill);
          }
        }
      }
    };

    // Start polling (interval 5 seconds)
    _realtimeService.startPolling(interval: const Duration(seconds: 5));
  }

  void _showNewBillNotification(Bill bill) {
    // ── Elegant floating overlay (notif mengambang) ──
    _triggerFloatingNotif(
      title: '📄 Tagihan Baru!',
      body: '${bill.period} - Rp ${_formatNumber(_getValidAmount(bill))}',
      icon: Icons.receipt_long_rounded,
      color: const Color(0xffF59E0B),
    );

    // ── Elegant new bill dialog ──
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xffFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xffF59E0B),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tagihan Baru!',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xff1D2939),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Anda memiliki tagihan baru untuk periode ${bill.period}',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: const Color(0xff667085),
                ),
              ),
              const SizedBox(height: 20),

              // Detail card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xffF0F5FF), Color(0xffFFFFFF)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xffE3EBFD)),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                        'Total Tagihan',
                        'Rp ${_formatNumber(_getValidAmount(bill))}',
                        true),
                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xffEAECF0)),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                        'Jatuh Tempo',
                        '28 ${bill.monthName} ${bill.year}',
                        false),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xff667085),
                        side: const BorderSide(color: Color(0xffD0D5DD)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Nanti',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        const SwitchTabNotification(1).dispatch(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff12B76A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.payment_rounded, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Bayar Sekarang',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isBold) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.poppins(
                fontSize: 13, color: const Color(0xff667085))),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold
                ? const Color(0xff295CD0)
                : const Color(0xff1D2939),
          ),
        ),
      ],
    );
  }

  void _showPaymentVerifiedNotification(Bill bill) {
    // Floating overlay
    _triggerFloatingNotif(
      title: '✅ Pembayaran Terverifikasi!',
      body: 'Tagihan ${bill.period} telah lunas. Terima kasih!',
      icon: Icons.verified_rounded,
      color: const Color(0xff12B76A),
    );

    // Elegant snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xffD1FADF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle,
                  color: Color(0xff027A48), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pembayaran Terverifikasi!',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Tagihan ${bill.period} telah lunas',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xff12B76A),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ── Floating notification overlay ──
  void _triggerFloatingNotif({
    required String title,
    required String body,
    required IconData icon,
    required Color color,
  }) {
    if (!mounted) return;
    setState(() {
      _floatingNotifTitle = title;
      _floatingNotifBody = body;
      _floatingNotifIcon = icon;
      _floatingNotifColor = color;
      _showFloatingNotif = true;
    });

    _floatAnimController.forward(from: 0);

    Future.delayed(const Duration(seconds: 5), () {
      _dismissFloatingNotif();
    });
  }

  void _dismissFloatingNotif() {
    if (!mounted) return;
    _floatAnimController.reverse().then((_) {
      if (mounted) {
        setState(() => _showFloatingNotif = false);
      }
    });
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Pelanggan';
    });
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final res = await _dashboardService.getCustomerBills();
      if (mounted) {
        setState(() {
          if (res['success'] == true) {
            _bills = res['data'] as List<Bill>;

            // Sort bills by period descending
            _bills.sort((a, b) {
              if (a.year != b.year) return b.year.compareTo(a.year);
              return b.month.compareTo(a.month);
            });

            _lastUnpaidCount = _bills.where((b) => !b.paid).length;

            debugPrint(
              '✅ Data loaded: ${_bills.length} bills, $_lastUnpaidCount unpaid',
            );
          } else {
            _errorMessage =
                res['message']?.toString() ?? 'Gagal mengambil data tagihan';
          }
          _isLoading = false;
        });
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
    if (n == 0) return '0';
    return n.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  double _getValidAmount(Bill bill) {
    if (bill.amount > 0) return bill.amount;
    if (bill.price > 0) return bill.price;
    return 0;
  }

  @override
  void dispose() {
    _realtimeService.dispose();
    _shakeAnimController?.dispose();
    _floatAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate unpaid bills
    final unpaidBills = _bills.where((b) => !b.paid).toList();
    final paidBills = _bills.where((b) => b.paid).toList();

    final unpaidCount = unpaidBills.length;
    final totalUnpaidAmount = unpaidBills.fold<double>(
      0.0,
      (sum, item) => sum + _getValidAmount(item),
    );
    final paidCount = paidBills.length;

    // Get latest bill
    final latestBill = _bills.isNotEmpty ? _bills.first : null;
    final latestBillAmount = latestBill != null
        ? _getValidAmount(latestBill)
        : 0;
    final latestBillMonthName = latestBill?.monthName ?? '';
    final latestBillYear = latestBill?.year ?? DateTime.now().year;

    return Stack(
      children: [
        Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xff295CD0)),
              )
            : Column(
                children: [
                  // App Bar with Notification Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    width: double.infinity,
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
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/Logo.png',
                              height: 38,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.water_rounded,
                                  color: Color(0xff2768CF),
                                  size: 38,
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'HaloAir',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: const Color(0xff2768CF),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    color: const Color(0xffD1FADF),
                                  ),
                                  child: Text(
                                    'CUSTOMER',
                                    style: GoogleFonts.poppins(
                                      color: const Color(0xff027A48),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // Notification Icon with Badge
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.notifications_rounded,
                                color: Color(0xff667085),
                                size: 24,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const NotifikasiCustomer(),
                                  ),
                                );
                              },
                            ),
                            if (unpaidCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: AnimatedBuilder(
                                  animation: _shakeAnimation!,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(_shakeAnimation!.value, 0),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 18,
                                          minHeight: 18,
                                        ),
                                        child: Text(
                                          '$unpaidCount',
                                          style: GoogleFonts.poppins(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Main Content
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _fetchData,
                      color: const Color(0xff295CD0),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_errorMessage.isNotEmpty) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xffFEE4E2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _errorMessage,
                                  style: GoogleFonts.poppins(
                                    color: const Color(0xffD92D20),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Blue Gradient Banner with Latest Bill
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xff1E40AF),
                                    Color(0xff2563EB),
                                    Color(0xff3B82F6),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xff2563EB,
                                    ).withValues(alpha: 0.2),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Halo, $_username 👋',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pelanggan Setia PDAM',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  const SizedBox(height: 20),

                                  // Inner White Bill Container
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.04,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: latestBill == null
                                        ? Center(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              child: Text(
                                                'Belum ada riwayat tagihan',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(
                                                    0xff667085,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          )
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    'Tagihan Bulan Ini',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: const Color(
                                                        0xff667085,
                                                      ),
                                                    ),
                                                  ),
                                                  AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 300,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: latestBill.paid
                                                          ? const Color(
                                                              0xffD1FADF,
                                                            )
                                                          : const Color(
                                                              0xffFEE4E2,
                                                            ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      latestBill.paid
                                                          ? 'Lunas'
                                                          : 'Belum Dibayar',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            color:
                                                                latestBill.paid
                                                                ? const Color(
                                                                    0xff027A48,
                                                                  )
                                                                : const Color(
                                                                    0xffB42318,
                                                                  ),
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                child: Text(
                                                  'Rp ${_formatNumber(latestBillAmount)}',
                                                  key: ValueKey(
                                                    latestBillAmount,
                                                  ),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                    color: const Color(
                                                      0xff091540,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      'Jatuh tempo: 28 $latestBillMonthName $latestBillYear',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w400,
                                                            color: const Color(
                                                              0xff667085,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                  if (!latestBill.paid &&
                                                      latestBillAmount > 0) ...[
                                                    const SizedBox(width: 8),
                                                    TweenAnimationBuilder(
                                                      tween: Tween<double>(
                                                        begin: 1.0,
                                                        end: 1.0,
                                                      ),
                                                      duration: const Duration(
                                                        milliseconds: 300,
                                                      ),
                                                      builder: (context, value, child) {
                                                        return Transform.scale(
                                                          scale: value,
                                                          child: GestureDetector(
                                                            onTap: () {
                                                              const SwitchTabNotification(
                                                                1,
                                                              ).dispatch(
                                                                context,
                                                              );
                                                            },
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        16,
                                                                    vertical: 8,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                gradient: const LinearGradient(
                                                                  colors: [
                                                                    Color(
                                                                      0xff12B76A,
                                                                    ),
                                                                    Color(
                                                                      0xff059669,
                                                                    ),
                                                                  ],
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      8,
                                                                    ),
                                                                boxShadow: [
                                                                  BoxShadow(
                                                                    color:
                                                                        const Color(
                                                                          0xff12B76A,
                                                                        ).withValues(
                                                                          alpha:
                                                                              0.3,
                                                                        ),
                                                                    blurRadius:
                                                                        8,
                                                                    offset:
                                                                        const Offset(
                                                                          0,
                                                                          2,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                              child: Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .min,
                                                                children: [
                                                                  const Icon(
                                                                    Icons
                                                                        .payment,
                                                                    color: Colors
                                                                        .white,
                                                                    size: 16,
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 6,
                                                                  ),
                                                                  Text(
                                                                    'Bayar Sekarang',
                                                                    style: GoogleFonts.poppins(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          12,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              if (latestBillAmount == 0 &&
                                                  !latestBill.paid) ...[
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xffFEF3C7,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.info_rounded,
                                                        size: 14,
                                                        color: Color(
                                                          0xffD97706,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          'Tagihan sedang diproses oleh admin',
                                                          style:
                                                              GoogleFonts.poppins(
                                                                fontSize: 11,
                                                                color:
                                                                    const Color(
                                                                      0xffD97706,
                                                                    ),
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Statistics Cards
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.receipt_long_outlined,
                                    iconBgColor: const Color(0xffE3EBFD),
                                    iconColor: const Color(0xff295CD0),
                                    count: unpaidCount,
                                    label: 'Bill Belum Dibayar',
                                    subtitle:
                                        'Total Rp ${_formatNumber(totalUnpaidAmount)}',
                                    onTap: unpaidCount > 0
                                        ? () {
                                            const SwitchTabNotification(
                                              1,
                                            ).dispatch(context);
                                          }
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    icon: Icons.assignment_turned_in_rounded,
                                    iconBgColor: const Color(0xffD1FADF),
                                    iconColor: const Color(0xff027A48),
                                    count: paidCount,
                                    label: 'Riwayat Pembayaran',
                                    subtitle: 'Lihat semua',
                                    onTap: () {
                                      const SwitchTabNotification(
                                        1,
                                      ).dispatch(context);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),

                            // Chart Section
                            Text(
                              'Grafik Tagihan (6 Bulan Terakhir)',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xff091540),
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildHistoricalChart(),
                            const SizedBox(height: 24),

                            // Ringkasan Card
                            _buildRingkasanCard(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    ),

        // ── Floating notification overlay ──
        if (_showFloatingNotif)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SlideTransition(
                position: _floatSlideAnim,
                child: Padding(
                  padding:
                      const EdgeInsets.fromLTRB(12, 4, 12, 0),
                  child: Material(
                    elevation: 8,
                    shadowColor: _floatingNotifColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _floatingNotifColor.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _floatingNotifColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _floatingNotifIcon,
                              color: _floatingNotifColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _floatingNotifTitle,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: const Color(0xff1D2939),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _floatingNotifBody,
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    color: const Color(0xff667085),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: _dismissFloatingNotif,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required int count,
    required String label,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffEAECF0), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '$count',
                      key: ValueKey(count),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xff091540),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xff667085),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: onTap != null
                    ? const Color(0xff295CD0)
                    : const Color(0xff344054),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingkasanCard() {
    final totalTagihan = _bills.fold<double>(
      0.0,
      (sum, b) => sum + _getValidAmount(b),
    );

    final distinctMonths = <String>{};
    for (final b in _bills) {
      distinctMonths.add('${b.year}-${b.month}');
    }
    final monthCount = distinctMonths.isEmpty ? 1 : distinctMonths.length;
    final avgPerMonth = monthCount > 0 ? totalTagihan / monthCount : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffEAECF0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ringkasan',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xff091540),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xffEAECF0)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Tagihan',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff667085),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        'Rp ${_formatNumber(totalTagihan)}',
                        key: ValueKey(totalTagihan),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: const Color(0xffEAECF0),
                margin: const EdgeInsets.symmetric(horizontal: 16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rata-rata / Bulan',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xff667085),
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        'Rp ${_formatNumber(avgPerMonth)}',
                        key: ValueKey(avgPerMonth),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff1E40AF),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricalChart() {
    // Get last 6 months of bills
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      return DateTime(now.year, now.month - (5 - i), 1);
    });

    final chartData = months.map((dt) {
      final matches = _bills
          .where((b) => b.month == dt.month && b.year == dt.year)
          .toList();
      final double amount = matches.isNotEmpty
          ? _getValidAmount(matches.first)
          : 0.0;
      return {'date': dt, 'amount': amount};
    }).toList();

    double maxVal = chartData.fold<double>(0.0, (max, item) {
      final double a = item['amount'] as double;
      return a > max ? a : max;
    });

    if (maxVal == 0.0) maxVal = 100000.0;

    final yLabels = [maxVal, maxVal * 0.75, maxVal * 0.50, maxVal * 0.25, 0.0];

    String formatChartLabel(double val) {
      if (val >= 1000) {
        return '${(val / 1000).toInt()}rb';
      }
      return val.toInt().toString();
    }

    const monthAbbrs = [
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: yLabels.map((val) {
            return Container(
              height: 24,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                formatChartLabel(val),
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xff98A2B3),
                ),
              ),
            );
          }).toList(),
        ),
        Expanded(
          child: Column(
            children: [
              Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ...List.generate(4, (index) {
                        return Column(
                          children: [
                            Container(
                              height: 24,
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: 1,
                                color: const Color(0xffEAECF0),
                              ),
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                  Positioned.fill(
                    bottom: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: chartData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final double amount = entry.value['amount'] as double;
                        final double barHeight = maxVal > 0
                            ? (amount / maxVal) * 90.0
                            : 0.0;
                        final bool isCurrentMonth =
                            index == chartData.length - 1;

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 18,
                              height: amount > 0
                                  ? barHeight.clamp(6.0, 90.0)
                                  : 6.0,
                              decoration: BoxDecoration(
                                color: amount > 0
                                    ? (isCurrentMonth
                                          ? const Color(0xff295CD0)
                                          : const Color(0xffD0E0FC))
                                    : const Color(0xffF2F4F7),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: chartData.map((item) {
                  final dt = item['date'] as DateTime;
                  final abbr = dt.month >= 1 && dt.month <= 12
                      ? monthAbbrs[dt.month]
                      : '';
                  return SizedBox(
                    width: 24,
                    child: Text(
                      abbr,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff475467),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

}
