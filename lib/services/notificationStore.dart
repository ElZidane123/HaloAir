import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationItem {
  final String title;
  final String body;
  final String time;
  final DateTime timestamp;
  final bool isRead;

  NotificationItem({
    required this.title,
    required this.body,
    required this.time,
    required this.timestamp,
    this.isRead = false,
  });

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      title: title,
      body: body,
      time: time,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'body': body,
        'time': time,
        'timestamp': timestamp.toIso8601String(),
        'isRead': isRead,
      };

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      title: json['title'] as String,
      body: json['body'] as String,
      time: json['time'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  static String formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m yang lalu';
    if (diff.inHours < 24) return '${diff.inHours}j yang lalu';
    if (diff.inDays < 7) return '${diff.inDays}h yang lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// Shared in-memory notification store (singleton).
/// Semua komponen (dashboard, notif page, navbar) mengakses store ini.
class NotificationStore extends ChangeNotifier {
  static final NotificationStore _instance = NotificationStore._internal();
  factory NotificationStore() => _instance;
  NotificationStore._internal();

  static const String _prefKey = 'notification_history';

  List<NotificationItem> _items = [];
  int _unreadCount = 0;

  List<NotificationItem> get items => List.unmodifiable(_items);
  int get unreadCount => _unreadCount;
  int get totalCount => _items.length;

  // ======================== INIT / LOAD ========================
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefKey);
      if (raw != null) {
        _items = raw
            .map((e) {
              try {
                return NotificationItem.fromJson(
                    jsonDecode(e) as Map<String, dynamic>);
              } catch (_) {
                return null;
              }
            })
            .whereType<NotificationItem>()
            .toList();
      }
    } catch (e) {
      debugPrint('[NotifStore] Load error: $e');
    }
    _recalculateUnread();
  }

  // ======================== ADD ========================
  Future<void> add({
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    final item = NotificationItem(
      title: title,
      body: body,
      time: NotificationItem.formatTime(now),
      timestamp: now,
      isRead: false,
    );
    _items.insert(0, item);

    // Batasi maks 100 notifikasi
    if (_items.length > 100) {
      _items = _items.sublist(0, 100);
    }

    _recalculateUnread();
    await _persist();
    notifyListeners();
  }

  // ======================== MARK READ ========================
  Future<void> markAllRead() async {
    _items = _items.map((e) => e.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    await _persist();
    notifyListeners();
  }

  Future<void> markAsRead(int index) async {
    if (index < 0 || index >= _items.length) return;
    _items[index] = _items[index].copyWith(isRead: true);
    _recalculateUnread();
    await _persist();
    notifyListeners();
  }

  // ======================== DELETE ========================
  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    _recalculateUnread();
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _items.clear();
    _unreadCount = 0;
    await _persist();
    notifyListeners();
  }

  // ======================== HELPERS ========================
  void _recalculateUnread() {
    _unreadCount = _items.where((e) => !e.isRead).length;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _items.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_prefKey, raw);
    } catch (e) {
      debugPrint('[NotifStore] Persist error: $e');
    }
  }
}
