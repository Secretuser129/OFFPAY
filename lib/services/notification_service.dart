import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'log_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize local notifications for offline/background BLE payments
  static Future<void> init() async {
    if (_initialized) return;

    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification clicked with payload: ${response.payload}');
        },
      );

      // Request Android 13+ POST_NOTIFICATIONS permission
      final androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.requestNotificationsPermission();
      }

      _initialized = true;
      LogService.log(
        'NotificationService initialized for offline payment alerts',
        category: 'SYSTEM',
        source: 'NotificationService',
      );
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  /// Show Android System Notification when an offline payment is received
  static Future<void> showPaymentReceivedNotification({
    required double amount,
    required String senderName,
    String? transactionId,
  }) async {
    try {
      if (!_initialized) {
        await init();
      }

      final String displayName = senderName.trim().isNotEmpty
          ? senderName.trim()
          : 'An OFFPAY User';

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'offpay_offline_payments_channel',
        'OFFPAY Offline Payments',
        channelDescription:
            'Instant notifications when offline Bluetooth payments are received',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Payment Received from OFFPAY',
        icon: '@mipmap/ic_launcher',
        styleInformation: BigTextStyleInformation(''),
      );

      const NotificationDetails details =
          NotificationDetails(android: androidDetails);

      final String title = 'OFFPAY • $displayName';
      final String body = '$displayName sent you payment ₹${amount.toStringAsFixed(2)}';

      await _notificationsPlugin.show(
        DateTime.now().millisecond,
        title,
        body,
        details,
        payload: transactionId,
      );

      LogService.log(
        'System Notification dispatched: "$body" (Offline BLE/Background)',
        category: 'SECURITY',
        source: 'NotificationService',
      );
    } catch (e) {
      debugPrint('Error showing payment notification: $e');
      LogService.log(
        'Failed to display system notification: $e',
        category: 'ERROR',
        source: 'NotificationService',
      );
    }
  }
}
