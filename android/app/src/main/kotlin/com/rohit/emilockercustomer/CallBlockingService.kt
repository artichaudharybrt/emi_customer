package com.rohit.emilockercustomer

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.telephony.PhoneStateListener
import android.telephony.TelephonyManager
import android.util.Log
import androidx.annotation.RequiresApi
import java.lang.reflect.Method

/**
 * Call Blocking Service - Blocks incoming calls when device is locked
 * 
 * Features:
 * - Listens for incoming calls using TelephonyManager
 * - Automatically rejects calls when device is locked
 * - Works with SystemOverlayService to enable/disable based on lock status
 * - Blocks both regular phone calls and attempts to block WhatsApp calls via overlay
 */
class CallBlockingService : Service() {
    
    companion object {
        private const val TAG = "CallBlockingService"
        private const val PREFS_NAME = "overlay_prefs"
        private const val KEY_IS_LOCKED = "is_locked"
        
        @Volatile
        private var isServiceRunning = false
        
        fun isRunning(): Boolean = isServiceRunning
    }
    
    private var telephonyManager: TelephonyManager? = null
    private var phoneStateListener: PhoneStateListener? = null
    private var handler: Handler? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "========== CallBlockingService CREATED ==========")
        isServiceRunning = true
        
        try {
            telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
            handler = Handler(Looper.getMainLooper())
            Log.d(TAG, "✅ CallBlockingService initialized")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error initializing CallBlockingService: ${e.message}", e)
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "========== CallBlockingService onStartCommand ==========")
        Log.d(TAG, "Action: ${intent?.action}")
        
        when (intent?.action) {
            "START_BLOCKING" -> {
                startCallBlocking()
            }
            "STOP_BLOCKING" -> {
                stopCallBlocking()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                // Check if device is locked and start blocking if needed
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val isLocked = prefs.getBoolean(KEY_IS_LOCKED, false)
                if (isLocked) {
                    startCallBlocking()
                } else {
                    stopCallBlocking()
                    stopSelf()
                    return START_NOT_STICKY
                }
            }
        }
        
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    /**
     * Start listening for incoming calls and block them
     */
    private fun startCallBlocking() {
        Log.d(TAG, "========== STARTING CALL BLOCKING ==========")
        
        if (phoneStateListener != null) {
            Log.d(TAG, "⚠️ Call blocking already active")
            return
        }
        
        try {
            phoneStateListener = object : PhoneStateListener() {
                override fun onCallStateChanged(state: Int, phoneNumber: String?) {
                    super.onCallStateChanged(state, phoneNumber)
                    
                    // Check if device is still locked
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val isLocked = prefs.getBoolean(KEY_IS_LOCKED, false)
                    
                    if (!isLocked) {
                        Log.d(TAG, "Device unlocked - allowing call")
                        return
                    }
                    
                    when (state) {
                        TelephonyManager.CALL_STATE_RINGING -> {
                            Log.d(TAG, "🚫 INCOMING CALL DETECTED - Blocking call from: $phoneNumber")
                            Log.d(TAG, "Device is locked - rejecting call")
                            
                            // Reject the call
                            rejectCall()
                        }
                        TelephonyManager.CALL_STATE_OFFHOOK -> {
                            Log.d(TAG, "Call answered or outgoing - device is locked")
                        }
                        TelephonyManager.CALL_STATE_IDLE -> {
                            Log.d(TAG, "Call ended")
                        }
                    }
                }
            }
            
            // Register listener
            // Note: For Android 12+, we need different approach, but PhoneStateListener works for most cases
            @Suppress("DEPRECATION")
            telephonyManager?.listen(phoneStateListener, PhoneStateListener.LISTEN_CALL_STATE)
            
            Log.d(TAG, "✅ Call blocking started - incoming calls will be rejected")
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Permission denied for call blocking: ${e.message}")
            Log.e(TAG, "Required permissions: READ_PHONE_STATE, CALL_PHONE")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting call blocking: ${e.message}", e)
        }
    }
    
    /**
     * Stop call blocking
     */
    private fun stopCallBlocking() {
        Log.d(TAG, "========== STOPPING CALL BLOCKING ==========")
        
        try {
            phoneStateListener?.let { listener ->
                @Suppress("DEPRECATION")
                telephonyManager?.listen(listener, PhoneStateListener.LISTEN_NONE)
            }
            phoneStateListener = null
            Log.d(TAG, "✅ Call blocking stopped")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping call blocking: ${e.message}", e)
        }
    }
    
    /**
     * Reject incoming call using ITelephony interface
     */
    private fun rejectCall() {
        try {
            // Method 1: Use ITelephony interface (works on most Android versions)
            val telephonyClass = Class.forName(telephonyManager?.javaClass?.name)
            val getITelephonyMethod: Method = telephonyClass.getDeclaredMethod("getITelephony")
            getITelephonyMethod.isAccessible = true
            
            val iTelephony = getITelephonyMethod.invoke(telephonyManager)
            val endCallMethod: Method = iTelephony.javaClass.getDeclaredMethod("endCall")
            endCallMethod.isAccessible = true
            
            val result = endCallMethod.invoke(iTelephony) as Boolean
            if (result) {
                Log.d(TAG, "✅ Call rejected successfully using ITelephony")
                return
            } else {
                Log.w(TAG, "⚠️ Failed to reject call using ITelephony (may have been answered already)")
            }
        } catch (e: NoSuchMethodException) {
            Log.e(TAG, "❌ ITelephony method not found: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error rejecting call with ITelephony: ${e.message}")
        }
        
        // Method 2: Try using TelecomManager for Android 9+ (if available)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                val telecomManager = getSystemService(Context.TELECOM_SERVICE) as? android.telecom.TelecomManager
                if (telecomManager != null) {
                    // Note: TelecomManager doesn't provide direct access to calls
                    // The overlay blocking should handle most cases
                    Log.d(TAG, "TelecomManager available but direct call rejection not supported")
                }
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error accessing TelecomManager: ${e.message}")
            }
        }
        
        // Note: If both methods fail, the overlay will still block the call UI
        // so user cannot interact with the call
        Log.d(TAG, "⚠️ Direct call rejection failed, but overlay will block call UI")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "========== CallBlockingService DESTROYED ==========")
        isServiceRunning = false
        stopCallBlocking()
    }
}


