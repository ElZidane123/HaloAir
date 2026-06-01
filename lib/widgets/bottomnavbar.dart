import 'package:aplikasi_pdam/services/notificationStore.dart';
import 'package:aplikasi_pdam/views/admins/kelolaBill.dart';
import 'package:aplikasi_pdam/views/customers/bill.dart';
import 'package:aplikasi_pdam/views/customers/homescreen.dart';
import 'package:aplikasi_pdam/views/admins/kelolaCust.dart';
import 'package:aplikasi_pdam/views/admins/layananAdmin.dart';
import 'package:aplikasi_pdam/views/customers/layananCust.dart';
import 'package:aplikasi_pdam/views/profile.dart';
import 'package:aplikasi_pdam/views/admins/adminDashboard.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Bottomnavbar extends StatefulWidget {
  final String? role;
  const Bottomnavbar({super.key, this.role});

  @override
  State<Bottomnavbar> createState() => _BottomnavbarState();
}

class _BottomnavbarState extends State<Bottomnavbar> {
  int _selectedIndex = 0;
  String _role = 'CUSTOMER';
  bool _isLoading = true;
  int _notifBadgeCount = 0;

  final NotificationStore _notifStore = NotificationStore();

  @override
  void initState() {
    super.initState();
    _loadRole();
    _notifStore.addListener(_onNotifChanged);
    _notifBadgeCount = _notifStore.unreadCount;
  }

  @override
  void dispose() {
    _notifStore.removeListener(_onNotifChanged);
    super.dispose();
  }

  void _onNotifChanged() {
    if (mounted) {
      setState(() {
        _notifBadgeCount = _notifStore.unreadCount;
      });
    }
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role') ?? widget.role ?? 'CUSTOMER';
    setState(() {
      _role = role.toUpperCase();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAdmin = _role == 'ADMIN';
    final pages = isAdmin ? _getAdminPages() : _getCustomerPages();
    final destinations = isAdmin ? _getAdminDestinations() : _getCustomerDestinations();

    return Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          indicatorColor: const Color(0xff2C5EC5).withValues(alpha: 0.12),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xff2C5EC5), size: 24);
            }
            return const IconThemeData(color: Color(0xff98A2B3), size: 24);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return GoogleFonts.poppins(
                color: const Color(0xff2C5EC5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              );
            }
            return GoogleFonts.poppins(
              color: const Color(0xff98A2B3),
              fontSize: 11,
              fontWeight: FontWeight.w400,
            );
          }),
        ),
      ),
      child: Scaffold(
        body: NotificationListener<SwitchTabNotification>(
          onNotification: (notification) {
            setState(() {
              _selectedIndex = notification.index;
            });
            return true;
          },
          child: pages[_selectedIndex],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: destinations,
        ),
      ),
    );
  }

  // ==================== ADMIN PAGES ====================
  List<Widget> _getAdminPages() {
    return [
      const AdminDashboard(), // Dashboard
      const Layananadmin(), // Layanan
      const Kelolacust(), // Customer
      const KelolaBill(), // Bill
      const Profil(), // Profil
    ];
  }

  List<NavigationDestination> _getAdminDestinations() {
    return [
      NavigationDestination(
        icon: _notifBadgeCount > 0
            ? Badge(
                label: Text(
                  _notifBadgeCount > 9 ? '9+' : '$_notifBadgeCount',
                  style: const TextStyle(fontSize: 9),
                ),
                child: const Icon(Icons.home_outlined),
              )
            : const Icon(Icons.home_outlined),
        selectedIcon: _notifBadgeCount > 0
            ? Badge(
                label: Text(
                  _notifBadgeCount > 9 ? '9+' : '$_notifBadgeCount',
                  style: const TextStyle(fontSize: 9),
                ),
                child: const Icon(Icons.home),
              )
            : const Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.grid_view_outlined),
        selectedIcon: Icon(Icons.grid_view),
        label: 'Layanan',
      ),
      const NavigationDestination(
        icon: Icon(Icons.people_outline),
        selectedIcon: Icon(Icons.people),
        label: 'Customer',
      ),
      const NavigationDestination(
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment),
        label: 'Bill',
      ),
      const NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profile',
      ),
    ];
  }

  // ==================== CUSTOMER PAGES ====================
  List<Widget> _getCustomerPages() {
    return [
      const Homescreen(), // Dashboard
      const Bill(), // Pembayaran
      const Layanancust(), // Layanan
      const Profil(), // Profil
    ];
  }

  List<NavigationDestination> _getCustomerDestinations() {
    return [
      NavigationDestination(
        icon: _notifBadgeCount > 0
            ? Badge(
                label: Text(
                  _notifBadgeCount > 9 ? '9+' : '$_notifBadgeCount',
                  style: const TextStyle(fontSize: 9),
                ),
                child: const Icon(Icons.home_outlined),
              )
            : const Icon(Icons.home_outlined),
        selectedIcon: _notifBadgeCount > 0
            ? Badge(
                label: Text(
                  _notifBadgeCount > 9 ? '9+' : '$_notifBadgeCount',
                  style: const TextStyle(fontSize: 9),
                ),
                child: const Icon(Icons.home),
              )
            : const Icon(Icons.home),
        label: 'Dashboard',
      ),
      NavigationDestination(
        icon: Icon(Icons.payment_outlined),
        selectedIcon: Icon(Icons.payment),
        label: 'Pembayaran',
      ),
      NavigationDestination(
        icon: Icon(Icons.miscellaneous_services_outlined),
        selectedIcon: Icon(Icons.miscellaneous_services),
        label: 'Layanan',
      ),
      NavigationDestination(
        icon: Icon(Icons.person_outline),
        selectedIcon: Icon(Icons.person),
        label: 'Profil',
      ),
    ];
  }
}

class SwitchTabNotification extends Notification {
  final int index;
  const SwitchTabNotification(this.index);
}