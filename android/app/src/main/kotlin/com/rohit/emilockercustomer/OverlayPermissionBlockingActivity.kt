package com.rohit.emilockercustomer

import android.app.Activity
import android.graphics.Color
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import android.view.WindowManager
import androidx.core.content.ContextCompat

/**
 * Blocking Activity shown when overlay permission is turned OFF
 * 
 * Flow:
 * 1. User turns OFF overlay permission
 * 2. App detects it (via OverlayPermissionMonitorService)
 * 3. App brings itself to foreground
 * 4. This Activity is shown
 * 5. User cannot bypass - must enable permission
 */
class OverlayPermissionBlockingActivity : Activity() {
    
    companion object {
        private const val TAG = "OverlayPermissionBlocking"
        
        @Volatile
        private var isOpeningSettingsFlag = false
        
        fun isOpeningSettings(): Boolean = isOpeningSettingsFlag
        
        fun setOpeningSettings(open: Boolean) {
            isOpeningSettingsFlag = open
        }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        try {
            super.onCreate(savedInstanceState)
            Log.e(TAG, "========== OVERLAY PERMISSION BLOCKING ACTIVITY CREATED ==========")
            Log.e(TAG, "✅✅✅ ACTIVITY IS BEING CREATED - THIS SHOULD BE VISIBLE ✅✅✅")
            
            // Mark as showing in SystemOverlayService
            SystemOverlayService.setBlockingActivityActive(true)
            
            // Make activity fullscreen and blocking FIRST
            setupBlockingActivity()
            
            // Create blocking UI
            setContentView(createBlockingView())
            
            Log.e(TAG, "✅✅✅ setContentView called - UI should be visible now ✅✅✅")
            
            // CRITICAL: Bring activity to front IMMEDIATELY and MULTIPLE TIMES
            try {
                val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
                Log.e(TAG, "✅✅✅ Activity brought to front in onCreate (IMMEDIATE) ✅✅✅")
            } catch (e: Exception) {
                Log.e(TAG, "Error bringing activity to front: ${e.message}")
            }
            
            // Bring to front after post
            window.decorView.post {
                try {
                    val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                    activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
                    Log.e(TAG, "✅✅✅ Activity brought to front in onCreate (POST) ✅✅✅")
                } catch (e: Exception) {
                    Log.e(TAG, "Error bringing activity to front: ${e.message}")
                }
            }
            
            // Also bring to front after delays
            window.decorView.postDelayed({
                try {
                    val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                    activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
                    Log.e(TAG, "✅✅✅ Activity brought to front in onCreate (DELAYED 200ms) ✅✅✅")
                } catch (e: Exception) {
                    Log.e(TAG, "Error bringing activity to front: ${e.message}")
                }
            }, 200)
            
            window.decorView.postDelayed({
                try {
                    val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                    activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
                    Log.e(TAG, "✅✅✅ Activity brought to front in onCreate (DELAYED 500ms) ✅✅✅")
                } catch (e: Exception) {
                    Log.e(TAG, "Error bringing activity to front: ${e.message}")
                }
            }, 500)
            
            window.decorView.postDelayed({
                try {
                    val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                    activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
                    Log.e(TAG, "✅✅✅ Activity brought to front in onCreate (DELAYED 1000ms) ✅✅✅")
                } catch (e: Exception) {
                    Log.e(TAG, "Error bringing activity to front: ${e.message}")
                }
            }, 1000)
        } catch (e: Exception) {
            Log.e(TAG, "❌❌❌ CRITICAL ERROR in onCreate: ${e.message} ❌❌❌", e)
            throw e // Re-throw to see the error
        }
    }
    
    override fun onStart() {
        super.onStart()
        Log.e(TAG, "========== ACTIVITY STARTED ==========")
        
        // Bring to front in onStart as well
        try {
            val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
            activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
            Log.e(TAG, "✅✅✅ Activity brought to front in onStart ✅✅✅")
        } catch (e: Exception) {
            Log.e(TAG, "Error bringing activity to front: ${e.message}")
        }
        
        // Also bring to front after post
        window.decorView.post {
            try {
                val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
                Log.e(TAG, "✅✅✅ Activity brought to front in onStart (POST) ✅✅✅")
            } catch (e: Exception) {
                Log.e(TAG, "Error bringing activity to front: ${e.message}")
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.e(TAG, "========== OVERLAY PERMISSION BLOCKING ACTIVITY DESTROYED ==========")
        // Reset flag when activity is destroyed
        SystemOverlayService.setBlockingActivityActive(false)
    }
    
    
    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) {
            // If we're opening settings, don't bring activity back
            if (isOpeningSettings) {
                Log.d(TAG, "⚠️ Activity lost focus but opening settings - allowing it")
                return
            }
            
            Log.d(TAG, "⚠️ Activity lost focus - bringing back to front")
            // Bring back to front immediately
            window.decorView.post {
                if (!isOpeningSettings && !isFinishing) {
                    try {
                        val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                        activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
                        Log.d(TAG, "✅ Activity brought back to front")
                    } catch (e: Exception) {
                        Log.e(TAG, "Error bringing activity to front: ${e.message}")
                    }
                }
            }
        }
    }
    
    override fun onBackPressed() {
        // Block back button - user must enable permission
        Log.d(TAG, "🚫 Back button blocked - permission required")
        // Do nothing - don't call super.onBackPressed()
    }
    
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        // Block all system keys
        if (keyCode == KeyEvent.KEYCODE_BACK || 
            keyCode == KeyEvent.KEYCODE_HOME ||
            keyCode == KeyEvent.KEYCODE_APP_SWITCH) {
            Log.d(TAG, "🚫 System key blocked: $keyCode")
            return true // Consume the event
        }
        return super.onKeyDown(keyCode, event)
    }
    
    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        // Block all system keys
        if (keyCode == KeyEvent.KEYCODE_BACK || 
            keyCode == KeyEvent.KEYCODE_HOME ||
            keyCode == KeyEvent.KEYCODE_APP_SWITCH) {
            return true // Consume the event
        }
        return super.onKeyUp(keyCode, event)
    }
    
    // Flag to track if we're opening settings (allow activity to be paused)
    private var isOpeningSettings = false
    
    override fun onUserLeaveHint() {
        // If we're opening settings, allow it
        if (isOpeningSettings) {
            Log.d(TAG, "Opening settings - allowing activity to be paused")
            super.onUserLeaveHint()
            return
        }
        
        // User tried to leave (home button, etc.) - bring activity back
        Log.d(TAG, "User tried to leave - bringing activity back to front IMMEDIATELY")
        super.onUserLeaveHint()
        
        // Bring activity back to front IMMEDIATELY (no delay)
        window.decorView.post {
            if (!isFinishing) {
                try {
                    // Method 1: Use moveTaskToFront
                    val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                    activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
                    Log.d(TAG, "✅ Activity brought to front via moveTaskToFront")
                } catch (e: Exception) {
                    Log.e(TAG, "Error with moveTaskToFront: ${e.message}")
                    // Method 2: Restart activity
                    try {
                        val intent = Intent(this, OverlayPermissionBlockingActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        }
                        startActivity(intent)
                        Log.d(TAG, "✅ Activity restarted")
                    } catch (e2: Exception) {
                        Log.e(TAG, "Error restarting activity: ${e2.message}", e2)
                    }
                }
            }
        }
    }
    
    override fun onPause() {
        super.onPause()
        // If we're opening settings, don't bring activity back immediately
        if (!isOpeningSettings) {
            Log.d(TAG, "Activity paused - will bring back if not opening settings")
        }
    }
    
    override fun onResume() {
        super.onResume()
        
        // Check if permission is now granted (regardless of flag)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (Settings.canDrawOverlays(this)) {
                Log.d(TAG, "✅ Overlay permission granted - finishing activity")
                isOpeningSettings = false
                setOpeningSettings(false) // Reset static flag
                finish()
                return
            }
        }
        
        // Reset flag when activity resumes (but only after a delay to allow settings to stay open)
        if (isOpeningSettings) {
            Log.d(TAG, "Activity resumed after opening settings - will check permission again in 2 seconds")
            // Don't reset flag immediately - give settings time to stay open
            // Reset after delay
            window.decorView.postDelayed({
                isOpeningSettings = false
                setOpeningSettings(false) // Also reset static flag
                Log.d(TAG, "isOpeningSettings flag reset after delay")
            }, 5000) // 5 seconds delay to allow settings to stay open
            // Don't bring activity to front if we just opened settings
            return
        }
        
        // Continue with normal resume logic
        checkAndBringToFront()
    }
    
    /**
     * Check permission and bring activity to front
     */
    private fun checkAndBringToFront() {
        Log.e(TAG, "========== ACTIVITY RESUMED ==========")
        
        // Keep activity on top
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
        
        // CRITICAL: Bring activity to front IMMEDIATELY and MULTIPLE TIMES
        try {
            val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
            activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
            Log.e(TAG, "✅✅✅ Activity brought to front in onResume (IMMEDIATE) ✅✅✅")
        } catch (e: Exception) {
            Log.e(TAG, "Error bringing activity to front: ${e.message}")
        }
        
        // Also bring to front after post
        window.decorView.post {
            try {
                val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
                Log.e(TAG, "✅✅✅ Activity brought to front in onResume (POST) ✅✅✅")
            } catch (e: Exception) {
                Log.e(TAG, "Error bringing activity to front: ${e.message}")
            }
        }
        
        // Bring to front again after delay
        window.decorView.postDelayed({
            try {
                val activityManager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                activityManager.moveTaskToFront(taskId, android.app.ActivityManager.MOVE_TASK_WITH_HOME)
                Log.e(TAG, "✅✅✅ Activity brought to front in onResume (DELAYED) ✅✅✅")
            } catch (e: Exception) {
                Log.e(TAG, "Error bringing activity to front: ${e.message}")
            }
        }, 200)
    }
    
    /**
     * Setup activity to be blocking and fullscreen
     */
    private fun setupBlockingActivity() {
        // Make activity fullscreen
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN
        )
        
        // Keep screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        
        // Show when locked
        window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        
        // Turn screen on
        window.addFlags(WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON)
        
        // Dismiss keyguard
        window.addFlags(WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD)
        
        // Block system UI - use post to ensure window is ready
        window.decorView.post {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    window.insetsController?.let { controller ->
                        controller.hide(android.view.WindowInsets.Type.statusBars())
                        controller.hide(android.view.WindowInsets.Type.navigationBars())
                    } ?: run {
                        // Fallback to deprecated method if insetsController is null
                        @Suppress("DEPRECATION")
                        window.decorView.systemUiVisibility = (
                            android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                            or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                            or android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                        )
                    }
                } else {
                    @Suppress("DEPRECATION")
                    window.decorView.systemUiVisibility = (
                        android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                        or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    )
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error setting up system UI: ${e.message}")
                // Fallback to deprecated method
                try {
                    @Suppress("DEPRECATION")
                    window.decorView.systemUiVisibility = (
                        android.view.View.SYSTEM_UI_FLAG_FULLSCREEN
                        or android.view.View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        or android.view.View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                    )
                } catch (e2: Exception) {
                    Log.e(TAG, "Error in fallback system UI setup: ${e2.message}")
                }
            }
        }
    }
    
    /**
     * Create blocking view with message and button
     */
    private fun createBlockingView(): android.view.View {
        val container = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(ContextCompat.getColor(this@OverlayPermissionBlockingActivity, android.R.color.black))
            gravity = android.view.Gravity.CENTER
            setPadding(50, 50, 50, 50)
        }
        
        // Card container
        val card = android.widget.LinearLayout(this).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            setBackgroundColor(ContextCompat.getColor(this@OverlayPermissionBlockingActivity, android.R.color.white))
            setPadding(60, 60, 60, 60)
            gravity = android.view.Gravity.CENTER
        }
        
        // Warning icon
        val warningIcon = android.widget.TextView(this).apply {
            text = "⚠️"
            textSize = 48f
            gravity = android.view.Gravity.CENTER
            setPadding(0, 0, 0, 30)
        }
        
        // Title
        val title = android.widget.TextView(this).apply {
            text = "Permission Required"
            textSize = 24f
            setTextColor(ContextCompat.getColor(this@OverlayPermissionBlockingActivity, android.R.color.holo_red_dark))
            gravity = android.view.Gravity.CENTER
            setPadding(0, 0, 0, 20)
            setTypeface(null, android.graphics.Typeface.BOLD)
        }
        
        // Message
        val message = android.widget.TextView(this).apply {
            text = "Display over other apps permission is required to continue using this device.\n\nPlease enable the permission to proceed."
            textSize = 16f
            setTextColor(ContextCompat.getColor(this@OverlayPermissionBlockingActivity, android.R.color.black))
            gravity = android.view.Gravity.CENTER
            setPadding(0, 0, 0, 16)
        }
        
        // Tip for "App was denied access" (Android 15+ and some devices)
        val restrictedTip = android.widget.TextView(this).apply {
            text = "If you see \"App was denied access\": Open Settings → Apps → Fasst Pay → ⋮ menu → Allow restricted settings, then enable \"Display over other apps\"."
            textSize = 12f
            setTextColor(Color.parseColor("#757575"))
            gravity = android.view.Gravity.CENTER
            setPadding(0, 0, 0, 30)
        }
        
        // Enable permission button
        val enableButton = android.widget.Button(this).apply {
            text = "Enable Permission"
            textSize = 18f
            setTextColor(ContextCompat.getColor(this@OverlayPermissionBlockingActivity, android.R.color.white))
            setBackgroundColor(ContextCompat.getColor(this@OverlayPermissionBlockingActivity, android.R.color.holo_blue_dark))
            setPadding(60, 30, 60, 30)
            setTypeface(null, android.graphics.Typeface.BOLD)
            
            setOnClickListener {
                Log.d(TAG, "Enable permission button clicked")
                openOverlayPermissionSettings()
            }
        }
        
        // Add views to card
        card.addView(warningIcon)
        card.addView(title)
        card.addView(message)
        card.addView(restrictedTip)
        card.addView(enableButton)
        
        // Add card to container
        container.addView(card)
        
        return container
    }
    
    /**
     * Open overlay permission settings
     */
    private fun openOverlayPermissionSettings() {
        try {
            Log.d(TAG, "🔵🔵🔵 Opening overlay permission settings for package: $packageName 🔵🔵🔵")
            
            // Set flag to allow activity to be paused when settings open
            isOpeningSettings = true
            setOpeningSettings(true) // Also set static flag for SystemOverlayService
            
            // Use handler to ensure UI is ready and intent can launch
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        // Method 1: Direct overlay permission settings (Android 6.0+)
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                                // Critical flags to ensure it launches even from blocking activity
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            }
                            
                            // Verify intent can be resolved
                            if (intent.resolveActivity(packageManager) != null) {
                                Log.d(TAG, "✅ Intent resolved - launching settings...")
                                startActivity(intent)
                                Log.d(TAG, "✅✅✅ Opened overlay permission settings via ACTION_MANAGE_OVERLAY_PERMISSION ✅✅✅")
                                return@post
                            } else {
                                Log.w(TAG, "⚠️ ACTION_MANAGE_OVERLAY_PERMISSION intent cannot be resolved")
                            }
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Failed to open via ACTION_MANAGE_OVERLAY_PERMISSION: ${e.message}", e)
                        }
                        
                        // Method 2: Try alternative intent for some devices
                        try {
                            val intent = Intent().apply {
                                action = Settings.ACTION_MANAGE_OVERLAY_PERMISSION
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            }
                            
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                                Log.d(TAG, "✅ Opened overlay permission settings (alternative method)")
                                return@post
                            }
                        } catch (e: Exception) {
                            Log.w(TAG, "Alternative method failed: ${e.message}")
                        }
                        
                        // Method 3: Fallback - Open app settings, user can navigate to overlay permission
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            }
                            
                            if (intent.resolveActivity(packageManager) != null) {
                                startActivity(intent)
                                Log.d(TAG, "✅ Opened app settings as fallback - user can navigate to 'Display over other apps'")
                            } else {
                                Log.e(TAG, "❌ App settings intent cannot be resolved")
                            }
                        } catch (e2: Exception) {
                            Log.e(TAG, "❌ Error opening app settings: ${e2.message}", e2)
                        }
                    } else {
                        // Android < 6.0 - Open app settings
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            }
                            startActivity(intent)
                            Log.d(TAG, "✅ Opened app settings (Android < 6.0)")
                        } catch (e: Exception) {
                            Log.e(TAG, "❌ Error opening app settings: ${e.message}", e)
                        }
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "❌❌❌ Critical error in openOverlayPermissionSettings: ${e.message} ❌❌❌", e)
                } finally {
                    // Reset flag after a delay (in case settings don't open)
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        if (!isFinishing) {
                            isOpeningSettings = false
                        }
                    }, 2000)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌❌❌ Critical error opening overlay permission settings: ${e.message} ❌❌❌", e)
            isOpeningSettings = false
        }
    }
}

