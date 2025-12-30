import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Global instance for background handler
final FlutterLocalNotificationsPlugin _backgroundNotifications = FlutterLocalNotificationsPlugin();

/// Initialize notifications in background handler
@pragma('vm:entry-point')
Future<void> _initializeBackgroundNotifications() async {
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  
  await _backgroundNotifications.initialize(
    initSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      debugPrint('[FCM] Background notification tapped: ${response.payload}');
    },
  );
  
  // Create high-priority notification channel
  const androidChannel = AndroidNotificationChannel(
    'device_lock_channel',
    'Device Lock Notifications',
    description: 'Critical notifications for device lock commands',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );
  
  await _backgroundNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);
  
  debugPrint('[FCM] ✅ Background notifications initialized');
}

/// Background message handler
/// This must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] ========== BACKGROUND MESSAGE RECEIVED ==========');
  debugPrint('[FCM] Message ID: ${message.messageId}');
  debugPrint('[FCM] Message data: ${message.data}');
  
  // Initialize notifications if not already done
  await _initializeBackgroundNotifications();
  
  final data = message.data;
  if (data.containsKey('type')) {
    final type = data['type'] as String;
    debugPrint('[FCM] Background message type: $type');
    
    final prefs = await SharedPreferences.getInstance();
    
    switch (type) {
      case 'lock_command':
        // Store lock command
        await prefs.setBool('fcm_lock_pending', true);
        if (data.containsKey('emiId')) {
          await prefs.setString('fcm_lock_emi_id', data['emiId'] as String);
        }
        // Store full command data
        await prefs.setString('fcm_lock_data', jsonEncode(data));
        debugPrint('[FCM] Lock command stored for processing when app opens');
        
        // Show high-priority notification that auto-opens app
        await _showAutoOpenNotification(message, data);
        break;
        
      case 'unlock_command':
      case 'extend_payment':
        // Store unlock command with HIGHEST PRIORITY
        debugPrint('[FCM] ========== UNLOCK COMMAND RECEIVED IN BACKGROUND ==========');
        await prefs.setBool('fcm_unlock_pending', true);
        
        // Clear all lock-related flags immediately
        await prefs.setBool('device_locked', false);
        await prefs.setBool('overlay_active', false);
        await prefs.remove('lock_emi_id');
        await prefs.remove('overlay_emi_id');
        await prefs.remove('fcm_lock_emi_id');
        await prefs.remove('fcm_lock_data');
        
        if (type == 'extend_payment' && data.containsKey('days')) {
          final days = (data['days'] as num?)?.toInt() ?? 0;
          if (days > 0) {
            final unlockUntil = DateTime.now().add(Duration(days: days));
            await prefs.setString('fcm_unlock_until', unlockUntil.toIso8601String());
          }
        } else {
          // For unlock_command, remove unlock_until
          await prefs.remove('fcm_unlock_until');
        }
        
        debugPrint('[FCM] ✅ Unlock command stored - all lock flags cleared');
        debugPrint('[FCM] App will hide overlay when it opens');
        break;
        
      default:
        debugPrint('[FCM] Unknown background message type: $type');
    }
  }
}

/// Show notification that auto-opens app
@pragma('vm:entry-point')
Future<void> _showAutoOpenNotification(RemoteMessage message, Map<String, dynamic> data) async {
  try {
    final title = message.notification?.title ?? 'Device Lock Required';
    final body = message.notification?.body ?? 
                 data['reason'] as String? ?? 
                 'Your device needs to be locked due to overdue EMI';
    
    debugPrint('[FCM] Showing auto-open notification: $title');
    
    final androidDetails = AndroidNotificationDetails(
      'device_lock_channel',
      'Device Lock Notifications',
      channelDescription: 'Critical notifications for device lock commands',
      importance: Importance.max, // Maximum importance for auto-open
      priority: Priority.max, // Maximum priority
      showWhen: true,
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true, // CRITICAL: Auto-open app
      autoCancel: false, // Don't auto-cancel
      ongoing: true, // Ongoing notification
      styleInformation: BigTextStyleInformation(body, contentTitle: title),
      category: AndroidNotificationCategory.alarm, // Alarm category for high priority
      visibility: NotificationVisibility.public,
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.critical,
    );
    
    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _backgroundNotifications.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title,
      body,
      notificationDetails,
      payload: jsonEncode(data),
    );
    
    debugPrint('[FCM] ✅ Auto-open notification shown (app will open automatically)');
  } catch (e) {
    debugPrint('[FCM] ❌ Error showing auto-open notification: $e');
  }
}

/// Check for pending FCM commands when app opens
Future<void> processPendingFcmCommands() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Check for pending lock command
    final lockPending = prefs.getBool('fcm_lock_pending') ?? false;
    if (lockPending) {
      debugPrint('[FCM] Processing pending lock command');
      await prefs.setBool('fcm_lock_pending', false);
      // The lock will be processed by AppOverlayService when it checks
    }
    
    // Check for pending unlock command
    final unlockPending = prefs.getBool('fcm_unlock_pending') ?? false;
    if (unlockPending) {
      debugPrint('[FCM] Processing pending unlock command');
      await prefs.setBool('fcm_unlock_pending', false);
      // The unlock will be processed by AppOverlayService when it checks
    }
  } catch (e) {
    debugPrint('[FCM] Error processing pending commands: $e');
  }
}





