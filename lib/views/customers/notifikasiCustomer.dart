import 'package:aplikasi_pdam/services/notificationStore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotifikasiCustomer extends StatefulWidget {
  const NotifikasiCustomer({super.key});

  @override
  State<NotifikasiCustomer> createState() => _NotifikasiCustomerState();
}

class _NotifikasiCustomerState extends State<NotifikasiCustomer> {
  final NotificationStore _store = NotificationStore();

  @override
  void initState() {
    super.initState();
    _store.load().then((_) {
      if (mounted) setState(() {});
    });
    _store.addListener(_onStoreChanged);
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  IconData _iconForTitle(String title) {
    if (title.contains('Tagihan') || title.contains('Bill')) {
      return Icons.receipt_long_rounded;
    }
    if (title.contains('Verifikasi') || title.contains('Lunas')) {
      return Icons.verified_rounded;
    }
    if (title.contains('Bayar') || title.contains('Pembayaran')) {
      return Icons.payment_rounded;
    }
    return Icons.notifications_rounded;
  }

  Color _iconColorForTitle(String title) {
    if (title.contains('Tagihan') || title.contains('Bill')) {
      return const Color(0xffF59E0B); // amber
    }
    if (title.contains('Verifikasi') || title.contains('Lunas')) {
      return const Color(0xff12B76A); // green
    }
    if (title.contains('Bayar') || title.contains('Pembayaran')) {
      return const Color(0xff295CD0); // blue
    }
    return const Color(0xff667085);
  }

  Color _iconBgForTitle(String title) {
    if (title.contains('Tagihan') || title.contains('Bill')) {
      return const Color(0xffFEF3C7); // amber light
    }
    if (title.contains('Verifikasi') || title.contains('Lunas')) {
      return const Color(0xffD1FADF); // green light
    }
    if (title.contains('Bayar') || title.contains('Pembayaran')) {
      return const Color(0xffE3EBFD); // blue light
    }
    return Colors.grey.shade100;
  }

  Future<void> _deleteNotif(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Notifikasi',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Hapus notifikasi ini?', style: GoogleFonts.poppins()),
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
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xffF2F4F7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.notifications_off_rounded,
                        size: 48, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Belum ada notifikasi',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff475467),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Notifikasi tagihan baru dan pembayaran\nterverifikasi akan muncul di sini',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: const Color(0xff98A2B3),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xff295CD0),
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
                    key: ValueKey(
                        'cust_notif_${notif.timestamp.millisecondsSinceEpoch}_$index'),
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
                              : _iconBgForTitle(notif.title),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _iconForTitle(notif.title),
                          color: notif.isRead
                              ? Colors.grey.shade400
                              : _iconColorForTitle(notif.title),
                          size: 20,
                        ),
                      ),
                      title: Text(
                        notif.title,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: notif.isRead
                              ? FontWeight.w400
                              : FontWeight.bold,
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
                                color: Color(0xff295CD0),
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
