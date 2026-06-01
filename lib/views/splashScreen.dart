import 'package:aplikasi_pdam/views/selectRole.dart';
import 'package:aplikasi_pdam/widgets/bottomnavbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen>
    with TickerProviderStateMixin {
  // ── Intro: logo + teks ──────────────────────────────────────────
  late AnimationController _introController;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoScale;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  // ── Curtain: panel biru naik dari bawah ─────────────────────────
  late AnimationController _curtainController;
  late Animation<double> _curtainRise; // 0→1: panel naik dari bawah ke atas

  bool _showCurtain = false;

  @override
  void initState() {
    super.initState();

    // ── INTRO ──────────────────────────────────────────────────────
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.55, curve: Curves.easeIn),
      ),
    );
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOutBack),
      ),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.45, 0.9, curve: Curves.easeIn),
      ),
    );
    _textSlide =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.45, 1.0, curve: Curves.easeOutBack),
      ),
    );

    _introController.forward();

    // ── CURTAIN ────────────────────────────────────────────────────
    // Panel biru muncul dari bawah, naik menutup seluruh layar
    _curtainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _curtainRise = CurvedAnimation(
      parent: _curtainController,
      curve: Curves.easeInOut,
    );

    // Setelah intro selesai, jeda lalu jalankan curtain
    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (!mounted) return;
          setState(() => _showCurtain = true);
          _curtainController.forward();
        });
      }
    });

    // Setelah curtain penuh menutup → navigasi
    _curtainController.addStatusListener((status) async {
      if (status == AnimationStatus.completed) {
        if (!mounted) return;
        // Tunggu 1 frame agar layar benar-benar tertutup sebelum navigate
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;

        final prefs = await SharedPreferences.getInstance();
        if (!mounted) return;
        final String? token = prefs.getString('token');

        if (token != null && token.isNotEmpty) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const Bottomnavbar(),
              transitionDuration: Duration.zero,
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const SelectRole(),
              transitionDuration: Duration.zero,
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _introController.dispose();
    _curtainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background + logo + teks ─────────────────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, Colors.blue.shade50],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: _logoOpacity,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: const Image(
                        image: AssetImage("assets/images/Logo.png"),
                        width: 160,
                        height: 160,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FadeTransition(
                    opacity: _textOpacity,
                    child: SlideTransition(
                      position: _textSlide,
                      child: Text(
                        "HaloAir",
                        style: GoogleFonts.poppins(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xff2768CF),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Curtain: panel biru naik dari bawah ──────────────────
          if (_showCurtain)
            AnimatedBuilder(
              animation: _curtainRise,
              builder: (context, _) {
                return CustomPaint(
                  painter: _RiseCurtainPainter(
                    progress: _curtainRise.value,
                    color: const Color(0xff2768CF),
                  ),
                  child: const SizedBox.expand(),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Panel biru solid naik dari bawah layar ke atas.
/// Tepi atas panel melengkung ke dalam (concave) untuk kesan smooth.
/// progress 0.0 = panel di luar bawah, progress 1.0 = menutup full layar.
class _RiseCurtainPainter extends CustomPainter {
  final double progress; // 0.0 → 1.0
  final Color color;

  const _RiseCurtainPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Tepi atas panel bergerak dari h (bawah) → 0 (atas)
    final double topY = h - (h * progress);

    // Kedalaman lengkungan concave di tepi atas panel (maks 40px)
    // Saat progress mendekati 1, lengkungan mengecil → terlihat "mengunci"
    final double curl = 40.0 * (1.0 - progress) * progress * 4;

    final path = Path();

    // Pojok kiri bawah
    path.moveTo(0, h);

    // Pojok kanan bawah
    path.lineTo(w, h);

    // Pojok kanan atas
    path.lineTo(w, topY);

    // Tepi atas: lengkung concave (cekung ke dalam / ke bawah)
    path.cubicTo(
      w * 0.75, topY - curl, // CP kanan — melengkung ke atas di sisi kanan
      w * 0.25, topY - curl, // CP kiri  — melengkung ke atas di sisi kiri
      0, topY,               // ujung kiri
    );

    path.close();

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_RiseCurtainPainter old) => old.progress != progress;
}