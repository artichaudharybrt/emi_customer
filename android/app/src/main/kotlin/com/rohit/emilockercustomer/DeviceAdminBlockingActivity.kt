package com.rohit.emilockercustomer

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Bundle
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Device Admin Blocking Activity
 * 
 * This activity is shown when device is locked via Device Admin.
 * It provides a full-screen blocking interface that cannot be dismissed
 * until the EMI payment is made.
 * 
 * Key Features:
 * - Full-screen blocking interface
 * - Cannot be dismissed by back button or home button
 * - Shows EMI payment information
 * - Provides contact information for payment
 * - Integrates with device admin for enhanced security
 */
class DeviceAdminBlockingActivity : Activity() {
    
    companion object {
        private const val TAG = "DeviceAdminBlockingActivity"
    }
    
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        Log.d(TAG, "Device Admin Blocking Activity created")
        
        // Check if we should finish immediately
        if (intent.getBooleanExtra("finish", false)) {
            Log.d(TAG, "Finish flag set - closing activity")
            finish()
            return
        }
        
        // Check if EMI is overdue
        val prefs = getSharedPreferences("overlay_prefs", Context.MODE_PRIVATE)
        val isEmiOverdue = prefs.getBoolean("emi_overdue_status", false)
        
        if (!isEmiOverdue) {
            Log.d(TAG, "EMI not overdue - closing activity")
            finish()
            return
        }
        
        // Create blocking interface
        createBlockingInterface()
        
        // Prevent activity from being destroyed
        setFinishOnTouchOutside(false)
    }
    
    /**
     * Create full-screen blocking interface
     */
    private fun createBlockingInterface() {
        try {
            // Get lock information
            val prefs = getSharedPreferences("overlay_prefs", Context.MODE_PRIVATE)
            val message = prefs.getString("lock_message", "Your EMI is overdue. Please contact shopkeeper.")
            val amount = prefs.getString("lock_amount", "0")
            
            // Create main layout
            val mainLayout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(Color.parseColor("#FF1744")) // Red background
                gravity = Gravity.CENTER
                setPadding(40, 40, 40, 40)
            }
            
            // App icon and title
            val titleText = TextView(this).apply {
                text = "🔒 Fasst Pay - Device Locked"
                textSize = 24f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 30)
            }
            mainLayout.addView(titleText)
            
            // Lock message
            val messageText = TextView(this).apply {
                text = message
                textSize = 18f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding(20, 20, 20, 20)
            }
            mainLayout.addView(messageText)
            
            // Amount information
            if (amount != "0") {
                val amountText = TextView(this).apply {
                    text = "Overdue Amount: ₹$amount"
                    textSize = 20f
                    setTextColor(Color.YELLOW)
                    gravity = Gravity.CENTER
                    setPadding(0, 20, 0, 20)
                }
                mainLayout.addView(amountText)
            }
            
            // Instructions
            val instructionsText = TextView(this).apply {
                text = "📞 Contact your shopkeeper to make payment\n\n" +
                       "⚠️ This device will remain locked until payment is completed\n\n" +
                       "🔐 Device Admin protection is active"
                textSize = 16f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding(20, 30, 20, 30)
            }
            mainLayout.addView(instructionsText)
            
            // Contact button (if available)
            val contactButton = Button(this).apply {
                text = "📞 Contact Shopkeeper"
                textSize = 16f
                setBackgroundColor(Color.parseColor("#4CAF50"))
                setTextColor(Color.WHITE)
                setPadding(30, 15, 30, 15)
                
                setOnClickListener {
                    // Try to open dialer or contact app
                    try {
                        val dialIntent = Intent(Intent.ACTION_DIAL)
                        startActivity(dialIntent)
                    } catch (e: Exception) {
                        Log.e(TAG, "Could not open dialer: ${e.message}")
                    }
                }
            }
            mainLayout.addView(contactButton)
            
            // Device admin info
            val adminInfoText = TextView(this).apply {
                text = "\n🛡️ Device Administrator Protection Active\n" +
                       "This app cannot be uninstalled until EMI is completed"
                textSize = 14f
                setTextColor(Color.parseColor("#FFCDD2"))
                gravity = Gravity.CENTER
                setPadding(20, 20, 20, 0)
            }
            mainLayout.addView(adminInfoText)
            
            // Set content view
            setContentView(mainLayout)
            
            Log.d(TAG, "✅ Device Admin blocking interface created")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error creating blocking interface: ${e.message}", e)
            
            // Fallback - create simple blocking view
            val fallbackLayout = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                setBackgroundColor(Color.RED)
                gravity = Gravity.CENTER
            }
            
            val fallbackText = TextView(this).apply {
                text = "🔒 Device Locked - EMI Overdue\n\nContact shopkeeper for payment"
                textSize = 20f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding(40, 40, 40, 40)
            }
            fallbackLayout.addView(fallbackText)
            
            setContentView(fallbackLayout)
        }
    }
    
    /**
     * Block back button
     */
    override fun onBackPressed() {
        Log.d(TAG, "🚫 Back button blocked in Device Admin blocking activity")
        // Do nothing - completely block back button
    }
    
    /**
     * Block all key events
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_BACK,
            KeyEvent.KEYCODE_HOME,
            KeyEvent.KEYCODE_MENU,
            KeyEvent.KEYCODE_APP_SWITCH -> {
                Log.d(TAG, "🚫 Key blocked: $keyCode")
                return true // Block the key
            }
        }
        return super.onKeyDown(keyCode, event)
    }
    
    /**
     * Block key up events
     */
    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_BACK,
            KeyEvent.KEYCODE_HOME,
            KeyEvent.KEYCODE_MENU,
            KeyEvent.KEYCODE_APP_SWITCH -> {
                Log.d(TAG, "🚫 Key up blocked: $keyCode")
                return true // Block the key
            }
        }
        return super.onKeyUp(keyCode, event)
    }
    
    /**
     * Prevent activity from being paused/stopped
     */
    override fun onPause() {
        super.onPause()
        Log.d(TAG, "Activity paused - checking if should restart")
        
        // Check if EMI is still overdue
        val prefs = getSharedPreferences("overlay_prefs", Context.MODE_PRIVATE)
        val isEmiOverdue = prefs.getBoolean("emi_overdue_status", false)
        
        if (isEmiOverdue) {
            // Restart activity to bring it back to foreground
            val intent = Intent(this, DeviceAdminBlockingActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
            startActivity(intent)
        }
    }
    
    /**
     * Check device admin status
     */
    private fun isDeviceAdminActive(): Boolean {
        return try {
            val devicePolicyManager = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val adminComponent = AppDeviceAdminReceiver.getComponentName(this)
            devicePolicyManager.isAdminActive(adminComponent)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking device admin status: ${e.message}")
            false
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Device Admin Blocking Activity destroyed")
        
        // Clean up overlay if exists
        try {
            overlayView?.let { view ->
                windowManager?.removeView(view)
                overlayView = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error cleaning up overlay: ${e.message}")
        }
    }
}