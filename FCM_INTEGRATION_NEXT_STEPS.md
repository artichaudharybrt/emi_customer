# FCM Integration - Next Steps Guide

## ✅ **Current Status**

FCM token registration API has been successfully integrated with detailed logging!

---

## 🔧 **What Has Been Implemented**

### **1. FCM Token Registration API Integration**
- ✅ API endpoint configured: `POST /api/users/fcm-token`
- ✅ Automatic token registration after login
- ✅ Token registration on token refresh
- ✅ Comprehensive logging for debugging

### **2. Enhanced Logging**
- ✅ Detailed logs for token registration process
- ✅ Request/Response logging
- ✅ Error handling with stack traces
- ✅ Success/failure status logging

### **3. Login Integration**
- ✅ FCM token registration after email/password login
- ✅ FCM token registration after Google sign-in
- ✅ Non-blocking (login continues even if FCM fails)

---

## 📋 **Next Steps**

### **Step 1: Update Backend URL (If Different)**

Check your backend URL in `lib/config/api_config.dart`:

```dart
static const String baseUrl = 'http://192.168.31.70:3050/api';
```

**If your backend runs on different port (e.g., 5000), update it:**

```dart
static const String baseUrl = 'http://192.168.31.70:5000/api';
```

Or if using different IP:
```dart
static const String baseUrl = 'http://YOUR_IP:5000/api';
```

---

### **Step 2: Add Firebase Configuration**

#### **A. Download `google-services.json`**
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Project Settings → Your apps
4. Click on Android app
5. Download `google-services.json`

#### **B. Place File**
Place `google-services.json` in:
```
android/app/google-services.json
```

#### **C. Add SHA-1 Certificate**
1. In Firebase Console → Project Settings → Your apps
2. Click on your Android app
3. Click "Add fingerprint"
4. Add your SHA-1: `5A:AE:A1:B7:AC:24:C2:4D:EA:E3:97:55:8A:1D:3F:FD:3B:97:F6:E0`
5. Download updated `google-services.json` again

---

### **Step 3: Test FCM Token Registration**

#### **A. Run the App**
```bash
flutter run
```

#### **B. Check Logs**
Look for these log messages:

**On App Start:**
```
[FCM] ========== GETTING FCM TOKEN ==========
[FCM] ✅ FCM Token received successfully
[FCM_REGISTRATION] ========== STARTING TOKEN REGISTRATION ==========
```

**After Login:**
```
[Login] Registering FCM token after login...
[FCM_REGISTRATION] ✅ Auth token found
[FCM_REGISTRATION] Sending POST request...
[FCM_REGISTRATION] Response Status Code: 200
[FCM_REGISTRATION] ✅ SUCCESS: Token registered to backend
```

#### **C. Verify in Backend**
Check your backend logs/database to confirm:
- FCM token is received
- Token is stored in database
- User ID is linked correctly

---

### **Step 4: Test FCM Messages**

#### **A. Test Lock Command**

**Using Firebase Console:**
1. Go to Firebase Console → Cloud Messaging
2. Click "Send test message"
3. Enter FCM token (from app logs)
4. Add notification:
   - Title: "Device Locked"
   - Body: "Your device has been locked"
5. Add custom data:
   ```
   type: lock_command
   emiId: test-emi-123
   reason: EMI overdue
   overdueAmount: 5000
   loanNumber: LOAN-001
   borrowerName: Test User
   ```
6. Send message

**Expected Result:**
- App should show overlay
- Device should be locked
- Check logs for lock command received

#### **B. Test Unlock Command**

Send FCM message with:
```
type: unlock_command
reason: Payment received
```

**Expected Result:**
- Overlay should disappear
- Device should unlock
- Check logs for unlock command

---

### **Step 5: Backend Integration Testing**

#### **Test API Endpoint Manually:**

```bash
# Replace YOUR_TOKEN_HERE with actual auth token
# Replace FCM_TOKEN_HERE with actual FCM token from app

curl -X POST "http://localhost:5000/api/users/fcm-token" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -H "Content-Type: application/json" \
  -d '{
    "fcmToken": "FCM_TOKEN_HERE"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "FCM token registered successfully",
  "data": {
    "userId": "user-123",
    "fcmToken": "FCM_TOKEN_HERE",
    "updatedAt": "2024-01-15T10:30:00Z"
  }
}
```

---

### **Step 6: Implement Backend Lock/Unlock Commands**

#### **A. Lock Command Endpoint**

Your backend should have:
```
POST /api/admin/devices/:userId/lock
```

**Request Body:**
```json
{
  "emiId": "emi-123",
  "reason": "EMI overdue",
  "overdueAmount": 5000,
  "loanNumber": "LOAN-001",
  "borrowerName": "John Doe"
}
```

#### **B. Unlock Command Endpoint**

```
POST /api/admin/devices/:userId/unlock
```

**Request Body:**
```json
{
  "reason": "Payment received"
}
```

#### **C. Extend Payment Endpoint**

```
POST /api/admin/devices/:userId/extend-payment
```

**Request Body:**
```json
{
  "days": 2,
  "reason": "Payment extension granted"
}
```

---

## 🧪 **Testing Checklist**

### **FCM Token Registration:**
- [ ] App starts and gets FCM token
- [ ] Token is logged in console
- [ ] User logs in successfully
- [ ] FCM token is registered to backend
- [ ] Backend receives token and stores it
- [ ] Token refresh works (if token changes)

### **FCM Messages:**
- [ ] Lock command received (app open)
- [ ] Lock command received (app background)
- [ ] Lock command received (app closed)
- [ ] Overlay shows when lock command received
- [ ] Unlock command received
- [ ] Overlay hides when unlock command received
- [ ] Extend payment command works
- [ ] Device re-locks after extension expires

### **Payment Integration:**
- [ ] Payment made via Razorpay
- [ ] Payment verified successfully
- [ ] Device unlocks automatically after payment
- [ ] Overlay removed after payment

---

## 📊 **Log Monitoring**

### **Key Log Prefixes to Monitor:**

1. **`[FCM]`** - General FCM operations
2. **`[FCM_REGISTRATION]`** - Token registration process
3. **`[AppOverlay]`** - Overlay service operations
4. **`[Login]`** - Login and token registration

### **Success Indicators:**
```
✅ SUCCESS
✅ Token registered to backend successfully
✅ FCM token registered successfully
```

### **Error Indicators:**
```
❌ ERROR
❌ FAILED
⚠️ WARNING
```

---

## 🔍 **Troubleshooting**

### **Issue: Token Not Registering**

**Check:**
1. Backend URL is correct
2. User is logged in (auth token exists)
3. Backend API is running
4. Network connectivity
5. Check logs for error messages

**Solution:**
- Verify backend URL in `api_config.dart`
- Check backend logs for errors
- Ensure user is authenticated
- Test API endpoint manually with curl

### **Issue: Token Registration Fails After Login**

**Check:**
1. Auth token is valid
2. Backend endpoint is correct
3. Backend accepts the request format
4. Check response status code in logs

**Solution:**
- Token will retry automatically on token refresh
- Check backend API response format
- Verify authorization header format

### **Issue: FCM Messages Not Received**

**Check:**
1. FCM token is registered in backend
2. Backend is sending to correct token
3. App has notification permission
4. Firebase configuration is correct

**Solution:**
- Verify token in backend database
- Test with Firebase Console
- Check notification permissions
- Verify `google-services.json` is correct

---

## 🚀 **Production Checklist**

Before going to production:

- [ ] Update backend URL to production URL
- [ ] Add release SHA-1 to Firebase
- [ ] Test on real device (not emulator)
- [ ] Test all FCM message types
- [ ] Test payment unlock flow
- [ ] Monitor backend logs
- [ ] Set up error tracking
- [ ] Test token refresh scenarios
- [ ] Test app restart scenarios
- [ ] Test background message handling

---

## 📝 **API Endpoint Details**

### **Register FCM Token**
```
POST /api/users/fcm-token
Headers:
  Authorization: Bearer <auth_token>
  Content-Type: application/json
Body:
  {
    "fcmToken": "fcm-token-string"
  }
```

### **Expected Response:**
```json
{
  "success": true,
  "message": "FCM token registered successfully",
  "data": {
    "userId": "user-id",
    "fcmToken": "fcm-token",
    "updatedAt": "2024-01-15T10:30:00Z"
  }
}
```

---

## 📞 **Support**

If you encounter issues:

1. **Check Logs**: Look for `[FCM_REGISTRATION]` logs
2. **Verify Backend**: Test API endpoint manually
3. **Check Firebase**: Verify configuration
4. **Test Token**: Use Firebase Console to send test message

---

## ✅ **Summary**

**What's Done:**
- ✅ FCM token registration API integrated
- ✅ Comprehensive logging added
- ✅ Login integration complete
- ✅ Token refresh handling
- ✅ Error handling implemented

**What's Next:**
1. Add `google-services.json` file
2. Update backend URL if needed
3. Test token registration
4. Test FCM messages
5. Implement backend lock/unlock endpoints

---

**Status**: ✅ **FCM Token Registration API Fully Integrated with Logging!**

**Ready for Testing!** 🚀


