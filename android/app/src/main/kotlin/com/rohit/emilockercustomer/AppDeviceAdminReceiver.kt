package com.rohit.emilockercustomer

import android.app.admin.DeviceAdminReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import android.widget.Toast

/**
 * Device Admin Receiver for Fasst Pay App
 * 
 * This receiver handles device admin events and prevents app uninstallation
 * when the device is locked for EMI payments.
 * 
 * Key Features:
 * - Prevents app uninstallation during EMI period
 * - Allows remote device locking via FCM
 * - Monitors device admin status changes
 * 
 * Legal Compliance:
 * - User must explicitly consent to device admin activation
 * - Clear explanation of permissions and their purpose
 * - Option to deactivate when EMI is completed
 */
class AppDeviceAdminReceiver : DeviceAdminReceiver() {
    
    companion object {
        private const val TAG = "AppDeviceAdminReceiver"
        
        /**
         * Get ComponentName for this device admin receiver
         */
        fun getComponentName(context: Context): ComponentName {
            return ComponentName(context, AppDeviceAdminReceiver::class.java)
        }
    }
    
    /**
     * Called when device admin is enabled
     * This prevents the app from being uninstalled
     */
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "Device Admin enabled - App protection activated")
        
        // Save device admin status
        val prefs = context.getSharedPreferences("device_admin_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("is_device_admin_active", true).apply()
        
        // Show confirmation to user
        Toast.makeText(context, "Fasst Pay Admin activated - App is now protected", Toast.LENGTH_LONG).show()
        
        // Notify Flutter app about device admin status
        notifyFlutterApp(context, "device_admin_enabled", true)
    }
    
    /**
     * Called when device admin is disabled
     * This allows the app to be uninstalled again
     */
    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d(TAG, "Device Admin disabled - App protection deactivated")
        
        // Save device admin status
        val prefs = context.getSharedPreferences("device_admin_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("is_device_admin_active", false).apply()
        
        // Show confirmation to user
        Toast.makeText(context, "Fasst Pay Admin deactivated - App can now be uninstalled", Toast.LENGTH_LONG).show()
        
        // Notify Flutter app about device admin status
        notifyFlutterApp(context, "device_admin_disabled", false)
    }
    
    /**
     * Called when user tries to disable device admin
     * We can show a warning message here
     */
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        Log.d(TAG, "Device Admin disable requested")
        
        // Return a message that will be shown to the user
        return "Disabling Fasst Pay Admin will allow app uninstallation. " +
               "Please ensure your EMI payments are completed before proceeding."
    }
    
    /**
     * Called when password changed
     */
    override fun onPasswordChanged(context: Context, intent: Intent) {
        super.onPasswordChanged(context, intent)
        Log.d(TAG, "Device password changed")
        
        // Notify Flutter app about password change
        notifyFlutterApp(context, "password_changed", true)
    }
    
    /**
     * Called when password failed
     */
    override fun onPasswordFailed(context: Context, intent: Intent) {
        super.onPasswordFailed(context, intent)
        Log.d(TAG, "Device password failed")
        
        // Notify Flutter app about password failure
        notifyFlutterApp(context, "password_failed", true)
    }
    
    /**
     * Called when password succeeded
     */
    override fun onPasswordSucceeded(context: Context, intent: Intent) {
        super.onPasswordSucceeded(context, intent)
        Log.d(TAG, "Device password succeeded")
        
        // Notify Flutter app about password success
        notifyFlutterApp(context, "password_succeeded", true)
    }
    
    /**
     * Notify Flutter app about device admin events
     */
    private fun notifyFlutterApp(context: Context, event: String, value: Boolean) {
        try {
            val intent = Intent("com.rohit.emilockercustomer.DEVICE_ADMIN_EVENT")
            intent.putExtra("event", event)
            intent.putExtra("value", value)
            context.sendBroadcast(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to notify Flutter app: ${e.message}")
        }
    }
}