package com.rohit.emilockercustomer

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Device Admin Manager for Fasst Pay App
 * 
 * This class handles all device admin operations including:
 * - Checking device admin status
 * - Requesting device admin activation
 * - Locking device remotely
 * - Preventing app uninstallation
 * 
 * Integration with Flutter:
 * - Provides method channel for Flutter communication
 * - Handles device admin permission requests
 * - Returns status updates to Flutter app
 */
class DeviceAdminManager(private val activity: Activity) : MethodCallHandler {
    
    companion object {
        private const val TAG = "DeviceAdminManager"
        private const val CHANNEL_NAME = "device_admin_channel"
        const val REQUEST_CODE_ENABLE_ADMIN = 1001
    }
    
    private val devicePolicyManager: DevicePolicyManager by lazy {
        activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    }
    
    private val adminComponent: ComponentName by lazy {
        ComponentName(activity, AppDeviceAdminReceiver::class.java)
    }
    
    private var methodChannel: MethodChannel? = null
    private var pendingResult: Result? = null
    
    /**
     * Initialize method channel for Flutter communication
     */
    fun initializeChannel(channel: MethodChannel) {
        methodChannel = channel
        channel.setMethodCallHandler(this)
    }
    
    /**
     * Handle method calls from Flutter
     */
    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isDeviceAdminActive" -> {
                result.success(isDeviceAdminActive())
            }
            "requestDeviceAdminPermission" -> {
                requestDeviceAdminPermission(result)
            }
            "lockDevice" -> {
                val success = lockDevice()
                result.success(success)
            }
            "isDeviceAdminSupported" -> {
                result.success(true) // Android always supports device admin
            }
            "getDeviceAdminInfo" -> {
                result.success(getDeviceAdminInfo())
            }
            "deactivateDeviceAdmin" -> {
                val success = deactivateDeviceAdmin()
                result.success(success)
            }
            else -> {
                result.notImplemented()
            }
        }
    }
    
    /**
     * Check if device admin is currently active
     */
    fun isDeviceAdminActive(): Boolean {
        return try {
            devicePolicyManager.isAdminActive(adminComponent)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking device admin status: ${e.message}")
            false
        }
    }
    
    /**
     * Request device admin permission from user
     */
    private fun requestDeviceAdminPermission(result: Result) {
        try {
            if (isDeviceAdminActive()) {
                result.success(true)
                return
            }
            
            pendingResult = result
            
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                putExtra(
                    DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                    "Fasst Pay needs device admin access to:\n\n" +
                    "• Prevent app uninstallation during EMI period\n" +
                    "• Lock device remotely for payment security\n" +
                    "• Monitor unauthorized access attempts\n" +
                    "• Ensure EMI payment compliance\n\n" +
                    "This permission can be revoked after EMI completion."
                )
            }
            
            activity.startActivityForResult(intent, REQUEST_CODE_ENABLE_ADMIN)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error requesting device admin permission: ${e.message}")
            result.error("DEVICE_ADMIN_ERROR", "Failed to request device admin permission", e.message)
        }
    }
    
    /**
     * Handle activity result for device admin permission
     */
    fun handleActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_CODE_ENABLE_ADMIN) {
            val success = resultCode == Activity.RESULT_OK && isDeviceAdminActive()
            
            pendingResult?.let { result ->
                if (success) {
                    Log.d(TAG, "Device admin activated successfully")
                    result.success(true)
                    
                    // Notify Flutter about successful activation
                    methodChannel?.invokeMethod("onDeviceAdminActivated", mapOf(
                        "success" to true,
                        "message" to "Device admin activated successfully"
                    ))
                } else {
                    Log.w(TAG, "Device admin activation failed or cancelled")
                    result.success(false)
                    
                    // Notify Flutter about failed activation
                    methodChannel?.invokeMethod("onDeviceAdminActivated", mapOf(
                        "success" to false,
                        "message" to "Device admin activation failed or cancelled"
                    ))
                }
                pendingResult = null
            }
        }
    }
    
    /**
     * Lock the device immediately
     */
    fun lockDevice(): Boolean {
        return try {
            if (!isDeviceAdminActive()) {
                Log.w(TAG, "Cannot lock device - device admin not active")
                return false
            }
            
            devicePolicyManager.lockNow()
            Log.d(TAG, "Device locked successfully")
            true
            
        } catch (e: Exception) {
            Log.e(TAG, "Error locking device: ${e.message}")
            false
        }
    }
    
    /**
     * Get device admin information
     */
    private fun getDeviceAdminInfo(): Map<String, Any> {
        return mapOf(
            "isActive" to isDeviceAdminActive(),
            "componentName" to adminComponent.className,
            "packageName" to adminComponent.packageName,
            "canLockDevice" to (isDeviceAdminActive() && devicePolicyManager.isAdminActive(adminComponent)),
            "canWipeData" to (isDeviceAdminActive() && devicePolicyManager.isAdminActive(adminComponent)),
            "description" to "Fasst Pay Device Administrator - Prevents app uninstallation during EMI period"
        )
    }
    
    /**
     * Deactivate device admin (should only be called when EMI is completed)
     */
    private fun deactivateDeviceAdmin(): Boolean {
        return try {
            if (!isDeviceAdminActive()) {
                return true // Already deactivated
            }
            
            // Note: We cannot programmatically deactivate device admin
            // User must do it manually through Settings > Security > Device administrators
            // We can only guide them to the settings
            
            val intent = Intent().apply {
                action = "android.settings.SECURITY_SETTINGS"
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            
            activity.startActivity(intent)
            
            // Return false because deactivation requires manual user action
            false
            
        } catch (e: Exception) {
            Log.e(TAG, "Error opening device admin settings: ${e.message}")
            false
        }
    }
    
    /**
     * Check if device can be locked (device admin active and has lock permission)
     */
    fun canLockDevice(): Boolean {
        return isDeviceAdminActive() && devicePolicyManager.isAdminActive(adminComponent)
    }
    
    /**
     * Get device admin status for debugging
     */
    fun getDebugInfo(): String {
        return buildString {
            appendLine("=== Device Admin Debug Info ===")
            appendLine("Admin Active: ${isDeviceAdminActive()}")
            appendLine("Component: ${adminComponent.className}")
            appendLine("Package: ${adminComponent.packageName}")
            appendLine("Can Lock: ${canLockDevice()}")
            
            try {
                val activeAdmins = devicePolicyManager.activeAdmins
                appendLine("Active Admins Count: ${activeAdmins?.size ?: 0}")
                activeAdmins?.forEach { admin ->
                    appendLine("  - ${admin.className}")
                }
            } catch (e: Exception) {
                appendLine("Error getting active admins: ${e.message}")
            }
        }
    }
}