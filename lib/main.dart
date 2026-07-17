import 'package:aplikasi_pdam/services/notificationStore.dart';
import 'package:aplikasi_pdam/views/admins/kelolaBill.dart';
import 'package:aplikasi_pdam/views/showMe.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:aplikasi_pdam/services/notificationService.dart';

// View/Screen Imports
import 'package:aplikasi_pdam/views/splashScreen.dart';
import 'package:aplikasi_pdam/views/selectRole.dart';
import 'package:aplikasi_pdam/views/login.dart';
import 'package:aplikasi_pdam/views/register.dart';
import 'package:aplikasi_pdam/views/registerCustomer.dart';
import 'package:aplikasi_pdam/views/admins/adminDashboard.dart';
import 'package:aplikasi_pdam/views/customers/homescreen.dart';

import 'package:aplikasi_pdam/views/profile.dart';

// Widget/Dashboard Imports
import 'package:aplikasi_pdam/widgets/bottomnavbar.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notifService = NotificationService();
  await notifService.initialize();
  notifService.setNavigatorKey(navigatorKey);
  await NotificationStore().load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'HaloAir',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        textTheme: GoogleFonts.poppinsTextTheme(
          Theme.of(context).textTheme,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const Splashscreen(),
        '/select-role': (context) => const SelectRole(),
        '/login': (context) => const Login(),
        '/register': (context) => const Register(),
        '/register-customer': (context) => const RegisterCustomer(),
        '/admin-dashboard': (context) => const AdminDashboard(),
        '/customer-dashboard': (context) => const Bottomnavbar(),
        '/homescreen': (context) => const Homescreen(),
        '/kelolaBill': (context) => const KelolaBill(),
        '/profile': (context) => const Profil(),
        "/showme": (context) {
          final role = ModalRoute.of(context)?.settings.arguments as String? ?? 'CUSTOMER';
          return Showme(role: role);
        },
      },
    );
  }
}