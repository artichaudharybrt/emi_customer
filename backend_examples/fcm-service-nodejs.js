/**
 * FCM Service - Node.js Implementation
 * Complete implementation for sending FCM messages
 */

const admin = require('firebase-admin');
const serviceAccount = require('../path/to/serviceAccountKey.json');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const messaging = admin.messaging();

class FCMService {
  /**
   * Send lock command to device
   * @param {String} userId - User ID
   * @param {Object} lockData - Lock command data
   * @returns {Promise<Object>}
   */
  async sendLockCommand(userId, lockData) {
    try {
      // Get user with FCM token from database
      // const user = await User.findById(userId);
      // Replace with your database query
      
      const fcmToken = lockData.fcmToken; // Get from user object in real implementation

      if (!fcmToken) {
        throw new Error('FCM token not found for user');
      }

      const message = {
        token: fcmToken,
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
      
      console.log('Lock command sent successfully:', response);

      return {
        success: true,
        messageId: response,
        sentAt: new Date(),
      };
    } catch (error) {
      console.error('Error sending lock command:', error);
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
      // Get user with FCM token from database
      // const user = await User.findById(userId);
      const fcmToken = unlockData.fcmToken; // Get from user object

      if (!fcmToken) {
        throw new Error('FCM token not found for user');
      }

      const message = {
        token: fcmToken,
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
      
      console.log('Unlock command sent successfully:', response);

      return {
        success: true,
        messageId: response,
        sentAt: new Date(),
      };
    } catch (error) {
      console.error('Error sending unlock command:', error);
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
      // Get user with FCM token from database
      // const user = await User.findById(userId);
      const fcmToken = 'user-fcm-token'; // Get from user object

      if (!fcmToken) {
        throw new Error('FCM token not found for user');
      }

      const unlockUntil = new Date();
      unlockUntil.setDate(unlockUntil.getDate() + days);

      const message = {
        token: fcmToken,
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
      
      console.log('Extend payment sent successfully:', response);

      return {
        success: true,
        messageId: response,
        unlockUntil: unlockUntil,
        sentAt: new Date(),
      };
    } catch (error) {
      console.error('Error sending extend payment:', error);
      throw error;
    }
  }
}

module.exports = new FCMService();





