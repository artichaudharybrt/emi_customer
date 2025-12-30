# FCM Implementation Summary - Device Lock/Unlock Functionality

## ✅ Implementation Complete

FCM (Firebase Cloud Messaging) functionality has been successfully implemented for device lock/unlock based on EMI payment status.

---

## 📋 What Has Been Implemented

### 1. **Firebase Dependencies Added**
   - ✅ `firebase_core: ^2.24.2`
   - ✅ `firebase_messaging: ^14.7.9`
   - ✅ Dependencies installed via `flutter pub get`

### 2. **FCM Service Created** (`lib/services/fcm_service.dart`)
   - ✅ FCM token management
   - ✅ Token registration to backend
   - ✅ Lock command handling
   - ✅ Unlock command handling
   - ✅ Extend payment command handling (temporary unlock)
   - ✅ Device lock status checking
   - ✅ Foreground and background message handling

### 3. **FCM Background Handler** (`lib/services/fcm_background_handler.dart`)
   - ✅ Background message processing
   - ✅ Pending command storage
   - ✅ Command processing on app start

### 4. **AppOverlayService Updated** (`lib/services/app_overlay_service.dart`)
   - ✅ FCM integration
   - ✅ Lock command handling from FCM
   - ✅ Unlock command handling from FCM
   - ✅ Device unlock after payment verification
   - ✅ FCM lock status checking

### 5. **Main.dart Updated** (`lib/main.dart`)
   - ✅ Firebase initialization
   - ✅ FCM service initialization
   - ✅ Background handler registration
   - ✅ Pending command processing

### 6. **Android Configuration**
   - ✅ `android/build.gradle.kts` - Google Services plugin added
   - ✅ `android/app/build.gradle.kts` - Firebase dependencies added
   - ✅ `android/app/src/main/AndroidManifest.xml` - FCM notification channel configured

### 7. **API Configuration** (`lib/config/api_config.dart`)
   - ✅ FCM token registration endpoint added: `/api/users/fcm-token`

### 8. **Payment Integration** (`lib/views/screens/emi_details.dart`)
   - ✅ Device unlock after successful payment verification
   - ✅ Automatic overlay removal after payment

---

## 🔄 How It Works

### **Lock Flow:**
1. Backend detects EMI overdue
2. Backend sends FCM message with `type: "lock_command"` and EMI details
3. App receives FCM message (foreground/background/closed)
4. `FCMService` processes lock command
5. `AppOverlayService` shows screen overlay
6. User cannot use device (overlay blocks all interactions)

### **Unlock Flows:**

#### **A. Manual Unlock (Admin Request):**
1. Admin sends FCM message with `type: "unlock_command"`
2. App receives message
3. `FCMService` processes unlock command
4. `AppOverlayService` hides overlay
5. Device unlocked

#### **B. Extend Payment (Temporary Unlock):**
1. Admin sends FCM message with `type: "extend_payment"` and `days: 2`
2. App receives message
3. `FCMService` unlocks device for specified days
4. After days expire, device locks again automatically

#### **C. Payment Gateway Unlock:**
1. User makes payment via Razorpay
2. Payment verification succeeds
3. `AppOverlayService.unlockDevice()` called automatically
4. Device unlocked immediately
5. Overlay removed

---

## 📱 FCM Message Formats

### **Lock Command:**
```json
{
  "token": "fcm-token-here",
  "data": {
    "type": "lock_command",
    "emiId": "emi-123",
    "reason": "EMI overdue",
    "overdueAmount": "5000",
    "loanNumber": "LOAN-001",
    "borrowerName": "John Doe",
    "userId": "user-123"
  },
  "notification": {
    "title": "Device Locked",
    "body": "Your device has been locked due to overdue EMI payment"
  }
}
```

### **Unlock Command:**
```json
{
  "token": "fcm-token-here",
  "data": {
    "type": "unlock_command",
    "reason": "Payment received / Admin unlock"
  },
  "notification": {
    "title": "Device Unlocked",
    "body": "Your device has been unlocked"
  }
}
```

### **Extend Payment:**
```json
{
  "token": "fcm-token-here",
  "data": {
    "type": "extend_payment",
    "days": 2,
    "reason": "Payment extension granted"
  },
  "notification": {
    "title": "Payment Extended",
    "body": "Your payment deadline has been extended by 2 days"
  }
}
```

---

## ⚠️ Required Setup Steps

### **1. Firebase Project Setup**
   - [ ] Create Firebase project at [Firebase Console](https://console.firebase.google.com/)
   - [ ] Add Android app with package name: `com.rohit.emilockercustomer`
   - [ ] Download `google-services.json`
   - [ ] Place `google-services.json` in `android/app/` directory
   - [ ] Add SHA-1 fingerprint to Firebase (for debug and release)

### **2. Firebase Options (Optional but Recommended)**
   ```bash
   # Install FlutterFire CLI
   dart pub global activate flutterfire_cli
   
   # Configure Firebase
   flutterfire configure
   ```
   This will generate `lib/firebase_options.dart` automatically.

### **3. Backend API Endpoints Required**

#### **A. Register FCM Token:**
```
POST /api/users/fcm-token
Headers: Authorization: Bearer <token>
Body: {
  "fcmToken": "fcm-token-string"
}
```

#### **B. Send Lock Command (Backend Implementation):**
Backend should send FCM message using Firebase Admin SDK when EMI is overdue.

#### **C. Send Unlock Command (Backend Implementation):**
Backend should send FCM message when admin manually unlocks or payment is received.

---

## 🧪 Testing Checklist

- [ ] Firebase project created and configured
- [ ] `google-services.json` added to `android/app/`
- [ ] App builds successfully
- [ ] FCM token received and logged
- [ ] FCM token registered to backend
- [ ] Lock command received (app open)
- [ ] Lock command received (app in background)
- [ ] Lock command received (app closed)
- [ ] Overlay shown when lock command received
- [ ] Unlock command received
- [ ] Overlay hidden when unlock command received
- [ ] Extend payment command received
- [ ] Device unlocks temporarily and re-locks after expiry
- [ ] Payment gateway unlock works
- [ ] Device unlocks immediately after payment verification

---

## 🔧 Backend Implementation Guide

### **Node.js Example:**

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
      emiId: lockData.emiId,
      reason: lockData.reason || 'EMI overdue',
      overdueAmount: lockData.overdueAmount.toString(),
      loanNumber: lockData.loanNumber,
      borrowerName: lockData.borrowerName,
      userId: lockData.userId,
    },
    notification: {
      title: 'Device Locked',
      body: 'Your device has been locked due to overdue EMI payment',
    },
    android: {
      priority: 'high',
      notification: {
        channelId: 'device_lock_channel',
      },
    },
  };
  
  try {
    const response = await admin.messaging().send(message);
    console.log('Lock command sent:', response);
    return response;
  } catch (error) {
    console.error('Error sending lock command:', error);
    throw error;
  }
}

// Send unlock command
async function sendUnlockCommand(fcmToken, reason) {
  const message = {
    token: fcmToken,
    data: {
      type: 'unlock_command',
      reason: reason || 'Payment received',
    },
    notification: {
      title: 'Device Unlocked',
      body: 'Your device has been unlocked',
    },
  };
  
  return await admin.messaging().send(message);
}

// Send extend payment command
async function sendExtendPayment(fcmToken, days, reason) {
  const message = {
    token: fcmToken,
    data: {
      type: 'extend_payment',
      days: days.toString(),
      reason: reason || 'Payment extension granted',
    },
    notification: {
      title: 'Payment Extended',
      body: `Your payment deadline has been extended by ${days} days`,
    },
  };
  
  return await admin.messaging().send(message);
}
```

---

## 📝 Important Notes

1. **Firebase Configuration Required**: The app will not work without `google-services.json` file. Make sure to add it before building.

2. **FCM Token Registration**: The app automatically registers FCM token to backend when:
   - App starts
   - Token is refreshed
   - User logs in

3. **Background Messages**: Background messages are stored and processed when app opens. The overlay will be shown automatically.

4. **Payment Gateway**: When payment is verified successfully, device unlocks immediately without waiting for FCM message.

5. **Extend Payment**: Device unlocks temporarily for specified days. After expiry, it locks again automatically.

6. **Screen Overlay**: The overlay blocks all user interactions. User can only pay or wait for unlock command.

---

## 🐛 Troubleshooting

### **Issue: FCM token not received**
- Check `google-services.json` is in correct location
- Verify SHA-1 fingerprint in Firebase Console
- Check internet connection
- Ensure notification permissions are granted

### **Issue: Messages not received**
- Verify FCM token is correct
- Check backend is using correct token
- Ensure app is not in Doze mode (Android)
- Check notification permissions

### **Issue: Overlay not showing**
- Check FCM lock status in SharedPreferences
- Verify lock command was received
- Check AppOverlayService initialization

### **Issue: Device not unlocking after payment**
- Verify payment verification API returns success
- Check AppOverlayService.unlockDevice() is called
- Verify FCM unlock status is cleared

---

## ✅ Next Steps

1. **Add `google-services.json`** to `android/app/` directory
2. **Configure Firebase** in backend
3. **Test FCM messages** using Firebase Console
4. **Implement backend endpoints** for sending FCM messages
5. **Test all scenarios** (lock, unlock, extend, payment)

---

## 📞 Support

If you encounter any issues, check:
- Firebase Console for message delivery status
- App logs for FCM-related messages (prefixed with `[FCM]`)
- Backend logs for FCM message sending status

---

**Implementation Date**: $(date)
**Status**: ✅ Complete - Ready for Firebase Configuration and Testing






