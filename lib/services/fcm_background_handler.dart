import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'overlay_lock_service.dart';
import 'user_location_service.dart';
import 'sim_details_service.dart';

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
        // Extract message and amount
        final message = data['message'] as String? ?? 
                       data['reason'] as String? ?? 
                       'Your EMI is overdue. Please contact shopkeeper.';
        final amount = data['amount'] as String? ?? 
                      data['overdueAmount']?.toString() ?? 
                      '0';
        
        debugPrint('[FCM] ========== LOCK COMMAND RECEIVED IN BACKGROUND ==========');
        debugPrint('[FCM] App may be closed - will save lock status and show notification');
        
        // CRITICAL: Save lock status in Flutter SharedPreferences first
        // This ensures app will show overlay when it opens
        await prefs.setBool('device_locked', true);
        await prefs.setBool('overlay_lock_status', true);
        await prefs.setString('overlay_message', message);
        await prefs.setString('overlay_amount', amount);
        await prefs.setBool('fcm_lock_pending', true);
        if (data.containsKey('emiId')) {
          await prefs.setString('fcm_lock_emi_id', data['emiId'] as String);
          await prefs.setString('lock_emi_id', data['emiId'] as String);
        }
        await prefs.setString('fcm_lock_data', jsonEncode(data));
        debugPrint('[FCM] ✅ Lock status saved in SharedPreferences');
        
        // NOTE: OverlayLockService.lockDevice() uses MethodChannel which won't work in background handler
        // So we'll rely on app opening and SystemOverlayService.initialize() to show overlay
        // Try to call lockDevice anyway (may fail silently but that's OK)
        try {
          await OverlayLockService.lockDevice(
            message: message,
            amount: amount,
          );
        } catch (e) {
          debugPrint('[FCM] ⚠️ Could not call lockDevice in background (expected): $e');
          debugPrint('[FCM] Overlay will show when app opens');
        }
        
        // Show high-priority notification that auto-opens app
        // This notification will automatically open the app via fullScreenIntent
        await _showAutoOpenNotificationFromData(data, message);
        debugPrint('[FCM] ✅ Lock command processed - notification shown (app will open automatically)');
        break;
        
      case 'unlock_command':
      case 'extend_payment':
        // Unlock device immediately using overlay lock service
        debugPrint('[FCM] ========== UNLOCK COMMAND RECEIVED IN BACKGROUND ==========');
        await OverlayLockService.unlockDevice();
        
        // Store unlock command
        await prefs.setBool('fcm_unlock_pending', true);
        
        // Clear all lock-related flags
        await prefs.setBool('device_locked', false);
        await prefs.remove('lock_emi_id');
        await prefs.remove('fcm_lock_emi_id');
        await prefs.remove('fcm_lock_data');
        
        if (type == 'extend_payment' && data.containsKey('days')) {
          final days = (data['days'] as num?)?.toInt() ?? 0;
          if (days > 0) {
            final unlockUntil = DateTime.now().add(Duration(days: days));
            await prefs.setString('fcm_unlock_until', unlockUntil.toIso8601String());
          }
        } else {
          await prefs.remove('fcm_unlock_until');
        }
        
        debugPrint('[FCM] ✅ Unlock command processed - overlay should be hidden');
        break;

      case 'get_location_command':
        debugPrint('[FCM] ========== GET LOCATION COMMAND IN BACKGROUND ==========');
        try {
          final sent = await UserLocationService.fetchAndSendLocation();
          debugPrint('[FCM] get_location_command (background) result: ${sent ? "OK" : "failed"}');
        } catch (e) {
          debugPrint('[FCM] get_location_command (background) error: $e');
        }
        break;

      case 'get_sim_details_command':
        debugPrint('[FCM] ========== GET SIM DETAILS COMMAND IN BACKGROUND ==========');
        try {
          final sent = await SimDetailsService.postSimDetailsIfAllowed();
          debugPrint('[FCM] get_sim_details_command (background) result: ${sent ? "OK" : "failed"}');
        } catch (e) {
          debugPrint('[FCM] get_sim_details_command (background) error: $e');
        }
        break;
        
      default:
        debugPrint('[FCM] Unknown background message type: $type');
    }
  }
}

/// Show notification that auto-opens app (from RemoteMessage)
@pragma('vm:entry-point')
Future<void> _showAutoOpenNotification(RemoteMessage message, Map<String, dynamic> data) async {
  try {
    final title = message.notification?.title ?? 'Device Lock Required';
    final body = message.notification?.body ?? 
                 data['reason'] as String? ?? 
                 'Your device needs to be locked due to overdue EMI';
    
    await _showNotification(title, body, data);
  } catch (e) {
    debugPrint('[FCM] ❌ Error showing auto-open notification: $e');
  }
}

/// Show notification that auto-opens app (from data only - for background handler)
@pragma('vm:entry-point')
Future<void> _showAutoOpenNotificationFromData(Map<String, dynamic> data, String lockMessage) async {
  try {
    final title = 'Device Lock Required';
    final body = lockMessage;
    
    await _showNotification(title, body, data);
  } catch (e) {
    debugPrint('[FCM] ❌ Error showing auto-open notification: $e');
  }
}

/// Show notification helper
@pragma('vm:entry-point')
Future<void> _showNotification(String title, String body, Map<String, dynamic> data) async {
  try {
    
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





