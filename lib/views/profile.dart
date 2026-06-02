import 'package:aplikasi_pdam/views/admins/notifikasiAdmin.dart';
import 'package:aplikasi_pdam/views/customers/notifikasiCustomer.dart';
import 'package:aplikasi_pdam/views/login.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Profil extends StatefulWidget {
  const Profil({super.key});

  @override
  State<Profil> createState() => _ProfilState();
}

class _ProfilState extends State<Profil> {
  String _username = 'Pelanggan';
  String _role = 'CUSTOMER';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString('username') ?? 'Pelanggan';
      _role = prefs.getString('role') ?? 'CUSTOMER';
    });
  }

  Future<void> _handleLogout() async {
    // Tampilkan dialog konfirmasi terlebih dahulu agar aman dan terkesan premium
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.red.shade600),
              const SizedBox(width: 10),
              Text(
                'Konfirmasi Keluar',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari akun ini?',
            style: GoogleFonts.poppins(fontSize: 14),
          ),
          actionsPadding: const EdgeInsets.only(right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Batal',
                style: GoogleFonts.poppins(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Keluar',
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (confirmLogout == true) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Login()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================== APP BAR ====================
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xff091540),
                        size: 24,
                      ),
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    Text(
                      'Profile',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff091540),
                      ),
                    ),
                    const SizedBox(width: 48), // Spacer to center the title
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ==================== USER INFO CARD ====================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xffEAECF0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar Container
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: Color(0xffE3EBFD),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Color(0xff295CD0),
                        size: 36,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // User Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _username,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff091540),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _role == 'ADMIN' ? 'Administrator' : 'Pelanggan',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xff667085),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _role == 'ADMIN'
                                ? 'admin@pdam.co.id'
                                : '${_username.toLowerCase().replaceAll(' ', '')}@pdam.co.id',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xff667085),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ==================== SETTINGS MENU CARD ====================
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xffEAECF0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildMenuRow(
                      icon: Icons.person_rounded,
                      title: 'Informasi Akun',
                      onTap: () {},
                    ),
                    const Divider(
                      height: 1,
                      color: Color(0xffEAECF0),
                      indent: 16,
                      endIndent: 16,
                    ),
                    _buildMenuRow(
                      icon: Icons.lock_open_rounded,
                      title: 'Ubah Password',
                      onTap: () {},
                    ),
                    const Divider(
                      height: 1,
                      color: Color(0xffEAECF0),
                      indent: 16,
                      endIndent: 16,
                    ),
                    _buildMenuRow(
                      icon: Icons.notifications_rounded,
                      title: 'Notifikasi',
                      onTap: () {
                        if (_role == 'ADMIN') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NotifikasiAdmin()),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const NotifikasiCustomer()),
                          );
                        }
                      },
                    ),
                    const Divider(
                      height: 1,
                      color: Color(0xffEAECF0),
                      indent: 16,
                      endIndent: 16,
                    ),
                    _buildMenuRow(
                      icon: Icons.info_rounded,
                      title: 'Tentang Aplikasi',
                      onTap: () {},
                    ),
                    const Divider(
                      height: 1,
                      color: Color(0xffEAECF0),
                      indent: 16,
                      endIndent: 16,
                    ),
                    _buildLogoutRow(),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // ==================== APP VERSION ====================
              Center(
                child: Text(
                  'Versi 1.0.0',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xff98A2B3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuRow({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: Color(0xffCADFFF),
                borderRadius: BorderRadius.circular(6)
              ),
              child: Icon(icon, color: const Color(0xff2C5EC5), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xff344054),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xff98A2B3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutRow() {
    return InkWell(
      onTap: _handleLogout,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: Color(0xffFFBCB9),
                borderRadius: BorderRadius.circular(6)
              ),
              child: Icon(
                Icons.logout_rounded,
                color: Color(0xffF04438),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Keluar',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xffF04438),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
