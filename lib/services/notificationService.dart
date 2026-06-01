import 'package:flutter/material.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  // Singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Navigator key untuk navigasi saat notifikasi di-tap
  GlobalKey<NavigatorState>? navigatorKey;

  // ======================== CHANNEL CONSTANTS ========================
  // Pakai channel baru (v2) supaya importance bisa di-upgrade
  // jika channel lama masih tersimpan di sistem dengan importance rendah
  static const String _channelId = 'pdam_admin_payments_v2';
  static const String _channelName = 'Pembayaran Admin PDAM';
  static const String _channelDesc =
      'Notifikasi pembayaran baru yang masuk ke admin dashboard';

  // Group key untuk mengelompokkan notifikasi
  static const String _groupKey = 'pdam_admin_payment_group_v2';
  // ID untuk notifikasi ringkasan grup
  static const int _groupSummaryId = 1000;
  // ID tetap untuk notifikasi pembayaran
  static const int _paymentNotifId = 1001;
  // ID untuk notifikasi test
  static const int _testNotifId = 9999;

  /// Set navigator key agar notifikasi bisa navigasi
  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    navigatorKey = key;
  }

  // ======================== INITIALIZE ========================
  Future<void> initialize() async {
    if (_initialized) return;

    // Android settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Hapus channel lama (jika ada) lalu buat channel baru dengan importance tinggi
    await _resetAndCreateChannel();

    _initialized = true;
    debugPrint('[NotificationService] Initialized ✓');
  }

  // ======================== RESET & CREATE CHANNEL ========================
  Future<void> _resetAndCreateChannel() async {
    final platform = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (platform == null) return;

    // Hapus channel lama agar bisa dibuat ulang dengan importance tinggi
    try {
      await platform.deleteNotificationChannel('pdam_admin_payments');
      await platform.deleteNotificationChannel('pdam_admin_payments_v2');
    } catch (_) {}

    // Buat channel baru dengan importance MAX + heads-up
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await platform.createNotificationChannel(channel);
    debugPrint('[NotificationService] Channel created: $_channelId (max importance)');
  }

  // ======================== REQUEST PERMISSION ========================
  Future<bool> requestPermission() async {
    // Android 13+ (API 33+) perlu POST_NOTIFICATIONS
    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final result = await Permission.notification.request();
    return result.isGranted;
  }

  /// Minta permission untuk notifikasi + fullScreenIntent (Android 14+)
  Future<bool> requestAllPermissions() async {
    // Permission notifikasi biasa
    final notifGranted = await requestPermission();

    // Android 14+ butuh SCHEDULE_EXACT_ALARM untuk notifikasi terjadwal
    if (await Permission.scheduleExactAlarm.status.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }

    // Coba minta ignore battery optimization agar notifikasi tidak di-delay
    if (await Permission.ignoreBatteryOptimizations.status.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }

    return notifGranted;
  }

  // ======================== SHOW NOTIFICATION ========================
  /// Tampilkan notifikasi sistem (heads-up, lock screen, notification tray)
  Future<void> showPaymentNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized) await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      number: 1,
      showWhen: true,
      ticker: 'Pembayaran baru masuk',
      groupKey: _groupKey,
      setAsGroupSummary: false,
      styleInformation: BigTextStyleInformation(''),
      // Android 12+ akan tetap show heads-up meski DND (alarm category)
      category: AndroidNotificationCategory.alarm,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(id, title, body, details);
    debugPrint('[NotificationService] Notification shown: $title');

    await _showGroupSummary(body);
  }

  /// Tampilkan notifikasi ringkasan grup di area notifikasi
  Future<void> _showGroupSummary(String latestBody) async {
    final AndroidNotificationDetails groupSummaryDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: false,
      groupKey: _groupKey,
      setAsGroupSummary: true,
      styleInformation: BigTextStyleInformation(latestBody),
    );

    final NotificationDetails groupDetails = NotificationDetails(
      android: groupSummaryDetails,
    );

    await _plugin.show(
      _groupSummaryId,
      '💧 HaloAir — Pembayaran Baru',
      latestBody,
      groupDetails,
    );
  }

  /// Tampilkan notifikasi + perbarui app badge (lencana ikon)
  Future<void> showPaymentBadgeNotification({
    required int unverifiedCount,
  }) async {
    await showPaymentNotification(
      id: _paymentNotifId,
      title: '💧 HaloAir — Pembayaran Baru',
      body: 'Ada $unverifiedCount pembayaran yang menunggu verifikasi Anda.',
    );

    // Update lencana di ikon aplikasi (launcher badge)
    await updateAppBadge(unverifiedCount);
  }

  /// Tampilkan notifikasi pembayaran dengan detail (nama customer + nominal)
  Future<void> showDetailedPaymentNotification({
    required int id,
    required String customerName,
    required double amount,
    required int totalUnverifiedCount,
  }) async {
    // Format amount ke Rupiah
    final formattedAmount = _formatCurrency(amount.toInt());
    
    // Build message
    final title = '💰 Pembayaran Masuk dari $customerName';
    final body = 'Sebesar $formattedAmount — Ada $totalUnverifiedCount pembayaran menunggu verifikasi.';

    await showPaymentNotification(
      id: id,
      title: title,
      body: body,
    );

    // Update lencana di ikon aplikasi
    await updateAppBadge(totalUnverifiedCount);
  }

  /// Format angka ke format Rupiah
  String _formatCurrency(int amount) {
    String amountStr = amount.toString();
    String result = '';
    int count = 0;
    
    for (int i = amountStr.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = '.$result';
      }
      result = amountStr[i] + result;
      count++;
    }
    
    return 'Rp $result';
  }

  /// Tampilkan notifikasi test (untuk debugging)
  Future<void> showTestNotification() async {
    if (!_initialized) await initialize();

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      number: 0,
      showWhen: true,
      ticker: 'Test Notifikasi',
      category: AndroidNotificationCategory.alarm,
      styleInformation: BigTextStyleInformation(
        'Notifikasi ini muncul sebagai test — jika Anda melihat ini, '
        'notifikasi sistem berfungsi dengan baik!',
      ),
    );

    await _plugin.show(
      _testNotifId,
      '🔔 Test Notifikasi HaloAir',
      'Notifikasi berfungsi! Swipe untuk menutup.',
      NotificationDetails(android: androidDetails),
    );

    debugPrint('[NotificationService] Test notification sent ✓');
  }

  // ======================== APP BADGE (LENCANA IKON) ========================
  /// Perbarui angka lencana di ikon aplikasi
  Future<void> updateAppBadge(int count) async {
    try {
      await AppBadgePlus.updateBadge(count);
      debugPrint('[NotificationService] App badge updated: $count');
    } catch (e) {
      debugPrint('[NotificationService] Badge error: $e');
    }
  }

  /// Hapus lencana ikon aplikasi
  Future<void> clearAppBadge() async {
    try {
      await AppBadgePlus.updateBadge(0);
    } catch (e) {
      debugPrint('[NotificationService] Clear badge error: $e');
    }
  }

  // ======================== CANCEL ========================
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    await clearAppBadge();
  }

  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  // ======================== NOTIFICATION TAP ========================
  /// Navigasi ke halaman kelolaBill saat notifikasi di-tap
  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[NotificationService] Notification tapped: ${response.id}');

    if (navigatorKey == null || navigatorKey?.currentContext == null) {
      debugPrint('[NotificationService] navigatorKey belum di-set');
      return;
    }

    // Navigasi ke halaman kelolaBill
    navigatorKey?.currentState?.pushNamed('/kelolaBill');
  }
}
