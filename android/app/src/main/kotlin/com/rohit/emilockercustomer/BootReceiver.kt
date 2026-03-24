package com.rohit.emilockercustomer

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * Boot Receiver - Automatically starts overlay service and opens app when device boots
 * This ensures the overlay comes back after phone restart
 */
class BootReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "BootReceiver"
        private const val PREFS_NAME = "overlay_prefs"
        private const val KEY_IS_LOCKED = "is_locked"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        // CRITICAL: Use Log.e for high visibility in logs
        // Also write to system log for maximum visibility
        android.util.Log.e(TAG, "========== BOOT RECEIVER TRIGGERED ==========")
        android.util.Log.e(TAG, "Action: ${intent.action}")
        android.util.Log.e(TAG, "Package: ${context.packageName}")
        android.util.Log.e(TAG, "Time: ${System.currentTimeMillis()}")
        
        // Also try to write to a file for debugging (if possible)
        try {
            val file = java.io.File(context.getExternalFilesDir(null), "boot_receiver_log.txt")
            file.appendText("BootReceiver triggered at ${System.currentTimeMillis()}, action: ${intent.action}\n")
        } catch (e: Exception) {
            // Ignore file write errors
        }
        
        val action = intent.action
        val isBootAction = action == Intent.ACTION_BOOT_COMPLETED ||
                           action == Intent.ACTION_MY_PACKAGE_REPLACED ||
                           action == Intent.ACTION_PACKAGE_REPLACED ||
                           action == "android.intent.action.QUICKBOOT_POWERON" || // Xiaomi
                           action == "com.htc.intent.action.QUICKBOOT_POWERON"    // HTC
        
        if (isBootAction) {
            Log.e(TAG, "✅✅✅ BOOT ACTION DETECTED - PROCESSING... ✅✅✅")
            Log.e(TAG, "Device booted or app updated - checking if overlay should be shown")
            
            // CRITICAL: Check if device is locked from native SharedPreferences
            // This is the PRIMARY source - native service saves here
            val nativePrefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isLocked = nativePrefs.getBoolean(KEY_IS_LOCKED, false)
            
            // CRITICAL: Use Log.e for high visibility
            Log.e(TAG, "========== BOOT RECEIVER CHECKING LOCK STATUS ==========")
            Log.e(TAG, "SharedPreferences file: $PREFS_NAME")
            Log.e(TAG, "Lock key: $KEY_IS_LOCKED")
            Log.e(TAG, "Device lock status: $isLocked")
            
            // Log all keys in SharedPreferences for debugging
            val allKeys = nativePrefs.all
            Log.e(TAG, "All keys in SharedPreferences: ${allKeys.keys}")
            for ((key, value) in allKeys) {
                Log.e(TAG, "  $key = $value")
            }
            
            if (isLocked) {
                Log.e(TAG, "✅✅✅ DEVICE IS LOCKED - WILL SHOW OVERLAY AND OPEN APP ✅✅✅")
                
                // Get lock message and amount from native SharedPreferences
                // These are saved by SystemOverlayService when device is locked
                val message = nativePrefs.getString("lock_message", "Your EMI is overdue. Please contact shopkeeper.")
                    ?: "Your EMI is overdue. Please contact shopkeeper."
                val amount = nativePrefs.getString("lock_amount", "0") ?: "0"
                
                Log.d(TAG, "Lock message from SharedPreferences: $message")
                Log.d(TAG, "Lock amount from SharedPreferences: $amount")
                
                // CRITICAL: Start service immediately (no delay on boot)
                // The delay was causing issues - start service right away
                try {
                    Log.e(TAG, "========== STARTING OVERLAY SERVICE ON BOOT ==========")
                    Log.e(TAG, "Message: $message")
                    Log.e(TAG, "Amount: $amount")
                    
                    // 1. Start the overlay service with lock data
                    val serviceIntent = Intent(context, SystemOverlayService::class.java).apply {
                        setAction("SHOW_OVERLAY")
                        putExtra("message", message)
                        putExtra("amount", amount)
                    }
                    
                    // CRITICAL: Use startService() to avoid foreground service timeout on boot
                    // The service will call startForeground() immediately in onStartCommand()
                    context.startService(serviceIntent)
                    Log.e(TAG, "✅✅✅ Overlay service STARTED on boot ✅✅✅")
                    Log.e(TAG, "Service intent sent: ${serviceIntent.action}")
                    
                    // 2. Open the app automatically after a short delay
                    Handler(Looper.getMainLooper()).postDelayed({
                        try {
                            val appIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            }
                            
                            if (appIntent != null) {
                                context.startActivity(appIntent)
                                Log.e(TAG, "✅ App opened automatically on boot")
                            } else {
                                Log.e(TAG, "❌ Could not get launch intent for app")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Error opening app on boot: ${e.message}", e)
                        }
                    }, 2000) // 2 second delay before opening app
                        
                } catch (e: Exception) {
                    Log.e(TAG, "❌❌❌ CRITICAL ERROR starting service on boot: ${e.message}", e)
                    Log.e(TAG, "Stack trace: ${e.stackTraceToString()}")
                }
                
            } else {
                Log.e(TAG, "❌ Device is NOT locked - overlay will NOT be shown on boot")
                Log.e(TAG, "This means lock status was cleared or device was unlocked")
                // Logged-in users: restart location foreground service so FCM get_location works without opening app
                try {
                    if (LocationTrackingService.shouldRun(context)) {
                        LocationTrackingService.start(context)
                        Log.e(TAG, "✅ LocationTrackingService started after boot (user logged in + location allowed)")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "LocationTrackingService on boot: ${e.message}", e)
                }
            }
        } else {
            Log.e(TAG, "❌ Not a boot action - ignoring. Action was: $action")
        }
    }
}


