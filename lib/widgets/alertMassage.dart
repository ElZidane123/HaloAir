import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Alertmassage {
  void showAlert(
    BuildContext context,
    String message,
    bool status, {
    Duration? duration,
    VoidCallback? onClose,
  }) {
    final overlay = Overlay.of(context);
    late final OverlayEntry overlayEntry;

    void dismissAlert() {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
      if (onClose != null) {
        onClose();
      }
    }

    overlayEntry = OverlayEntry(
      builder: (_) => _AlertOverlay(
        message: message,
        isSuccess: status,
        onDismiss: dismissAlert,
      ),
    );

    overlay.insert(overlayEntry);

    final displayDuration = duration ?? const Duration(seconds: 3);
    Future.delayed(displayDuration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
      if (onClose != null) {
        onClose();
      }
    });
  }
}

class _AlertOverlay extends StatefulWidget {
  final String message;
  final bool isSuccess;
  final VoidCallback onDismiss;

  const _AlertOverlay({
    required this.message,
    required this.isSuccess,
    required this.onDismiss,
  });

  @override
  State<_AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends State<_AlertOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Scale animation with spring effect
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    // Opacity animation
    _opacityAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    // Slide animation from top
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.isSuccess;
    final bgColor = isSuccess 
        ? const Color(0xFFEBF9F3)
        : const Color(0xFFFEEAEA);
    final accentColor = isSuccess 
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final darkAccent = isSuccess
        ? const Color(0xFF059669)
        : const Color(0xFFDC2626);
    final icon = isSuccess
        ? Icons.check_circle_rounded
        : Icons.error_rounded;

    return Positioned(
      top: MediaQuery.of(context).viewPadding.top + 20,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _opacityAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accentColor.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon container with gradient background
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [accentColor, darkAccent],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Message with better typography
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isSuccess ? 'Berhasil!' : 'Error!',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: darkAccent,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.message,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF374151),
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Close button
                      GestureDetector(
                        onTap: widget.onDismiss,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.close_rounded,
                              color: accentColor,
                              size: 18,
                            ),
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
    );
  }
}