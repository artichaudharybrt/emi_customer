# FCM Implementation Guide - Device Lock Functionality

## Overview
यह guide Firebase Cloud Messaging (FCM) के through device lock/unlock functionality implement करने के लिए complete requirements और steps है।

---

## 1. Prerequisites & Requirements

### 1.1 Firebase Project Setup
- ✅ Google Account (Firebase Console access)
- ✅ Firebase Project create करना होगा
- ✅ Android app register करना होगा Firebase में
- ✅ iOS app register करना होगा (अगर iOS support चाहिए)

### 1.2 Required Files from Firebase
- ✅ `google-services.json` (Android के लिए)
- ✅ `GoogleService-Info.plist` (iOS के लिए)
- ✅ Server Key / Service Account JSON (Backend के लिए)

---

## 2. Firebase Console Setup Steps

### Step 1: Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project" या existing project select करें
3. Project name enter करें
4. Google Analytics enable/disable (optional)

### Step 2: Add Android App
1. Project में जाएं
2. Click on Android icon
3. Enter package name: `com.rohit.emilockernew` (check your `build.gradle`)
4. App nickname (optional)
5. Download `google-services.json`
6. SHA-1 certificate fingerprint add करें (debug और release दोनों)

### Step 3: Add iOS App (if needed)
1. Click on iOS icon
2. Enter bundle ID
3. Download `GoogleService-Info.plist`

### Step 4: Get Server Key
1. Project Settings → Cloud Messaging tab
2. Copy "Server key" या "Legacy server key"
3. या Service Account JSON download करें (recommended)

---

## 3. Flutter Dependencies

### 3.1 Add to `pubspec.yaml`
```yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Firebase Core (required)
  firebase_core: ^2.24.2
  
  # Firebase Cloud Messaging
  firebase_messaging: ^14.7.9
  
  # For background message handling
  flutter_local_notifications: ^16.3.0
  
  # For device info (device ID generation)
  device_info_plus: ^9.0.2  # Already in your project
  
  # For storing FCM token
  shared_preferences: ^2.2.2  # Already in your project
```

### 3.2 Install Dependencies
```bash
flutter pub get
```

---

## 4. Android Configuration

### 4.1 Files to Add/Modify

#### A. `android/app/build.gradle.kts`
```kotlin
// Add at the top
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")  // ADD THIS
}

dependencies {
    // ... existing dependencies
    
    // Firebase BOM (add this)
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}
```

#### B. `android/build.gradle.kts` (project level)
```kotlin
buildscript {
    dependencies {
        // ... existing dependencies
        classpath("com.google.gms:google-services:4.4.0")  // ADD THIS
    }
}
```

#### C. Add `google-services.json`
- Download from Firebase Console
- Place at: `android/app/google-services.json`

#### D. `android/app/src/main/AndroidManifest.xml`
Add these permissions and services:
```xml
<manifest>
    <!-- Existing permissions -->
    
    <!-- FCM Permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    
    <application>
        <!-- Existing application code -->
        
        <!-- FCM Default Notification Channel -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="device_lock_channel" />
        
        <!-- FCM Service (for background messages) -->
        <service
            android:name="com.rohit.emilockernew.FirebaseMessagingService"
            android:exported="false">
            <intent-filter>
                <action android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>
    </application>
</manifest>
```

#### E. Create `android/app/src/main/kotlin/com/example/emilockernew/FirebaseMessagingService.kt`
```kotlin
package com.rohit.emilockernew

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class FirebaseMessagingService : FirebaseMessagingService() {
    private val CHANNEL = "fcm_messages"
    
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }
    
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        // Handle data messages (lock/unlock commands)
        if (remoteMessage.data.isNotEmpty) {
            sendMessageToFlutter(remoteMessage.data)
        }
        
        // Handle notification messages
        remoteMessage.notification?.let {
            showNotification(it.title ?: "Device Lock", it.body ?: "")
        }
    }
    
    override fun onNewToken(token: String) {
        // Send token to Flutter
        sendTokenToFlutter(token)
    }
    
    private fun sendMessageToFlutter(data: Map<String, String>) {
        // Get Flutter engine and send data
        val flutterEngine = FlutterEngineCache.getInstance().get("main")
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod("onMessage", data)
        }
    }
    
    private fun sendTokenToFlutter(token: String) {
        val flutterEngine = FlutterEngineCache.getInstance().get("main")
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, CHANNEL).invokeMethod("onToken", token)
        }
    }
    
    private fun showNotification(title: String, body: String) {
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        
        val notificationBuilder = NotificationCompat.Builder(this, "device_lock_channel")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
        
        notificationManager.notify(System.currentTimeMillis().toInt(), notificationBuilder.build())
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "device_lock_channel",
                "Device Lock Notifications",
                NotificationManager.IMPORTANCE_HIGH
            )
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
}
```

---

## 5. iOS Configuration (if needed)

### 5.1 Files to Add/Modify

#### A. Add `GoogleService-Info.plist`
- Download from Firebase Console
- Place at: `ios/Runner/GoogleService-Info.plist`
- Add to Xcode project

#### B. `ios/Runner/Info.plist`
Add background modes:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
</array>
```

#### C. Enable Push Notifications in Xcode
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target
3. Signing & Capabilities tab
4. Click "+ Capability"
5. Add "Push Notifications"
6. Add "Background Modes" → Enable "Remote notifications"

#### D. APNs Certificate Setup
1. Apple Developer Account में जाएं
2. Certificates → Create new APNs certificate
3. Upload to Firebase Console → Project Settings → Cloud Messaging

---

## 6. Flutter Implementation Files

### 6.1 New Files to Create

#### A. `lib/services/fcm_service.dart`
```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FCMService {
  static const String _tokenKey = 'fcm_token';
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  String? _fcmToken;
  Function(Map<String, dynamic>)? onLockCommand;
  Function(Map<String, dynamic>)? onUnlockCommand;
  Function(String)? onTokenReceived;
  
  Future<void> initialize() async {
    // Request permission
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }
    
    // Get FCM token
    await _getToken();
    
    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _saveToken(newToken);
      onTokenReceived?.call(newToken);
    });
    
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    
    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
    
    // Check if app opened from notification
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }
  }
  
  Future<String?> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
        await _saveToken(_fcmToken!);
        onTokenReceived?.call(_fcmToken!);
      }
      return _fcmToken;
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }
  
  Future<void> _saveToken(String token) async {
    _fcmToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }
  
  Future<String?> getStoredToken() async {
    if (_fcmToken != null) return _fcmToken;
    final prefs = await SharedPreferences.getInstance();
    _fcmToken = prefs.getString(_tokenKey);
    return _fcmToken;
  }
  
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Foreground message received: ${message.messageId}');
    _handleMessage(message);
  }
  
  void _handleMessageTap(RemoteMessage message) {
    debugPrint('Message tapped: ${message.messageId}');
    _handleMessage(message);
  }
  
  void _handleMessage(RemoteMessage message) {
    final data = message.data;
    
    if (data.containsKey('type')) {
      final type = data['type'] as String;
      
      switch (type) {
        case 'lock_command':
          onLockCommand?.call(data);
          break;
        case 'unlock_command':
          onUnlockCommand?.call(data);
          break;
        case 'state_check':
          // Handle state check request
          break;
        default:
          debugPrint('Unknown message type: $type');
      }
    }
  }
  
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
  }
  
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
  }
}
```

#### B. `lib/services/fcm_background_handler.dart`
```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// This must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background message received: ${message.messageId}');
  
  // Handle background message
  // Note: You can't use UI or call LockerState directly here
  // Store message and process when app opens
  
  final data = message.data;
  if (data.containsKey('type')) {
    final type = data['type'] as String;
    debugPrint('Background message type: $type');
    
    // You can save to SharedPreferences here
    // App will read when it opens
  }
}
```

#### C. Update `lib/main.dart`
```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/fcm_background_handler.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Register background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize FCM Service
  final fcmService = FCMService();
  await fcmService.initialize();
  
  runApp(MyApp(fcmService: fcmService));
}
```

#### D. Update `lib/state/locker_state.dart`
Add FCM integration:
```dart
class LockerState extends ChangeNotifier {
  final FCMService _fcmService;
  
  LockerState(this._backend, this._fcmService) {
    _bootstrap();
    _setupFCMListeners();
  }
  
  void _setupFCMListeners() {
    _fcmService.onLockCommand = (data) {
      _handleLockCommand(data);
    };
    
    _fcmService.onUnlockCommand = (data) {
      _handleUnlockCommand(data);
    };
  }
  
  Future<void> _handleLockCommand(Map<String, dynamic> data) async {
    final snapshot = LockSnapshot(
      lockStatus: LockStatus.locked,
      loanSummary: LoanSummary(
        customerName: data['borrowerName'] ?? 'Customer',
        loanNumber: data['loanNumber'] ?? '--',
        overdueAmount: (data['overdueAmount'] as num?)?.toDouble() ?? 0.0,
      ),
      lockReason: data['reason'] ?? 'EMI overdue',
      lastUpdatedAt: DateTime.now(),
    );
    
    await _applySnapshot(snapshot);
  }
  
  Future<void> _handleUnlockCommand(Map<String, dynamic> data) async {
    if (loanSummary == null) return;
    
    final snapshot = LockSnapshot(
      lockStatus: LockStatus.unlocked,
      loanSummary: loanSummary!,
      lockReason: null,
      lastUpdatedAt: DateTime.now(),
    );
    
    await _applySnapshot(snapshot);
  }
}
```

---

## 7. Backend Requirements

### 7.1 FCM Server Setup
Backend में FCM Admin SDK install करना होगा:

**Node.js:**
```bash
npm install firebase-admin
```

**Python:**
```bash
pip install firebase-admin
```

### 7.2 Backend Service Account
1. Firebase Console → Project Settings → Service Accounts
2. "Generate new private key" click करें
3. JSON file download करें
4. Backend में use करें

### 7.3 Backend API to Send FCM Messages

**Example (Node.js):**
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./path/to/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// Send lock command
async function sendLockCommand(fcmToken, lockData) {
  const message = {
    token: fcmToken,
    data: {
      type: 'lock_command',
      reason: lockData.reason || 'EMI overdue',
      emiId: lockData.emiId,
      overdueAmount: lockData.overdueAmount.toString(),
      loanNumber: lockData.loanNumber,
      borrowerName: lockData.borrowerName,
    },
    notification: {
      title: 'Device Locked',
      body: 'Your device has been locked due to overdue EMI payment',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'device_lock_channel',
        sound: 'default',
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
      },
      payload: {
        aps: {
          sound: 'default',
        },
      },
    },
  };
  
  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
    return response;
  } catch (error) {
    console.error('Error sending message:', error);
    throw error;
  }
}

// Send unlock command
async function sendUnlockCommand(fcmToken, unlockData) {
  const message = {
    token: fcmToken,
    data: {
      type: 'unlock_command',
      reason: unlockData.reason || 'Payment received',
    },
    notification: {
      title: 'Device Unlocked',
      body: 'Your device has been unlocked',
    },
  };
  
  return await admin.messaging().send(message);
}
```

### 7.4 Backend Endpoints Needed

1. **Register FCM Token**
```
POST /api/devices/{deviceId}/fcm-token
Body: { "fcmToken": "token-here" }
```

2. **Send Lock Command** (Internal/Admin only)
```
POST /api/devices/{deviceId}/send-lock-command
Body: { 
  "reason": "EMI overdue",
  "emiId": "emi-123",
  ...
}
```

3. **Send Unlock Command** (Internal/Admin only)
```
POST /api/devices/{deviceId}/send-unlock-command
Body: { "reason": "Payment received" }
```

---

## 8. Message Format

### 8.1 Lock Command Message
```json
{
  "token": "fcm-token-here",
  "data": {
    "type": "lock_command",
    "reason": "EMI overdue",
    "emiId": "emi-123",
    "overdueAmount": "5000",
    "loanNumber": "LOAN-001",
    "borrowerName": "John Doe",
    "commandId": "cmd-123",
    "timestamp": "2024-01-15T10:30:00Z"
  },
  "notification": {
    "title": "Device Locked",
    "body": "Your device has been locked due to overdue EMI payment"
  }
}
```

### 8.2 Unlock Command Message
```json
{
  "token": "fcm-token-here",
  "data": {
    "type": "unlock_command",
    "reason": "Payment received",
    "commandId": "cmd-124",
    "timestamp": "2024-01-15T10:30:00Z"
  },
  "notification": {
    "title": "Device Unlocked",
    "body": "Your device has been unlocked"
  }
}
```

### 8.3 State Check Request
```json
{
  "token": "fcm-token-here",
  "data": {
    "type": "state_check",
    "requestId": "req-123",
    "timestamp": "2024-01-15T10:30:00Z"
  }
}
```

---

## 9. Testing Requirements

### 9.1 Test Devices
- Real Android device (emulator में FCM properly work नहीं करता)
- Real iOS device (simulator में push notifications नहीं आते)

### 9.2 Testing Tools
- Firebase Console → Cloud Messaging → "Send test message"
- Postman/curl से backend API test करें
- FCM token verify करें

### 9.3 Test Scenarios
1. ✅ App open - Lock command receive
2. ✅ App in background - Lock command receive
3. ✅ App closed - Lock command receive (notification tap)
4. ✅ Unlock command receive
5. ✅ Token refresh
6. ✅ Multiple rapid commands
7. ✅ Invalid token handling

---

## 10. Checklist

### Firebase Setup
- [ ] Firebase project created
- [ ] Android app registered
- [ ] iOS app registered (if needed)
- [ ] `google-services.json` downloaded
- [ ] `GoogleService-Info.plist` downloaded (iOS)
- [ ] Server key/Service account obtained

### Android Configuration
- [ ] `google-services.json` added to `android/app/`
- [ ] `build.gradle.kts` updated with Google Services plugin
- [ ] `AndroidManifest.xml` updated with permissions
- [ ] `FirebaseMessagingService.kt` created
- [ ] SHA-1 fingerprint added to Firebase

### iOS Configuration (if needed)
- [ ] `GoogleService-Info.plist` added
- [ ] Push Notifications capability enabled
- [ ] APNs certificate uploaded to Firebase
- [ ] Background modes configured

### Flutter Implementation
- [ ] Dependencies added to `pubspec.yaml`
- [ ] `FCMService` created
- [ ] Background handler registered
- [ ] `main.dart` updated
- [ ] `LockerState` integrated with FCM
- [ ] FCM token stored and sent to backend

### Backend Integration
- [ ] FCM Admin SDK installed
- [ ] Service account configured
- [ ] Token registration endpoint
- [ ] Lock command sending logic
- [ ] Unlock command sending logic

### Testing
- [ ] FCM token received
- [ ] Lock command tested
- [ ] Unlock command tested
- [ ] Background message handling tested
- [ ] Notification tap handling tested

---

## 11. Common Issues & Solutions

### Issue 1: Token not received
**Solution:**
- Check `google-services.json` is in correct location
- Verify SHA-1 fingerprint in Firebase
- Check internet connection
- Ensure app has notification permission

### Issue 2: Messages not received
**Solution:**
- Verify FCM token is correct
- Check backend is using correct token
- Ensure app is not in Doze mode (Android)
- Check notification permissions

### Issue 3: Background messages not handled
**Solution:**
- Ensure background handler is top-level function
- Check `@pragma('vm:entry-point')` annotation
- Verify handler is registered in `main()`

### Issue 4: iOS notifications not working
**Solution:**
- Verify APNs certificate in Firebase
- Check Push Notifications capability enabled
- Ensure device is registered with APNs
- Test on real device (not simulator)

---

## 12. Next Steps

1. ✅ Firebase project setup करें
2. ✅ `google-services.json` download करें
3. ✅ Dependencies add करें
4. ✅ Android configuration complete करें
5. ✅ FCM Service implement करें
6. ✅ Backend integration करें
7. ✅ Testing करें

---

## Questions?

अगर कोई confusion है या help चाहिए, तो बताइए। मैं step-by-step guide कर सकता हूं।

