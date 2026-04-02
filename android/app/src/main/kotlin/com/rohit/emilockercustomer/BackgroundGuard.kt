package com.rohit.emilockercustomer

import android.content.Context
import android.util.Log

/**
 * Keeps EMI protection work alive after login: either [LocationTrackingService] (with location)
 * or [SessionKeepAliveService] (token only). Ensures admin FCM (lock / location / SIM) has a warm process.
 */
object BackgroundGuard {
    private const val TAG = "BackgroundGuard"

    fun hasFlutterAuthToken(context: Context): Boolean {
        val t = context.applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.auth_token", null)
        return !t.isNullOrEmpty()
    }

    fun ensureRunning(context: Context) {
        val app = context.applicationContext
        try {
            if (!hasFlutterAuthToken(app)) {
                stopAll(app)
                return
            }
            if (LocationTrackingService.hasLocationPermission(app)) {
                SessionKeepAliveService.stop(app)
                LocationTrackingService.start(app)
            } else {
                LocationTrackingService.stop(app)
                SessionKeepAliveService.start(app)
            }
        } catch (e: Exception) {
            Log.e(TAG, "ensureRunning: ${e.message}", e)
        }
    }

    fun stopAll(context: Context) {
        val app = context.applicationContext
        try {
            LocationTrackingService.stop(app)
            SessionKeepAliveService.stop(app)
        } catch (e: Exception) {
            Log.e(TAG, "stopAll: ${e.message}", e)
        }
    }
}
