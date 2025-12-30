# FCM Device Lock/Unlock Flow Diagram

## 📱 Complete Flow - Phone Lock/Unlock Functionality

---

## 🔒 **SCENARIO 1: DEVICE LOCK FLOW (EMI Overdue)**

```
┌─────────────────────────────────────────────────────────────────┐
│                    BACKEND DETECTS EMI OVERDUE                 │
│  - Backend checks EMI due dates                                 │
│  - Finds overdue EMI for user                                   │
│  - Gets user's FCM token from database                          │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              BACKEND SENDS FCM LOCK COMMAND                     │
│  Message Type: "lock_command"                                   │
│  Data: {                                                        │
│    type: "lock_command",                                        │
│    emiId: "emi-123",                                            │
│    reason: "EMI overdue",                                       │
│    overdueAmount: "5000",                                       │
│    loanNumber: "LOAN-001",                                      │
│    borrowerName: "John Doe"                                     │
│  }                                                              │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │   APP STATE: FOREGROUND / BACKGROUND   │
        │            / CLOSED                     │
        └───────┬───────────────┬───────────────┘
                │               │               │
                ▼               ▼               ▼
    ┌───────────────┐  ┌───────────────┐  ┌───────────────┐
    │  APP OPEN     │  │ APP BACKGROUND│  │  APP CLOSED   │
    │  (Foreground) │  │               │  │               │
    └───────┬───────┘  └───────┬───────┘  └───────┬───────┘
            │                  │                   │
            │                  │                   │
            ▼                  ▼                   ▼
    ┌──────────────────────────────────────────────────────┐
    │  FCMService._handleForegroundMessage()               │
    │  OR                                                   │
    │  FCMService._handleMessageTap()                      │
    │  OR                                                   │
    │  firebaseMessagingBackgroundHandler()                │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  FCMService._handleLockCommand()                      │
    │  - Store lock status in SharedPreferences              │
    │  - Save EMI ID                                        │
    │  - Set overlay_active = true                          │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService._handleFcmLockCommand()            │
    │  - Receives lock command data                         │
    │  - Stores overlay state                              │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService.checkAndShowOverlay()              │
    │  - Checks FCM lock status                             │
    │  - Fetches EMI details                                │
    │  - Creates overlay entry                              │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService.showOverlay()                      │
    │  - Creates EmiOverlayWidget                         │
    │  - Inserts overlay entry                              │
    │  - Blocks all user interactions                       │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │           📱 DEVICE LOCKED - OVERLAY SHOWN             │
    │  - User cannot use device                             │
    │  - Screen overlay blocks all interactions             │
    │  - Only "Pay Now" button visible                      │
    └──────────────────────────────────────────────────────┘
```

---

## 🔓 **SCENARIO 2: MANUAL UNLOCK FLOW (Admin Request)**

```
┌─────────────────────────────────────────────────────────────────┐
│                    ADMIN SENDS UNLOCK COMMAND                   │
│  - Admin manually unlocks device via backend                   │
│  - Backend gets user's FCM token                              │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              BACKEND SENDS FCM UNLOCK COMMAND                    │
│  Message Type: "unlock_command"                                 │
│  Data: {                                                        │
│    type: "unlock_command",                                      │
│    reason: "Admin unlock / Payment received"                    │
│  }                                                              │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
        ┌───────────────────────────────────────┐
        │   APP STATE: FOREGROUND / BACKGROUND   │
        │            / CLOSED                     │
        └───────┬───────────────┬───────────────┘
                │               │               │
                ▼               ▼               ▼
    ┌──────────────────────────────────────────────────────┐
    │  FCMService receives unlock command                   │
    │  - _handleForegroundMessage()                        │
    │  - _handleMessageTap()                                │
    │  - firebaseMessagingBackgroundHandler()               │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  FCMService._handleUnlockCommand()                   │
    │  - Clear lock status from SharedPreferences           │
    │  - Remove EMI ID                                      │
    │  - Remove unlock_until date                           │
    │  - Set overlay_active = false                         │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService._handleFcmUnlockCommand()         │
    │  - Receives unlock command                            │
    │  - Calls hideOverlay()                                │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService.hideOverlay()                      │
    │  - Removes overlay entry                               │
    │  - Clears stored state                                 │
    │  - Sets _isShowing = false                            │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │           📱 DEVICE UNLOCKED - OVERLAY REMOVED         │
    │  - User can use device normally                        │
    │  - All functionality restored                          │
    └──────────────────────────────────────────────────────┘
```

---

## ⏰ **SCENARIO 3: EXTEND PAYMENT FLOW (Temporary Unlock)**

```
┌─────────────────────────────────────────────────────────────────┐
│              ADMIN GRANTS PAYMENT EXTENSION                      │
│  - Admin extends payment deadline (e.g., 2 days)                │
│  - Backend gets user's FCM token                                │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│          BACKEND SENDS FCM EXTEND PAYMENT COMMAND               │
│  Message Type: "extend_payment"                                 │
│  Data: {                                                        │
│    type: "extend_payment",                                      │
│    days: "2",                                                    │
│    reason: "Payment extension granted"                           │
│  }                                                              │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
    ┌──────────────────────────────────────────────────────┐
    │  FCMService receives extend payment command           │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  FCMService._handleExtendPayment()                     │
    │  - Calculate unlock_until date                        │
    │    (current date + days)                              │
    │  - Store unlock_until in SharedPreferences             │
    │  - Set overlay_active = false (temporary unlock)      │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService._handleFcmUnlockCommand()          │
    │  - Hides overlay                                       │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │           📱 DEVICE TEMPORARILY UNLOCKED               │
    │  - User can use device for 2 days                     │
    │  - Overlay removed                                    │
    └───────────────────────────┬──────────────────────────┘
                                │
                                │ (After 2 days)
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService.checkAndShowOverlay()              │
    │  - Checks FCMService.isDeviceLocked()                │
    │  - Compares current date with unlock_until            │
    │  - If expired, locks again                            │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │           📱 DEVICE RE-LOCKED (Extension Expired)       │
    │  - Overlay shown again                                 │
    │  - User must pay or get another extension              │
    └──────────────────────────────────────────────────────┘
```

---

## 💳 **SCENARIO 4: PAYMENT GATEWAY UNLOCK FLOW**

```
┌─────────────────────────────────────────────────────────────────┐
│                    USER CLICKS "PAY NOW"                        │
│  - User taps Pay Now button on overlay                          │
│  - Overlay hides temporarily                                   │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
    ┌──────────────────────────────────────────────────────┐
    │  Navigate to EMI Details Screen                       │
    │  - User selects payment method                        │
    │  - User chooses Razorpay payment                       │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  PaymentService.createRazorpayOrder()                 │
    │  - Creates Razorpay order via backend                 │
    │  - Gets order ID and amount                            │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  Razorpay Payment Gateway Opens                        │
    │  - User enters payment details                         │
    │  - User completes payment                              │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  Razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS)          │
    │  - Payment success callback triggered                 │
    │  - Receives payment ID, order ID, signature          │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  _handlePaymentSuccess()                              │
    │  - Validates payment details                          │
    │  - Shows loading dialog                               │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  PaymentService.verifyRazorpayPayment()              │
    │  - Sends payment details to backend                    │
    │  - Backend verifies with Razorpay                    │
    │  - Backend confirms payment                            │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │  Verification Result   │
                    └───────┬───────────────┘
                            │
            ┌───────────────┴───────────────┐
            │                               │
            ▼                               ▼
    ┌───────────────┐              ┌───────────────┐
    │   SUCCESS     │              │    FAILED     │
    └───────┬───────┘              └───────┬───────┘
            │                               │
            │                               ▼
            │                      ┌──────────────────────┐
            │                      │ Show Error Message   │
            │                      │ Payment Failed       │
            │                      └──────────────────────┘
            │
            ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService.unlockDevice()                     │
    │  - Called automatically after successful verification │
    │  - Clears lock status                                 │
    │  - Removes overlay                                    │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  FCMService.unlockDevice()                            │
    │  - Sets overlay_active = false                        │
    │  - Removes EMI ID                                     │
    │  - Clears unlock_until                                │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService.hideOverlay()                      │
    │  - Removes overlay entry                              │
    │  - Clears stored state                                │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │           📱 DEVICE UNLOCKED - PAYMENT SUCCESS         │
    │  - Payment verified successfully                      │
    │  - Device unlocked immediately                         │
    │  - User can use device normally                        │
    └──────────────────────────────────────────────────────┘
```

---

## 🔄 **APP STARTUP FLOW (Check Lock Status)**

```
┌─────────────────────────────────────────────────────────────────┐
│                    APP STARTS / RESUMES                          │
│  - User opens app                                                │
│  - App comes to foreground                                       │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
    ┌──────────────────────────────────────────────────────┐
    │  main() Function                                      │
    │  - Firebase.initializeApp()                           │
    │  - FCMService.initialize()                            │
    │  - processPendingFcmCommands()                        │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService.checkOnAppStart()                  │
    │  - Checks FCM lock status                             │
    │  - Checks stored overlay state                         │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  FCMService.isDeviceLocked()                          │
    │  - Checks SharedPreferences for lock status            │
    │  - Checks unlock_until date                           │
    │  - Returns true if locked                             │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
                    ┌───────────────────────┐
                    │  Is Device Locked?     │
                    └───────┬───────────────┘
                            │
            ┌───────────────┴───────────────┐
            │                               │
            ▼                               ▼
    ┌───────────────┐              ┌───────────────┐
    │     YES        │              │      NO      │
    └───────┬───────┘              └───────┬───────┘
            │                               │
            │                               ▼
            │                      ┌──────────────────────┐
            │                      │ App Runs Normally     │
            │                      │ No Overlay Shown      │
            │                      └──────────────────────┘
            │
            ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService.checkAndShowOverlay()             │
    │  - Fetches EMI details                                │
    │  - Creates overlay                                    │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  AppOverlayService.showOverlay()                     │
    │  - Shows screen overlay                               │
    │  - Blocks device usage                                │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │           📱 DEVICE LOCKED - OVERLAY SHOWN             │
    │  - User must pay or wait for unlock                    │
    └──────────────────────────────────────────────────────┘
```

---

## 🔑 **FCM TOKEN REGISTRATION FLOW**

```
┌─────────────────────────────────────────────────────────────────┐
│                    APP INITIALIZATION                           │
│  - App starts for first time                                   │
│  - User logs in                                                │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
    ┌──────────────────────────────────────────────────────┐
    │  FCMService.initialize()                              │
    │  - Requests notification permission                   │
    │  - Gets FCM token from Firebase                       │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  FCMService._getToken()                                │
    │  - Calls FirebaseMessaging.instance.getToken()        │
    │  - Receives unique FCM token                            │
    │  - Saves token locally                                │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  FCMService._registerTokenToBackend()                 │
    │  - Sends token to backend API                         │
    │  - POST /api/users/fcm-token                           │
    │  - Backend stores token in database                   │
    └───────────────────────────┬──────────────────────────┘
                                │
                                ▼
    ┌──────────────────────────────────────────────────────┐
    │  Token Refresh Listener                               │
    │  - Listens for token refresh events                   │
    │  - Automatically re-registers new token               │
    └──────────────────────────────────────────────────────┘
```

---

## 📊 **COMPLETE STATE DIAGRAM**

```
                    ┌─────────────────┐
                    │   DEVICE FREE   │
                    │  (Normal State)  │
                    └────────┬─────────┘
                             │
                             │ EMI Overdue
                             │ FCM Lock Command
                             ▼
                    ┌─────────────────┐
                    │  DEVICE LOCKED  │
                    │  Overlay Shown  │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ Manual Unlock │  │ Extend Payment│  │ Payment Made  │
│ (Admin FCM)   │  │ (Admin FCM)   │  │ (Razorpay)    │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                  │                   │
        │                  │                   │
        └──────────────────┼───────────────────┘
                           │
                           │ All lead to unlock
                           ▼
                    ┌─────────────────┐
                    │  DEVICE UNLOCKED │
                    │  Overlay Removed │
                    └────────┬─────────┘
                             │
                             │ (If extend payment)
                             │ After days expire
                             ▼
                    ┌─────────────────┐
                    │  DEVICE LOCKED  │
                    │  (Re-locked)    │
                    └─────────────────┘
```

---

## 🎯 **KEY COMPONENTS & THEIR ROLES**

### **1. FCMService** (`lib/services/fcm_service.dart`)
- ✅ Receives FCM messages
- ✅ Manages FCM token
- ✅ Registers token to backend
- ✅ Handles lock/unlock commands
- ✅ Stores lock status in SharedPreferences

### **2. AppOverlayService** (`lib/services/app_overlay_service.dart`)
- ✅ Shows/hides screen overlay
- ✅ Integrates with FCM commands
- ✅ Manages overlay state
- ✅ Unlocks device after payment

### **3. FCM Background Handler** (`lib/services/fcm_background_handler.dart`)
- ✅ Processes background messages
- ✅ Stores pending commands
- ✅ Processes commands when app opens

### **4. Payment Service** (`lib/services/payment_service.dart`)
- ✅ Creates Razorpay orders
- ✅ Verifies payments
- ✅ Triggers device unlock

### **5. Main.dart**
- ✅ Initializes Firebase
- ✅ Initializes FCM Service
- ✅ Registers background handler
- ✅ Processes pending commands

---

## 📝 **IMPORTANT NOTES**

1. **Lock Status Storage**: Uses SharedPreferences to persist lock state
2. **Background Messages**: Stored and processed when app opens
3. **Token Refresh**: Automatically handled and re-registered
4. **Payment Unlock**: Immediate unlock without waiting for FCM
5. **Extend Payment**: Temporary unlock with automatic re-lock
6. **Overlay Blocking**: Complete device blocking when overlay is shown

---

**यह flow diagram सभी scenarios को cover करता है जो code में implement किए गए हैं।**





