import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(initSettings);
    _isInitialized = true;
  }

  /// Check if low stock notifications are enabled
  Future<bool> isLowStockNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notif_low_stock') ?? true;
  }

  /// Check if pending approvals notifications are enabled
  Future<bool> isPendingApprovalsNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notif_pending_approvals') ?? true;
  }

  /// Check if daily summary notifications are enabled
  Future<bool> isDailySummaryNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('notif_daily_summary') ?? false;
  }

  /// Show a low stock notification
  Future<void> showLowStockNotification({
    required String itemName,
    required double currentStock,
    required double minStock,
    required String unit,
  }) async {
    if (!await isLowStockNotificationsEnabled()) return;

    const androidDetails = AndroidNotificationDetails(
      'low_stock',
      'Low Stock Alerts',
      channelDescription: 'Notifications when stock falls below minimum level',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      itemName.hashCode, // Use item name hash as unique ID
      '⚠️ Low Stock Alert',
      '$itemName: ${currentStock.toStringAsFixed(1)} $unit (Min: ${minStock.toStringAsFixed(1)} $unit)',
      details,
    );
  }

  /// Show a pending approval notification
  Future<void> showPendingApprovalNotification({
    required String type, // 'Purchase' or 'Issue'
    required String referenceNo,
    required String requestedBy,
  }) async {
    if (!await isPendingApprovalsNotificationsEnabled()) return;

    const androidDetails = AndroidNotificationDetails(
      'pending_approvals',
      'Pending Approvals',
      channelDescription: 'Notifications for pending approvals',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      referenceNo.hashCode, // Use reference number hash as unique ID
      '📋 Pending $type Approval',
      '$referenceNo by $requestedBy needs approval',
      details,
    );
  }

  /// Show daily summary notification
  Future<void> showDailySummaryNotification({
    required int lowStockItems,
    required int pendingApprovals,
    required double totalIssues,
  }) async {
    if (!await isDailySummaryNotificationsEnabled()) return;

    const androidDetails = AndroidNotificationDetails(
      'daily_summary',
      'Daily Summary',
      channelDescription: 'Daily inventory summary',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final message = '📊 Summary: $lowStockItems low stock, '
        '$pendingApprovals pending approvals, '
        '₹${totalIssues.toStringAsFixed(0)} issued today';

    await _notifications.show(
      0, // Fixed ID for daily summary
      '📈 HIMS Daily Summary',
      message,
      details,
    );
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Request notification permissions (iOS only)
  Future<bool?> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    return await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }
}
