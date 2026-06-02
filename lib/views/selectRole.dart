import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Warna ───────────────────────────────────────────────────────
const Color _blue = Color(0xff2C5EC5);
const Color _blueCard = Color(0xff285BCF);
const Color _white = Colors.white;

class SelectRole extends StatefulWidget {
  const SelectRole({super.key});

  @override
  State<SelectRole> createState() => _SelectRoleState();
}

class _SelectRoleState extends State<SelectRole>
    with SingleTickerProviderStateMixin {
  late AnimationController _ac;
  late Animation<double> _cardFade;
  late Animation<Offset> _cardSlide;
  late Animation<double> _bottomFade;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    _cardSlide = Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _ac,
            curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _bottomFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ac,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    _ac.forward();
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Pastikan status bar transparan agar foto terlihat penuh
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _blue,
      body: Stack(
        children: [
          // ── 1. Foto hero (atas) dengan ClipPath miring/radius ──────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: ClipPath(
              clipper: _HeroImageClipper(),
              child: Image.asset('assets/images/foto1.png', fit: BoxFit.cover),
            ),
          ),

          // ── 2. Konten scroll utama ───────────────────────────────
          SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: size.height),
              child: Column(
                children: [
                  // Spacer foto hero
                  SizedBox(height: size.height * 0.35),

                  // ── Logo icon ──────────────────────────────────
                  Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/images/Logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Judul ──────────────────────────────────────
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: 'Langkah ',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _white,
                          ),
                        ),
                        TextSpan(
                          text: 'Pertama!',
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color.fromARGB(255, 209, 225, 255),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Selamat datang! Ayo, mulai sekarang!',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: _white.withOpacity(0.75),
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Role cards ─────────────────────────────────
                  FadeTransition(
                    opacity: _cardFade,
                    child: SlideTransition(
                      position: _cardSlide,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            _RoleCard(
                              icon: Icons.person_rounded,
                              title: 'Customer',
                              subtitle: 'Saya ingin menggunakan layanan',
                              filled: true,
                              onTap: () => Navigator.pushNamed(
                                context,
                                '/register-customer',
                              ),
                            ),
                            const SizedBox(height: 14),
                            _RoleCard(
                              icon: Icons.shield_rounded,
                              title: 'Admin',
                              subtitle: 'Saya ingin masuk ke dashboard',
                              filled: false,
                              onTap: () =>
                                  Navigator.pushNamed(context, '/register'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Login link ─────────────────────────────────
                  FadeTransition(
                    opacity: _bottomFade,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Apakah kamu sudah punya akun? ',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: _white.withOpacity(0.75),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/login'),
                          child: Text(
                            'Login',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: _white,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Trust badges ───────────────────────────────
                  FadeTransition(
                    opacity: _bottomFade,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _TrustBadge(
                            icon: Icons.shield_rounded,
                            label: 'Aman',
                          ),
                          _divider(),
                          _TrustBadge(
                            icon: Icons.flash_on_rounded,
                            label: 'Cepat',
                          ),
                          _divider(),
                          _TrustBadge(
                            icon: Icons.verified_rounded,
                            label: 'Terpercaya',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Text(
      '|',
      style: TextStyle(color: _white.withOpacity(0.3), fontSize: 14),
    ),
  );
}

// ─── Role Card ────────────────────────────────────────────────────
class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled; // true = biru (customer), false = putih (admin)
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.filled,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Premium theme color adjustments matching the reference photo
    final bg = widget.filled ? _blueCard : _white;
    final titleColor = widget.filled ? _white : const Color(0xFF1D2939);
    final subtitleColor = widget.filled
        ? _white.withOpacity(0.75)
        : const Color(0xFF667085);
    final iconBg = widget.filled ? _white : const Color(0xFFEEF4FF);
    final iconColor = widget.filled ? _blueCard : _blue;
    final arrowBg = widget.filled ? _white : const Color(0xFFEEF4FF);
    final arrowColor = widget.filled ? _blueCard : _blue;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(widget.filled ? 0.12 : 0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: subtitleColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: arrowBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: arrowColor,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Trust Badge ──────────────────────────────────────────────────
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.7), size: 15),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─── Custom Clipper for Slanted Hero Image ─────────────────────────
class _HeroImageClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Start at left edge, 60% down the height
    path.lineTo(0, size.height * 0.50);

    // Single smooth quadratic Bezier curve
    final controlPoint = Offset(size.width * 0.20, size.height * 0.90);
    final endPoint = Offset(size.width, size.height * 0.88);
    path.quadraticBezierTo(
      controlPoint.dx,
      controlPoint.dy,
      endPoint.dx,
      endPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
