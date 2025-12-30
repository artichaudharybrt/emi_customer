import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();

  static const String _fcmTokenKey = 'fcm_token';
  static const String _pendingOverlayKey = 'pending_overlay';

  /// Initialize notification service
  static Future<void> initialize() async {
    // Request permission for notifications
    await _requestNotificationPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();
  }

  /// Request notification permissions
  static Future<void> _requestNotificationPermission() async {
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
  }

  /// Initialize local notifications
  static Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'emi_due_channel',
      'EMI Due Notifications',
      description: 'Notifications for EMI due dates',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Show overlay from notification data
  static Future<void> _showOverlayFromNotification(Map<String, dynamic> data) async {
    try {
      // Store pending overlay request - will be handled by app overlay service
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingOverlayKey, jsonEncode(data));
    } catch (e) {
      print('Error storing overlay from notification: $e');
    }
  }

  /// Show local notification
  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'emi_due_channel',
      'EMI Due Notifications',
      channelDescription: 'Notifications for EMI due dates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        if (data['type'] == 'emi_due') {
          _showOverlayFromNotification(data);
        }
      } catch (e) {
        print('Error handling notification tap: $e');
      }
    }
  }

  /// Get FCM token (if using FCM)
  static Future<String?> getFcmToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fcmTokenKey);
  }

  /// Save FCM token (if using FCM)
  static Future<void> saveFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fcmTokenKey, token);
  }

  /// Check for pending overlay on app start
  static Future<void> checkPendingOverlay() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingDataStr = prefs.getString(_pendingOverlayKey);
      
      if (pendingDataStr != null) {
        // Overlay will be shown by app overlay service
        await prefs.remove(_pendingOverlayKey);
      }
    } catch (e) {
      print('Error checking pending overlay: $e');
    }
  }

  /// Show notification for EMI due
  static Future<void> showEmiDueNotification({
    required String emiId,
    required String billNumber,
    required double amount,
  }) async {
    await _showLocalNotification(
      title: 'EMI Payment Due!',
      body: 'Bill $billNumber: ₹${amount.toStringAsFixed(0)} is due',
      payload: jsonEncode({
        'type': 'emi_due',
        'emiId': emiId,
      }),
    );
  }
}

