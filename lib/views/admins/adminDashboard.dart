import 'package:aplikasi_pdam/services/adminPaymentPollingService.dart';
import 'package:aplikasi_pdam/services/dashboardService.dart';
import 'package:aplikasi_pdam/services/notificationService.dart';
import 'package:aplikasi_pdam/services/notificationStore.dart';
import 'package:aplikasi_pdam/views/admins/notifikasiAdmin.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  String _adminUsername = 'Admin';

  // Dashboard states
  int _customerCount = 0;
  int _unverifiedPaymentCount = 0;
  int _serviceCount = 0;
  double _totalRevenue = 0.0;
  bool _isLoading = true;

  // ── Notification states ──────────────────────────────────────────────
  int _notifBadgeCount = 0;
  bool _showFloatingNotif = false;
  String _floatingNotifTitle = '';
  String _floatingNotifBody = '';
  String _floatingNotifAmount = '';
  String _floatingNotifCustomer = '';

  // Services
  final DashboardService _dashboardService = DashboardService();
  final AdminPaymentPollingService _pollingService =
      AdminPaymentPollingService();
  final NotificationService _notificationService = NotificationService();
  final NotificationStore _notifStore = NotificationStore();

  // Animation
  late AnimationController _floatAnimController;
  late Animation<Offset> _floatSlideAnim;
  late AnimationController _badgePulseController;
  late Animation<double> _badgePulseAnim;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadAdminData();
    _fetchDashboardData();
    _initNotifications();
  }

  // ── Animations ───────────────────────────────────────────────────────
  void _initAnimations() {
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

    // Badge pulse
    _badgePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _badgePulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _badgePulseController, curve: Curves.easeInOut),
    );
  }

  // ── Init Notifications ───────────────────────────────────────────────
  Future<void> _initNotifications() async {
    // Load notification store
    await _notifStore.load();

    // Sync badge dari store yang sudah ada
    if (mounted) {
      setState(() {
        _notifBadgeCount = _notifStore.unreadCount;
      });
    }

    // Listen to store changes for badge count
    _notifStore.addListener(_onNotifStoreChanged);

    // Pastikan semua permission sudah diminta
    await _notificationService.requestAllPermissions();

    // Set callback polling — floating notif + app badge
    _pollingService.onNewPayment = (newCount, details) {
      if (!mounted) return;

      // Build title & body
      String title;
      String body;

      if (details.isEmpty) {
        title = '💳 Pembayaran Baru Masuk!';
        body = '$newCount pembayaran menunggu verifikasi.';
      } else if (details.length == 1) {
        final d = details.first;
        title = '💰 Pembayaran dari ${d.customerName}!';
        body = 'Rp ${_formatNumber(d.amount.toInt())} — segera verifikasi.';
      } else {
        final names = details.map((d) => d.customerName).join(', ');
        title = '📥 ${details.length} Pembayaran Baru!';
        body = 'Dari: $names — Total $newCount menunggu.';
      }

      // Update app badge
      _notificationService.updateAppBadge(newCount);

      // Trigger floating notif
      final customerText = details.isEmpty
          ? 'Pembayaran baru'
          : details.length == 1
              ? details.first.customerName
              : '${details.length} customer';
      final amountText = details.isEmpty
          ? ''
          : details.length == 1
              ? 'Rp ${_formatNumber(details.first.amount.toInt())}'
              : 'Total Rp ${_formatNumber(details.fold<double>(0.0, (s, d) => s + d.amount).toInt())}';

      _triggerFloatingNotif(
        title: title,
        body: body,
        count: newCount,
        customerName: customerText,
        amount: amountText,
      );
    };

    // Mulai polling
    await _pollingService.start();

    // Sync badge dengan data saat ini setelah fetch selesai
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationService.updateAppBadge(_unverifiedPaymentCount);
    });
  }

  void _onNotifStoreChanged() {
    if (!mounted) return;
    setState(() {
      _notifBadgeCount = _notifStore.unreadCount;
    });
  }

  // ── Trigger floating notification ────────────────────────────────────
  void _triggerFloatingNotif({
    required String title,
    required String body,
    required int count,
    String customerName = '',
    String amount = '',
  }) {
    if (!mounted) return;
    setState(() {
      _floatingNotifTitle = title;
      _floatingNotifBody = body;
      _floatingNotifCustomer = customerName;
      _floatingNotifAmount = amount;
      _showFloatingNotif = true;
      _notifBadgeCount = count;
    });

    debugPrint('[FloatingNotif] Triggered: $title');

    // Make sure controller is not animating first
    if (_floatAnimController.isAnimating) {
      _floatAnimController.reset();
    }

    // Animate in
    _floatAnimController.forward(from: 0.0).then((_) {
      debugPrint('[FloatingNotif] Animation completed');
    });

    // Auto-dismiss setelah 5 detik
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _dismissFloatingNotif();
      }
    });
  }

  void _dismissFloatingNotif() {
    if (!mounted) return;
    debugPrint('[FloatingNotif] Dismissed');
    if (_floatAnimController.isAnimating) {
      _floatAnimController.reverse().then((_) {
        if (mounted) {
          setState(() => _showFloatingNotif = false);
        }
      });
    } else {
      setState(() => _showFloatingNotif = false);
    }
  }

  @override
  void dispose() {
    _floatAnimController.dispose();
    _badgePulseController.dispose();
    _notifStore.removeListener(_onNotifStoreChanged);
    _pollingService.stop();
    super.dispose();
  }

  // ── Data ─────────────────────────────────────────────────────────────
  Future<void> _loadAdminData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _adminUsername = prefs.getString('username') ?? 'Admin';
    });
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final custCount = await _dashboardService.getCustomersCount();
      final servCount = await _dashboardService.getServicesCount();
      final paymentStats = await _dashboardService.getPaymentStats();

      if (mounted) {
        setState(() {
          _customerCount = custCount;
          _serviceCount = servCount;
          _unverifiedPaymentCount = paymentStats['unverifiedCount'] ?? 0;
          _totalRevenue = paymentStats['totalRevenue'] ?? 0.0;
          _isLoading = false;
        });
      }

      // Force polling untuk real-time check pembayaran terbaru
      await _pollingService.forcePoll();
    } catch (e) {
      debugPrint('Error fetching dashboard data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatNumber(num number) {
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  String _formatRupiah(double amount) {
    return 'Rp. ${_formatNumber(amount.toInt())}';
  }

  // ========================== BUILD ==========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── Main Content ─────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _fetchDashboardData,
                    color: const Color(0xff025ae9),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              _buildBlueBanner(),
                              _buildWhiteContentCard(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Floating Notification Overlay ────────────────────────────
          if (_showFloatingNotif) _buildFloatingNotif(),
        ],
      ),
    );
  }

  // ========================== HEADER ==========================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          // Logo & title
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/Logo.png',
                height: 38,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.water_rounded,
                      color: Color(0xff2768CF), size: 38);
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: const Color(0xffE3E6FD),
                    ),
                    child: Text(
                      'ADMIN Panel',
                      style: GoogleFonts.poppins(
                        color: const Color(0xff2C5EC5),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Bell icon with Badge ─────────────────────────────────────
          GestureDetector(
            onTap: () async {
              // Navigasi ke halaman notifikasi
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotifikasiAdmin()),
              );
              // Setelah kembali, update badge dari store
              if (mounted) {
                setState(() {
                  _notifBadgeCount = _notifStore.unreadCount;
                });
                _notificationService.clearAppBadge();
              }
            },
            onLongPress: () async {
              // Long press = test notifikasi sistem + in-app
              await _notificationService.requestAllPermissions();
              await _notificationService.showTestNotification();
              // Juga tampilkan floating notif di dalam app
              _triggerFloatingNotif(
                title: '🔔 Test Notifikasi',
                body: 'Notifikasi sistem berhasil dikirim! Lihat dari atas layar.',
                count: _notifBadgeCount,
              );
              // Tambahkan ke store
              await _notifStore.add(
                title: '🔔 Test Notifikasi',
                body: 'In-app + sistem notification test berhasil.',
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Notifikasi test terkirim! Lihat dari atas layar.'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xff025ae9),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _notifBadgeCount > 0
                        ? const Color(0xffFFF4ED)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _notifBadgeCount > 0
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_rounded,
                    color: _notifBadgeCount > 0
                        ? const Color(0xffE04F16)
                        : const Color(0xff475467),
                    size: 26,
                  ),
                ),
                // Badge lencana merah
                if (_notifBadgeCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: ScaleTransition(
                      scale: _badgePulseAnim,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: const Color(0xffE53E3E),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xffE53E3E).withValues(alpha: 0.5),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _notifBadgeCount > 9
                                ? '9+'
                                : '$_notifBadgeCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================== FLOATING NOTIF ==========================
  Widget _buildFloatingNotif() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _floatSlideAnim,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff1e3a8a), Color(0xff2563eb)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff2563eb).withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icon with badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.payment_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    // Lencana nominal
                    if (_floatingNotifAmount.isNotEmpty)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xff12B76A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                          child: Text(
                            _floatingNotifAmount.length > 12
                                ? '${_floatingNotifAmount.substring(0, 10)}..'
                                : _floatingNotifAmount,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _floatingNotifTitle,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _floatingNotifBody,
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Customer name row
                      if (_floatingNotifCustomer.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_rounded,
                                size: 10,
                                color: Colors.white.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _floatingNotifCustomer,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Dismiss
                GestureDetector(
                  onTap: _dismissFloatingNotif,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.7),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========================== BLUE BANNER ==========================
  Widget _buildBlueBanner() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff41a1f6), Color(0xff025ae9)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: 0.5,
              child: Image.asset(
                'assets/images/Pattern3.png',
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox(),
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 24,
            child: Opacity(
              opacity: 0.8,
              child: Image.asset(
                'assets/images/titik.png',
                height: 35,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox(),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 10,
            child: Image.asset(
              'assets/images/ilustrasi1.png',
              height: 190,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, $_adminUsername 👋',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dashboard',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kelola sistem PDAM\ndengan mudah',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 15,
                    height: 1.3,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================== WHITE CONTENT CARD ==========================
  Widget _buildWhiteContentCard() {
    return Container(
      margin: const EdgeInsets.only(top: 185),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Stats grid ──────────────────────────────────────────────
            _isLoading
                ? _buildGridSkeleton()
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Jumlah Customer',
                              value: _formatNumber(_customerCount),
                              subtext: '+32 Customer Baru',
                              icon: Icons.person_rounded,
                              iconColor: const Color(0xff2C5EC5),
                              iconBgColor: const Color(0xffEEF4FF),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Bayaran Belum Diverifikasi',
                              value: _formatNumber(_unverifiedPaymentCount),
                              icon: Icons.pending_actions_rounded,
                              iconColor: const Color(0xffE04F16),
                              iconBgColor: const Color(0xffFFF4ED),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Jumlah Layanan Aktif',
                              value: _formatNumber(_serviceCount),
                              icon: Icons.opacity,
                              iconColor: const Color(0xff0284C7),
                              iconBgColor: const Color(0xffE0F2FE),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Total Pendapatan Bulan ini',
                              value: _formatRupiah(_totalRevenue),
                              icon: Icons.trending_up_rounded,
                              iconColor: const Color(0xff12B76A),
                              iconBgColor: const Color(0xffECFDF3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

            const SizedBox(height: 32),

            // ── Ringkasan Cepat ──────────────────────────────────────────
            Text(
              'Ringkasan Cepat',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xff1D2939),
              ),
            ),
            const SizedBox(height: 16),

            _isLoading
                ? _buildSkeletonList()
                : Column(
                    children: [
                      _buildQuickSummaryCard(
                        title: 'Customer Aktif Terdaftar',
                        subtitle:
                            'Total ada $_customerCount customer menggunakan HaloAir saat ini.',
                        icon: Icons.people_rounded,
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickSummaryCard(
                        title: 'Persetujuan Pembayaran',
                        subtitle: _unverifiedPaymentCount > 0
                            ? 'Ada $_unverifiedPaymentCount pembayaran baru yang membutuhkan verifikasi Anda.'
                            : 'Semua pembayaran pelanggan telah diverifikasi.',
                        icon: Icons.verified_user_rounded,
                        color: _unverifiedPaymentCount > 0
                            ? Colors.orange.shade600
                            : Colors.green.shade600,
                      ),
                      const SizedBox(height: 12),
                      _buildQuickSummaryCard(
                        title: 'Status Layanan PDAM',
                        subtitle:
                            'HaloAir mengelola $_serviceCount tipe layanan aktif dengan harga yang disesuaikan.',
                        icon: Icons.settings_suggest_rounded,
                        color: Colors.purple.shade600,
                      ),
                    ],
                  ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ========================== STAT CARD ==========================
  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtext,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF2F4F7), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: const Color(0xff1D2939),
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: const Color(0xff667085),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtext != null) ...[
            const SizedBox(height: 2),
            Text(
              subtext,
              style: GoogleFonts.poppins(
                color: const Color(0xff12B76A),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ========================== QUICK SUMMARY CARD ==========================
  Widget _buildQuickSummaryCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xffF8F9FC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF2F4F7), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xff1D2939),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xff475467),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================== SKELETONS ==========================
  Widget _buildGridSkeleton() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildSkeletonCard()),
            const SizedBox(width: 14),
            Expanded(child: _buildSkeletonCard()),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _buildSkeletonCard()),
            const SizedBox(width: 14),
            Expanded(child: _buildSkeletonCard()),
          ],
        ),
      ],
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffF2F4F7), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 60,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            width: 90,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 50,
            height: 10,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return Column(
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xffF8F9FC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffF2F4F7), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
