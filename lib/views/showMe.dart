import 'package:aplikasi_pdam/models/showme.dart' as model;
import 'package:aplikasi_pdam/services/user.dart';
import 'package:aplikasi_pdam/widgets/bottomnavbar.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Showme extends StatefulWidget {
  final String role; // 'ADMIN' atau 'CUSTOMER'
  const Showme({super.key, this.role = 'CUSTOMER'});

  @override
  State<Showme> createState() => _ShowmeState();
}

class _ShowmeState extends State<Showme> with TickerProviderStateMixin {
  final _userServices = UserServices();
  model.Showme? _profile;
  bool _isLoading = true;
  String? _errorMsg;

  late AnimationController _checkAnimController;
  late AnimationController _textAnimController;
  late Animation<double> _checkScale;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _fetchProfile();
  }

  void _setupAnimations() {
    // Check icon animation - scale and bounce
    _checkAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkAnimController, curve: Curves.elasticOut),
    );

    // Text animation - fade in and slide up
    _textAnimController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textAnimController, curve: Curves.easeIn),
    );

    // Start animations
    _checkAnimController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _textAnimController.forward();
    });
  }

  @override
  void dispose() {
    _checkAnimController.dispose();
    _textAnimController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    final result = widget.role.toUpperCase() == 'ADMIN'
        ? await _userServices.showmeAdmin()
        : await _userServices.showmeCustomer();

    if (!mounted) return;

    print('_fetchProfile result: ${result.success}');
    print('_fetchProfile message: ${result.message}');
    print('_fetchProfile data: ${result.data}');

    if (result.success && result.data != null) {
      try {
        final profileData = model.Showme.fromJson(result.data as Map<String, dynamic>);
        print('Parsed profile: name=${profileData.name}, phone=${profileData.phone}, userId=${profileData.userId}');
        setState(() {
          _profile = profileData;
          _isLoading = false;
        });
      } catch (e) {
        print('Error parsing profile: $e');
        setState(() {
          _errorMsg = 'Gagal memuat data: $e';
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _errorMsg = result.message;
        _isLoading = false;
      });
    }
  }

  /// Format ISO date string → "27 May 2025 • 09:41 AM"
  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      final min = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} ${months[dt.month]} ${dt.year} • ${hour.toString().padLeft(2, '0')}:$min $period';
    } catch (_) {
      return iso;
    }
  }

  void _navigateToDashboard() {
    final role = widget.role.toUpperCase();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => Bottomnavbar(role: role),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF295CD0),
      body: Stack(
        children: [
          // ── Decorative circles background ──────────────────
          Positioned(
            top: -30,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: 60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),

          // ── Main content ───────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── TOP SECTION: success indicator ──────────
                const SizedBox(height: 40),
                // Animated success circle with check icon
                ScaleTransition(
                  scale: _checkScale,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF4B7DE8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF295CD0).withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      // Inner white circle
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 44,
                          color: Color(0xFF2E60F1),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Animated text - fade in and slide up
                FadeTransition(
                  opacity: _textOpacity,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: _textAnimController, curve: Curves.easeOut),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Akun berhasil dibuat',
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Akunmu sudah siap digunakan!',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── BOTTOM CARD ──────────────────────────────
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F7FF),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF295CD0),
                            ),
                          )
                        : _errorMsg != null
                        ? _buildError()
                        : _buildProfileCard(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Color(0xFF98A2B3),
            ),
            const SizedBox(height: 12),
            Text(
              _errorMsg ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF667085),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMsg = null;
                });
                _fetchProfile();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Coba Lagi', style: GoogleFonts.poppins()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF295CD0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final p = _profile!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        children: [
          // ── Welcome header + avatar row ──────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome,',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: const Color(0xFF667085),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${p.name} 👋',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1D2939),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Berikut informasi akunmu',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF98A2B3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Avatar
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4B7DE8), Color(0xFF295CD0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF295CD0).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFEAECF0)),
                const SizedBox(height: 4),

                // Info rows
                _infoRow(
                  icon: Icons.person_rounded,
                  label: 'Username',
                  value: p.user?.username ?? 'N/A',
                ),
                _divider(),
                _infoRow(
                  icon: Icons.phone_rounded,
                  label: 'Phone Number',
                  value: p.phone,
                ),
                _divider(),
                _infoRow(
                  icon: Icons.badge_rounded,
                  label: 'User ID',
                  value: '#${p.id}',
                ),
                _divider(),
                _infoRow(
                  icon: Icons.security_rounded,
                  label: 'Role',
                  value: p.user?.role ?? 'N/A',
                ),
                _divider(),
                _infoRow(
                  icon: Icons.calendar_month_rounded,
                  label: 'Joined on',
                  value: _formatDate(p.createdAt),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Continue to Dashboard button ──────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _navigateToDashboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF295CD0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                'Continue to Dashboard',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF295CD0), size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF98A2B3),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1D2939),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, color: Color(0xFFF2F4F7));
}