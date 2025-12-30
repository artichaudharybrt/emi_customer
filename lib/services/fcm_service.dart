import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import '../config/api_config.dart';
import 'auth_service.dart';

class FCMService {
  static const String _tokenKey = 'fcm_token';
  static const String _lockStatusKey = 'device_locked';
  static const String _lockEmiIdKey = 'lock_emi_id';
  static const String _unlockUntilKey = 'unlock_until';
  
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final AuthService _authService = AuthService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  Function(Map<String, dynamic>)? onLockCommand;
  Function(Map<String, dynamic>)? onUnlockCommand;
  Function(String)? onTokenReceived;
  
  /// Initialize notification channel for high-priority notifications
  Future<void> _initializeNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'device_lock_channel',
      'Device Lock Notifications',
      description: 'Critical notifications for device lock commands',
      importance: Importance.max, // Maximum importance for auto-open
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
    
    debugPrint('[FCM] ✅ High-priority notification channel created');
  }
  
  /// Initialize FCM Service
  Future<void> initialize() async {
    try {
      // Initialize notification channel
      await _initializeNotificationChannel();
      
      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('[FCM] Local notification tapped: ${response.payload}');
          // Handle notification tap - app will open automatically
        },
      );
      
      // Request notification permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[FCM] User granted notification permission');
      } else {
        debugPrint('[FCM] User denied notification permission');
      }
      
      // Get FCM token
      await _getToken();
      
      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] ========== TOKEN REFRESH DETECTED ==========');
        debugPrint('[FCM] New Token: ${newToken.substring(0, 30)}...');
        debugPrint('[FCM] Old Token: ${_fcmToken?.substring(0, 30) ?? 'null'}...');
        _saveToken(newToken);
        onTokenReceived?.call(newToken);
        _registerTokenToBackend(newToken);
        debugPrint('[FCM] ✅ Token refresh handled successfully');
      });
      
      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      
      // Handle background message tap (when app is in background)
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
      
      // Check if app opened from notification (when app was closed)
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] ========== APP OPENED FROM NOTIFICATION ==========');
        debugPrint('[FCM] Initial message: ${initialMessage.messageId}');
        debugPrint('[FCM] Message data: ${initialMessage.data}');
        
        // Handle message
        _handleMessage(initialMessage);
        
        // For lock commands, ensure overlay shows after app fully loads
        final data = initialMessage.data;
        if (data.containsKey('type') && data['type'] == 'lock_command') {
          debugPrint('[FCM] Lock command in initial message, will show overlay after app loads');
          // Wait for app to fully initialize, then trigger overlay
          Future.delayed(const Duration(milliseconds: 1000), () {
            onLockCommand?.call(data);
          });
        }
      }
    } catch (e) {
      debugPrint('[FCM] Error initializing FCM: $e');
    }
  }
  
  /// Get FCM token
  Future<String?> _getToken() async {
    try {
      debugPrint('[FCM] ========== GETTING FCM TOKEN ==========');
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        debugPrint('[FCM] ✅ FCM Token received successfully');
        debugPrint('[FCM] Token Length: ${_fcmToken!.length}');
        debugPrint('[FCM] Token Preview: ${_fcmToken!.substring(0, 30)}...');
        await _saveToken(_fcmToken!);
        onTokenReceived?.call(_fcmToken!);
        await _registerTokenToBackend(_fcmToken!);
      } else {
        debugPrint('[FCM] ⚠️ WARNING: FCM Token is null');
      }
      return _fcmToken;
    } catch (e, stackTrace) {
      debugPrint('[FCM] ❌ ERROR: Error getting FCM token: $e');
      debugPrint('[FCM] Stack Trace: $stackTrace');
      return null;
    }
  }
  
  /// Save token locally
  Future<void> _saveToken(String token) async {
    _fcmToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }
  
  /// Get stored token
  Future<String?> getStoredToken() async {
    if (_fcmToken != null) return _fcmToken;
    final prefs = await SharedPreferences.getInstance();
    _fcmToken = prefs.getString(_tokenKey);
    return _fcmToken;
  }
  
  /// Register FCM token to backend
  Future<void> _registerTokenToBackend(String token) async {
    try {
      debugPrint('[FCM_REGISTRATION] ========== STARTING TOKEN REGISTRATION ==========');
      debugPrint('[FCM_REGISTRATION] FCM Token: ${token.substring(0, 20)}...');
      
      final authToken = await _authService.getAuthToken();
      if (authToken == null || authToken.isEmpty) {
        debugPrint('[FCM_REGISTRATION] ❌ ERROR: User not authenticated');
        debugPrint('[FCM_REGISTRATION] Token registration skipped. Will retry after login.');
        return;
      }
      
      debugPrint('[FCM_REGISTRATION] ✅ Auth token found');
      debugPrint('[FCM_REGISTRATION] API Endpoint: ${ApiConfig.registerFcmToken}');
      
      final uri = Uri.parse(ApiConfig.registerFcmToken);
      final requestBody = jsonEncode({
        'fcmToken': token,
      });
      
      debugPrint('[FCM_REGISTRATION] Request Body: $requestBody');
      debugPrint('[FCM_REGISTRATION] Sending POST request...');
      
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: requestBody,
      );
      
      debugPrint('[FCM_REGISTRATION] Response Status Code: ${response.statusCode}');
      debugPrint('[FCM_REGISTRATION] Response Body: ${response.body}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        try {
          final responseData = jsonDecode(response.body) as Map<String, dynamic>;
          debugPrint('[FCM_REGISTRATION] ✅ SUCCESS: Token registered to backend');
          debugPrint('[FCM_REGISTRATION] Response Data: $responseData');
          
          if (responseData.containsKey('data')) {
            final data = responseData['data'] as Map<String, dynamic>?;
            if (data != null && data.containsKey('fcmToken')) {
              debugPrint('[FCM_REGISTRATION] Registered Token: ${data['fcmToken']}');
            }
          }
        } catch (e) {
          debugPrint('[FCM_REGISTRATION] ⚠️ WARNING: Success but failed to parse response: $e');
          debugPrint('[FCM_REGISTRATION] Raw Response: ${response.body}');
        }
      } else {
        debugPrint('[FCM_REGISTRATION] ❌ FAILED: Token registration failed');
        debugPrint('[FCM_REGISTRATION] Status Code: ${response.statusCode}');
        debugPrint('[FCM_REGISTRATION] Error Response: ${response.body}');
        
        try {
          final errorData = jsonDecode(response.body) as Map<String, dynamic>;
          if (errorData.containsKey('message')) {
            debugPrint('[FCM_REGISTRATION] Error Message: ${errorData['message']}');
          }
        } catch (e) {
          debugPrint('[FCM_REGISTRATION] Could not parse error response');
        }
      }
      
      debugPrint('[FCM_REGISTRATION] ========== TOKEN REGISTRATION COMPLETE ==========');
    } catch (e, stackTrace) {
      debugPrint('[FCM_REGISTRATION] ❌ EXCEPTION: Error registering token to backend');
      debugPrint('[FCM_REGISTRATION] Error: $e');
      debugPrint('[FCM_REGISTRATION] Stack Trace: $stackTrace');
    }
  }
  
  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] ========== FOREGROUND MESSAGE RECEIVED ==========');
    debugPrint('[FCM] Message ID: ${message.messageId}');
    debugPrint('[FCM] Message data: ${message.data}');
    
    final data = message.data;
    final type = data['type'] as String?;
    
    // For lock commands, show high-priority notification that opens app
    if (type == 'lock_command') {
      debugPrint('[FCM] Lock command in foreground - showing high-priority notification');
      
      // Show notification that will open app
      await _showLockNotification(message);
      
      // Also handle message immediately
      _handleMessage(message);
      
      // Trigger overlay after short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        onLockCommand?.call(data);
      });
    } else {
      // Handle other messages normally
      _handleMessage(message);
    }
  }
  
  /// Show high-priority notification for lock command
  Future<void> _showLockNotification(RemoteMessage message) async {
    try {
      final data = message.data;
      final title = message.notification?.title ?? 'Device Lock Required';
      final body = message.notification?.body ?? 
                   data['reason'] as String? ?? 
                   'Your device needs to be locked due to overdue EMI';
      
      final androidDetails = AndroidNotificationDetails(
        'device_lock_channel',
        'Device Lock Notifications',
        channelDescription: 'Critical notifications for device lock commands',
        importance: Importance.max, // Maximum importance
        priority: Priority.max, // Maximum priority
        showWhen: true,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true, // Auto-open app
        autoCancel: false, // Don't auto-cancel
        ongoing: true, // Ongoing notification
        styleInformation: BigTextStyleInformation(body, contentTitle: title),
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
      
      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        notificationDetails,
        payload: jsonEncode(data),
      );
      
      debugPrint('[FCM] ✅ High-priority lock notification shown');
    } catch (e) {
      debugPrint('[FCM] ❌ Error showing lock notification: $e');
    }
  }
  
  /// Handle message tap (when app is in background)
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('[FCM] ========== MESSAGE TAPPED (APP OPENED FROM NOTIFICATION) ==========');
    debugPrint('[FCM] Message ID: ${message.messageId}');
    debugPrint('[FCM] Message data: ${message.data}');
    
    // Handle message immediately
    _handleMessage(message);
    
    // For lock commands, ensure overlay shows after app opens
    final data = message.data;
    if (data.containsKey('type') && data['type'] == 'lock_command') {
      debugPrint('[FCM] Lock command detected, will show overlay when app opens');
      // The overlay will be shown by AppOverlayService when context is available
      // We'll trigger it after a short delay to ensure app is fully loaded
      Future.delayed(const Duration(milliseconds: 500), () {
        onLockCommand?.call(data);
      });
    }
  }
  
  /// Handle FCM message
  void _handleMessage(RemoteMessage message) {
    final data = message.data;
    
    if (data.containsKey('type')) {
      final type = data['type'] as String;
      debugPrint('[FCM] Message type: $type');
      
      switch (type) {
        case 'lock_command':
          _handleLockCommand(data);
          break;
        case 'unlock_command':
          // Handle unlock immediately
          _handleUnlockCommand(data);
          // Also trigger callback to ensure overlay service gets notified
          if (onUnlockCommand != null) {
            debugPrint('[FCM] Also calling unlock callback directly from _handleMessage');
            onUnlockCommand!(data);
          }
          break;
        case 'extend_payment':
          _handleExtendPayment(data);
          break;
        default:
          debugPrint('[FCM] Unknown message type: $type');
      }
    }
  }
  
  /// Handle lock command
  void _handleLockCommand(Map<String, dynamic> data) async {
    debugPrint('[FCM] Lock command received');
    
    // Store lock status
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockStatusKey, true);
    
    if (data.containsKey('emiId')) {
      await prefs.setString(_lockEmiIdKey, data['emiId'] as String);
    }
    
    // Notify overlay service
    onLockCommand?.call(data);
  }
  
  /// Handle unlock command
  void _handleUnlockCommand(Map<String, dynamic> data) async {
    debugPrint('[FCM] ========== UNLOCK COMMAND RECEIVED ==========');
    debugPrint('[FCM] Unlock command data: $data');
    
    try {
      // Clear lock status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_lockStatusKey, false);
      await prefs.remove(_lockEmiIdKey);
      await prefs.remove(_unlockUntilKey);
      debugPrint('[FCM] ✅ Lock status cleared in FCM service');
      
      // Notify overlay service immediately
      debugPrint('[FCM] Calling onUnlockCommand callback...');
      if (onUnlockCommand != null) {
        onUnlockCommand!(data);
        debugPrint('[FCM] ✅ Unlock callback called');
      } else {
        debugPrint('[FCM] ⚠️ WARNING: onUnlockCommand callback is null!');
      }
    } catch (e, stackTrace) {
      debugPrint('[FCM] ❌ EXCEPTION: Error handling unlock command: $e');
      debugPrint('[FCM] Stack Trace: $stackTrace');
    }
  }
  
  /// Handle extend payment command
  void _handleExtendPayment(Map<String, dynamic> data) async {
    debugPrint('[FCM] Extend payment command received');
    
    final prefs = await SharedPreferences.getInstance();
    
    // Calculate unlock until date
    int? days;
    if (data.containsKey('days')) {
      days = (data['days'] as num?)?.toInt();
    } else if (data.containsKey('extendDays')) {
      days = (data['extendDays'] as num?)?.toInt();
    }
    
    if (days != null && days > 0) {
      final unlockUntil = DateTime.now().add(Duration(days: days));
      await prefs.setString(_unlockUntilKey, unlockUntil.toIso8601String());
      debugPrint('[FCM] Device unlocked until: $unlockUntil');
    }
    
    // Temporarily unlock
    await prefs.setBool(_lockStatusKey, false);
    
    // Notify overlay service
    onUnlockCommand?.call(data);
  }
  
  /// Check if device is locked
  Future<bool> isDeviceLocked() async {
    final prefs = await SharedPreferences.getInstance();
    final isLocked = prefs.getBool(_lockStatusKey) ?? false;
    
    if (!isLocked) return false;
    
    // Check if unlock period has expired
    final unlockUntilStr = prefs.getString(_unlockUntilKey);
    if (unlockUntilStr != null) {
      try {
        final unlockUntil = DateTime.parse(unlockUntilStr);
        if (DateTime.now().isAfter(unlockUntil)) {
          // Unlock period expired, lock again
          await prefs.setBool(_lockStatusKey, true);
          await prefs.remove(_unlockUntilKey);
          return true;
        } else {
          // Still in unlock period
          return false;
        }
      } catch (e) {
        debugPrint('[FCM] Error parsing unlock until date: $e');
      }
    }
    
    return isLocked;
  }
  
  /// Get locked EMI ID
  Future<String?> getLockedEmiId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lockEmiIdKey);
  }
  
  /// Manually unlock device (e.g., after payment verification)
  Future<void> unlockDevice() async {
    debugPrint('[FCM] Manually unlocking device');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lockStatusKey, false);
    await prefs.remove(_lockEmiIdKey);
    await prefs.remove(_unlockUntilKey);
    
    // Notify overlay service
    onUnlockCommand?.call({'type': 'unlock_command', 'reason': 'payment_verified'});
  }
  
  /// Register FCM token after login (public method)
  /// Call this after successful login to register token
  Future<bool> registerTokenAfterLogin() async {
    try {
      debugPrint('[FCM_REGISTRATION] ========== REGISTERING TOKEN AFTER LOGIN ==========');
      
      // Get stored token or get new one
      String? token = await getStoredToken();
      if (token == null) {
        debugPrint('[FCM_REGISTRATION] No stored token, getting new token...');
        token = await _getToken();
      }
      
      if (token == null) {
        debugPrint('[FCM_REGISTRATION] ❌ ERROR: Could not get FCM token');
        return false;
      }
      
      debugPrint('[FCM_REGISTRATION] Token found, registering to backend...');
      await _registerTokenToBackend(token);
      
      return true;
    } catch (e, stackTrace) {
      debugPrint('[FCM_REGISTRATION] ❌ EXCEPTION: Error in registerTokenAfterLogin');
      debugPrint('[FCM_REGISTRATION] Error: $e');
      debugPrint('[FCM_REGISTRATION] Stack Trace: $stackTrace');
      return false;
    }
  }
}





