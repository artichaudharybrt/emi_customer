package com.rohit.emilockercustomer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * FCM Command Receiver
 * Receives broadcast from Flutter background handler to start overlay service
 * 
 * This receiver is triggered when Flutter background handler receives FCM message
 * and needs to start SystemOverlayService (since MethodChannel doesn't work in background)
 */
class FcmCommandReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "FcmCommandReceiver"
        private const val ACTION_LOCK_COMMAND = "com.rohit.emilockercustomer.ACTION_LOCK_COMMAND"
        private const val ACTION_UNLOCK_COMMAND = "com.rohit.emilockercustomer.ACTION_UNLOCK_COMMAND"
        const val EXTRA_MESSAGE = "message"
        const val EXTRA_AMOUNT = "amount"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.e(TAG, "========== FCM COMMAND RECEIVER TRIGGERED ==========")
        Log.e(TAG, "Action: $action")
        
        when (action) {
            ACTION_LOCK_COMMAND -> {
                handleLockCommand(context, intent)
            }
            ACTION_UNLOCK_COMMAND -> {
                handleUnlockCommand(context, intent)
            }
            else -> {
                Log.w(TAG, "Unknown action: $action")
            }
        }
    }
    
    private fun handleLockCommand(context: Context, intent: Intent) {
        Log.e(TAG, "========== LOCK COMMAND RECEIVED ==========")
        
        val message = intent.getStringExtra(EXTRA_MESSAGE) ?: 
                     "Your EMI is overdue. Please contact shopkeeper."
        val amount = intent.getStringExtra(EXTRA_AMOUNT) ?: "0"
        
        Log.e(TAG, "Lock message: $message")
        Log.e(TAG, "Lock amount: $amount")
        
        // Start SystemOverlayService to show overlay
        try {
            val serviceIntent = Intent(context, SystemOverlayService::class.java).apply {
                action = "SHOW_OVERLAY"
                putExtra("message", message)
                putExtra("amount", amount)
            }
            
            // CRITICAL: Use startService() to start overlay service
            // This works even when app is closed
            context.startService(serviceIntent)
            Log.e(TAG, "✅✅✅ OVERLAY SERVICE STARTED FROM FCM RECEIVER ✅✅✅")
            Log.e(TAG, "Overlay should be showing now (even if app is closed)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting overlay service: ${e.message}", e)
        }
    }
    
    private fun handleUnlockCommand(context: Context, intent: Intent) {
        Log.e(TAG, "========== UNLOCK COMMAND RECEIVED ==========")
        
        // Stop SystemOverlayService to hide overlay
        try {
            val serviceIntent = Intent(context, SystemOverlayService::class.java).apply {
                action = "HIDE_OVERLAY"
            }
            
            context.startService(serviceIntent)
            Log.e(TAG, "✅✅✅ OVERLAY SERVICE STOPPED FROM FCM RECEIVER ✅✅✅")
            Log.e(TAG, "Overlay should be hidden now")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping overlay service: ${e.message}", e)
        }
    }
}


