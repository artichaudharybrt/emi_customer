# Backend Implementation Guide - FCM Device Lock/Unlock

## Complete Backend Implementation for FCM Functionality

---

## 📋 **Table of Contents**

1. [Prerequisites](#prerequisites)
2. [Firebase Admin SDK Setup](#firebase-admin-sdk-setup)
3. [Database Schema](#database-schema)
4. [API Endpoints](#api-endpoints)
5. [Node.js Implementation](#nodejs-implementation)
6. [Python Implementation](#python-implementation)
7. [Testing Guide](#testing-guide)
8. [Error Handling](#error-handling)

---

## 🔧 **Prerequisites**

### Required:
- ✅ Firebase Project created
- ✅ Service Account JSON key downloaded
- ✅ Backend server (Node.js/Python/Java/etc.)
- ✅ Database (MongoDB/PostgreSQL/MySQL)
- ✅ User authentication system

### Firebase Service Account:
1. Go to Firebase Console → Project Settings
2. Click on **Service Accounts** tab
3. Click **Generate new private key**
4. Download the JSON file
5. Keep it secure (don't commit to git)

---

## 🔥 **Firebase Admin SDK Setup**

### **Node.js Setup**

```bash
npm install firebase-admin
```

### **Python Setup**

```bash
pip install firebase-admin
```

---

## 💾 **Database Schema**

### **Users Collection/Table**

```javascript
{
  _id: ObjectId,
  email: String,
  mobile: String,
  fullName: String,
  fcmToken: String,           // FCM token for push notifications
  fcmTokenUpdatedAt: Date,   // Last token update time
  deviceId: String,           // Unique device identifier
  isDeviceLocked: Boolean,    // Current lock status
  lockedEmiId: String,        // EMI ID that caused lock
  unlockUntil: Date,         // Temporary unlock expiry (for extend payment)
  createdAt: Date,
  updatedAt: Date
}
```

### **EMIs Collection/Table**

```javascript
{
  _id: ObjectId,
  userId: ObjectId,          // Reference to user
  principalAmount: Number,
  interestPercentage: Number,
  totalAmount: Number,
  description: String,
  billNumber: String,
  startDate: Date,
  dueDates: [Date],
  paidInstallments: Number,
  totalInstallments: Number,
  status: String,             // 'active', 'completed', 'overdue'
  isLocked: Boolean,          // Is this EMI causing device lock
  createdAt: Date,
  updatedAt: Date
}
```

### **FCM Messages Log (Optional - for tracking)**

```javascript
{
  _id: ObjectId,
  userId: ObjectId,
  fcmToken: String,
  messageType: String,        // 'lock_command', 'unlock_command', 'extend_payment'
  emiId: String,
  status: String,              // 'sent', 'delivered', 'failed'
  error: String,
  sentAt: Date,
  deliveredAt: Date
}
```

---

## 🌐 **API Endpoints**

### **1. Register FCM Token**

**Endpoint**: `POST /api/users/fcm-token`

**Headers**:
```
Authorization: Bearer <user-token>
Content-Type: application/json
```

**Request Body**:
```json
{
  "fcmToken": "fcm-token-string-here"
}
```

**Response (Success - 200)**:
```json
{
  "success": true,
  "message": "FCM token registered successfully",
  "data": {
    "userId": "user-123",
    "fcmToken": "fcm-token-string-here",
    "updatedAt": "2024-01-15T10:30:00Z"
  }
}
```

**Response (Error - 400)**:
```json
{
  "success": false,
  "message": "Invalid FCM token",
  "error": "Token format is invalid"
}
```

---

### **2. Check Due EMIs**

**Endpoint**: `GET /api/emis/check-due`

**Headers**:
```
Authorization: Bearer <user-token>
```

**Response (Success - 200)**:
```json
{
  "success": true,
  "message": "Due EMIs retrieved successfully",
  "data": [
    {
      "_id": "emi-123",
      "userId": "user-123",
      "principalAmount": 10000,
      "totalAmount": 10400,
      "description": "EMI Product",
      "billNumber": "BILL-001",
      "dueDates": ["2024-01-15T00:00:00Z"],
      "paidInstallments": 0,
      "totalInstallments": 3,
      "status": "active"
    }
  ]
}
```

---

### **3. Send Lock Command (Admin Only)**

**Endpoint**: `POST /api/admin/devices/:userId/lock`

**Headers**:
```
Authorization: Bearer <admin-token>
Content-Type: application/json
```

**Request Body**:
```json
{
  "emiId": "emi-123",
  "reason": "EMI overdue",
  "overdueAmount": 5000,
  "loanNumber": "LOAN-001",
  "borrowerName": "John Doe"
}
```

**Response (Success - 200)**:
```json
{
  "success": true,
  "message": "Lock command sent successfully",
  "data": {
    "userId": "user-123",
    "messageId": "fcm-message-id",
    "sentAt": "2024-01-15T10:30:00Z"
  }
}
```

---

### **4. Send Unlock Command (Admin Only)**

**Endpoint**: `POST /api/admin/devices/:userId/unlock`

**Headers**:
```
Authorization: Bearer <admin-token>
Content-Type: application/json
```

**Request Body**:
```json
{
  "reason": "Payment received / Admin unlock"
}
```

**Response (Success - 200)**:
```json
{
  "success": true,
  "message": "Unlock command sent successfully",
  "data": {
    "userId": "user-123",
    "messageId": "fcm-message-id",
    "sentAt": "2024-01-15T10:30:00Z"
  }
}
```

---

### **5. Extend Payment (Admin Only)**

**Endpoint**: `POST /api/admin/devices/:userId/extend-payment`

**Headers**:
```
Authorization: Bearer <admin-token>
Content-Type: application/json
```

**Request Body**:
```json
{
  "days": 2,
  "reason": "Payment extension granted"
}
```

**Response (Success - 200)**:
```json
{
  "success": true,
  "message": "Payment extension sent successfully",
  "data": {
    "userId": "user-123",
    "days": 2,
    "unlockUntil": "2024-01-17T10:30:00Z",
    "messageId": "fcm-message-id",
    "sentAt": "2024-01-15T10:30:00Z"
  }
}
```

---

## 💻 **Node.js Implementation**

### **1. Firebase Admin Initialization**

**File: `config/firebase-admin.js`**

```javascript
const admin = require('firebase-admin');
const serviceAccount = require('../path/to/serviceAccountKey.json');

// Initialize Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const messaging = admin.messaging();

module.exports = { admin, messaging };
```

### **2. FCM Service**

**File: `services/fcm-service.js`**

```javascript
const { messaging } = require('../config/firebase-admin');
const User = require('../models/User');
const FCMessageLog = require('../models/FCMessageLog');

class FCMService {
  /**
   * Send lock command to device
   * @param {String} userId - User ID
   * @param {Object} lockData - Lock command data
   * @returns {Promise<Object>}
   */
  async sendLockCommand(userId, lockData) {
    try {
      // Get user with FCM token
      const user = await User.findById(userId);
      
      if (!user || !user.fcmToken) {
        throw new Error('User not found or FCM token not registered');
      }

      const message = {
        token: user.fcmToken,
        data: {
          type: 'lock_command',
          emiId: lockData.emiId || '',
          reason: lockData.reason || 'EMI overdue',
          overdueAmount: String(lockData.overdueAmount || 0),
          loanNumber: lockData.loanNumber || '',
          borrowerName: lockData.borrowerName || '',
          userId: String(userId),
          timestamp: new Date().toISOString(),
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
            priority: 'high',
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      };

      // Send message
      const response = await messaging.send(message);
      
      // Update user lock status
      await User.findByIdAndUpdate(userId, {
        isDeviceLocked: true,
        lockedEmiId: lockData.emiId,
        updatedAt: new Date(),
      });

      // Log message
      await this.logMessage(userId, user.fcmToken, 'lock_command', lockData.emiId, 'sent', response);

      return {
        success: true,
        messageId: response,
        sentAt: new Date(),
      };
    } catch (error) {
      console.error('Error sending lock command:', error);
      
      // Log error
      await this.logMessage(userId, null, 'lock_command', lockData.emiId, 'failed', null, error.message);
      
      throw error;
    }
  }

  /**
   * Send unlock command to device
   * @param {String} userId - User ID
   * @param {Object} unlockData - Unlock command data
   * @returns {Promise<Object>}
   */
  async sendUnlockCommand(userId, unlockData) {
    try {
      const user = await User.findById(userId);
      
      if (!user || !user.fcmToken) {
        throw new Error('User not found or FCM token not registered');
      }

      const message = {
        token: user.fcmToken,
        data: {
          type: 'unlock_command',
          reason: unlockData.reason || 'Payment received',
          timestamp: new Date().toISOString(),
        },
        notification: {
          title: 'Device Unlocked',
          body: 'Your device has been unlocked',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'device_lock_channel',
            sound: 'default',
          },
        },
      };

      const response = await messaging.send(message);
      
      // Update user lock status
      await User.findByIdAndUpdate(userId, {
        isDeviceLocked: false,
        lockedEmiId: null,
        unlockUntil: null,
        updatedAt: new Date(),
      });

      // Log message
      await this.logMessage(userId, user.fcmToken, 'unlock_command', null, 'sent', response);

      return {
        success: true,
        messageId: response,
        sentAt: new Date(),
      };
    } catch (error) {
      console.error('Error sending unlock command:', error);
      await this.logMessage(userId, null, 'unlock_command', null, 'failed', null, error.message);
      throw error;
    }
  }

  /**
   * Send extend payment command
   * @param {String} userId - User ID
   * @param {Number} days - Number of days to extend
   * @param {String} reason - Reason for extension
   * @returns {Promise<Object>}
   */
  async sendExtendPayment(userId, days, reason) {
    try {
      const user = await User.findById(userId);
      
      if (!user || !user.fcmToken) {
        throw new Error('User not found or FCM token not registered');
      }

      const unlockUntil = new Date();
      unlockUntil.setDate(unlockUntil.getDate() + days);

      const message = {
        token: user.fcmToken,
        data: {
          type: 'extend_payment',
          days: String(days),
          reason: reason || 'Payment extension granted',
          timestamp: new Date().toISOString(),
        },
        notification: {
          title: 'Payment Extended',
          body: `Your payment deadline has been extended by ${days} days`,
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'device_lock_channel',
            sound: 'default',
          },
        },
      };

      const response = await messaging.send(message);
      
      // Update user unlock until date
      await User.findByIdAndUpdate(userId, {
        isDeviceLocked: false,
        unlockUntil: unlockUntil,
        updatedAt: new Date(),
      });

      // Log message
      await this.logMessage(userId, user.fcmToken, 'extend_payment', null, 'sent', response);

      return {
        success: true,
        messageId: response,
        unlockUntil: unlockUntil,
        sentAt: new Date(),
      };
    } catch (error) {
      console.error('Error sending extend payment:', error);
      await this.logMessage(userId, null, 'extend_payment', null, 'failed', null, error.message);
      throw error;
    }
  }

  /**
   * Log FCM message
   * @private
   */
  async logMessage(userId, fcmToken, messageType, emiId, status, messageId, error = null) {
    try {
      await FCMessageLog.create({
        userId,
        fcmToken,
        messageType,
        emiId,
        status,
        messageId,
        error,
        sentAt: new Date(),
      });
    } catch (err) {
      console.error('Error logging FCM message:', err);
    }
  }
}

module.exports = new FCMService();
```

### **3. API Routes**

**File: `routes/user-routes.js`**

```javascript
const express = require('express');
const router = express.Router();
const auth = require('../middleware/auth');
const fcmService = require('../services/fcm-service');
const User = require('../models/User');

// Register FCM Token
router.post('/fcm-token', auth, async (req, res) => {
  try {
    const { fcmToken } = req.body;
    const userId = req.user.id;

    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        message: 'FCM token is required',
      });
    }

    // Update user FCM token
    const user = await User.findByIdAndUpdate(
      userId,
      {
        fcmToken,
        fcmTokenUpdatedAt: new Date(),
        updatedAt: new Date(),
      },
      { new: true }
    );

    res.json({
      success: true,
      message: 'FCM token registered successfully',
      data: {
        userId: user._id,
        fcmToken: user.fcmToken,
        updatedAt: user.fcmTokenUpdatedAt,
      },
    });
  } catch (error) {
    console.error('Error registering FCM token:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to register FCM token',
      error: error.message,
    });
  }
});

module.exports = router;
```

**File: `routes/admin-routes.js`**

```javascript
const express = require('express');
const router = express.Router();
const adminAuth = require('../middleware/admin-auth');
const fcmService = require('../services/fcm-service');

// Send Lock Command
router.post('/devices/:userId/lock', adminAuth, async (req, res) => {
  try {
    const { userId } = req.params;
    const lockData = req.body;

    const result = await fcmService.sendLockCommand(userId, lockData);

    res.json({
      success: true,
      message: 'Lock command sent successfully',
      data: {
        userId,
        messageId: result.messageId,
        sentAt: result.sentAt,
      },
    });
  } catch (error) {
    console.error('Error sending lock command:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send lock command',
      error: error.message,
    });
  }
});

// Send Unlock Command
router.post('/devices/:userId/unlock', adminAuth, async (req, res) => {
  try {
    const { userId } = req.params;
    const { reason } = req.body;

    const result = await fcmService.sendUnlockCommand(userId, { reason });

    res.json({
      success: true,
      message: 'Unlock command sent successfully',
      data: {
        userId,
        messageId: result.messageId,
        sentAt: result.sentAt,
      },
    });
  } catch (error) {
    console.error('Error sending unlock command:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send unlock command',
      error: error.message,
    });
  }
});

// Extend Payment
router.post('/devices/:userId/extend-payment', adminAuth, async (req, res) => {
  try {
    const { userId } = req.params;
    const { days, reason } = req.body;

    if (!days || days <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Valid number of days is required',
      });
    }

    const result = await fcmService.sendExtendPayment(userId, days, reason);

    res.json({
      success: true,
      message: 'Payment extension sent successfully',
      data: {
        userId,
        days,
        unlockUntil: result.unlockUntil,
        messageId: result.messageId,
        sentAt: result.sentAt,
      },
    });
  } catch (error) {
    console.error('Error sending extend payment:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to send payment extension',
      error: error.message,
    });
  }
});

module.exports = router;
```

### **4. Auto Lock on EMI Overdue (Cron Job)**

**File: `jobs/check-overdue-emis.js`**

```javascript
const cron = require('node-cron');
const EMI = require('../models/EMI');
const User = require('../models/User');
const fcmService = require('../services/fcm-service');

// Run every hour
cron.schedule('0 * * * *', async () => {
  try {
    console.log('Checking for overdue EMIs...');
    
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // Find all active EMIs with overdue dates
    const overdueEmis = await EMI.find({
      status: 'active',
      dueDates: { $lte: today },
      isLocked: false,
    }).populate('userId');

    for (const emi of overdueEmis) {
      const user = emi.userId;
      
      // Check if device is already locked
      if (user.isDeviceLocked) {
        continue;
      }

      // Calculate overdue amount
      const overdueAmount = emi.totalAmount - (emi.paidInstallments * (emi.totalAmount / emi.totalInstallments));

      // Send lock command
      try {
        await fcmService.sendLockCommand(user._id, {
          emiId: emi._id.toString(),
          reason: 'EMI overdue',
          overdueAmount: overdueAmount,
          loanNumber: emi.billNumber,
          borrowerName: user.fullName,
        });

        // Mark EMI as locked
        await EMI.findByIdAndUpdate(emi._id, {
          isLocked: true,
          status: 'overdue',
          updatedAt: new Date(),
        });

        console.log(`Lock command sent to user ${user._id} for EMI ${emi._id}`);
      } catch (error) {
        console.error(`Error locking device for user ${user._id}:`, error);
      }
    }

    console.log(`Processed ${overdueEmis.length} overdue EMIs`);
  } catch (error) {
    console.error('Error in check-overdue-emis job:', error);
  }
});
```

---

## 🐍 **Python Implementation**

### **1. Firebase Admin Initialization**

**File: `config/firebase_admin.py`**

```python
import firebase_admin
from firebase_admin import credentials, messaging
import os

# Initialize Firebase Admin
cred = credentials.Certificate('path/to/serviceAccountKey.json')
firebase_admin.initialize_app(cred)

def get_messaging():
    return messaging
```

### **2. FCM Service**

**File: `services/fcm_service.py`**

```python
from firebase_admin import messaging
from models.user import User
from datetime import datetime, timedelta
import logging

logger = logging.getLogger(__name__)

class FCMService:
    def send_lock_command(self, user_id, lock_data):
        """Send lock command to device"""
        try:
            user = User.objects.get(id=user_id)
            
            if not user or not user.fcm_token:
                raise ValueError('User not found or FCM token not registered')

            message = messaging.Message(
                token=user.fcm_token,
                data={
                    'type': 'lock_command',
                    'emiId': lock_data.get('emiId', ''),
                    'reason': lock_data.get('reason', 'EMI overdue'),
                    'overdueAmount': str(lock_data.get('overdueAmount', 0)),
                    'loanNumber': lock_data.get('loanNumber', ''),
                    'borrowerName': lock_data.get('borrowerName', ''),
                    'userId': str(user_id),
                    'timestamp': datetime.now().isoformat(),
                },
                notification=messaging.Notification(
                    title='Device Locked',
                    body='Your device has been locked due to overdue EMI payment',
                ),
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='device_lock_channel',
                        sound='default',
                    ),
                ),
                apns=messaging.APNSConfig(
                    headers={'apns-priority': '10'},
                    payload=messaging.APNSPayload(
                        aps=messaging.Aps(sound='default', badge=1)
                    ),
                ),
            )

            response = messaging.send(message)
            
            # Update user lock status
            user.is_device_locked = True
            user.locked_emi_id = lock_data.get('emiId')
            user.updated_at = datetime.now()
            user.save()

            logger.info(f'Lock command sent to user {user_id}: {response}')
            
            return {
                'success': True,
                'messageId': response,
                'sentAt': datetime.now(),
            }
        except Exception as e:
            logger.error(f'Error sending lock command: {e}')
            raise

    def send_unlock_command(self, user_id, unlock_data):
        """Send unlock command to device"""
        try:
            user = User.objects.get(id=user_id)
            
            if not user or not user.fcm_token:
                raise ValueError('User not found or FCM token not registered')

            message = messaging.Message(
                token=user.fcm_token,
                data={
                    'type': 'unlock_command',
                    'reason': unlock_data.get('reason', 'Payment received'),
                    'timestamp': datetime.now().isoformat(),
                },
                notification=messaging.Notification(
                    title='Device Unlocked',
                    body='Your device has been unlocked',
                ),
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='device_lock_channel',
                        sound='default',
                    ),
                ),
            )

            response = messaging.send(message)
            
            # Update user lock status
            user.is_device_locked = False
            user.locked_emi_id = None
            user.unlock_until = None
            user.updated_at = datetime.now()
            user.save()

            logger.info(f'Unlock command sent to user {user_id}: {response}')
            
            return {
                'success': True,
                'messageId': response,
                'sentAt': datetime.now(),
            }
        except Exception as e:
            logger.error(f'Error sending unlock command: {e}')
            raise

    def send_extend_payment(self, user_id, days, reason=None):
        """Send extend payment command"""
        try:
            user = User.objects.get(id=user_id)
            
            if not user or not user.fcm_token:
                raise ValueError('User not found or FCM token not registered')

            unlock_until = datetime.now() + timedelta(days=days)

            message = messaging.Message(
                token=user.fcm_token,
                data={
                    'type': 'extend_payment',
                    'days': str(days),
                    'reason': reason or 'Payment extension granted',
                    'timestamp': datetime.now().isoformat(),
                },
                notification=messaging.Notification(
                    title='Payment Extended',
                    body=f'Your payment deadline has been extended by {days} days',
                ),
                android=messaging.AndroidConfig(
                    priority='high',
                    notification=messaging.AndroidNotification(
                        channel_id='device_lock_channel',
                        sound='default',
                    ),
                ),
            )

            response = messaging.send(message)
            
            # Update user unlock until date
            user.is_device_locked = False
            user.unlock_until = unlock_until
            user.updated_at = datetime.now()
            user.save()

            logger.info(f'Extend payment sent to user {user_id}: {response}')
            
            return {
                'success': True,
                'messageId': response,
                'unlockUntil': unlock_until,
                'sentAt': datetime.now(),
            }
        except Exception as e:
            logger.error(f'Error sending extend payment: {e}')
            raise
```

### **3. API Routes (Flask)**

**File: `routes/user_routes.py`**

```python
from flask import Blueprint, request, jsonify
from middleware.auth import require_auth
from models.user import User
from datetime import datetime

user_routes = Blueprint('user_routes', __name__)

@user_routes.route('/fcm-token', methods=['POST'])
@require_auth
def register_fcm_token():
    """Register FCM token"""
    try:
        data = request.get_json()
        fcm_token = data.get('fcmToken')
        user_id = request.user.id

        if not fcm_token:
            return jsonify({
                'success': False,
                'message': 'FCM token is required',
            }), 400

        user = User.objects.get(id=user_id)
        user.fcm_token = fcm_token
        user.fcm_token_updated_at = datetime.now()
        user.updated_at = datetime.now()
        user.save()

        return jsonify({
            'success': True,
            'message': 'FCM token registered successfully',
            'data': {
                'userId': str(user.id),
                'fcmToken': user.fcm_token,
                'updatedAt': user.fcm_token_updated_at.isoformat(),
            },
        }), 200
    except Exception as e:
        return jsonify({
            'success': False,
            'message': 'Failed to register FCM token',
            'error': str(e),
        }), 500
```

---

## 🧪 **Testing Guide**

### **Test FCM Token Registration**

```bash
curl -X POST http://localhost:3050/api/users/fcm-token \
  -H "Authorization: Bearer <user-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "fcmToken": "test-fcm-token-here"
  }'
```

### **Test Lock Command**

```bash
curl -X POST http://localhost:3050/api/admin/devices/user-123/lock \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "emiId": "emi-123",
    "reason": "EMI overdue",
    "overdueAmount": 5000,
    "loanNumber": "LOAN-001",
    "borrowerName": "John Doe"
  }'
```

### **Test Unlock Command**

```bash
curl -X POST http://localhost:3050/api/admin/devices/user-123/unlock \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Payment received"
  }'
```

### **Test Extend Payment**

```bash
curl -X POST http://localhost:3050/api/admin/devices/user-123/extend-payment \
  -H "Authorization: Bearer <admin-token>" \
  -H "Content-Type: application/json" \
  -d '{
    "days": 2,
    "reason": "Payment extension granted"
  }'
```

---

## ⚠️ **Error Handling**

### **Common Errors**

1. **Invalid FCM Token**
   - Error: `messaging/invalid-registration-token`
   - Solution: User needs to re-register FCM token

2. **Token Not Registered**
   - Error: User doesn't have FCM token
   - Solution: User must register token first

3. **Firebase Service Account Error**
   - Error: Invalid service account JSON
   - Solution: Re-download service account key

---

## 📝 **Environment Variables**

Create `.env` file:

```env
# Firebase
FIREBASE_SERVICE_ACCOUNT_PATH=./path/to/serviceAccountKey.json

# Server
PORT=3050
NODE_ENV=development

# Database
MONGODB_URI=mongodb://localhost:27017/emilocker
```

---

## 🔒 **Security Best Practices**

1. ✅ Keep service account JSON secure
2. ✅ Use environment variables for sensitive data
3. ✅ Implement proper authentication/authorization
4. ✅ Validate all input data
5. ✅ Log all FCM messages
6. ✅ Handle errors gracefully
7. ✅ Rate limit API endpoints

---

## 📚 **Additional Resources**

- [Firebase Admin SDK Documentation](https://firebase.google.com/docs/admin/setup)
- [FCM Message Types](https://firebase.google.com/docs/cloud-messaging/concept-options)
- [Node.js Firebase Admin](https://firebase.google.com/docs/reference/admin/node)
- [Python Firebase Admin](https://firebase.google.com/docs/reference/admin/python)

---

**End of Backend Implementation Guide**





