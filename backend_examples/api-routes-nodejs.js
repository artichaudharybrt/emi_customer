/**
 * API Routes - Node.js/Express Implementation
 * Complete API endpoints for FCM functionality
 */

const express = require('express');
const router = express.Router();
const fcmService = require('./fcm-service-nodejs');

// Middleware for authentication (implement your own)
const auth = require('../middleware/auth');
const adminAuth = require('../middleware/admin-auth');

/**
 * Register FCM Token
 * POST /api/users/fcm-token
 */
router.post('/fcm-token', auth, async (req, res) => {
  try {
    const { fcmToken } = req.body;
    const userId = req.user.id; // From auth middleware

    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        message: 'FCM token is required',
      });
    }

    // Update user FCM token in database
    // await User.findByIdAndUpdate(userId, {
    //   fcmToken,
    //   fcmTokenUpdatedAt: new Date(),
    //   updatedAt: new Date(),
    // });

    res.json({
      success: true,
      message: 'FCM token registered successfully',
      data: {
        userId: userId,
        fcmToken: fcmToken,
        updatedAt: new Date(),
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

/**
 * Send Lock Command (Admin Only)
 * POST /api/admin/devices/:userId/lock
 */
router.post('/devices/:userId/lock', adminAuth, async (req, res) => {
  try {
    const { userId } = req.params;
    const lockData = req.body;

    // Get user's FCM token from database
    // const user = await User.findById(userId);
    // lockData.fcmToken = user.fcmToken;

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

/**
 * Send Unlock Command (Admin Only)
 * POST /api/admin/devices/:userId/unlock
 */
router.post('/devices/:userId/unlock', adminAuth, async (req, res) => {
  try {
    const { userId } = req.params;
    const { reason } = req.body;

    // Get user's FCM token from database
    // const user = await User.findById(userId);
    const unlockData = {
      reason: reason || 'Payment received',
      fcmToken: 'user-fcm-token', // Get from user object
    };

    const result = await fcmService.sendUnlockCommand(userId, unlockData);

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

/**
 * Extend Payment (Admin Only)
 * POST /api/admin/devices/:userId/extend-payment
 */
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





