package com.rohit.emilockercustomer

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority

/**
 * Foreground service that keeps an up-to-date location cache while the user is logged in.
 * FCM [get_location_command] reads this cache in [MyFirebaseMessagingService] so the shopkeeper
 * gets coordinates even when the user is not actively opening the app.
 */
class LocationTrackingService : Service() {

    private var fusedClient: FusedLocationProviderClient? = null
    private var locationCallback: LocationCallback? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        fusedClient = LocationServices.getFusedLocationProviderClient(this)
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopTracking()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        if (!hasLocationPermission()) {
            Log.w(TAG, "No location permission — not starting")
            stopSelf()
            return START_NOT_STICKY
        }
        if (!hasFlutterAuthToken()) {
            Log.w(TAG, "No auth token — not starting")
            stopSelf()
            return START_NOT_STICKY
        }

        try {
            SessionKeepAliveService.stop(this)
        } catch (_: Exception) {
        }

        startForegroundWithType()
        startLocationUpdates()
        return START_STICKY
    }

    private fun startForegroundWithType() {
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (BackgroundGuard.hasFlutterAuthToken(this)) {
            Handler(Looper.getMainLooper()).postDelayed({
                BackgroundGuard.ensureRunning(applicationContext)
            }, 800L)
        }
    }

    private fun startLocationUpdates() {
        val client = fusedClient ?: return
        locationCallback?.let { cb ->
            try {
                client.removeLocationUpdates(cb)
            } catch (_: Exception) {
            }
        }

        val request = LocationRequest.Builder(Priority.PRIORITY_BALANCED_POWER_ACCURACY, UPDATE_INTERVAL_MS)
            .setMinUpdateIntervalMillis(MIN_UPDATE_INTERVAL_MS)
            .setMaxUpdateDelayMillis(MAX_UPDATE_DELAY_MS)
            .build()

        val cb = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val loc = result.lastLocation ?: return
                val acc = if (loc.hasAccuracy()) loc.accuracy.toDouble() else 0.0
                cacheLocation(loc.latitude, loc.longitude, acc)
            }
        }
        locationCallback = cb
        try {
            client.requestLocationUpdates(request, cb, mainLooper)
        } catch (e: SecurityException) {
            Log.e(TAG, "requestLocationUpdates: ${e.message}", e)
        }
    }

    private fun cacheLocation(lat: Double, lng: Double, accuracy: Double) {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
            .putString(KEY_LAT, lat.toString())
            .putString(KEY_LNG, lng.toString())
            .putString(KEY_ACC, accuracy.toString())
            .putLong(KEY_TIME, System.currentTimeMillis())
            .apply()
        Log.d(TAG, "Cached location lat=$lat lng=$lng acc=$accuracy")
    }

    private fun stopTracking() {
        val cb = locationCallback ?: return
        val client = fusedClient ?: return
        try {
            client.removeLocationUpdates(cb)
        } catch (_: Exception) {
        }
        locationCallback = null
    }

    override fun onDestroy() {
        stopTracking()
        super.onDestroy()
    }

    private fun hasFlutterAuthToken(): Boolean {
        val t = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
            .getString("flutter.auth_token", null)
        return !t.isNullOrEmpty()
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Location sharing",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Updates your last known location for EMI account security while you are logged in"
                setShowBadge(false)
            }
            (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val launch = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        val pending = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Fasst Pay active")
            .setContentText("Location is updated periodically for your EMI account security")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pending)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    companion object {
        private const val TAG = "LocationTrackingSvc"
        const val PREFS = "location_tracking_cache"
        const val KEY_LAT = "lat"
        const val KEY_LNG = "lng"
        const val KEY_ACC = "accuracy"
        const val KEY_TIME = "time_ms"
        const val ACTION_START = "com.rohit.emilockercustomer.location.START"
        const val ACTION_STOP = "com.rohit.emilockercustomer.location.STOP"
        private const val NOTIFICATION_ID = 91002
        private const val CHANNEL_ID = "location_tracking_channel"
        private const val UPDATE_INTERVAL_MS = 120_000L
        private const val MIN_UPDATE_INTERVAL_MS = 60_000L
        private const val MAX_UPDATE_DELAY_MS = 300_000L

        fun hasFlutterAuthToken(context: Context): Boolean {
            val t = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.auth_token", null)
            return !t.isNullOrEmpty()
        }

        fun hasLocationPermission(context: Context): Boolean {
            return ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        }

        fun shouldRun(context: Context): Boolean {
            return hasFlutterAuthToken(context) && hasLocationPermission(context)
        }

        fun start(context: Context) {
            if (!shouldRun(context)) {
                Log.d(TAG, "start skipped (no token or no location permission)")
                return
            }
            val intent = Intent(context, LocationTrackingService::class.java).apply { action = ACTION_START }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, LocationTrackingService::class.java).apply { action = ACTION_STOP }
            context.startService(intent)
        }

        fun readCachedLocation(context: Context, maxAgeMs: Long): Triple<Double, Double, Double>? {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val t = p.getLong(KEY_TIME, 0L)
            if (t == 0L) return null
            if (System.currentTimeMillis() - t > maxAgeMs) return null
            val lat = p.getString(KEY_LAT, null)?.toDoubleOrNull() ?: return null
            val lng = p.getString(KEY_LNG, null)?.toDoubleOrNull() ?: return null
            val acc = p.getString(KEY_ACC, null)?.toDoubleOrNull() ?: 0.0
            return Triple(lat, lng, acc)
        }
    }
}
