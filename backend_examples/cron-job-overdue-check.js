/**
 * Cron Job - Auto Check Overdue EMIs and Send Lock Commands
 * Run this job periodically to check for overdue EMIs
 */

const cron = require('node-cron');
const fcmService = require('./fcm-service-nodejs');
// const EMI = require('../models/EMI');
// const User = require('../models/User');

/**
 * Check for overdue EMIs and send lock commands
 * Runs every hour at minute 0
 */
cron.schedule('0 * * * *', async () => {
  try {
    console.log('[' + new Date().toISOString() + '] Checking for overdue EMIs...');
    
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    // Find all active EMIs with overdue dates
    // Replace with your database query
    /*
    const overdueEmis = await EMI.find({
      status: 'active',
      dueDates: { $lte: today },
      isLocked: false,
    }).populate('userId');
    */

    // Example data structure
    const overdueEmis = [
      {
        _id: 'emi-123',
        userId: {
          _id: 'user-123',
          fcmToken: 'fcm-token-here',
          fullName: 'John Doe',
          isDeviceLocked: false,
        },
        totalAmount: 10400,
        paidInstallments: 0,
        totalInstallments: 3,
        billNumber: 'BILL-001',
      }
    ];

    let processedCount = 0;
    let errorCount = 0;

    for (const emi of overdueEmis) {
      const user = emi.userId;
      
      // Check if device is already locked
      if (user.isDeviceLocked) {
        console.log(`Device already locked for user ${user._id}`);
        continue;
      }

      // Calculate overdue amount
      const installmentAmount = emi.totalAmount / emi.totalInstallments;
      const overdueAmount = emi.totalAmount - (emi.paidInstallments * installmentAmount);

      // Send lock command
      try {
        await fcmService.sendLockCommand(user._id, {
          emiId: emi._id.toString(),
          reason: 'EMI overdue',
          overdueAmount: overdueAmount,
          loanNumber: emi.billNumber,
          borrowerName: user.fullName,
          fcmToken: user.fcmToken,
        });

        // Mark EMI as locked in database
        /*
        await EMI.findByIdAndUpdate(emi._id, {
          isLocked: true,
          status: 'overdue',
          updatedAt: new Date(),
        });

        await User.findByIdAndUpdate(user._id, {
          isDeviceLocked: true,
          lockedEmiId: emi._id,
          updatedAt: new Date(),
        });
        */

        processedCount++;
        console.log(`✅ Lock command sent to user ${user._id} for EMI ${emi._id}`);
      } catch (error) {
        errorCount++;
        console.error(`❌ Error locking device for user ${user._id}:`, error.message);
      }
    }

    console.log(`[${new Date().toISOString()}] Processed ${processedCount} overdue EMIs, ${errorCount} errors`);
  } catch (error) {
    console.error('Error in check-overdue-emis job:', error);
  }
});

/**
 * Check for expired unlock periods (for extend payment)
 * Runs every day at midnight
 */
cron.schedule('0 0 * * *', async () => {
  try {
    console.log('[' + new Date().toISOString() + '] Checking for expired unlock periods...');
    
    const now = new Date();

    // Find users with expired unlock periods
    /*
    const usersWithExpiredUnlock = await User.find({
      isDeviceLocked: false,
      unlockUntil: { $lte: now },
      unlockUntil: { $ne: null },
    });
    */

    // Re-lock devices with expired unlock periods
    // Implementation here

    console.log('Expired unlock periods checked');
  } catch (error) {
    console.error('Error checking expired unlock periods:', error);
  }
});

console.log('Cron jobs started:');
console.log('- Overdue EMI check: Every hour at minute 0');
console.log('- Expired unlock check: Daily at midnight');





