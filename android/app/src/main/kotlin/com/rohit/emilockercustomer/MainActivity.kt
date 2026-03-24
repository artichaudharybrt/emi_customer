package com.rohit.emilockercustomer

import android.Manifest
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.view.KeyEvent
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val BACK_BUTTON_CHANNEL = "com.rohit.emilockercustomer/back_button"
    private val SYSTEM_OVERLAY_CHANNEL = "com.rohit.emilockercustomer/system_overlay"
    private val DEVICE_CONTROL_CHANNEL = "device_control"
    private val SIM_DETAILS_CHANNEL = "com.rohit.emilockercustomer/sim_details"
    private val LOCATION_TRACKING_CHANNEL = "com.rohit.emilockercustomer/location_tracking"
    private var isBackButtonBlocked = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // CRITICAL: Enable BootReceiver when app opens
        // Android requires app to be opened at least once for BOOT_COMPLETED to work
        try {
            val componentName = android.content.ComponentName(this, BootReceiver::class.java)
            packageManager.setComponentEnabledSetting(
                componentName,
                android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                android.content.pm.PackageManager.DONT_KILL_APP
            )
            android.util.Log.d("MainActivity", "✅ BootReceiver enabled")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ Error enabling BootReceiver: ${e.message}", e)
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Back button channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BACK_BUTTON_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableBackButtonBlocking" -> {
                    isBackButtonBlocked = true
                    result.success(null)
                }
                "disableBackButtonBlocking" -> {
                    isBackButtonBlocked = false
                    result.success(null)
                }
                "isBackButtonBlocked" -> {
                    result.success(isBackButtonBlocked)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // System overlay channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYSTEM_OVERLAY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkOverlayPermission" -> {
                    val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasPermission)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        }
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "showSystemOverlay" -> {
                    val message = call.argument<String>("message") ?: "Your EMI is overdue. Please contact shopkeeper."
                    val amount = call.argument<String>("amount") ?: "0"
                    
                    val serviceIntent = Intent(this, SystemOverlayService::class.java).apply {
                        action = "SHOW_OVERLAY"
                        putExtra("message", message)
                        putExtra("amount", amount)
                    }
                    
                    // CRITICAL: Always use startService() instead of startForegroundService()
                    // This avoids the 5-second timeout issue when service is restarting
                    // The service will call startForeground() itself in onStartCommand()
                    try {
                        android.util.Log.d("MainActivity", "Starting overlay service with startService()")
                        startService(serviceIntent)
                        result.success(null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error starting overlay service: ${e.message}", e)
                        result.error("SERVICE_ERROR", "Failed to start overlay service: ${e.message}", null)
                    }
                }
                "hideSystemOverlay" -> {
                    android.util.Log.e("MainActivity", "========== HIDE SYSTEM OVERLAY CALLED ==========")
                    
                    // CRITICAL: Clear native SharedPreferences FIRST, even if service is not running
                    // This ensures that on restart, the service won't show overlay again
                    try {
                        val prefs = getSharedPreferences("overlay_prefs", Context.MODE_PRIVATE)
                        val cleared = prefs.edit()
                            .putBoolean("is_locked", false)
                            .remove("lock_message")
                            .remove("lock_amount")
                            .commit() // Use commit() for immediate synchronous save
                        
                        if (cleared) {
                            android.util.Log.e("MainActivity", "✅✅✅ Native lock status cleared IMMEDIATELY ✅✅✅")
                        } else {
                            android.util.Log.e("MainActivity", "❌❌❌ CRITICAL: Failed to clear native lock status! ❌❌❌")
                        }
                        
                        // Verify it's cleared
                        val isStillLocked = prefs.getBoolean("is_locked", false)
                        if (isStillLocked) {
                            android.util.Log.e("MainActivity", "❌❌❌ CRITICAL: Native lock status still true! Force clearing... ❌❌❌")
                            prefs.edit().putBoolean("is_locked", false).commit()
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "❌ Error clearing native SharedPreferences: ${e.message}", e)
                    }
                    
                    // Now send intent to service to hide overlay (if service is running)
                    val intent = Intent(this, SystemOverlayService::class.java).apply {
                        action = "HIDE_OVERLAY"
                    }
                    
                    try {
                        // Use startService for hide to avoid foreground service timeout
                        // Service will call startForeground() if needed, or stop itself
                        startService(intent)
                        android.util.Log.e("MainActivity", "✅ Hide overlay intent sent to service")
                        result.success(null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "⚠️ Error sending hide intent (service might not be running): ${e.message}")
                        // This is OK - native SharedPreferences is already cleared
                        result.success(null) // Still return success - native prefs are cleared
                    }
                }
                "isSystemOverlayShowing" -> {
                    result.success(SystemOverlayService.isOverlayShowing)
                }
                "isNativeDeviceLocked" -> {
                    // Check native SharedPreferences directly
                    try {
                        val prefs = getSharedPreferences("overlay_prefs", Context.MODE_PRIVATE)
                        val isLocked = prefs.getBoolean("is_locked", false)
                        android.util.Log.d("MainActivity", "Native device lock status: $isLocked")
                        result.success(isLocked)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error checking native lock status: ${e.message}", e)
                        result.success(false) // Default to unlocked on error
                    }
                }
                "bringAppToForeground" -> {
                    try {
                        android.util.Log.d("MainActivity", "Bringing app to foreground...")
                        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        }
                        if (intent != null) {
                            startActivity(intent)
                            android.util.Log.d("MainActivity", "✅ App brought to foreground")
                            result.success(null)
                        } else {
                            android.util.Log.e("MainActivity", "❌ Could not get launch intent")
                            result.error("INTENT_ERROR", "Could not get launch intent", null)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "❌ Error bringing app to foreground: ${e.message}", e)
                        result.error("FOREGROUND_ERROR", "Failed to bring app to foreground: ${e.message}", null)
                    }
                }
                "showOverlayPermissionBlockingActivity" -> {
                    try {
                        android.util.Log.e("MainActivity", "========== SHOWING OVERLAY PERMISSION BLOCKING ACTIVITY ==========")
                        val intent = Intent(this, OverlayPermissionBlockingActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                            addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                            addFlags(Intent.FLAG_ACTIVITY_BROUGHT_TO_FRONT)
                        }
                        startActivity(intent)
                        
                        // Also bring app to foreground to ensure activity is visible
                        try {
                            val packageManager = packageManager
                            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                            launchIntent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            launchIntent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            startActivity(launchIntent)
                        } catch (e: Exception) {
                            android.util.Log.d("MainActivity", "Could not bring app to foreground: ${e.message}")
                        }
                        
                        android.util.Log.e("MainActivity", "✅✅✅ Overlay permission blocking activity shown ✅✅✅")
                        result.success(null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "❌❌❌ Error showing overlay permission blocking activity: ${e.message} ❌❌❌", e)
                        result.error("BLOCKING_ACTIVITY_ERROR", "Failed to show blocking activity: ${e.message}", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // Device Control channel (for device admin)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CONTROL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAccessibilityPermission" -> {
                    try {
                        // Open accessibility settings
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error opening accessibility settings: ${e.message}", e)
                        result.error("ACCESSIBILITY_ERROR", "Failed to open accessibility settings: ${e.message}", null)
                    }
                }
                "testProtectionOverlay" -> {
                    try {
                        android.util.Log.e("MainActivity", "========== TESTING PROTECTION OVERLAY ==========")
                        
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                            android.widget.Toast.makeText(this, "Enable \"Display over other apps\" for Fasst Pay first", android.widget.Toast.LENGTH_LONG).show()
                            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        
                        // Ask accessibility service to show the same overlay it uses for App info block
                        sendBroadcast(Intent(AppUsageMonitorService.ACTION_SHOW_TEST_OVERLAY))
                        android.util.Log.e("MainActivity", "✅ Test protection overlay broadcast sent - if Accessibility is ON you should see overlay")
                        android.widget.Toast.makeText(this, "If Protection is ON, overlay should appear", android.widget.Toast.LENGTH_SHORT).show()
                        result.success(null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "❌ Error testing protection overlay: ${e.message}", e)
                        result.error("TEST_ERROR", "Failed to test protection overlay: ${e.message}", null)
                    }
                }
                "isAccessibilityServiceEnabled" -> {
                    try {
                        val isEnabled = AppUsageMonitorService.isEnabled()
                        android.util.Log.e("MainActivity", "========== ACCESSIBILITY SERVICE STATUS CHECK ==========")
                        android.util.Log.e("MainActivity", "Service Enabled: $isEnabled")
                        
                        // Also check system settings
                        val enabledServices = android.provider.Settings.Secure.getString(
                            contentResolver,
                            android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                        )
                        android.util.Log.e("MainActivity", "System Enabled Services: $enabledServices")
                        
                        val serviceName = "com.rohit.emilockercustomer/com.rohit.emilockercustomer.AppUsageMonitorService"
                        val isInSystem = enabledServices?.contains(serviceName) == true
                        android.util.Log.e("MainActivity", "Service in System Settings: $isInSystem")
                        android.util.Log.e("MainActivity", "============================================================")
                        
                        result.success(isEnabled && isInSystem)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error checking accessibility service: ${e.message}", e)
                        result.success(false)
                    }
                }
                "testFasstPayDetection" -> {
                    try {
                        android.util.Log.e("MainActivity", "========== TESTING FASST PAY DETECTION ==========")
                        
                        // Open Settings > Apps to trigger detection
                        val intent = Intent(android.provider.Settings.ACTION_APPLICATION_SETTINGS).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        
                        android.util.Log.e("MainActivity", "✅ Opened Settings > Apps")
                        android.util.Log.e("MainActivity", "📱 Now tap on Fasst Pay app - overlay should appear!")
                        android.util.Log.e("MainActivity", "============================================================")
                        
                        result.success(null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "❌ Error opening settings: ${e.message}", e)
                        result.error("SETTINGS_ERROR", "Failed to open settings: ${e.message}", null)
                    }
                }
                "requestAdmin" -> {
                    try {
                        val devicePolicyManager = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val adminComponent = AppDeviceAdminReceiver.getComponentName(this)
                        
                        if (devicePolicyManager.isAdminActive(adminComponent)) {
                            android.util.Log.d("MainActivity", "✅ Device admin already enabled")
                            result.success(true)
                        } else {
                            // Request device admin permission
                            android.util.Log.d("MainActivity", "Requesting device admin permission...")
                            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
                                putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                                    "Fasst Pay needs device administrator access to:\n\n" +
                                    "• Prevent app uninstallation during EMI period\n" +
                                    "• Lock device remotely for payment security\n" +
                                    "• Monitor unauthorized access attempts\n" +
                                    "• Ensure EMI payment compliance\n\n" +
                                    "This permission can be revoked after EMI completion.\n\n" +
                                    "You agreed to these terms when taking the loan.")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(null) // Return null - user will grant/deny in system dialog
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error requesting device admin: ${e.message}", e)
                        result.error("DEVICE_ADMIN_ERROR", "Failed to request device admin: ${e.message}", null)
                    }
                }
                "isAdminActive" -> {
                    try {
                        val devicePolicyManager = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val adminComponent = AppDeviceAdminReceiver.getComponentName(this)
                        val isActive = devicePolicyManager.isAdminActive(adminComponent)
                        android.util.Log.d("MainActivity", "Device admin status check: $isActive")
                        result.success(isActive)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error checking device admin status: ${e.message}", e)
                        result.success(false)
                    }
                }
                "lockNow" -> {
                    try {
                        val devicePolicyManager = getSystemService(DEVICE_POLICY_SERVICE) as DevicePolicyManager
                        val adminComponent = AppDeviceAdminReceiver.getComponentName(this)
                        
                        if (!devicePolicyManager.isAdminActive(adminComponent)) {
                            android.util.Log.e("MainActivity", "❌ Device admin not active - cannot lock")
                            result.error("DEVICE_ADMIN_NOT_ACTIVE", "Device admin permission not granted", null)
                        } else {
                            android.util.Log.e("MainActivity", "========== LOCKING DEVICE NOW ==========")
                            devicePolicyManager.lockNow()
                            android.util.Log.e("MainActivity", "✅ Device locked successfully")
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "❌ Error locking device: ${e.message}", e)
                        result.error("LOCK_ERROR", "Failed to lock device: ${e.message}", null)
                    }
                }
                "showBlockingActivity" -> {
                    try {
                        val message = call.argument<String>("message") ?: "Your EMI is overdue. Please contact shopkeeper."
                        val amount = call.argument<String>("amount") ?: "0"
                        
                        // Save lock info to SharedPreferences
                        val prefs = getSharedPreferences("overlay_prefs", Context.MODE_PRIVATE)
                        prefs.edit()
                            .putString("lock_message", message)
                            .putString("lock_amount", amount)
                            .putBoolean("emi_overdue_status", true)
                            .commit()
                        
                        // Open blocking activity
                        val intent = Intent(this, DeviceAdminBlockingActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        }
                        startActivity(intent)
                        android.util.Log.d("MainActivity", "✅ Blocking activity shown")
                        result.success(null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "❌ Error showing blocking activity: ${e.message}", e)
                        result.error("BLOCKING_ACTIVITY_ERROR", "Failed to show blocking activity: ${e.message}", null)
                    }
                }
                "hideBlockingActivity" -> {
                    try {
                        // Clear EMI overdue status
                        val prefs = getSharedPreferences("overlay_prefs", Context.MODE_PRIVATE)
                        prefs.edit()
                            .putBoolean("emi_overdue_status", false)
                            .commit()
                        
                        // Close blocking activity if open
                        val intent = Intent(this, DeviceAdminBlockingActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        }
                        intent.putExtra("finish", true)
                        startActivity(intent)
                        
                        android.util.Log.d("MainActivity", "✅ Blocking activity hidden")
                        result.success(null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "❌ Error hiding blocking activity: ${e.message}", e)
                        result.success(null) // Don't fail - status is cleared
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // SIM / Phone details channel - for posting SIM details after permission grant
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIM_DETAILS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "markSimDetailsPosted" -> {
                    try {
                        SimChangeReceiver.saveCurrentSimId(this)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", e.message, null)
                    }
                }
                "getSimDetails" -> {
                    try {
                        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE) != PackageManager.PERMISSION_GRANTED) {
                            result.error("PERMISSION_DENIED", "READ_PHONE_STATE not granted", null)
                            return@setMethodCallHandler
                        }
                        val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                        val details = mutableMapOf<String, Any?>()
                        // Line1 number (may be null on many carriers)
                        var phoneNumber: String? = null
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_NUMBERS) == PackageManager.PERMISSION_GRANTED) {
                                phoneNumber = tm.line1Number?.takeIf { it.isNotBlank() }
                            }
                        }
                        if (phoneNumber.isNullOrBlank()) {
                            @Suppress("DEPRECATION")
                            phoneNumber = tm.line1Number?.takeIf { it.isNotBlank() }
                        }
                        details["phoneNumber"] = phoneNumber
                        details["simOperatorName"] = tm.simOperatorName?.takeIf { it.isNotBlank() } ?: ""
                        details["simCountryIso"] = tm.simCountryIso?.takeIf { it.isNotBlank() } ?: ""
                        details["networkOperatorName"] = tm.networkOperatorName?.takeIf { it.isNotBlank() } ?: ""
                        details["simCount"] = tm.phoneCount
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            try {
                                @Suppress("DEPRECATION")
                                details["deviceId"] = tm.deviceId
                            } catch (e: SecurityException) {
                                details["deviceId"] = null
                            }
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                            val subMgr = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                            val subs = subMgr?.activeSubscriptionInfoList
                            val carrierNames = mutableListOf<String>()
                            val numbers = mutableListOf<String>()
                            if (subs != null) {
                                for (info in subs) {
                                    info.carrierName?.toString()?.takeIf { it.isNotBlank() }?.let { carrierNames.add(it) }
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                        info.number?.takeIf { it.isNotBlank() }?.let { numbers.add(it) }
                                    }
                                }
                            }
                            details["carrierNames"] = carrierNames
                            if (numbers.isNotEmpty()) details["simNumbers"] = numbers
                        }
                        android.util.Log.d("MainActivity", "SIM details: phoneNumber=$phoneNumber, simCount=${details["simCount"]}")
                        result.success(details)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error getting SIM details: ${e.message}", e)
                        result.error("SIM_ERROR", "Failed to get SIM details: ${e.message}", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOCATION_TRACKING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    try {
                        LocationTrackingService.start(this)
                        result.success(null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "LocationTracking start: ${e.message}", e)
                        result.error("LOCATION_TRACKING_ERROR", e.message, null)
                    }
                }
                "stop" -> {
                    try {
                        LocationTrackingService.stop(this)
                        result.success(null)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "LocationTracking stop: ${e.message}", e)
                        result.error("LOCATION_TRACKING_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onBackPressed() {
        if (isBackButtonBlocked) {
            // Completely ignore back button when blocked
            android.util.Log.d("MainActivity", "🚫 Back button blocked - device is locked")
            android.util.Log.d("MainActivity", "Back button press completely ignored")
            return
        }
        // Allow normal back button behavior when not blocked
        super.onBackPressed()
    }
    
    override fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (isBackButtonBlocked && keyCode == KeyEvent.KEYCODE_BACK) {
            android.util.Log.d("MainActivity", "🚫 Back button onKeyDown blocked")
            return true // Consume the event
        }
        return super.onKeyDown(keyCode, event)
    }
    
    override fun onKeyUp(keyCode: Int, event: KeyEvent): Boolean {
        if (isBackButtonBlocked && keyCode == KeyEvent.KEYCODE_BACK) {
            android.util.Log.d("MainActivity", "🚫 Back button onKeyUp blocked")
            return true // Consume the event
        }
        return super.onKeyUp(keyCode, event)
    }
    
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (isBackButtonBlocked && event.keyCode == KeyEvent.KEYCODE_BACK) {
            android.util.Log.d("MainActivity", "🚫 Back button dispatchKeyEvent blocked")
            return true // Consume the event
        }
        return super.dispatchKeyEvent(event)
    }
}
