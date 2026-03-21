package com.rohit.emilockercustomer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.util.Log

/**
 * Receiver that listens for USER_PRESENT action
 * When user unlocks screen, this receiver opens DeviceAdminBlockingActivity
 * 
 * Flow:
 * 1. Device locked via lockNow()
 * 2. User unlocks screen
 * 3. USER_PRESENT broadcast sent
 * 4. This receiver catches it
 * 5. Opens DeviceAdminBlockingActivity
 */
class UserPresentReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "UserPresentReceiver"
        private const val PREFS_NAME = "overlay_prefs"
        private const val KEY_EMI_OVERDUE = "emi_overdue_status"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_USER_PRESENT) {
            Log.d(TAG, "========== USER_PRESENT RECEIVED ==========")
            Log.d(TAG, "User unlocked screen - checking if blocking activity should be shown")
            
            // Check if EMI is overdue
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isOverdue = prefs.getBoolean(KEY_EMI_OVERDUE, false)
            
            if (isOverdue) {
                Log.d(TAG, "✅ EMI is overdue - opening blocking activity")
                
                try {
                    val blockingIntent = Intent(context, DeviceAdminBlockingActivity::class.java).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    }
                    context.startActivity(blockingIntent)
                    Log.d(TAG, "✅ Blocking activity opened")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error opening blocking activity: ${e.message}", e)
                }
            } else {
                Log.d(TAG, "EMI is not overdue - no blocking activity needed")
            }
        }
    }
}

