package com.rohit.emilockercustomer

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.location.Location
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.Tasks
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONObject
import java.io.OutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.Locale
import java.util.concurrent.TimeUnit

/**
 * Firebase Cloud Messaging Service
 * Handles FCM messages in background (even when app is closed)
 * 
 * This service receives FCM messages and starts SystemOverlayService
 * for lock/unlock commands, ensuring overlay shows even when app is closed.
 */
class MyFirebaseMessagingService : FirebaseMessagingService() {
    
    companion object {
        private const val TAG = "FcmService"
        private const val PREFS_NAME = "overlay_prefs"
        private const val KEY_IS_LOCKED = "is_locked"
        private const val KEY_LOCK_MESSAGE = "lock_message"
        private const val KEY_LOCK_AMOUNT = "lock_amount"
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.e(TAG, "========== FCM SERVICE CREATED ==========")
    }
    
    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.e(TAG, "========== FCM MESSAGE RECEIVED ==========")
        Log.e(TAG, "Message ID: ${remoteMessage.messageId}")
        Log.e(TAG, "From: ${remoteMessage.from}")
        Log.e(TAG, "Data: ${remoteMessage.data}")
        
        // Get data from message
        val data = remoteMessage.data
        
        // Check if message has type
        if (data.containsKey("type")) {
            val type = (data["type"] as? String ?: "").trim()
            Log.e(TAG, "Message type: [$type] length=${type.length}")
            
            when {
                type == "lock_command" -> handleLockCommand(data)
                type == "unlock_command" || type == "extend_payment" -> handleUnlockCommand(data)
                type == "get_location_command" -> handleGetLocationCommand()
                type == "get_sim_details_command" || type.contains("get_sim_details") -> {
                    Log.e(TAG, "Matched get_sim_details_command -> calling handleGetSimDetailsCommand()")
                    handleGetSimDetailsCommand()
                }
                type == "can_user_uninstall_sync" -> handleCanUserUninstallSync(data)
                else -> Log.w(TAG, "Unknown message type: $type")
            }
        } else {
            Log.w(TAG, "Message has no type field")
        }
        // Keep foreground session/location pipeline warm after any FCM wake-up
        try {
            BackgroundGuard.ensureRunning(applicationContext)
        } catch (e: Exception) {
            Log.w(TAG, "BackgroundGuard after FCM: ${e.message}")
        }
    }
    
    /**
     * Handle lock command from FCM
     * Starts SystemOverlayService to show overlay
     */
    private fun handleLockCommand(data: Map<String, String>) {
        Log.e(TAG, "========== LOCK COMMAND RECEIVED ==========")
        
        // Extract message and amount
        val message = data["message"] ?: 
                     data["reason"] ?: 
                     "Your EMI is overdue. Please contact shopkeeper."
        val amount = data["amount"] ?: 
                    data["overdueAmount"] ?: 
                    "0"
        
        Log.e(TAG, "Lock message: $message")
        Log.e(TAG, "Lock amount: $amount")
        
        // CRITICAL: Save lock status in SharedPreferences FIRST
        // This ensures BootReceiver can read it on boot
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_IS_LOCKED, true)
            .putString(KEY_LOCK_MESSAGE, message)
            .putString(KEY_LOCK_AMOUNT, amount)
            .commit() // Use commit() to ensure immediate save
        
        Log.e(TAG, "✅ Lock status saved to SharedPreferences")
        
        // Start SystemOverlayService to show overlay
        try {
            val serviceIntent = Intent(this, SystemOverlayService::class.java).apply {
                action = "SHOW_OVERLAY"
                putExtra("message", message)
                putExtra("amount", amount)
            }
            
            // CRITICAL: Use startService() to start overlay service
            // This works even when app is closed
            startService(serviceIntent)
            Log.e(TAG, "✅✅✅ OVERLAY SERVICE STARTED FROM FCM ✅✅✅")
            Log.e(TAG, "Overlay should be showing now (even if app is closed)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error starting overlay service: ${e.message}", e)
        }
    }
    
    /**
     * Handle unlock command from FCM
     * Stops SystemOverlayService to hide overlay
     */
    private fun handleUnlockCommand(data: Map<String, String>) {
        Log.e(TAG, "========== UNLOCK COMMAND RECEIVED ==========")
        
        // CRITICAL: Clear lock status from SharedPreferences FIRST
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putBoolean(KEY_IS_LOCKED, false)
            .remove(KEY_LOCK_MESSAGE)
            .remove(KEY_LOCK_AMOUNT)
            .commit() // Use commit() to ensure immediate save
        
        Log.e(TAG, "✅ Lock status cleared from SharedPreferences")
        
        // Stop SystemOverlayService to hide overlay
        try {
            val serviceIntent = Intent(this, SystemOverlayService::class.java).apply {
                action = "HIDE_OVERLAY"
            }
            
            // Start service with HIDE_OVERLAY action to stop overlay
            startService(serviceIntent)
            Log.e(TAG, "✅✅✅ OVERLAY SERVICE STOPPED FROM FCM ✅✅✅")
            Log.e(TAG, "Overlay should be hidden now")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping overlay service: ${e.message}", e)
        }
    }
    
    /**
     * When FCM type=get_sim_details_command: get SIM details and POST to /device-sim-details.
     * Runs in background via SimChangeReceiver.
     */
    private fun handleGetSimDetailsCommand() {
        Log.e(TAG, "========== GET SIM DETAILS COMMAND RECEIVED ==========")
        Log.e(TAG, "[SIM] Calling postSimDetailsForFcm (background)...")
        SimChangeReceiver.postSimDetailsForFcm(this)
    }

    /**
     * FCM data-only: type=can_user_uninstall_sync, canUserUninstallFlag=true|false
     * true → [AppUsageMonitorService] skips blocking overlays (Settings/uninstall/factory reset).
     * false → blocking overlays active again.
     */
    private fun handleCanUserUninstallSync(data: Map<String, String>) {
        Log.e(TAG, "========== CAN_USER_UNINSTALL_SYNC (native FCM) ==========")
        val raw = data["canUserUninstallFlag"]?.trim().orEmpty().ifEmpty { "false" }
        val allowed = raw.equals("true", ignoreCase = true) ||
            raw == "1" ||
            raw.equals("yes", ignoreCase = true)
        getSharedPreferences("protection_prefs", Context.MODE_PRIVATE)
            .edit()
            .putBoolean("can_user_uninstall", allowed)
            .commit()
        Log.e(TAG, "✅ protection_prefs can_user_uninstall=$allowed (true=disable EMI protection overlays)")
    }

    /**
     * When FCM type=get_location_command: get current location and POST to /user-locations.
     * Runs on background thread so it does not block FCM.
     */
    private fun handleGetLocationCommand() {
        Log.e(TAG, "========== GET LOCATION COMMAND RECEIVED ==========")
        Thread {
            try {
                val token = getFlutterAuthToken()
                if (token.isNullOrEmpty()) {
                    Log.w(TAG, "get_location_command: No auth token")
                    return@Thread
                }
                val location = getLastOrCurrentLocation()
                if (location == null) {
                    Log.w(TAG, "get_location_command: No location")
                    return@Thread
                }
                val body = JSONObject().apply {
                    put("latitude", location.first)
                    put("longitude", location.second)
                    put("accuracy", location.third)
                    put("recordedAt", java.text.SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply { timeZone = java.util.TimeZone.getTimeZone("UTC") }.format(java.util.Date()))
                }
                postUserLocation(token, body)
            } catch (e: Exception) {
                Log.e(TAG, "get_location_command error: ${e.message}", e)
            }
        }.start()
    }

    private fun getFlutterAuthToken(): String? {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            prefs.getString("flutter.auth_token", null)?.takeIf { it.isNotEmpty() }
        } catch (e: Exception) {
            Log.e(TAG, "getFlutterAuthToken: ${e.message}")
            null
        }
    }

    /**
     * 1) Cache from [LocationTrackingService] (foreground updates while logged in)
     * 2) Fused single fix (timeout)
     * 3) Last known GPS/network (often null/stale when app was never opened)
     */
    @Suppress("DEPRECATION")
    private fun getLastOrCurrentLocation(): Triple<Double, Double, Double>? {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "get_location_command: No location permission")
            return null
        }
        LocationTrackingService.readCachedLocation(this, 45 * 60 * 1000L)?.let {
            Log.e(TAG, "get_location_command: Using tracking cache → lat=${it.first}, lng=${it.second}")
            return it
        }
        fusedGetCurrentLocation()?.let { return it }
        val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager ?: return null
        // Try GPS first (real device in India → correct coords). Network often gives wrong location.
        val providers = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        } else {
            @Suppress("DEPRECATION")
            listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        }
        for (provider in providers) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!lm.isProviderEnabled(provider)) continue
            } else {
                @Suppress("DEPRECATION")
                if (!lm.isProviderEnabled(provider)) continue
            }
            val loc = lm.getLastKnownLocation(provider) ?: continue
            val accuracy = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && loc.hasAccuracy()) loc.accuracy.toDouble() else 0.0
            Log.e(TAG, "get_location_command: Using $provider → lat=${loc.latitude}, lng=${loc.longitude}")
            return Triple(loc.latitude, loc.longitude, accuracy)
        }
        Log.w(TAG, "get_location_command: No location from GPS or Network")
        return null
    }

    private fun fusedGetCurrentLocation(): Triple<Double, Double, Double>? {
        return try {
            val client = LocationServices.getFusedLocationProviderClient(applicationContext)
            val task = client.getCurrentLocation(
                Priority.PRIORITY_BALANCED_POWER_ACCURACY,
                null,
            )
            val loc: Location = Tasks.await(task, 18, TimeUnit.SECONDS) ?: return null
            val acc = if (loc.hasAccuracy()) loc.accuracy.toDouble() else 0.0
            Log.e(TAG, "get_location_command: Fused getCurrentLocation → lat=${loc.latitude}, lng=${loc.longitude}")
            Triple(loc.latitude, loc.longitude, acc)
        } catch (e: Exception) {
            Log.w(TAG, "get_location_command: fused getCurrentLocation failed: ${e.message}")
            null
        }
    }

    private fun postUserLocation(authToken: String, body: JSONObject) {
        var conn: HttpURLConnection? = null
        try {
            val url = URL("https://dev.api.fasstpay.co/api/user-locations")
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json")
            conn.setRequestProperty("Authorization", "Bearer $authToken")
            conn.doOutput = true
            conn.connectTimeout = 15000
            conn.readTimeout = 15000
            conn.outputStream.use { os: OutputStream ->
                os.write(body.toString().toByteArray(Charsets.UTF_8))
            }
            val code = conn.responseCode
            if (code in 200..299) {
                Log.e(TAG, "✅ user-locations POST success: $code")
            } else {
                Log.w(TAG, "user-locations POST failed: $code ${conn.responseMessage}")
            }
        } catch (e: Exception) {
            Log.e(TAG, "postUserLocation error: ${e.message}", e)
        } finally {
            conn?.disconnect()
        }
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "========== NEW FCM TOKEN ==========")
        Log.d(TAG, "Token: ${token.take(20)}...")
        // Token will be registered by Flutter FCM service
        super.onNewToken(token)
    }
}


