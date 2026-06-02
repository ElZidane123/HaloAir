import 'package:aplikasi_pdam/services/notificationStore.dart';
import 'package:aplikasi_pdam/services/adminPaymentPollingService.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotifikasiAdmin extends StatefulWidget {
  const NotifikasiAdmin({super.key});

  @override
  State<NotifikasiAdmin> createState() => _NotifikasiAdminState();
}

class _NotifikasiAdminState extends State<NotifikasiAdmin> {
  final NotificationStore _store = NotificationStore();
  final AdminPaymentPollingService _pollingService = AdminPaymentPollingService();

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _store.markAllRead();
    
    // Force polling ketika masuk halaman notifikasi untuk real-time data
    _pollingService.forcePoll();
    
    // Load store untuk pastikan data terbaru
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _store.load().then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _deleteNotif(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Notifikasi',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Hapus notifikasi ini?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus',
                style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _store.removeAt(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _store.items;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xff1D2939)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Notifikasi',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: const Color(0xff1D2939),
          ),
        ),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: Text('Hapus Semua',
                        style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold)),
                    content: Text('Hapus semua notifikasi?',
                        style: GoogleFonts.poppins()),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Batal', style: GoogleFonts.poppins()),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text('Hapus Semua',
                            style: GoogleFonts.poppins(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _store.clearAll();
                }
              },
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: Color(0xff667085)),
              tooltip: 'Hapus Semua',
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_rounded,
                      size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada notifikasi',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Notifikasi pembayaran baru akan muncul di sini',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xff025ae9),
              onRefresh: () async {
                setState(() {});
              },
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
                  final notif = items[index];
                  return Dismissible(
                    key: ValueKey('notif_${notif.timestamp.millisecondsSinceEpoch}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: Colors.red.shade50,
                      child: Icon(Icons.delete_rounded,
                          color: Colors.red.shade400, size: 24),
                    ),
                    onDismissed: (_) => _store.removeAt(index),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: notif.isRead
                              ? Colors.grey.shade100
                              : const Color(0xffEEF4FF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.payment_rounded,
                          color: notif.isRead
                              ? Colors.grey.shade400
                              : const Color(0xff2563eb),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        notif.title,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight:
                              notif.isRead ? FontWeight.w400 : FontWeight.bold,
                          color: const Color(0xff1D2939),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notif.body,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: const Color(0xff667085),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            NotificationItem.formatTime(notif.timestamp),
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                      trailing: !notif.isRead
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xff2563eb),
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                      onTap: () {
                        _store.markAsRead(index);
                      },
                      onLongPress: () => _deleteNotif(index),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
