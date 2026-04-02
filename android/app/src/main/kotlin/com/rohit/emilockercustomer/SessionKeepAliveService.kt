package com.rohit.emilockercustomer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Foreground service when user is logged in but location is not granted.
 * Keeps process alive so FCM (lock, get_location best-effort, SIM) is more reliable on aggressive OEMs.
 */
class SessionKeepAliveService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                stopForeground(STOP_FOREGROUND_REMOVE)
            } else {
                @Suppress("DEPRECATION")
                stopForeground(true)
            }
            stopSelf()
            return START_NOT_STICKY
        }

        if (!BackgroundGuard.hasFlutterAuthToken(this)) {
            Log.w(TAG, "No auth token — stopping")
            stopSelf()
            return START_NOT_STICKY
        }
        if (LocationTrackingService.hasLocationPermission(this)) {
            Log.d(TAG, "Location granted — LocationTrackingService should run instead")
            stopSelf()
            return START_NOT_STICKY
        }

        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        if (BackgroundGuard.hasFlutterAuthToken(this)) {
            Handler(Looper.getMainLooper()).postDelayed({
                BackgroundGuard.ensureRunning(applicationContext)
            }, 800L)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                "EMI account protection",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Keeps Fasst Pay active in background for EMI security and admin alerts"
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
            1,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Fasst Pay active")
            .setContentText("Background protection on. Allow location in app for full account security.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pending)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    companion object {
        private const val TAG = "SessionKeepAliveSvc"
        const val ACTION_START = "com.rohit.emilockercustomer.session.START"
        const val ACTION_STOP = "com.rohit.emilockercustomer.session.STOP"
        private const val NOTIFICATION_ID = 91003
        private const val CHANNEL_ID = "session_keepalive_channel"

        fun start(context: Context) {
            if (!BackgroundGuard.hasFlutterAuthToken(context)) return
            if (LocationTrackingService.hasLocationPermission(context)) return
            val intent = Intent(context, SessionKeepAliveService::class.java).apply { action = ACTION_START }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, SessionKeepAliveService::class.java).apply { action = ACTION_STOP }
            context.startService(intent)
        }
    }
}
